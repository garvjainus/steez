import SwiftUI

// MARK: - Usage Quota Widget
/// Compact widget to show user's daily quota status
struct UsageQuotaWidget: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var usageService = UsageTrackingService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Quota circle indicator
            QuotaCircleView(quota: usageService.currentQuota)
            
            // Quota info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(quotaTitle)
                        .font(SteezFonts.medium(12))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    if let quota = usageService.currentQuota, quota.isPro {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(SteezColors.accent)
                    }
                }
                
                Text(quotaDescription)
                    .font(SteezFonts.regular(10))
                    .foregroundColor(SteezColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Upgrade button for free users near quota
            if shouldShowUpgradeButton {
                Button("Upgrade") {
                    Task {
                        await appState.showPaywall(for: .general)
                    }
                }
                .font(SteezFonts.medium(10))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [SteezColors.primary, SteezColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SteezColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(quotaBorderColor, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onAppear {
            Task {
                await usageService.refreshQuota()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var quotaTitle: String {
        guard let quota = usageService.currentQuota else {
            return "Loading..."
        }
        
        if quota.isPro {
            return "Pro Member"
        } else {
            return "Daily Usage: \(quota.totalCount)/\(UsageQuota.freeUserDailyLimit)"
        }
    }
    
    private var quotaDescription: String {
        guard let quota = usageService.currentQuota else {
            return "Checking quota..."
        }
        
        if quota.isPro {
            return "Unlimited uploads and shares"
        } else if quota.isQuotaExceeded {
            return "Daily limit reached"
        } else {
            let remaining = quota.remainingQuota
            return "\(remaining) upload\(remaining == 1 ? "" : "s") remaining today"
        }
    }
    
    private var quotaBorderColor: Color {
        guard let quota = usageService.currentQuota else {
            return Color.clear
        }
        
        if quota.isPro {
            return SteezColors.accent.opacity(0.3)
        } else if quota.isQuotaExceeded {
            return .red.opacity(0.3)
        } else if quota.quotaProgress > 0.7 {
            return .orange.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var shouldShowUpgradeButton: Bool {
        guard let quota = usageService.currentQuota else { return false }
        return !quota.isPro && (quota.quotaProgress > 0.5 || quota.isQuotaExceeded)
    }
}

// MARK: - Quota Circle View

struct QuotaCircleView: View {
    let quota: UsageQuota?
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(SteezColors.surface, lineWidth: 3)
                .frame(width: 24, height: 24)
            
            // Progress circle
            if let quota = quota {
                Circle()
                    .trim(from: 0, to: quota.isPro ? 1.0 : quota.quotaProgress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: quota.quotaProgress)
            }
            
            // Center icon
            Image(systemName: centerIcon)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(iconColor)
        }
    }
    
    private var progressColor: Color {
        guard let quota = quota else { return SteezColors.primary }
        
        if quota.isPro {
            return SteezColors.accent
        } else if quota.isQuotaExceeded {
            return .red
        } else if quota.quotaProgress > 0.7 {
            return .orange
        } else {
            return SteezColors.primary
        }
    }
    
    private var centerIcon: String {
        guard let quota = quota else { return "hourglass" }
        
        if quota.isPro {
            return "crown.fill"
        } else if quota.isQuotaExceeded {
            return "exclamationmark"
        } else {
            return "arrow.up"
        }
    }
    
    private var iconColor: Color {
        guard let quota = quota else { return SteezColors.textSecondary }
        
        if quota.isPro {
            return SteezColors.accent
        } else if quota.isQuotaExceeded {
            return .red
        } else {
            return SteezColors.primary
        }
    }
}

// MARK: - Expanded Usage View

struct UsageQuotaDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var usageService = UsageTrackingService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Usage & Subscription")
                    .font(SteezFonts.medium(18))
                    .foregroundColor(SteezColors.textPrimary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await usageService.refreshQuota()
                        await subscriptionService.refreshSubscription()
                    }
                }
                .font(SteezFonts.medium(12))
                .foregroundColor(SteezColors.primary)
            }
            
            if let quota = usageService.currentQuota {
                // Current subscription status
                SubscriptionStatusCard(quota: quota)
                
                // Usage breakdown
                if !quota.isPro {
                    UsageBreakdownView(quota: quota)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if !quota.isPro {
                        Button("Upgrade to Pro") {
                            Task {
                                await appState.showPaywall(for: .general)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    Button("Manage Subscription") {
                        // TODO: Show subscription management
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                // Loading state
                ProgressView("Loading usage data...")
                    .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
            }
        }
        .padding()
        .onAppear {
            Task {
                await usageService.refreshQuota()
                await subscriptionService.refreshSubscription()
            }
        }
    }
}

// MARK: - Subscription Status Card

struct SubscriptionStatusCard: View {
    let quota: UsageQuota
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: quota.isPro ? "crown.fill" : "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(quota.isPro ? SteezColors.accent : SteezColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(quota.isPro ? "Steez Pro" : "Free Plan")
                        .font(SteezFonts.medium(16))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text(subscriptionService.subscriptionStatusMessage)
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Benefits list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(subscriptionService.currentBenefits, id: \.self) { benefit in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(quota.isPro ? SteezColors.accent : SteezColors.primary)
                        
                        Text(benefit)
                            .font(SteezFonts.regular(12))
                            .foregroundColor(SteezColors.textSecondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(SteezColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(quota.isPro ? SteezColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Usage Breakdown View

struct UsageBreakdownView: View {
    let quota: UsageQuota
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(SteezFonts.medium(14))
                .foregroundColor(SteezColors.textPrimary)
            
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Daily Quota")
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(quota.totalCount) / \(UsageQuota.freeUserDailyLimit)")
                        .font(SteezFonts.medium(12))
                        .foregroundColor(SteezColors.textPrimary)
                }
                
                ProgressView(value: quota.quotaProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: quota.isQuotaExceeded ? .red : SteezColors.primary))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            
            // Usage details
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(quota.uploadCount)")
                        .font(SteezFonts.medium(16))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("Uploads")
                        .font(SteezFonts.regular(10))
                        .foregroundColor(SteezColors.textSecondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(quota.shareCount)")
                        .font(SteezFonts.medium(16))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("Shares")
                        .font(SteezFonts.regular(10))
                        .foregroundColor(SteezColors.textSecondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(quota.remainingQuota)")
                        .font(SteezFonts.medium(16))
                        .foregroundColor(quota.remainingQuota > 0 ? SteezColors.primary : .red)
                    
                    Text("Remaining")
                        .font(SteezFonts.regular(10))
                        .foregroundColor(SteezColors.textSecondary)
                }
            }
        }
        .padding(16)
        .background(SteezColors.cardBackground)
        .cornerRadius(12)
    }
}

#if DEBUG
struct UsageQuotaWidget_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            UsageQuotaWidget()
            
            UsageQuotaDetailView()
        }
        .padding()
        .environmentObject(AppState())
    }
}
#endif
