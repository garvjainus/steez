import SwiftUI
import StoreKit

// MARK: - Main Paywall View
struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var storeKitManager = StoreKitManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var usageService = UsageTrackingService.shared
    
    let context: PaywallContext
    let onDismiss: () -> Void
    
    @State private var selectedProduct: StoreProduct?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var animateContent = false
    
    // Sort products so annual plan appears first (same logic as SubscriptionOptionsView)
    private var sortedProducts: [StoreProduct] {
        storeKitManager.subscriptionProducts.sorted { product1, product2 in
            let product1IsAnnual = product1.displayName.contains("Yearly")
            let product2IsAnnual = product2.displayName.contains("Yearly")
            
            // Annual plans come first
            if product1IsAnnual && !product2IsAnnual {
                return true
            } else if !product1IsAnnual && product2IsAnnual {
                return false
            } else {
                return false // Maintain original order for same type
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        SteezColors.primary.opacity(0.05),
                        SteezColors.background,
                        SteezColors.accent.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header Section
                        PaywallHeaderView(context: context)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : -30)
                        
                        // Features Section
                        PaywallFeaturesView()
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                        
                        // Subscription Options
                        if !storeKitManager.products.isEmpty {
                            SubscriptionOptionsView(
                                products: sortedProducts,
                                selectedProduct: $selectedProduct,
                                purchaseState: storeKitManager.purchaseState
                            )
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                        } else {
                            // Loading products
                            LoadingProductsView()
                        }
                        
                        // Purchase Button
                        if let product = selectedProduct ?? sortedProducts.first {
                            PurchaseButtonView(
                                product: product,
                                purchaseState: storeKitManager.purchaseState,
                                onPurchase: {
                                    await handlePurchase(product)
                                }
                            )
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 30)
                        }
                        
                        // Footer Actions
                        PaywallFooterView(
                            onRestore: {
                                await handleRestore()
                            },
                            onTerms: {
                                // TODO: Show terms
                            },
                            onPrivacy: {
                                // TODO: Show privacy policy
                            }
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(SteezColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore") {
                        Task {
                            await handleRestore()
                        }
                    }
                    .foregroundColor(SteezColors.primary)
                    .disabled(storeKitManager.purchaseState.isProcessing)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateContent = true
            }
            
            // Auto-select the first sorted product (annual plan)
            autoSelectFirstProduct()
        }
        .onChange(of: storeKitManager.products) { _ in
            // When products are loaded/updated, auto-select the first sorted product
            autoSelectFirstProduct()
        }
        .alert("Purchase Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: storeKitManager.purchaseState) { state in
            handlePurchaseStateChange(state)
        }
    }
    
    // MARK: - Purchase Handling
    
    private func handlePurchase(_ product: StoreProduct) async {
        do {
            let result = try await storeKitManager.purchase(product)
            
            switch result {
            case .success:
                // Success handled in state change
                break
            case .cancelled:
                // User cancelled, no action needed
                break
            case .pending:
                // Pending, show appropriate message
                break
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func handleRestore() async {
        do {
            try await storeKitManager.restore()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func handlePurchaseStateChange(_ state: PurchaseState) {
        switch state {
        case .purchased, .restored:
            // Refresh app subscription state
            Task {
                await appState.fetchSubscriptionData()
                await appState.refreshUsageQuota()
                onDismiss()
            }
        case .failed(let message):
            showError(message)
        default:
            break
        }
    }
    
    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    /// Auto-select the first sorted product (annual plan if available)
    private func autoSelectFirstProduct() {
        // Only auto-select if no product is currently selected
        // and we have products available
        if selectedProduct == nil, let firstProduct = sortedProducts.first {
            selectedProduct = firstProduct
        }
    }
}

// MARK: - Header Section

struct PaywallHeaderView: View {
    let context: PaywallContext
    
    var body: some View {
        VStack(spacing: 16) {
            // App Logo
            Image("steezlogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: SteezColors.primary.opacity(0.3), radius: 15, x: 0, y: 8)
            
            // Title and subtitle
            VStack(spacing: 8) {
                Text(context.title)
                    .font(SteezFonts.medium(28))
                    .foregroundColor(SteezColors.textPrimary)
                    .multilineTextAlignment(.center)
                
            }
        }
    }
}




struct UsageStatView: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(SteezColors.primary)
            
            Text("\(count)")
                .font(SteezFonts.medium(16))
                .foregroundColor(SteezColors.textPrimary)
            
            Text(title)
                .font(SteezFonts.regular(12))
                .foregroundColor(SteezColors.textSecondary)
        }
    }
}

// MARK: - Features Section

struct PaywallFeaturesView: View {
    private let features = [
        PaywallFeature(
            icon: "infinity",
            title: "Unlimited Uploads",
        ),
        PaywallFeature(
            icon: "square.and.arrow.up",
            title: "Unlimited Sharing",
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(features) { feature in
                    PaywallFeatureCard(feature: feature)
                }
            }
        }
    }
}

struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

struct PaywallFeatureCard: View {
    let feature: PaywallFeature
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(SteezColors.primary)
                    .frame(width: 24, height: 24)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(SteezFonts.medium(14))
                    .foregroundColor(SteezColors.textPrimary)
                
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(SteezColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Subscription Options

struct SubscriptionOptionsView: View {
    let products: [StoreProduct]
    @Binding var selectedProduct: StoreProduct?
    let purchaseState: PurchaseState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(SteezFonts.medium(22))
                .foregroundColor(SteezColors.textPrimary)
            
            ForEach(products, id: \.id) { product in
                SubscriptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: {
                        selectedProduct = product
                    }
                )
                .disabled(purchaseState.isProcessing)
            }
        }
    }
}

