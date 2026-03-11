import Foundation

struct Nudge: Identifiable, Codable {
    let id: UUID
    var neighbor: Neighbor
    var tossedItem: TossedItem
    var wish: Wish
    var message: String
    let dateGenerated: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        neighbor: Neighbor,
        tossedItem: TossedItem,
        wish: Wish,
        message: String
    ) {
        self.id = id
        self.neighbor = neighbor
        self.tossedItem = tossedItem
        self.wish = wish
        self.message = message
        self.dateGenerated = Date()
        self.isRead = false
    }
}
