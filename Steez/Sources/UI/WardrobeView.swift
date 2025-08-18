import SwiftUI

struct WardrobeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int
    
    private var categorizedPieces: [String: [WardrobeClothingPiece]] {
        let allPieces = appState.wardrobeItems.flatMap { $0.pieces }
        return Dictionary(grouping: allPieces, by: { $0.category })
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
                        Text("All your saved items, ready to style.")
                            .font(SteezFonts.regular(16))
                            .foregroundColor(SteezColors.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    
                    // Categories
                    ForEach(categories, id: \.self) { category in
                        if let pieces = categorizedPieces[category], !pieces.isEmpty {
                            WardrobeCategoryRow(category: category, pieces: pieces)
                        }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.capitalized)
                .font(SteezFonts.medium(20))
                .foregroundColor(SteezColors.textPrimary)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(pieces) { piece in
                        NavigationLink(destination: WardrobeDetailView(piece: piece)) {
                            WardrobeItemCard(piece: piece)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct WardrobeItemCard: View {
    let piece: WardrobeClothingPiece
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // For now, we'll just show the item type.
            // In a real app, you'd want to find the parent WardrobeItem to get the image URL.
            Text(piece.itemType.capitalized)
                .font(SteezFonts.medium(16))
                .foregroundColor(SteezColors.textPrimary)
            
            Text("\(piece.matches.count) matches")
                .font(SteezFonts.regular(12))
                .foregroundColor(SteezColors.textSecondary)
        }
        .padding()
        .background(SteezColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct WardrobeDetailView: View {
    let piece: WardrobeClothingPiece
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(piece.phrase)
                    .font(SteezFonts.title)
                
                ForEach(piece.matches) { match in
                    Link(match.phrase, destination: URL(string: match.link)!)
                        .font(SteezFonts.body)
                }
            }
            .padding()
        }
        .navigationTitle(piece.itemType.capitalized)
    }
} 