import Foundation

// MARK: - Pure Swift Wardrobe Models
// These models replace the old Realm objects and work purely with Swift and cloud storage

struct WardrobeItem: Identifiable {
    let id: String
    let imageUrl: String
    let createdAt: Date
    let pieces: [WardrobeClothingPiece]
    
    init(id: String = UUID().uuidString, imageUrl: String, createdAt: Date = Date(), pieces: [WardrobeClothingPiece] = []) {
        self.id = id
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.pieces = pieces
    }
}

struct WardrobeClothingPiece: Identifiable {
    let id: String
    let itemType: String
    let phrase: String
    let confidence: Double
    let category: String
    let matches: [WardrobeEbayMatch]
    
    init(id: String = UUID().uuidString, itemType: String, phrase: String, confidence: Double, category: String, matches: [WardrobeEbayMatch] = []) {
        self.id = id
        self.itemType = itemType
        self.phrase = phrase
        self.confidence = confidence
        self.category = category
        self.matches = matches
    }
}

struct WardrobeEbayMatch: Identifiable {
    let id: String
    let phrase: String
    let link: String
    
    init(id: String = UUID().uuidString, phrase: String, link: String) {
        self.id = id
        self.phrase = phrase
        self.link = link
    }
}
