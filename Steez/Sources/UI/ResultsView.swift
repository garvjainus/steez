import SwiftUI

// MARK: - Results Display Components

// Segmented results UI removed (segmentation disabled)

// MARK: - Lens Results Display
struct LensResultsDisplay: View {
    @EnvironmentObject var appState: AppState
    let lensProducts: [LensProduct]
    
    var body: some View {
        if !lensProducts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Similar Items")
                    .font(SteezFonts.medium(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                LazyVStack(spacing: 12) {
                    ForEach(lensProducts) { product in
                        LensProductRow(product: product)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
        }
    }
}

// MARK: - Lens Product Row
struct LensProductRow: View {
    let product: LensProduct
    @State private var showingOriginalImage = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIApplication.shared.open(product.link)
            }) {
                HStack(spacing: 15) {
                    // Product Image
                    AsyncImage(url: product.thumbnailUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SteezColors.textSecondary.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(SteezColors.textSecondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.title)
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            Text(product.source)
                                .font(SteezFonts.regular(12))
                                .foregroundColor(SteezColors.textSecondary)
                            
                            if let category = product.category, !category.isEmpty {
                                Text("•")
                                    .font(SteezFonts.regular(12))
                                    .foregroundColor(SteezColors.textSecondary)
                                Text(category)
                                    .font(SteezFonts.regular(12))
                                    .foregroundColor(SteezColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if let price = product.price {
                            Text(price)
                                .font(SteezFonts.medium(14))
                                .foregroundColor(product.extractedPrice != nil ? SteezColors.success : SteezColors.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SteezColors.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SteezColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SteezColors.textSecondary.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            // View Original Image button
            if let _ = product.imageUrl {
                Button(action: { showingOriginalImage = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                        Text("View Original Image")
                            .font(SteezFonts.regular(12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(SteezColors.primary.opacity(0.1))
                    )
                    .foregroundColor(SteezColors.primary)
                }
                .padding(.top, 8)
                .sheet(isPresented: $showingOriginalImage) {
                    OriginalImageView(imageUrl: product.imageUrl!)
                }
            }
        }
    }
}

// MARK: - Original Image View
struct OriginalImageView: View {
    let imageUrl: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(SteezColors.error)
                            Text("Failed to load image")
                                .foregroundColor(SteezColors.textSecondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .navigationTitle("Original Image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}

// Legacy eBay view removed