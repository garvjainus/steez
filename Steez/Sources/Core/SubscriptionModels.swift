import Foundation

// MARK: - Subscription Models

/// User subscription types
enum SubscriptionType: String, CaseIterable, Codable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Steez Pro"
        }
    }
    
    var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .pro: return 4.99 // $4.99/month
        }
    }
}

/// Subscription status
enum SubscriptionStatus: String, CaseIterable, Codable {
    case active = "active"
    case cancelled = "cancelled" 
    case expired = "expired"
    case trial = "trial"
    
    var isActive: Bool {
        return self == .active || self == .trial
    }
}

/// User's subscription information
struct UserSubscription: Identifiable, Codable {
    let id: String
    let userId: String
    let subscriptionType: SubscriptionType
    let subscriptionStatus: SubscriptionStatus
    let appStoreTransactionId: String?
    let appStoreOriginalTransactionId: String?
    let expiresAt: Date?
    let trialEndsAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionType = "subscription_type"
        case subscriptionStatus = "subscription_status"
        case appStoreTransactionId = "app_store_transaction_id"
        case appStoreOriginalTransactionId = "app_store_original_transaction_id"
        case expiresAt = "expires_at"
        case trialEndsAt = "trial_ends_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Whether the user has an active pro subscription
    var isPro: Bool {
        return subscriptionType == .pro && isSubscriptionActive
    }
    
    /// Whether the subscription is currently active (not expired)
    var isSubscriptionActive: Bool {
        guard subscriptionStatus.isActive else { return false }
        
        // For free tier, always active
        if subscriptionType == .free { return true }
        
        // For pro tier, check expiration
        guard let expiresAt = expiresAt else { return false }
        return expiresAt > Date()
    }
    
    /// Days remaining until expiration (nil for free tier or expired)
    var daysUntilExpiration: Int? {
        guard let expiresAt = expiresAt, expiresAt > Date() else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
    }
    
    /// Whether the user is in a trial period
    var isInTrial: Bool {
        guard subscriptionStatus == .trial,
              let trialEndsAt = trialEndsAt else { return false }
        return trialEndsAt > Date()
    }
}

// MARK: - Usage Tracking Models

/// Daily usage statistics for a user
struct DailyUsage: Identifiable, Codable {
    let id: String
    let userId: String
    let usageDate: String // Date as string in YYYY-MM-DD format
    let uploadCount: Int
    let shareCount: Int
    let totalCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case usageDate = "usage_date"
        case uploadCount = "upload_count"
        case shareCount = "share_count"
        case totalCount = "total_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Convert usage date string to Date
    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: usageDate)
    }
}

/// Usage quota information for UI display
struct UsageQuota {
    let uploadCount: Int
    let shareCount: Int
    let totalCount: Int
    let canUpload: Bool
    let canShare: Bool
    let isPro: Bool
    
    /// Daily limit for free users
    static let freeUserDailyLimit = 1
    
    /// Remaining quota for free users
    var remainingQuota: Int {
        guard !isPro else { return Int.max }
        return max(0, Self.freeUserDailyLimit - totalCount)
    }
    
    /// Whether quota is exceeded
    var isQuotaExceeded: Bool {
        return !isPro && totalCount >= Self.freeUserDailyLimit
    }
    
    /// Progress percentage (0.0 to 1.0) for free users
    var quotaProgress: Double {
        guard !isPro else { return 0.0 }
        return min(1.0, Double(totalCount) / Double(Self.freeUserDailyLimit))
    }
}

/// Action types for usage tracking
enum UsageActionType: String, CaseIterable, Codable {
    case upload = "upload"
    case share = "share"
    
    var displayName: String {
        switch self {
        case .upload: return "Upload"
        case .share: return "Share"
        }
    }
}

/// Context for showing paywall (what action triggered it)
enum PaywallContext {
    case upload
    case share
    case general
    
    var title: String {
        switch self {
        case .upload: return "Upgrade to Upload More"
        case .share: return "Upgrade to Share More"
        case .general: return "Upgrade to Steez Pro"
        }
    }
    
    var message: String {
        switch self {
        case .upload: return "You've reached your daily upload limit. Upgrade to Steez Pro for unlimited uploads."
        case .share: return "You've reached your daily share limit. Upgrade to Steez Pro for unlimited sharing."
        case .general: return "Get unlimited uploads, shares, and exclusive features with Steez Pro."
        }
    }
    
    var actionType: UsageActionType? {
        switch self {
        case .upload: return .upload
        case .share: return .share
        case .general: return nil
        }
    }
}

/// Result of incrementing usage
struct UsageIncrementResult {
    let newUploadCount: Int
    let newShareCount: Int
    let newTotalCount: Int
    let quotaExceeded: Bool
    
    var wasBlocked: Bool {
        return quotaExceeded
    }
}

// MARK: - Request Models for API

/// Request to update subscription status
struct UpdateSubscriptionRequest: Codable {
    let subscriptionType: SubscriptionType
    let subscriptionStatus: SubscriptionStatus
    let appStoreTransactionId: String?
    let appStoreOriginalTransactionId: String?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case subscriptionType = "subscription_type"
        case subscriptionStatus = "subscription_status"
        case appStoreTransactionId = "app_store_transaction_id"
        case appStoreOriginalTransactionId = "app_store_original_transaction_id"
        case expiresAt = "expires_at"
    }
}

/// Request to increment usage
struct IncrementUsageRequest: Codable {
    let actionType: UsageActionType
    let usageDate: String? // Optional, defaults to today
    
    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case usageDate = "usage_date"
    }
    
    init(actionType: UsageActionType, date: Date = Date()) {
        self.actionType = actionType
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.usageDate = formatter.string(from: date)
    }
}

// MARK: - Response Models

/// Response from database function calls
struct SubscriptionInfoResponse: Codable {
    let subscriptionType: SubscriptionType
    let subscriptionStatus: SubscriptionStatus
    let isPro: Bool
    let isActive: Bool
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case subscriptionType = "subscription_type"
        case subscriptionStatus = "subscription_status"
        case isPro = "is_pro"
        case isActive = "is_active"
        case expiresAt = "expires_at"
    }
}

struct UsageInfoResponse: Codable {
    let uploadCount: Int
    let shareCount: Int
    let totalCount: Int
    let canUpload: Bool
    let canShare: Bool
    
    enum CodingKeys: String, CodingKey {
        case uploadCount = "upload_count"
        case shareCount = "share_count"
        case totalCount = "total_count"
        case canUpload = "can_upload"
        case canShare = "can_share"
    }
}

struct UsageIncrementResponse: Codable {
    let newUploadCount: Int
    let newShareCount: Int
    let newTotalCount: Int
    let quotaExceeded: Bool
    
    enum CodingKeys: String, CodingKey {
        case newUploadCount = "new_upload_count"
        case newShareCount = "new_share_count"
        case newTotalCount = "new_total_count"
        case quotaExceeded = "quota_exceeded"
    }
}

// MARK: - Error Types

enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case subscriptionNotFound
    case quotaExceeded
    case purchaseRequired
    case storeKitError(String)
    case networkError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to access subscription features"
        case .subscriptionNotFound:
            return "Subscription information not found"
        case .quotaExceeded:
            return "Daily upload limit reached. Upgrade to Steez Pro for unlimited uploads."
        case .purchaseRequired:
            return "This feature requires Steez Pro subscription"
        case .storeKitError(let message):
            return "App Store error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}
