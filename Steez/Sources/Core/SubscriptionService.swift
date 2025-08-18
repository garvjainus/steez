import Foundation
import Supabase

// MARK: - Subscription Service
/// Service for managing user subscriptions and App Store integration
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    private let supabase = SupabaseService.shared.client
    
    /// Published subscription state for UI binding
    @Published var currentSubscription: UserSubscription?
    @Published var isLoading = false
    @Published var error: Error?
    
    /// Quick access to subscription status
    @Published var isPro = false
    @Published var isSubscriptionActive = false
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get current user's subscription information
    func fetchSubscription() async throws -> UserSubscription? {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            
            // First try to get existing subscription
            let subscriptions: [UserSubscription] = try await supabase
                .from("user_subscriptions")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            let subscription: UserSubscription
            
            if let existingSubscription = subscriptions.first {
                subscription = existingSubscription
            } else {
                // Create default free subscription if none exists
                subscription = try await createDefaultSubscription(for: userId)
            }
            
            await updateSubscriptionState(subscription)
            await clearError()
            
            return subscription
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Update subscription status (called after successful purchase)
    func updateSubscription(
        type: SubscriptionType,
        status: SubscriptionStatus,
        transactionId: String? = nil,
        originalTransactionId: String? = nil,
        expiresAt: Date? = nil
    ) async throws {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            
            let updateRequest = UpdateSubscriptionRequest(
                subscriptionType: type,
                subscriptionStatus: status,
                appStoreTransactionId: transactionId,
                appStoreOriginalTransactionId: originalTransactionId,
                expiresAt: expiresAt
            )
            
            let updatedSubscriptions: [UserSubscription] = try await supabase
                .from("user_subscriptions")
                .update(updateRequest)
                .eq("user_id", value: userId)
                .select()
                .execute()
                .value
            
            guard let updatedSubscription = updatedSubscriptions.first else {
                throw SubscriptionError.validationError("Failed to update subscription")
            }
            
            await updateSubscriptionState(updatedSubscription)
            await clearError()
            
            print("✅ Subscription updated: \(type.displayName) - \(status.rawValue)")
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Check if user has an active pro subscription
    func hasActivePro() async throws -> Bool {
        let subscription = try await fetchSubscription()
        return subscription?.isPro ?? false
    }
    
    /// Get subscription info for quota checking
    func getSubscriptionInfo() async throws -> SubscriptionInfoResponse {
        guard await isUserAuthenticated() else {
            throw SubscriptionError.notAuthenticated
        }
        
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
    
    /// Cancel subscription (mark as cancelled but keep until expiration)
    func cancelSubscription() async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        // Don't cancel free subscriptions
        guard subscription.subscriptionType == .pro else {
            throw SubscriptionError.validationError("Cannot cancel free subscription")
        }
        
        try await updateSubscription(
            type: .pro,
            status: .cancelled,
            transactionId: subscription.appStoreTransactionId,
            originalTransactionId: subscription.appStoreOriginalTransactionId,
            expiresAt: subscription.expiresAt
        )
    }
    
    /// Restore subscription (reactivate if valid)
    func restoreSubscription() async throws {
        // TODO: Implement StoreKit restore purchases
        // For now, just refresh current subscription
        _ = try await fetchSubscription()
        print("🔄 Subscription restore requested - StoreKit integration needed")
    }
    
    /// Refresh subscription state (useful after app store changes)
    func refreshSubscription() async {
        do {
            _ = try await fetchSubscription()
        } catch {
            print("❌ Failed to refresh subscription: \(error)")
        }
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
    
    private func createDefaultSubscription(for userId: String) async throws -> UserSubscription {
        let defaultSubscription = [
            "user_id": userId,
            "subscription_type": SubscriptionType.free.rawValue,
            "subscription_status": SubscriptionStatus.active.rawValue
        ]
        
        let createdSubscriptions: [UserSubscription] = try await supabase
            .from("user_subscriptions")
            .insert(defaultSubscription)
            .select()
            .execute()
            .value
        
        guard let subscription = createdSubscriptions.first else {
            throw SubscriptionError.validationError("Failed to create default subscription")
        }
        
        return subscription
    }
    
    @MainActor
    private func updateSubscriptionState(_ subscription: UserSubscription) {
        self.currentSubscription = subscription
        self.isPro = subscription.isPro
        self.isSubscriptionActive = subscription.isSubscriptionActive
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
    
    /// Clear all subscription data (for sign out)
    func clearAllData() async {
        await MainActor.run {
            currentSubscription = nil
            isPro = false
            isSubscriptionActive = false
            error = nil
            isLoading = false
        }
    }
}

// MARK: - Extension for Paywall Integration

extension SubscriptionService {
    
    /// Check if user should see paywall for a specific action
    func shouldShowPaywall(for actionType: UsageActionType) async -> Bool {
        do {
            // If user is pro, never show paywall
            if try await hasActivePro() {
                return false
            }
            
            // Check if user has quota remaining
            let canPerform = try await UsageTrackingService.shared.canPerformAction(actionType)
            return !canPerform
        } catch {
            // If there's an error checking, err on the side of showing paywall
            return true
        }
    }
    
    /// Get user-friendly subscription status message
    var subscriptionStatusMessage: String {
        guard let subscription = currentSubscription else {
            return "Free Plan - 1 upload per day"
        }
        
        switch subscription.subscriptionType {
        case .free:
            return "Free Plan - 1 upload per day"
        case .pro:
            if subscription.isSubscriptionActive {
                if let daysRemaining = subscription.daysUntilExpiration {
                    return "Steez Pro - \(daysRemaining) days remaining"
                } else {
                    return "Steez Pro - Active"
                }
            } else {
                return "Steez Pro - Expired"
            }
        }
    }
    
    /// Get benefits text for current subscription
    var currentBenefits: [String] {
        guard let subscription = currentSubscription else {
            return ["1 upload per day", "Access to wardrobe", "Basic analysis"]
        }
        
        switch subscription.subscriptionType {
        case .free:
            return [
                "1 upload per day",
                "Access to wardrobe", 
                "Basic analysis"
            ]
        case .pro:
            return [
                "Unlimited uploads",
                "Unlimited shares",
                "Priority processing",
                "Advanced analytics",
                "Export capabilities",
                "Early access to new features"
            ]
        }
    }
}

// MARK: - Debug and Testing Helpers

#if DEBUG
extension SubscriptionService {
    
    /// Simulate pro subscription (for testing)
    func simulateProSubscription() async {
        let mockSubscription = UserSubscription(
            id: UUID().uuidString,
            userId: "test-user",
            subscriptionType: .pro,
            subscriptionStatus: .active,
            appStoreTransactionId: "test-transaction",
            appStoreOriginalTransactionId: "test-original",
            expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            trialEndsAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await updateSubscriptionState(mockSubscription)
        print("🧪 Simulated Pro subscription")
    }
    
    /// Simulate free subscription (for testing)
    func simulateFreeSubscription() async {
        let mockSubscription = UserSubscription(
            id: UUID().uuidString,
            userId: "test-user",
            subscriptionType: .free,
            subscriptionStatus: .active,
            appStoreTransactionId: nil,
            appStoreOriginalTransactionId: nil,
            expiresAt: nil,
            trialEndsAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await updateSubscriptionState(mockSubscription)
        print("🧪 Simulated Free subscription")
    }
    
    /// Simulate expired subscription (for testing)
    func simulateExpiredSubscription() async {
        let mockSubscription = UserSubscription(
            id: UUID().uuidString,
            userId: "test-user",
            subscriptionType: .pro,
            subscriptionStatus: .expired,
            appStoreTransactionId: "test-transaction",
            appStoreOriginalTransactionId: "test-original",
            expiresAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            trialEndsAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await updateSubscriptionState(mockSubscription)
        print("🧪 Simulated Expired subscription")
    }
}
#endif
