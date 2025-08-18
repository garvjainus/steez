import Foundation
import StoreKit

// MARK: - Unified StoreKit Manager
/// Manages App Store product information and purchases with iOS version compatibility
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    // Product IDs - these should match what's configured in App Store Connect
    struct ProductIDs {
        static let steezProMonthly = "sub001"
        static let steezProYearly = "sub002"
        // Add more products here if needed (yearly, etc.)
    }
    
    /// Available products (unified format)
    @Published var products: [StoreProduct] = []
    
    /// Current transaction state
    @Published var purchaseState: PurchaseState = .idle
    
    /// Available subscription products
    var subscriptionProducts: [StoreProduct] {
        return products.filter { $0.isSubscription }
    }
    
    /// Steez Pro monthly product
    var steezProMonthly: StoreProduct? {
        return products.first { $0.id == ProductIDs.steezProMonthly }
    }
    var steezProYearly: StoreProduct? {
        return products.first { $0.id == ProductIDs.steezProYearly }
    }
    
    // StoreKit 2 properties (iOS 15+)
    @available(iOS 15.0, *)
    private var modernProducts: [Product] = []
    
    @available(iOS 15.0, *)
    private var transactionListener: Task<Void, Error>?
    
    // StoreKit 1 properties (iOS 14 and below)
    private var legacyProducts: [SKProduct] = []
    private var productsRequest: SKProductsRequest?
    private var completionHandler: ((Bool) -> Void)?
    
    override init() {
        super.init()
        
        // Add legacy payment observer for iOS 14
        SKPaymentQueue.default().add(self)
        
        // Start modern listener for iOS 15+
        if #available(iOS 15.0, *) {
            transactionListener = listenForTransactions()
        }
        
        // Load products
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
        
        if #available(iOS 15.0, *) {
            transactionListener?.cancel()
        }
    }
    
    // MARK: - Product Loading
    
    /// Load available products from App Store
    func loadProducts() async {
        if #available(iOS 15.0, *) {
            await loadModernProducts()
        } else {
            loadLegacyProducts()
        }
    }
    
    @available(iOS 15.0, *)
    private func loadModernProducts() async {
        do {
            let productIDs = [ProductIDs.steezProMonthly, ProductIDs.steezProYearly]
            let products = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.modernProducts = products
                self.products = products.map { StoreProduct(from: $0) }
                print("✅ Loaded \(products.count) modern StoreKit products")
                
                // Debug: Print loaded products
                for product in self.products {
                    print("📦 Product: \(product.id) - \(product.displayName) - \(product.priceFormatted)")
                }
                
                // If no products loaded, create test product for development
                if self.products.isEmpty {
                    print("⚠️ No products loaded from StoreKit, creating test product for development")
                    self.createTestProduct()
                }
            }
        } catch {
            print("❌ Failed to load modern StoreKit products: \(error)")
            print("❌ Error type: \(type(of: error))")
            
            // Check if we're running in simulator
            #if targetEnvironment(simulator)
            print("⚠️ Running in simulator - App Store Connect products won't load")
            #endif
            
            await MainActor.run {
                print("⚠️ Creating test product for development due to StoreKit error")
                self.createTestProduct()
            }
        }
    }
    
    private func loadLegacyProducts() {
        let productIDs = Set([ProductIDs.steezProMonthly, ProductIDs.steezProYearly])
        productsRequest = SKProductsRequest(productIdentifiers: productIDs)
        productsRequest?.delegate = self
        productsRequest?.start()
        
        // Fallback for development - create test product after 3 seconds if no products load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.products.isEmpty {
                print("⚠️ No legacy products loaded after 3 seconds, creating test product for development")
                self.createTestProduct()
            }
        }
    }
    
    // MARK: - Test Product for Development
    
    private func createTestProduct() {
        // Create both monthly and yearly test products
        let monthlyProduct = StoreProduct(
            id: ProductIDs.steezProMonthly,
            displayName: "Steez Pro Monthly",
            description: "Unlimited uploads and shares with premium features",
            price: Decimal(4.99),
            priceFormatted: "$4.99",
            isSubscription: true
        )
        
        let yearlyProduct = StoreProduct(
            id: ProductIDs.steezProYearly,
            displayName: "Steez Pro Yearly",
            description: "Unlimited uploads and shares with premium features (yearly plan)",
            price: Decimal(19.99),
            priceFormatted: "$19.99",
            isSubscription: true
        )
        
        self.products = [monthlyProduct, yearlyProduct]
        print("✅ Created test products for development: Monthly(\(monthlyProduct.displayName)) & Yearly(\(yearlyProduct.displayName))")
    }
    
    // MARK: - Purchase Flow
    
    /// Purchase a subscription product
    func purchase(_ product: StoreProduct) async throws -> PurchaseResult {
        await setPurchaseState(.purchasing)
        
        // Handle test products for development
        if (product.id == ProductIDs.steezProMonthly && product.priceFormatted == "$4.99") || 
           (product.id == ProductIDs.steezProYearly && product.priceFormatted == "$19.99") {
            print("🧪 Simulating purchase for test product in development: \(product.displayName)")
            
            // Simulate a brief purchase delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await setPurchaseState(.purchased)
            return .success
        }
        
        if #available(iOS 15.0, *) {
            return try await purchaseModern(product)
        } else {
            return try await purchaseLegacy(product)
        }
    }
    
    @available(iOS 15.0, *)
    private func purchaseModern(_ storeProduct: StoreProduct) async throws -> PurchaseResult {
        guard let product = modernProducts.first(where: { $0.id == storeProduct.id }) else {
            throw StoreKitError.productNotFound
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update subscription in our backend
                await handleSuccessfulPurchase(transaction: transaction)
                
                // Finish the transaction
                await transaction.finish()
                
                await setPurchaseState(.purchased)
                return .success
                
            case .userCancelled:
                await setPurchaseState(.cancelled)
                return .cancelled
                
            case .pending:
                await setPurchaseState(.pending)
                return .pending
                
            @unknown default:
                await setPurchaseState(.failed("Unknown purchase result"))
                throw StoreKitError.unknownError
            }
        } catch {
            await setPurchaseState(.failed(error.localizedDescription))
            throw error
        }
    }
    
    private func purchaseLegacy(_ storeProduct: StoreProduct) async throws -> PurchaseResult {
        guard let product = legacyProducts.first(where: { $0.productIdentifier == storeProduct.id }) else {
            throw StoreKitError.productNotFound
        }
        
        guard SKPaymentQueue.canMakePayments() else {
            throw StoreKitError.purchaseNotAllowed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            completionHandler = { success in
                if success {
                    continuation.resume(returning: .success)
                } else {
                    continuation.resume(throwing: StoreKitError.unknownError)
                }
            }
            
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
    }
    
    /// Restore previous purchases
    func restore() async throws {
        await setPurchaseState(.restoring)
        
        if #available(iOS 15.0, *) {
            try await restoreModern()
        } else {
            try await restoreLegacy()
        }
    }
    
    @available(iOS 15.0, *)
    private func restoreModern() async throws {
        do {
            try await AppStore.sync()
            
            // Check for active subscriptions
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    // Update subscription in our backend
                    await handleSuccessfulPurchase(transaction: transaction)
                }
            }
            
            await setPurchaseState(.restored)
        } catch {
            await setPurchaseState(.failed(error.localizedDescription))
            throw error
        }
    }
    
    private func restoreLegacy() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            completionHandler = { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StoreKitError.unknownError)
                }
            }
            
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        if #available(iOS 15.0, *) {
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    
                    if transaction.productType == .autoRenewable {
                        // Update subscription in our backend
                        await handleSuccessfulPurchase(transaction: transaction)
                    }
                } catch {
                    print("❌ Failed to verify transaction: \(error)")
                }
            }
        }
        // Legacy version doesn't have currentEntitlements
    }
    
    // MARK: - Transaction Handling (iOS 15+)
    
    @available(iOS 15.0, *)
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.handleTransactionUpdate(transaction)
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    @available(iOS 15.0, *)
    /// Handle transaction updates
    private func handleTransactionUpdate(_ transaction: Transaction?) async {
        guard let transaction = transaction else { return }
        
        if transaction.productType == .autoRenewable {
            await handleSuccessfulPurchase(transaction: transaction)
        }
        
        await transaction.finish()
    }
    
    @available(iOS 15.0, *)
    /// Handle successful purchase by updating backend
    private func handleSuccessfulPurchase(transaction: Transaction) async {
        do {
            // Determine subscription type based on product ID
            let subscriptionType: SubscriptionType = .pro
            let expiresAt = transaction.expirationDate
            
            // Update subscription in our backend
            try await SubscriptionService.shared.updateSubscription(
                type: subscriptionType,
                status: .active,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                expiresAt: expiresAt
            )
            
            print("✅ Updated subscription in backend for transaction: \(transaction.id)")
            
        } catch {
            print("❌ Failed to update subscription in backend: \(error)")
        }
    }
    
    // Legacy transaction handling
    private func handleSuccessfulPurchase(transaction: SKPaymentTransaction) async {
        do {
            try await SubscriptionService.shared.updateSubscription(
                type: .pro,
                status: .active,
                transactionId: transaction.transactionIdentifier,
                originalTransactionId: transaction.original?.transactionIdentifier
            )
            
            print("✅ Updated subscription in backend for legacy transaction: \(transaction.transactionIdentifier ?? "unknown")")
            
        } catch {
            print("❌ Failed to update subscription in backend: \(error)")
        }
    }
    
    @available(iOS 15.0, *)
    /// Verify transaction signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - State Management
    
    @MainActor
    private func setPurchaseState(_ state: PurchaseState) {
        self.purchaseState = state
    }
    
    /// Reset purchase state
    func resetPurchaseState() async {
        await setPurchaseState(.idle)
    }
}

