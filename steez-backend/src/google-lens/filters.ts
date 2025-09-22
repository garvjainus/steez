/*
  Heuristics to score and filter Google Lens results for apparel relevance.
  Standalone, unit-testable functions. Keep free of NestJS dependencies.
*/

export interface LensLikeItem {
  title?: string;
  link?: string;
  source?: string;
  category?: string;
  price?: any;
  thumbnail?: string;
  image?: string;
  position?: number;
}

const FASHION_KEYWORDS = [
  'shirt', 't-shirt', 't shirt', 'tee', 'jersey', 'jacket', 'hoodie', 'jeans',
  'pants', 'chinos', 'trousers', 'skirt', 'dress', 'sweater', 'cardigan', 'coat', 'blazer',
  'suit', 'socks', 'hat', 'cap', 'beanie', 'shoe', 'sneaker', 'boot', 'loafer', 'sandal',
  'shorts', 'scarf', 'gloves', 'underwear', 'bra', 'lingerie', 'belt', 'apparel', 'clothing',
  'fashion', 'wear', 'outfit', 'style',
  // materials/patterns often on titles of clothing
  'denim', 'cotton', 'wool', 'leather', 'suede', 'silk', 'nylon', 'polyester',
  'checked', 'plaid', 'striped', 'ribbed', 'graphic', 'logo'
];

const EXCLUDE_KEYWORDS = [
  '#fyp', '#dancechallenge', '#trend', '#viral', '#foryou', 'tiktok', 'instagram',
  'music', 'remix', 'lyrics', 'meme', 'funny', 'challenge', 'compilation'
];

const FASHION_CATEGORY_HINTS = [
  'apparel', 'clothing', 'clothes', 'shoes', 'footwear', 'accessories', 'fashion', 'bags'
];

const INCLUDE_DOMAINS = new Set<string>([
  'amazon.com', 'amazon.co.uk', 'ebay.com', 'etsy.com', 'nike.com', 'adidas.com', 'zara.com',
  'hm.com', 'uniqlo.com', 'gap.com', 'oldnavy.gap.com', 'urbanoutfitters.com', 'asos.com',
  'farfetch.com', 'ssense.com', 'stockx.com', 'grailed.com', 'therealreal.com', 'poshmark.com',
  'dickssportinggoods.com', 'footlocker.com', 'finishline.com', 'jdSports.com', 'macys.com',
  'nordstrom.com', 'bloomingdales.com', 'saksfifthavenue.com', 'mrporter.com', 'net-a-porter.com',
]);

const EXCLUDE_DOMAINS = new Set<string>([
  'tiktok.com', 'instagram.com', 'youtu.be', 'youtube.com', 'twitter.com', 'x.com', 'reddit.com',
  'news', 'blogspot.com'
]);

export function parseDomain(url?: string): string | null {
  if (!url) return null;
  try {
    const u = new URL(url);
    return u.hostname.toLowerCase();
  } catch {
    return null;
  }
}

export function isFashionDomain(hostname: string | null): boolean {
  if (!hostname) return false;
  if (INCLUDE_DOMAINS.has(hostname)) return true;
  // Broad heuristics for regional subdomains and known retailers
  const known = [
    'nike.', 'adidas.', 'puma.', 'reebok.', 'newbalance.', 'hoka.', 'converse.', 'vans.',
    'uniqlo.', 'zara.', 'hm.', 'gap.', 'oldnavy.', 'shein.', 'temu.', 'asos.', 'farfetch.',
    'ssense.', 'stockx.', 'grailed.', 'poshmark.', 'therealreal.', 'footlocker.', 'finishline.',
    'macys.', 'nordstrom.', 'saks', 'bloomingdales.', 'mrporter.', 'net-a-porter.', 'urbanoutfitters.'
  ];
  return known.some((k) => hostname.includes(k));
}

export function isExcludedDomain(hostname: string | null): boolean {
  if (!hostname) return false;
  if (EXCLUDE_DOMAINS.has(hostname)) return true;
  // Exclude obvious non-commerce hosts
  const excluded = ['tiktok.', 'instagram.', 'youtube.', 'youtu.', 'twitter.', 'x.', 'reddit.'];
  return excluded.some((k) => hostname.includes(k));
}

export function scoreFashionRelevance(item: LensLikeItem): number {
  let score = 0;
  const title = (item.title || '').toLowerCase();
  const category = (item.category || '').toLowerCase();
  const source = (item.source || '').toLowerCase();
  const hostname = parseDomain(item.link);

  // Positive signals
  for (const kw of FASHION_KEYWORDS) {
    if (title.includes(kw)) score += 2;
  }
  for (const cat of FASHION_CATEGORY_HINTS) {
    if (category.includes(cat)) score += 3;
  }
  if (isFashionDomain(hostname)) score += 4;
  if (/shop|store|boutique|official/.test(source)) score += 1;
  if (item.price) score += 1;
  if (item.thumbnail || item.image) score += 1;

  // Negative signals
  for (const bad of EXCLUDE_KEYWORDS) {
    if (title.includes(bad)) score -= 3;
  }
  if (isExcludedDomain(hostname)) score -= 5;

  // Titles that are mostly hashtags or too short likely not products
  const words = title.split(/\s+/).filter(Boolean);
  const hashtags = words.filter((w) => w.startsWith('#')).length;
  if (words.length > 0 && hashtags / words.length > 0.4) score -= 2;
  if (title.replace(/[^a-z0-9]/g, '').length < 6) score -= 1;

  return score;
}

export function normalizeCandidates(
  visualMatches: LensLikeItem[],
  shoppingResults: LensLikeItem[],
): LensLikeItem[] {
  // Some shopping results may have slightly different field names; keep as-is for scoring which is tolerant
  const items: LensLikeItem[] = [];
  for (const v of visualMatches || []) items.push(v);
  for (const s of shoppingResults || []) items.push(s);
  return items;
}


