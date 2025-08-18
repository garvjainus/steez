import Foundation
import Supabase

// MARK: - Usage Tracking Service
/// Service for managing daily usage quotas and subscription-based limits
class UsageTrackingService: ObservableObject {
    static let shared = UsageTrackingService()
    
    private let supabase = SupabaseService.shared.client
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Published usage quota for UI binding
    @Published var currentQuota: UsageQuota?
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if user can perform an action and get current quota
    func checkQuota(for actionType: UsageActionType, date: Date = Date()) async throws -> UsageQuota {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            let dateString = dateFormatter.string(from: date)
            
            // Call the database function to get usage info
            let response: [UsageInfoResponse] = try await supabase
                .rpc("get_user_daily_usage", params: [
                    "user_uuid": userId,
                    "check_date": dateString
                ])
                .execute()
                .value
            
            guard let usageInfo = response.first else {
                throw SubscriptionError.validationError("Failed to get usage information")
            }
            
            // Get subscription info to determine if user is pro
            let subscriptionInfo = try await getSubscriptionInfo()
            
            let quota = UsageQuota(
                uploadCount: usageInfo.uploadCount,
                shareCount: usageInfo.shareCount,
                totalCount: usageInfo.totalCount,
                canUpload: usageInfo.canUpload,
                canShare: usageInfo.canShare,
                isPro: subscriptionInfo.isPro
            )
            
            await setQuota(quota)
            await clearError()
            
            return quota
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Attempt to perform an action (upload/share) and increment usage
    func performAction(_ actionType: UsageActionType, date: Date = Date()) async throws -> UsageIncrementResult {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            let dateString = dateFormatter.string(from: date)
            
            // Call the database function to increment usage
            let response: [UsageIncrementResponse] = try await supabase
                .rpc("increment_user_usage", params: [
                    "user_uuid": userId,
                    "action_type": actionType.rawValue,
                    "input_date": dateString
                ])
                .execute()
                .value
            
            guard let incrementResult = response.first else {
                throw SubscriptionError.validationError("Failed to increment usage")
            }
            
            let result = UsageIncrementResult(
                newUploadCount: incrementResult.newUploadCount,
                newShareCount: incrementResult.newShareCount,
                newTotalCount: incrementResult.newTotalCount,
                quotaExceeded: incrementResult.quotaExceeded
            )
            
            // If quota was exceeded, throw error
            if result.quotaExceeded {
                await setError(SubscriptionError.quotaExceeded)
                throw SubscriptionError.quotaExceeded
            }
            
            // Update current quota
            await refreshQuota(date: date)
            await clearError()
            
            print("✅ \(actionType.displayName) action recorded. Total today: \(result.newTotalCount)")
            
            return result
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Check if user can perform an action without incrementing usage
    func canPerformAction(_ actionType: UsageActionType, date: Date = Date()) async throws -> Bool {
        let quota = try await checkQuota(for: actionType, date: date)
        
        switch actionType {
        case .upload:
            return quota.canUpload
        case .share:
            return quota.canShare
        }
    }
    
    /// Get current usage statistics for a specific date
    func getUsageStats(for date: Date = Date()) async throws -> UsageQuota {
        return try await checkQuota(for: .upload, date: date)
    }
    
    /// Refresh the current quota (useful after subscription changes)
    func refreshQuota(date: Date = Date()) async {
        do {
            _ = try await checkQuota(for: .upload, date: date)
        } catch {
            print("❌ Failed to refresh quota: \(error)")
        }
    }
    
    /// Get usage history for the past week
    func getWeeklyUsageHistory() async throws -> [DailyUsage] {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        let userId = try await getCurrentUserId()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekAgoString = dateFormatter.string(from: weekAgo)
        
        let response: [DailyUsage] = try await supabase
            .from("daily_usage")
            .select()
            .eq("user_id", value: userId)
            .gte("usage_date", value: weekAgoString)
            .order("usage_date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    /// Reset usage for a specific date (admin/testing only)
    func resetUsage(for date: Date = Date()) async throws {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        let userId = try await getCurrentUserId()
        let dateString = dateFormatter.string(from: date)
        
        try await supabase
            .from("daily_usage")
            .delete()
            .eq("user_id", value: userId)
            .eq("usage_date", value: dateString)
            .execute()
        
        await refreshQuota(date: date)
        print("✅ Usage reset for \(dateString)")
    }
    
    // MARK: - Private Helpers
    
    private func isUserAuthenticated() async -> Bool {
        do {
            _ = try await SupabaseService.shared.session()
            return true
        } catch {
            return false
        }
    }
    
    private func getCurrentUserId() async throws -> String {
        let session = try await SupabaseService.shared.session()
        return session.user.id.uuidString
    }
    
    private func getSubscriptionInfo() async throws -> SubscriptionInfoResponse {
        let userId = try await getCurrentUserId()
        
        let response: [SubscriptionInfoResponse] = try await supabase
            .rpc("get_user_subscription", params: [
                "user_uuid": userId
            ])
            .execute()
            .value
        
        guard let subscriptionInfo = response.first else {
            // Return default free subscription if none found
            return SubscriptionInfoResponse(
                subscriptionType: .free,
                subscriptionStatus: .active,
                isPro: false,
                isActive: true,
                expiresAt: nil
            )
        }
        
        return subscriptionInfo
    }
    
    @MainActor
    private func setQuota(_ quota: UsageQuota) {
        self.currentQuota = quota
    }
    
    @MainActor
    private func setLoading(_ loading: Bool) {
        self.isLoading = loading
    }
    
    @MainActor
    private func setError(_ error: Error) {
        self.error = error
    }
    
    @MainActor
    private func clearError() {
        self.error = nil
    }
    
    /// Clear all state (for sign out)
    func clearAllData() async {
        await MainActor.run {
            currentQuota = nil
            error = nil
            isLoading = false
        }
    }
}

// MARK: - Extension for Convenient Usage Checking

extension UsageTrackingService {
    
    /// Quick check if user can upload
    func canUpload(showPaywallOnFail: Bool = false) async -> Bool {
        do {
            return try await canPerformAction(.upload)
        } catch {
            if showPaywallOnFail && error is SubscriptionError {
                // TODO: Show paywall modal
                print("💰 Should show paywall for upload")
            }
            return false
        }
    }
    
    /// Quick check if user can share
    func canShare(showPaywallOnFail: Bool = false) async -> Bool {
        do {
            return try await canPerformAction(.share)
        } catch {
            if showPaywallOnFail && error is SubscriptionError {
                // TODO: Show paywall modal
                print("💰 Should show paywall for share")
            }
            return false
        }
    }
    
    /// Perform upload action with automatic paywall handling
    func recordUpload() async throws {
        do {
            _ = try await performAction(.upload)
        } catch SubscriptionError.quotaExceeded {
            // Re-throw quota exceeded specifically for paywall handling
            throw SubscriptionError.quotaExceeded
        } catch {
            throw error
        }
    }
    
    /// Perform share action with automatic paywall handling
    func recordShare() async throws {
        do {
            _ = try await performAction(.share)
        } catch SubscriptionError.quotaExceeded {
            // Re-throw quota exceeded specifically for paywall handling
            throw SubscriptionError.quotaExceeded
        } catch {
            throw error
        }
    }
}

// MARK: - Debug and Testing Helpers

#if DEBUG
extension UsageTrackingService {
    
    /// Simulate reaching quota (for testing paywall)
    func simulateQuotaReached() async {
        let mockQuota = UsageQuota(
            uploadCount: 1,
            shareCount: 0,
            totalCount: 1,
            canUpload: false,
            canShare: false,
            isPro: false
        )
        
        await setQuota(mockQuota)
        await setError(SubscriptionError.quotaExceeded)
    }
    
    /// Reset to free user with no usage (for testing)
    func simulateNewFreeUser() async {
        let mockQuota = UsageQuota(
            uploadCount: 0,
            shareCount: 0,
            totalCount: 0,
            canUpload: true,
            canShare: true,
            isPro: false
        )
        
        await setQuota(mockQuota)
        await clearError()
    }
    
    /// Simulate pro user (for testing)
    func simulateProUser() async {
        let mockQuota = UsageQuota(
            uploadCount: 5,
            shareCount: 3,
            totalCount: 8,
            canUpload: true,
            canShare: true,
            isPro: true
        )
        
        await setQuota(mockQuota)
        await clearError()
    }
}
#endif
