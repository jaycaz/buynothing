import Foundation

struct Neighbor: Identifiable, Codable {
    let id: UUID
    var name: String
    var tossedItems: [TossedItem]
    var wishes: [Wish]
    var neighborhood: String

    init(
        id: UUID = UUID(),
        name: String,
        tossedItems: [TossedItem] = [],
        wishes: [Wish] = [],
        neighborhood: String = ""
    ) {
        self.id = id
        self.name = name
        self.tossedItems = tossedItems
        self.wishes = wishes
        self.neighborhood = neighborhood
    }
}
