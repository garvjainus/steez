import Foundation
import Supabase

// MARK: - Simplified Wardrobe Service
/// Single service that handles both UI state and Supabase operations
/// All wardrobe data is stored in Supabase and tied to the user's account
class WardrobeService: ObservableObject {
    static let shared = WardrobeService()
    
    private let supabase = SupabaseService.shared.client
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Published items for UI binding
    @Published var items: [WardrobeItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save a new wardrobe item (requires authentication)
    func saveNewItem(imageUrl: URL, results: SegmentedResults) async throws {
        guard await isUserAuthenticated() else {
            throw WardrobeError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            
            // Create the main wardrobe item
            let wardrobeItemRequest = WardrobeItemRequest(
                userId: userId,
                imageUrl: imageUrl.absoluteString
            )
            
            // Insert the wardrobe item and get the ID
            let wardrobeItemResponse: [WardrobeItemResponse] = try await supabase
                .from("wardrobe_items")
                .insert(wardrobeItemRequest)
                .select()
                .execute()
                .value
            
            guard let wardrobeItem = wardrobeItemResponse.first else {
                throw WardrobeError.saveFailed("Failed to create wardrobe item")
            }
            
            // Insert clothing pieces (mapped from new segmentation model)
            for segment in results.segments {
                let derivedItemType = (segment.className?.lowercased()) ?? segment.category.lowercased()
                let derivedPhrase = segment.productLinks.first?.title ?? (segment.className ?? segment.category.capitalized)

                let pieceRequest = WardrobeClothingPieceRequest(
                    wardrobeItemId: wardrobeItem.id,
                    itemType: derivedItemType,
                    phrase: derivedPhrase,
                    confidence: segment.confidence,
                    category: segment.category
                )
                
                let clothingPieceResponses: [WardrobeClothingPieceResponse] = try await supabase
                    .from("wardrobe_clothing_pieces")
                    .insert(pieceRequest)
                    .select()
                    .execute()
                    .value
                
                // Legacy: previously inserted eBay matches per clothing piece. Now product links are shown inline from Google Lens.
            }
            
            await refreshItems()
            await clearError()
            print("✅ Saved item to cloud storage")
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Fetch all wardrobe items (requires authentication)
    func fetchAllItems() async throws -> [WardrobeItem] {
        guard await isUserAuthenticated() else {
            throw WardrobeError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            
            // Fetch wardrobe items
            let wardrobeItemResponses: [WardrobeItemResponse] = try await supabase
                .from("wardrobe_items")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            var wardrobeItems: [WardrobeItem] = []
            
            for itemResponse in wardrobeItemResponses {
                // Fetch clothing pieces for this item
                let clothingPieceResponses: [WardrobeClothingPieceResponse] = try await supabase
                    .from("wardrobe_clothing_pieces")
                    .select()
                    .eq("wardrobe_item_id", value: itemResponse.id)
                    .execute()
                    .value
                
                var clothingPieces: [WardrobeClothingPiece] = []
                
                for pieceResponse in clothingPieceResponses {
                    let clothingPiece = WardrobeClothingPiece(
                        id: pieceResponse.id,
                        itemType: pieceResponse.itemType,
                        phrase: pieceResponse.phrase,
                        confidence: pieceResponse.confidence,
                        category: pieceResponse.category
                    )
                    
                    clothingPieces.append(clothingPiece)
                }
                
                let wardrobeItem = WardrobeItem(
                    id: itemResponse.id,
                    imageUrl: itemResponse.imageUrl,
                    createdAt: parseDate(itemResponse.createdAt) ?? Date(),
                    pieces: clothingPieces
                )
                
                wardrobeItems.append(wardrobeItem)
            }
            
            await setItems(wardrobeItems)
            await clearError()
            return wardrobeItems
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Get items grouped by category
    func fetchItemsGroupedByCategory() async throws -> [String: [WardrobeClothingPiece]] {
        let items = try await fetchAllItems()
        let allPieces = items.flatMap { $0.pieces }
        return Dictionary(grouping: allPieces, by: { $0.category })
    }
    
    /// Delete a wardrobe item (requires authentication)
    func deleteItem(withId itemId: String) async throws {
        guard await isUserAuthenticated() else {
            throw WardrobeError.notAuthenticated
        }
        
        await setLoading(true)
        defer { Task { await setLoading(false) } }
        
        do {
            let userId = try await getCurrentUserId()
            
            // Verify the item belongs to the current user
            let items: [WardrobeItemResponse] = try await supabase
                .from("wardrobe_items")
                .select()
                .eq("id", value: itemId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            guard !items.isEmpty else {
                throw WardrobeError.deleteFailed("Item not found or you don't have permission to delete it")
            }
            
            // Delete the item (cascade will handle pieces and matches)
            try await supabase
                .from("wardrobe_items")
                .delete()
                .eq("id", value: itemId)
                .eq("user_id", value: userId)
                .execute()
            
            await refreshItems()
            await clearError()
            print("✅ Deleted item from cloud storage")
        } catch {
            await setError(error)
            throw error
        }
    }
    
    /// Force refresh items from cloud storage
    func refreshItems() async {
        do {
            _ = try await fetchAllItems()
        } catch {
            print("❌ Failed to refresh items: \(error)")
        }
    }
    
    /// Check if user is authenticated
    func isUserAuthenticated() async -> Bool {
        do {
            _ = try await SupabaseService.shared.session()
            return true
        } catch {
            return false
        }
    }
    
    /// Clear all wardrobe data (for sign out)
    func clearAllData() async {
        await MainActor.run {
            items = []
            error = nil
            isLoading = false
        }
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentUserId() async throws -> String {
        let session = try await SupabaseService.shared.session()
        return session.user.id.uuidString
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        return dateFormatter.date(from: dateString)
    }
    
    @MainActor
    private func setItems(_ items: [WardrobeItem]) {
        self.items = items
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
}

// MARK: - Error Types

enum WardrobeError: LocalizedError {
    case notAuthenticated
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to access your wardrobe"
        case .saveFailed(let message):
            return "Failed to save item: \(message)"
        case .fetchFailed(let message):
            return "Failed to load wardrobe: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete item: \(message)"
        }
    }
}

// MARK: - Database Models (internal use only)

// Request Models (for sending data to Supabase)
private struct WardrobeItemRequest: Codable {
    let userId: String
    let imageUrl: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case imageUrl = "image_url"
    }
}

private struct WardrobeClothingPieceRequest: Codable {
    let wardrobeItemId: String
    let itemType: String
    let phrase: String
    let confidence: Double
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case wardrobeItemId = "wardrobe_item_id"
        case itemType = "item_type"
        case phrase
        case confidence
        case category
    }
}

// Legacy eBay models removed

// Response Models (for receiving data from Supabase)
private struct WardrobeItemResponse: Codable {
    let id: String
    let userId: String
    let imageUrl: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct WardrobeClothingPieceResponse: Codable {
    let id: String
    let wardrobeItemId: String
    let itemType: String
    let phrase: String
    let confidence: Double
    let category: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case wardrobeItemId = "wardrobe_item_id"
        case itemType = "item_type"
        case phrase
        case confidence
        case category
        case createdAt = "created_at"
    }
}

// Legacy eBay models removed

// MARK: - Extension for UI Compatibility

extension WardrobeService {
    /// Synchronous wrapper for compatibility with existing UI code
    var wardrobeItems: [WardrobeItem] {
        return items
    }
}