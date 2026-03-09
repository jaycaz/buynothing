import Foundation

enum ItemCategory: String, CaseIterable, Codable {
    case electronics = "Electronics"
    case furniture = "Furniture"
    case clothing = "Clothing"
    case books = "Books"
    case kitchenware = "Kitchenware"
    case tools = "Tools"
    case toys = "Toys"
    case sports = "Sports"
    case office = "Office"
    case other = "Other"

    var systemImageName: String {
        switch self {
        case .electronics: return "iphone"
        case .furniture: return "chair"
        case .clothing: return "tshirt"
        case .books: return "book"
        case .kitchenware: return "fork.knife"
        case .tools: return "wrench"
        case .toys: return "gamecontroller"
        case .sports: return "sportscourt"
        case .office: return "desktopcomputer"
        case .other: return "questionmark.circle"
        }
    }
}

enum ItemCondition: String, CaseIterable, Codable {
    case new = "New"
    case likeNew = "Like New"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

struct TossedItem: Identifiable, Codable {
    let id: UUID
    var photoData: Data?
    var title: String
    var description: String
    var tags: [String]
    var category: ItemCategory
    var condition: ItemCondition
    let dateAdded: Date
    var isAvailable: Bool
    var ownerID: UUID

    init(
        id: UUID = UUID(),
        photoData: Data? = nil,
        title: String,
        description: String = "",
        tags: [String] = [],
        category: ItemCategory = .other,
        condition: ItemCondition = .good,
        ownerID: UUID
    ) {
        self.id = id
        self.photoData = photoData
        self.title = title
        self.description = description
        self.tags = tags
        self.category = category
        self.condition = condition
        self.dateAdded = Date()
        self.isAvailable = true
        self.ownerID = ownerID
    }
}

struct Wish: Identifiable, Codable {
    let id: UUID
    var text: String
    var keywords: [String]
    let dateAdded: Date
    var isFulfilled: Bool

    init(
        id: UUID = UUID(),
        text: String,
        keywords: [String] = []
    ) {
        self.id = id
        self.text = text
        self.keywords = keywords
        self.dateAdded = Date()
        self.isFulfilled = false
    }
}
