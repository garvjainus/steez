import SwiftUI
import Kingfisher

struct WardrobeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int
    
    private var categorizedPieces: [String: [WardrobeClothingPiece]] {
        let allPieces = appState.wardrobeItems.flatMap { $0.pieces }
        return Dictionary(grouping: allPieces, by: { $0.category })
    }
    
    private var hasAnyItems: Bool {
        !appState.wardrobeItems.isEmpty
    }
    
    private let categories = ["top", "bottom", "outerwear", "shoes", "accessories", "other"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Wardrobe")
                            .font(SteezFonts.title)
                            .foregroundColor(SteezColors.textPrimary)
                        
                        if appState.isAuthenticated {
                            Text("All your saved items, ready to style.")
                                .font(SteezFonts.regular(16))
                                .foregroundColor(SteezColors.textSecondary)
                        } else {
                            Text("Sign in to save and access your wardrobe items.")
                                .font(SteezFonts.regular(16))
                                .foregroundColor(SteezColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Add New Items Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1 // Navigate to import tab
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("Add New Items")
                                .font(SteezFonts.medium(16))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [SteezColors.primary, SteezColors.primaryLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: SteezColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    
                    // Content
                    if !appState.isAuthenticated {
                        // Not authenticated state
                        NotAuthenticatedWardrobeView()
                    } else if appState.isLoadingWardrobe {
                        // Loading state
                        LoadingWardrobeView()
                    } else if let error = appState.wardrobeError {
                        // Error state
                        ErrorWardrobeView(error: error) {
                            Task {
                                await appState.fetchWardrobeItems()
                            }
                        }
                    } else if hasAnyItems {
                        // Categories
                        ForEach(categories, id: \.self) { category in
                            if let pieces = categorizedPieces[category], !pieces.isEmpty {
                                WardrobeCategoryRow(
                                    category: category, 
                                    pieces: pieces,
                                    wardrobeItems: appState.wardrobeItems
                                )
                            }
                        }
                    } else {
                        // Empty State (authenticated but no items)
                        EmptyWardrobeView()
                    }
                }
                .padding(.vertical, 24)
            }
            .background(SteezColors.background)
            .navigationBarHidden(true)
        }
    }
}

struct WardrobeCategoryRow: View {
    let category: String
    let pieces: [WardrobeClothingPiece]
    let wardrobeItems: [WardrobeItem]
    
    // Helper function to find the parent wardrobe item for a piece
    private func findParentItem(for piece: WardrobeClothingPiece) -> WardrobeItem? {
        return wardrobeItems.first { item in
            item.pieces.contains { $0.id == piece.id }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(category.capitalized)
                    .font(SteezFonts.medium(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Spacer()
                
                Text("\(pieces.count) item\(pieces.count == 1 ? "" : "s")")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(pieces) { piece in
                        NavigationLink(destination: WardrobeDetailView(
                            piece: piece,
                            parentItem: findParentItem(for: piece)
                        )) {
                            WardrobeItemCard(
                                piece: piece,
                                parentItem: findParentItem(for: piece)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct WardrobeItemCard: View {
    let piece: WardrobeClothingPiece
    let parentItem: WardrobeItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            Group {
                if let parentItem = parentItem, 
                   let imageUrl = URL(string: parentItem.imageUrl) {
                    KFImage(imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                        .background(SteezColors.surface)
                } else {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(SteezColors.surface)
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(SteezColors.textSecondary.opacity(0.6))
                                Text("No Image")
                                    .font(SteezFonts.regular(10))
                                    .foregroundColor(SteezColors.textSecondary.opacity(0.6))
                            }
                        )
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(piece.itemType.capitalized)
                    .font(SteezFonts.medium(14))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineLimit(2)
                
                Text("\(piece.matches.count) match\(piece.matches.count == 1 ? "" : "es")")
                    .font(SteezFonts.regular(11))
                    .foregroundColor(SteezColors.textSecondary)
                
                // Confidence indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                    
                    Text("\(Int(piece.confidence * 100))% confident")
                        .font(SteezFonts.regular(10))
                        .foregroundColor(SteezColors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 120)
        .background(SteezColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    private var confidenceColor: Color {
        switch piece.confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

struct WardrobeDetailView: View {
    let piece: WardrobeClothingPiece
    let parentItem: WardrobeItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Main Image
                if let parentItem = parentItem,
                   let imageUrl = URL(string: parentItem.imageUrl) {
                    KFImage(imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .background(SteezColors.surface)
                }
                
                // Item Details
                VStack(alignment: .leading, spacing: 12) {
                    Text(piece.phrase)
                        .font(SteezFonts.title)
                        .foregroundColor(SteezColors.textPrimary)
                    
                    HStack {
                        Text("Category:")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textSecondary)
                        Text(piece.category.capitalized)
                            .font(SteezFonts.regular(16))
                            .foregroundColor(SteezColors.textPrimary)
                    }
                    
                    HStack {
                        Text("Confidence:")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textSecondary)
                        Text("\(Int(piece.confidence * 100))%")
                            .font(SteezFonts.regular(16))
                            .foregroundColor(SteezColors.textPrimary)
                    }
                }
                
                // Shopping Matches
                if !piece.matches.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Shopping Matches")
                            .font(SteezFonts.medium(20))
                            .foregroundColor(SteezColors.textPrimary)
                        
                        ForEach(piece.matches) { match in
                            ShoppingMatchCard(match: match)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(SteezColors.textSecondary.opacity(0.6))
                        
                        Text("No shopping matches found")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textSecondary)
                        
                        Text("Try searching manually or check back later")
                            .font(SteezFonts.regular(14))
                            .foregroundColor(SteezColors.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(piece.itemType.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .background(SteezColors.background)
    }
}

struct ShoppingMatchCard: View {
    let match: WardrobeEbayMatch
    
    var body: some View {
        Button(action: {
            if let url = URL(string: match.link) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(SteezColors.primary)
                    .frame(width: 32, height: 32)
                    .background(SteezColors.primary.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.phrase)
                        .font(SteezFonts.medium(14))
                        .foregroundColor(SteezColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text("Tap to view on eBay")
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SteezColors.textSecondary)
            }
            .padding()
            .background(SteezColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyWardrobeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tshirt")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(SteezColors.textSecondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Your wardrobe is empty")
                    .font(SteezFonts.medium(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text("Start by adding some items from photos or videos")
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

struct NotAuthenticatedWardrobeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(SteezColors.primary.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Sign in required")
                    .font(SteezFonts.medium(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text("Please sign in to access your personal wardrobe. All your saved items will be securely stored in your account.")
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingWardrobeView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
                .scaleEffect(1.2)
            
            Text("Loading your wardrobe...")
                .font(SteezFonts.medium(16))
                .foregroundColor(SteezColors.textSecondary)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorWardrobeView: View {
    let error: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Couldn't load wardrobe")
                    .font(SteezFonts.medium(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text(error)
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
} 