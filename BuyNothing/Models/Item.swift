import Foundation

enum ItemCategory: String, CaseIterable, Codable {
    case electronics = "Electronics"
    case cables = "Cables"
    case furniture = "Furniture"
    case clothing = "Clothing"
    case books = "Books"
    case kitchenware = "Kitchenware"
    case tools = "Tools"
    case toys = "Toys"
    case sports = "Sports"
    case other = "Other"
    
    var systemImageName: String {
        switch self {
        case .electronics: return "iphone"
        case .cables: return "cable.connector"
        case .furniture: return "chair"
        case .clothing: return "tshirt"
        case .books: return "book"
        case .kitchenware: return "fork.knife"
        case .tools: return "wrench"
        case .toys: return "gamecontroller"
        case .sports: return "sportscourt"
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
    
    var colorName: String {
        switch self {
        case .new, .likeNew: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

protocol Item: Identifiable, Codable {
    var id: UUID { get }
    var title: String { get set }
    var description: String { get set }
    var category: ItemCategory { get set }
    var condition: ItemCondition { get set }
    var imageData: Data? { get set }
    var dateAdded: Date { get }
    var isAvailable: Bool { get set }
    var ownerID: UUID? { get set }
    var location: String? { get set }
    var tags: [String] { get set }
}

struct GenericItem: Item {
    let id = UUID()
    var title: String
    var description: String
    var category: ItemCategory
    var condition: ItemCondition
    var imageData: Data?
    let dateAdded: Date
    var isAvailable: Bool
    var ownerID: UUID?
    var location: String?
    var tags: [String]
    
    init(
        title: String,
        description: String = "",
        category: ItemCategory = .other,
        condition: ItemCondition = .good,
        imageData: Data? = nil,
        location: String? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.condition = condition
        self.imageData = imageData
        self.dateAdded = Date()
        self.isAvailable = true
        self.ownerID = nil
        self.location = location
        self.tags = tags
    }
}