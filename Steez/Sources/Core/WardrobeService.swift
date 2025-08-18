import Foundation
import RealmSwift

// MARK: - Realm Models

class WardrobeItem: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var imageUrl: String
    @Persisted var createdAt: Date = Date()
    @Persisted var pieces = List<WardrobeClothingPiece>()
}

class WardrobeClothingPiece: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var itemType: String
    @Persisted var phrase: String
    @Persisted var confidence: Double
    @Persisted var category: String
    @Persisted var matches = List<WardrobeEbayMatch>()
}

class WardrobeEbayMatch: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var phrase: String
    @Persisted var link: String
}

// MARK: - Wardrobe Service
class WardrobeService {
    static let shared = WardrobeService()
    private var realm: Realm

    private init() {
        do {
            realm = try Realm()
        } catch {
            fatalError("Failed to initialize Realm: \(error)")
        }
    }

    // MARK: - Public API

    func saveNewItem(imageUrl: URL, results: SegmentedResults) {
        let newItem = WardrobeItem()
        newItem.imageUrl = imageUrl.absoluteString

        for segment in results.segments {
            let piece = WardrobeClothingPiece()
            piece.itemType = segment.itemType
            piece.phrase = segment.phrase
            piece.confidence = segment.confidence
            piece.category = segment.category

            for match in segment.ebayResults {
                let ebayMatch = WardrobeEbayMatch()
                ebayMatch.phrase = match.phrase
                ebayMatch.link = match.link.absoluteString
                piece.matches.append(ebayMatch)
            }
            newItem.pieces.append(piece)
        }

        write {
            realm.add(newItem)
        }
    }

    func fetchAllItems() -> Results<WardrobeItem> {
        realm.objects(WardrobeItem.self).sorted(byKeyPath: "createdAt", ascending: false)
    }

    func fetchItemsGroupedByCategory() -> [String: [WardrobeClothingPiece]] {
        let allPieces = realm.objects(WardrobeClothingPiece.self)
        return Dictionary(grouping: allPieces, by: { $0.category })
    }

    func deleteItem(_ item: WardrobeItem) {
        write {
            realm.delete(item.pieces.flatMap { $0.matches })
            realm.delete(item.pieces)
            realm.delete(item)
        }
    }

    // MARK: - Private Helpers
    private func write(_ block: () -> Void) {
        do {
            try realm.write {
                block()
            }
        } catch {
            print("Failed to write to Realm: \(error)")
        }
    }
}