// MARK: - Unified Product Model

/// Unified product model that works with both StoreKit versions
struct StoreProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let price: Decimal
    let priceFormatted: String
    let isSubscription: Bool
    
    @available(iOS 15.0, *)
    init(from product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.description = product.description
        self.price = product.price
        self.priceFormatted = product.displayPrice
        self.isSubscription = product.type == .autoRenewable
    }
    
    init(from product: SKProduct) {
        self.id = product.productIdentifier
        self.displayName = product.localizedTitle
        self.description = product.localizedDescription
        self.price = product.price.decimalValue
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        self.priceFormatted = formatter.string(from: product.price) ?? "\(product.price)"
        
        // Assume subscription for our app
        self.isSubscription = true
    }
    
    // Custom initializer for test products
    init(id: String, displayName: String, description: String, price: Decimal, priceFormatted: String, isSubscription: Bool) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.price = price
        self.priceFormatted = priceFormatted
        self.isSubscription = isSubscription
    }
    
    // MARK: - Equatable
    static func == (lhs: StoreProduct, rhs: StoreProduct) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Legacy StoreKit Delegate Methods

extension StoreKitManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.legacyProducts = response.products
            self.products = response.products.map { StoreProduct(from: $0) }
            print("✅ Loaded \(response.products.count) legacy products")
            if !response.invalidProductIdentifiers.isEmpty {
                print("❌ Invalid product IDs: \(response.invalidProductIdentifiers)")
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("❌ Legacy products request failed: \(error)")
        print("❌ Error type: \(type(of: error))")
        
        // Check if we're running in simulator
        #if targetEnvironment(simulator)
        print("⚠️ Running in simulator - App Store Connect products won't load")
        #endif
        
        DispatchQueue.main.async {
            self.products = []
            print("⚠️ Creating test product for development due to legacy StoreKit error")
            self.createTestProduct()
        }
    }
}

