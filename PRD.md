# Steez – Product Requirements Document (PRD)

_Last updated: 2025-06-26_

## 1. Product Vision
Send any fashion image or video to **Steez**; it instantly spots every garment, finds the cheapest legit sellers, drops each piece into your digital wardrobe, and lets you buy in one tap.

## 2. Goals & Success Metrics
• < 5 s P95 latency from upload → results (image); < 15 s for ≤15 s videos.  
• ≥ 85 % correct garment & brand recognition vs. human-labelled baseline.  
• ≥ 70 % of detected items have at least one in-stock seller link.  
• ≤ $0.03 infra cost per import (image) and ≤ $0.10 per 15 s video.  
• Day-7 retention > 40 % for private beta cohort.

## 3. Personas
1. **Hype Shopper** – buys streetwear drops, wants the best deal fast.  
2. **Fashion Curator** – organises looks, tracks prices, shares boards.  
3. **Casual Browser** – snaps outfits for inspiration, occasional buyer.

## 4. Core User Flows
1. **Quick Snap & Match (MVP)**  
   • User opens app → camera → snaps photo.  
   • Image uploaded; backend runs Gemini Vision ➞ eBay match ➞ returns ≤5 links/garment.  
   • User taps a seller link → redirected to in-app Safari.
2. **Share-Extension Import (v1.1)**  
   • User shares TikTok/IG video to Steez extension.  
   • Backend downloads & frames at 2 fps → detects items → matches sellers → returns ImportResult.  
   • User reviews & accepts items into wardrobe.
3. **Wardrobe Browse (v1.2)**  
   • Local Realm cache synced bi-directionally with **Supabase Postgres** via the iOS Supabase Swift client (realtime subscriptions).  
   • User views items grouped by category; price charts & alerts.
4. **Price Refresh Job (v1.3)** – nightly Cloud Run cron re-queries sellers, pushes cheaper price alerts.

## 5. Feature List (Roadmap)
• Google Gemini Vision garment segmentation & attributes.  
• Dynamic eBay seller search with OAuth 2 token cache.  
• Size & country preferences onboarding (Core Location).  
• Multiple seller cards UI (horizontal scroll).  
• Share-extension for social videos.  
• Wardrobe database & analytics.  
• Pro subscription: unlimited imports, historical price graph, price-drop alerts.  
• Outfit generator (GPT-4o) – _stretch_.

## 6. System Design
### 6.1 High-Level Diagram
`iOS App` ⇄ `Supabase PostgREST / Realtime` & `Storage`  
⇅ auth via **Supabase Auth (JWT, Apple Sign-in)**  
⬆ image/video multipart to `Supabase Storage (uploads bucket)`  
➡ heavy compute to `Gemini Vision` & `eBay Match` microservices (NestJS) which persist results back to Supabase.

### 6.2 iOS Front-end
• Swift 5.10, SwiftUI, MVVM-C.  
• Network: `URLSession` + async/await (multi-part upload with size & country params).  
• State: `AppState` (ObservableObject) – userSize, userCountry, hasOnboarded.  
• Local cache: RealmSwift (wardrobe items, ImportJobs).

### 6.3 Backend (Node 18 / NestJS)
Modules:
1. **UploadModule** – POST `/upload` multipart image/video; streams file directly to **Supabase Storage** `uploads/` bucket and returns the public URL.
2. **GeminiVisionService** – lazy-loads env, calls Google AI Gemini Vision 1.5 Flash function calling; persists <ClothingSegment[]> rows into `clothing_segments` table.
3. **EbayService** – runtime endpoint (sandbox/prod); 2-hour in-mem OAuth token cache; `searchEbay(phrase, size, country) → MatchResult[]` (≤5) and bulk insert into `ebay_matches` table.
4. **ImportJobModule** (phase 2) – orchestrates video download, frame sampling, Vision calls; writes status rows in `import_jobs`.
5. **CronModule** – nightly price refresh (implemented as **Supabase Edge Function (Deno)** scheduled via the Supabase dashboard).

### 6.4 Data Models (Supabase Postgres)
Tables with row-level security (RLS) per `auth.uid()`:
`users`, `wardrobe_items`, `product_links`, `import_jobs`, `clothing_segments`, `ebay_matches` (see Appendix A).

### 6.5 Non-Functional
• Security: HTTPS only, **Supabase Auth JWT** with RLS, least-privilege service roles.  
• Scalability: Supabase Postgres (managed read replicas) & auto-scaling Edge Functions; stateless NestJS services on Fly.io.  
• Observability: Supabase Logs & Stats, pgAudit, Sentry (iOS + backend).  
• CI/CD: GitHub Actions → unit tests (Jest/XCTest) → `supabase db push && supabase functions deploy` → TestFlight.

## 7. Open Questions
• Additional auth providers needed beyond Supabase (Google, Discord?).  
• Where to host heavy ML microservices (supabase functions vs. Cloud Run).  
• Video processing infra: GPU Lambda vs. Cloud Run + NVIDIA.  
• Payment rails for Pro subscription (RevenueCat vs. StoreKit2 direct).  
• Additional retailers besides eBay – ShopStyle, Amazon, GOAT?

## 8. Milestones
| Date | Version | Scope |
|------|---------|-------|
| 2025-07-15 | v0.9 Alpha | Photo import, Gemini + eBay, 1-tap buy link |
| 2025-08-15 | v1.0 Beta  | Share-extension import, size/country prefs, multiple seller UI |
| 2025-09-30 | v1.1 GA    | Wardrobe, price refresh, Pro subscription |

## Appendix A – Data Schemas (Typescript)
```ts
export interface ClothingSegment {
  label: string;        // "Hoodie" / brand if available
  boundingBox: number[]; // [x1, y1, x2, y2]
  color?: string;
  ebayMatches: MatchResult[]; // ≤5 sellers
}

export interface MatchResult {
  title: string;
  price: number;
  currency: string;
  imageUrl: string;
  permalink: string;
}
```

---
This PRD supersedes `steez_requirements.json`. 