import Foundation

enum MockData {
    static let neighbors: [Neighbor] = makeNeighbors()

    static func makeNeighbors() -> [Neighbor] {
        let mariaID = UUID()
        let jamesID = UUID()
        let priyaID = UUID()
        let davidID = UUID()
        let lenaID = UUID()

        let maria = Neighbor(
            id: mariaID,
            name: "Maria",
            tossedItems: [
                TossedItem(
                    title: "Standing Desk Lamp",
                    description: "Adjustable arm lamp with warm and cool settings. Works perfectly, just upgrading.",
                    tags: ["lamp", "lighting", "desk", "adjustable"],
                    category: .office,
                    condition: .good,
                    ownerID: mariaID
                ),
                TossedItem(
                    title: "Set of Throw Pillows",
                    description: "Three decorative pillows in earth tones, gently used.",
                    tags: ["pillows", "decor", "living room"],
                    category: .furniture,
                    condition: .good,
                    ownerID: mariaID
                ),
                TossedItem(
                    title: "Yoga Mat",
                    description: "Purple foam yoga mat, slightly worn but still grippy.",
                    tags: ["yoga", "fitness", "mat"],
                    category: .sports,
                    condition: .fair,
                    ownerID: mariaID
                ),
            ],
            wishes: [
                Wish(
                    text: "Looking for children's books, any age welcome",
                    keywords: ["kids", "books", "children", "picture books", "chapter books"]
                ),
            ],
            neighborhood: "Maple Street"
        )

        let james = Neighbor(
            id: jamesID,
            name: "James",
            tossedItems: [
                TossedItem(
                    title: "HDMI Cable Bundle",
                    description: "Three HDMI cables of various lengths, all working.",
                    tags: ["hdmi", "cables", "electronics"],
                    category: .electronics,
                    condition: .good,
                    ownerID: jamesID
                ),
                TossedItem(
                    title: "USB Cable Assortment",
                    description: "Bag of USB-A, USB-C, and micro-USB cables. All tested and functional.",
                    tags: ["usb", "cables", "charger"],
                    category: .electronics,
                    condition: .good,
                    ownerID: jamesID
                ),
            ],
            wishes: [
                Wish(
                    text: "Need a small toaster or toaster oven",
                    keywords: ["toaster", "kitchen", "appliance", "small appliance"]
                ),
                Wish(
                    text: "Looking for a blender or food processor",
                    keywords: ["blender", "food processor", "kitchen", "appliance"]
                ),
            ],
            neighborhood: "Oak Avenue"
        )

        let priya = Neighbor(
            id: priyaID,
            name: "Priya",
            tossedItems: [
                TossedItem(
                    title: "Bread Maker",
                    description: "Zojirushi bread machine, lightly used. Makes perfect loaves.",
                    tags: ["bread maker", "kitchen", "baking", "appliance"],
                    category: .kitchenware,
                    condition: .likeNew,
                    ownerID: priyaID
                ),
                TossedItem(
                    title: "Spice Rack with Spices",
                    description: "Wooden rotating spice rack with 16 filled jars.",
                    tags: ["spices", "kitchen", "cooking", "spice rack"],
                    category: .kitchenware,
                    condition: .good,
                    ownerID: priyaID
                ),
            ],
            wishes: [
                Wish(
                    text: "Looking for yoga blocks and a strap set",
                    keywords: ["yoga", "blocks", "strap", "fitness", "gear"]
                ),
                Wish(
                    text: "Would love a foam roller for recovery",
                    keywords: ["foam roller", "fitness", "recovery", "massage"]
                ),
            ],
            neighborhood: "Cedar Lane"
        )

        let david = Neighbor(
            id: davidID,
            name: "David",
            tossedItems: [
                TossedItem(
                    title: "Box of Novels",
                    description: "About 20 paperback novels — mystery, sci-fi, and literary fiction. Take one or all.",
                    tags: ["books", "novels", "fiction", "paperback"],
                    category: .books,
                    condition: .good,
                    ownerID: davidID
                ),
                TossedItem(
                    title: "Art History Coffee Table Books",
                    description: "Three oversized art books: Monet, Picasso, and a general survey.",
                    tags: ["books", "art", "coffee table", "history"],
                    category: .books,
                    condition: .good,
                    ownerID: davidID
                ),
                TossedItem(
                    title: "Desk Fan",
                    description: "Small USB-powered desk fan, two speed settings.",
                    tags: ["fan", "desk", "office", "usb"],
                    category: .office,
                    condition: .good,
                    ownerID: davidID
                ),
            ],
            wishes: [
                Wish(
                    text: "Need USB-C charging cables, preferably braided",
                    keywords: ["usb-c", "cable", "charger", "braided", "electronics"]
                ),
            ],
            neighborhood: "Pine Road"
        )

        let lena = Neighbor(
            id: lenaID,
            name: "Lena",
            tossedItems: [
                TossedItem(
                    title: "Kitchen Utensil Set",
                    description: "Silicone spatulas, tongs, ladle, and whisk. All clean and in great shape.",
                    tags: ["utensils", "kitchen", "cooking", "spatula"],
                    category: .kitchenware,
                    condition: .good,
                    ownerID: lenaID
                ),
                TossedItem(
                    title: "Cast Iron Skillet",
                    description: "10-inch Lodge cast iron, well-seasoned and ready to use.",
                    tags: ["cast iron", "skillet", "cooking", "kitchen"],
                    category: .kitchenware,
                    condition: .good,
                    ownerID: lenaID
                ),
                TossedItem(
                    title: "Muffin Tins (2)",
                    description: "Two standard 12-cup muffin tins, non-stick.",
                    tags: ["baking", "muffin tin", "kitchen"],
                    category: .kitchenware,
                    condition: .good,
                    ownerID: lenaID
                ),
            ],
            wishes: [
                Wish(
                    text: "Looking for a desk lamp or any good office lighting",
                    keywords: ["lamp", "desk", "office", "lighting"]
                ),
                Wish(
                    text: "Need a small whiteboard or corkboard for my home office",
                    keywords: ["whiteboard", "corkboard", "office", "bulletin board"]
                ),
            ],
            neighborhood: "Birch Court"
        )

        return [maria, james, priya, david, lena]
    }

    static var sampleNudges: [Nudge] {
        let neighbors = makeNeighbors()
        guard
            let lena = neighbors.first(where: { $0.name == "Lena" }),
            let maria = neighbors.first(where: { $0.name == "Maria" }),
            let james = neighbors.first(where: { $0.name == "James" }),
            let david = neighbors.first(where: { $0.name == "David" }),
            let lamp = maria.tossedItems.first(where: { $0.title.contains("Lamp") }),
            let lenaLampWish = lena.wishes.first,
            let cables = james.tossedItems.first(where: { $0.title.contains("USB") }),
            let davidCableWish = david.wishes.first
        else { return [] }

        return [
            Nudge(
                neighbor: lena,
                tossedItem: lamp,
                wish: lenaLampWish,
                message: "Maria has a standing desk lamp that sounds perfect for your home office. Reach out!"
            ),
            Nudge(
                neighbor: david,
                tossedItem: cables,
                wish: davidCableWish,
                message: "James has a bag of USB cables including USB-C — exactly what you've been looking for."
            ),
        ]
    }
}