extension StoreKitManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchased(transaction)
            case .restored:
                handleRestored(transaction)
            case .failed:
                handleFailed(transaction)
            case .deferred:
                DispatchQueue.main.async {
                    self.purchaseState = .pending
                }
            case .purchasing:
                DispatchQueue.main.async {
                    self.purchaseState = .purchasing
                }
            @unknown default:
                break
            }
        }
    }
    
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        // Update subscription in backend
        Task {
            await handleSuccessfulPurchase(transaction: transaction)
            
            await MainActor.run {
                self.purchaseState = .purchased
                self.completionHandler?(true)
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handleRestored(_ transaction: SKPaymentTransaction) {
        // Handle restored transaction similar to purchased
        handlePurchased(transaction)
    }
    
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        let errorMessage = transaction.error?.localizedDescription ?? "Purchase failed"
        
        DispatchQueue.main.async {
            if (transaction.error as? SKError)?.code == .paymentCancelled {
                self.purchaseState = .cancelled
            } else {
                self.purchaseState = .failed(errorMessage)
            }
            self.completionHandler?(false)
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}

// MARK: - Purchase State

enum PurchaseState: Equatable {
    case idle
    case purchasing
    case purchased
    case cancelled
    case pending
    case restoring
    case restored
    case failed(String)
    
    var isProcessing: Bool {
        switch self {
        case .purchasing, .restoring:
            return true
        default:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .idle:
            return ""
        case .purchasing:
            return "Processing purchase..."
        case .purchased:
            return "Purchase successful!"
        case .cancelled:
            return "Purchase cancelled"
        case .pending:
            return "Purchase pending approval"
        case .restoring:
            return "Restoring purchases..."
        case .restored:
            return "Purchases restored"
        case .failed(let error):
            return "Purchase failed: \(error)"
        }
    }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success
    case cancelled
    case pending
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case failedVerification
    case unknownError
    case productNotFound
    case purchaseNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed"
        case .unknownError:
            return "An unknown error occurred"
        case .productNotFound:
            return "Product not found"
        case .purchaseNotAllowed:
            return "Purchases are not allowed on this device"
        }
    }
}