struct SubscriptionCard: View {
    let product: StoreProduct
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isAnnualPlan: Bool {
        product.displayName.contains("Yearly")
    }
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? SteezColors.primary : SteezColors.textSecondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if isSelected {
                            Circle()
                                .fill(SteezColors.primary)
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getProductTitle())
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textPrimary)
                        
                        Text(getProductDescription())
                            .font(SteezFonts.regular(14))
                            .foregroundColor(SteezColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        // Show crossed-out original price for annual plan
                        if isAnnualPlan {
                            Text("$59.99")
                                .font(SteezFonts.regular(14))
                                .foregroundColor(SteezColors.textSecondary)
                                .strikethrough(true, color: SteezColors.textSecondary)
                        }
                        
                        Text(product.priceFormatted)
                            .font(SteezFonts.medium(18))
                            .foregroundColor(SteezColors.textPrimary)
                        
                        Text(getProductStatus())
                            .font(SteezFonts.regular(12))
                            .foregroundColor(SteezColors.textSecondary)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SteezColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSelected ? SteezColors.primary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: isSelected ? SteezColors.primary.opacity(0.2) : .black.opacity(0.05), 
                       radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 6 : 2)
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                // Most Popular tag for annual plan
                if isAnnualPlan {
                    Text("Most Popular")
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .offset(x: -8, y: -8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getProductTitle() -> String {
        if product.displayName.contains("Monthly") {
            return "Monthly Plan"
        } else if product.displayName.contains("Yearly") {
            return "Annual Plan"
        }
        return "Steez Pro"
    }
    
    private func getProductDescription() -> String {
        if product.displayName.contains("Monthly") {
            return "Cancel anytime!"
        } else if product.displayName.contains("Yearly") {
            return "Save 66.7%!"
        }
        return "Premium features unlocked"
    }
    
    private func getProductStatus() -> String {
        if product.displayName.contains("Monthly") {
            return "per month"
        } else if product.displayName.contains("Yearly") {
            return "per year"
        }
        return ""
    }
}

// MARK: - Purchase Button

struct PurchaseButtonView: View {
    let product: StoreProduct
    let purchaseState: PurchaseState
    let onPurchase: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await onPurchase()
            }
        }) {
            HStack(spacing: 12) {
                if purchaseState.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Start Pro for \(product.priceFormatted)\(getPeriodText(for: product))")
                        .font(SteezFonts.medium(16))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [SteezColors.primary, SteezColors.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: SteezColors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
            .scaleEffect(purchaseState.isProcessing ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: purchaseState.isProcessing)
        }
        .disabled(purchaseState.isProcessing)
    }
    
    private func getPeriodText(for product: StoreProduct) -> String {
        if product.displayName.contains("Monthly") {
            return "/month"
        } else if product.displayName.contains("Yearly") {
            return "/year"
        }
        return ""
    }
}

// MARK: - Footer

struct PaywallFooterView: View {
    let onRestore: () async -> Void
    let onTerms: () -> Void
    let onPrivacy: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button("Restore Purchases") {
                Task {
                    await onRestore()
                }
            }
            .font(SteezFonts.medium(14))
            .foregroundColor(SteezColors.primary)
            
            HStack(spacing: 8) {
                Button("Terms of Service") {
                    onTerms()
                }
                .font(SteezFonts.regular(12))
                .foregroundColor(SteezColors.textSecondary)
                
                Text("•")
                    .font(SteezFonts.regular(12))
                    .foregroundColor(SteezColors.textSecondary)
                
                Button("Privacy Policy") {
                    onPrivacy()
                }
                .font(SteezFonts.regular(12))
                .foregroundColor(SteezColors.textSecondary)
            }
            
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(SteezFonts.regular(10))
                .foregroundColor(SteezColors.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
}

// MARK: - Loading State

struct LoadingProductsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
                .scaleEffect(1.2)
            
            Text("Loading subscription options...")
                .font(SteezFonts.regular(14))
                .foregroundColor(SteezColors.textSecondary)
        }
        .frame(height: 100)
    }
}

// MARK: - Modal Wrapper

struct PaywallModalView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        PaywallView(
            context: appState.paywallContext,
            onDismiss: {
                Task {
                    await appState.hidePaywall()
                }
            }
        )
    }
}

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(
            context: .upload,
            onDismiss: {}
        )
        .environmentObject(AppState())
    }
}
#endif
