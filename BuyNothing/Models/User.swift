import Foundation

struct User: Identifiable, Codable {
    let id = UUID()
    var name: String
    var profileImageData: Data?
    var location: String?
    var bio: String?
    var joinDate: Date
    var isActive: Bool
    var itemsShared: Int
    var itemsReceived: Int
    var rating: Double
    var favoriteCategories: [ItemCategory]
    
    init(
        name: String,
        profileImageData: Data? = nil,
        location: String? = nil,
        bio: String? = nil
    ) {
        self.name = name
        self.profileImageData = profileImageData
        self.location = location
        self.bio = bio
        self.joinDate = Date()
        self.isActive = true
        self.itemsShared = 0
        self.itemsReceived = 0
        self.rating = 5.0
        self.favoriteCategories = []
    }
    
    var displayName: String {
        return name.isEmpty ? "Anonymous" : name
    }
    
    var experienceLevel: String {
        let totalItems = itemsShared + itemsReceived
        switch totalItems {
        case 0...5: return "New"
        case 6...20: return "Active"
        case 21...50: return "Experienced"
        default: return "Community Champion"
        }
    }
    
    mutating func shareItem() {
        itemsShared += 1
    }
    
    mutating func receiveItem() {
        itemsReceived += 1
    }
}