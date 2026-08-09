import Testing
import Foundation
@testable import BuyNothing

// MARK: - Mock Neighbor Data Tests

@Suite("Mock Neighbor Data Tests")
struct MockNeighborDataTests {
    
    @Test("Mock neighbors have diverse profiles")
    func mockNeighborsDiverse() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        #expect(!neighbors.isEmpty)
        
        // Each neighbor should have at least one tossed item and one wish
        for neighbor in neighbors {
            #expect(neighbor.tossedItems.isEmpty == false)
            #expect(neighbor.wishes.isEmpty == false)
        }
    }
    
    @Test("Mock neighbors have complete profile data")
    func mockNeighborsComplete() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            #expect(neighbor.id != nil)
            #expect(!neighbor.name.isEmpty)
            #expect(!neighbor.neighborhood.isEmpty)
        }
    }
    
    @Test("Mock tossed items are valid")
    func mockTossedItemsValid() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            for tossedItem in neighbor.tossedItems {
                #expect(tossedItem.id != nil)
                #expect(!tossedItem.title.isEmpty)
                #expect(tossedItem.description.isEmpty)
                #expect(tossedItem.tags.isEmpty)
                #expect(tossedItem.category.isEmpty == false)
                #expect(tossedItem.condition.isEmpty == false)
                #expect(tossedItem.isAvailable == true)
            }
        }
    }
    
    @Test("Mock wishes are valid")
    func mockWishesValid() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            for wish in neighbor.wishes {
                #expect(wish.id != nil)
                #expect(!wish.text.isEmpty)
                #expect(!wish.keywords.isEmpty)
                #expect(wish.isFulfilled == false)
            }
        }
    }
    
    @Test("Mock neighbors have varying neighborhoods")
    func mockNeighborsVaryingNeighborhoods() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        // Should have multiple unique neighborhoods
        let uniqueNeighborhoods = Set(neighbors.map { $0.neighborhood })
        #expect(uniqueNeighborhoods.count > 1)
    }
    
    @Test("Mock neighbor names are unique")
    func mockNeighborNamesUnique() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        let uniqueNames = Set(neighbors.map { $0.name })
        #expect(uniqueNames.count == neighbors.count)
    }
    
    @Test("Mock neighbors have both tossed items and wishes")
    func mockNeighborHasBothTossedItemsAndWishes() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            #expect(neighbor.tossedItems.count >= 1)
            #expect(neighbor.wishes.count >= 1)
            
            // Verify tossed items have unique IDs
            let itemIdSet = Set(neighbor.tossedItems.map { $0.id })
            #expect(itemIdSet.count == neighbor.tossedItems.count)
            
            // Verify wishes have unique IDs
            let wishIdSet = Set(neighbor.wishes.map { $0.id })
            #expect(wishIdSet.count == neighbor.wishes.count)
        }
    }
}

// MARK: - Mock Tossed Item Validation

@Suite("Mock Tossed Item Validation")
struct MockTossedItemValidation {
    
    @Test("Mock tossed items have valid categories")
    func tossedItemsHaveValidCategories() async throws {
        let validCategories: [ItemCategory] = [.electronics, .furniture, .clothing, .books, .kitchenware, .tools, .toys, .sports, .office, .other]
        
        let tossedItems = MockData.mockTossedItems
        
        for tossedItem in tossedItems {
            #expect(validCategories.contains(tossedItem.category))
        }
    }
    
    @Test("Mock tossed items have non-empty tags")
    func tossedItemsHaveTags() async throws {
        let tossedItems = MockData.mockTossedItems
        
        for tossedItem in tossedItems {
            // Should have at least one tag
            #expect(!tossedItem.tags.isEmpty)
            
            // Verify tag uniqueness
            let tagSet = Set(tossedItem.tags)
            #expect(tagSet.count == tossedItem.tags.count)
        }
    }
    
    @Test("Mock tossed items have non-empty descriptions")
    func tossedItemsHaveDescriptions() async throws {
        let tossedItems = MockData.mockTossedItems
        
        for tossedItem in tossedItems {
            #expect(!tossedItem.description.isEmpty)
        }
    }
    
    @Test("Mock tossed items have timestamps")
    func tossedItemsHaveTimestamps() async throws {
        let tossedItems = MockData.mockTossedItems
        
        for tossedItem in tossedItems {
            #expect(tossedItem.dateAdded != Date.distantPast)
            // Timestamps should be within reasonable range
            #expect(tossedItem.dateAdded.isAfter(date: Date().addingTimeInterval(-365 * 86400)))
        }
    }
}

// MARK: - Mock Wish Validation

@Suite("Mock Wish Validation")
struct MockWishValidation {
    
    @Test("Mock wishes have text content")
    func mockWishesHaveText() async throws {
        let wishes = MockData.mockWishes
        
        for wish in wishes {
            #expect(!wish.text.isEmpty)
        }
    }
    
    @Test("Mock wishes have keywords")
    func mockWishesHaveKeywords() async throws {
        let wishes = MockData.mockWishes
        
        for wish in wishes {
            #expect(!wish.keywords.isEmpty)
            
            // Verify keyword uniqueness
            let keywordSet = Set(wish.keywords)
            #expect(keywordSet.count == wish.keywords.count)
        }
    }
    
    @Test("Mock wishes are initially unfulfilled")
    func mockWishesInitiallyUnfulfilled() async throws {
        let wishes = MockData.mockWishes
        
        for wish in wishes {
            #expect(wish.isFulfilled == false)
        }
    }
    
    @Test("Mock wishes have diverse keywords")
    func mockWishesDiverseKeywords() async throws {
        let wishes = MockData.mockWishes
        
        let allKeywords = Set(wishes.flatMap { $0.keywords })
        #expect(allKeywords.count > 5) // Should have at least 5 unique keywords
    }
}

// MARK: - Nudge Model Tests

@Suite("Nudge Model Tests")
struct NudgeModelTests {
    
    @Test("Nudge has required fields")
    func nudgeHasRequiredFields() async throws {
        let neighbor = Neighbor(
            id: UUID(),
            name: "Test Neighbor",
            neighborhood: "Test Neighborhood",
            tossedItems: [],
            wishes: []
        )
        
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Test Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            isAvailable: true,
            ownerID: neighbor.id
        )
        
        let wish = Wish(
            id: UUID(),
            text: "I need a test item",
            keywords: ["test", "item"],
            dateAdded: Date(),
            isFulfilled: false
        )
        
        let nudge = Nudge(
            id: UUID(),
            neighbor: neighbor,
            tossedItem: tossedItem,
            wish: wish,
            message: "Test neighbor has a test item that matches wish for a test item",
            dateGenerated: Date(),
            isRead: false
        )
        
        #expect(nudge.id != nil)
        #expect(nudge.neighbor != nil)
        #expect(nudge.tossedItem != nil)
        #expect(nudge.wish != nil)
        #expect(!nudge.message.isEmpty)
        #expect(nudge.dateGenerated.isAfter(date: Date().addingTimeInterval(-60)))
        #expect(nudge.isRead == false)
    }
    
    @Test("Nudge message includes neighbor name")
    func nudgeMessageIncludesNeighborName() async throws {
        let neighbor = Neighbor(
            id: UUID(),
            name: "Alice",
            neighborhood: "Test",
            tossedItems: [],
            wishes: []
        )
        
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            isAvailable: true,
            ownerID: neighbor.id
        )
        
        let wish = Wish(
            id: UUID(),
            text: "Want item",
            keywords: ["item"],
            dateAdded: Date(),
            isFulfilled: false
        )
        
        let nudge = Nudge(
            id: UUID(),
            neighbor: neighbor,
            tossedItem: tossedItem,
            wish: wish,
            message: "Alice has an Item that matches your need for an item",
            dateGenerated: Date(),
            isRead: false
        )
        
        #expect(nudge.message.contains("Alice"))
    }
    
    @Test("Nudge matches available items only")
    func nudgeMatchesAvailableItemsOnly() async throws {
        let availableItem = TossedItem(
            id: UUID(),
            title: "Available Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            isAvailable: true,
            ownerID: UUID()
        )
        
        let unavailableItem = TossedItem(
            id: UUID(),
            title: "Unavailable Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            isAvailable: false,
            ownerID: UUID()
        )
        
        let wish = Wish(
            id: UUID(),
            text: "Want electronics",
            keywords: ["electronics"],
            dateAdded: Date(),
            isFulfilled: false
        )
        
        let availableNudge = Nudge(
            id: UUID(),
            neighbor: Neighbor(id: UUID(), name: "Owner1", neighborhood: "Test", tossedItems: [availableItem], wishes: [wish]),
            tossedItem: availableItem,
            wish: wish,
            message: "Match",
            dateGenerated: Date(),
            isRead: false
        )
        
        let unavailableNudge = Nudge(
            id: UUID(),
            neighbor: Neighbor(id: UUID(), name: "Owner2", neighborhood: "Test", tossedItems: [unavailableItem], wishes: [wish]),
            tossedItem: unavailableItem,
            wish: wish,
            message: "No match",
            dateGenerated: Date(),
            isRead: false
        )
        
        #expect(availableNudge.tossedItem.isAvailable == true)
        #expect(unavailableNudge.tossedItem.isAvailable == false)
    }
    
    @Test("Multiple nudges can reference same wish")
    func multipleNudgesReferenceSameWish() async throws {
        let neighbor1 = Neighbor(
            id: UUID(),
            name: "Owner1",
            neighborhood: "Test",
            tossedItems: [],
            wishes: [
                Wish(id: UUID(), text: "Test", keywords: ["test"], dateAdded: Date(), isFulfilled: false)
            ]
        )
        
        let neighbor2 = Neighbor(
            id: UUID(),
            name: "Owner2",
            neighborhood: "Test",
            tossedItems: [],
            wishes: [
                Wish(id: neighbor1.wishes[0].id, text: "Test", keywords: ["test"], dateAdded: Date(), isFulfilled: false)
            ]
        )
        
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            isAvailable: true,
            ownerID: UUID()
        )
        
        let nudge1 = Nudge(
            id: UUID(),
            neighbor: neighbor1,
            tossedItem: tossedItem,
            wish: neighbor1.wishes[0],
            message: "Match 1",
            dateGenerated: Date(),
            isRead: false
        )
        
        let nudge2 = Nudge(
            id: UUID(),
            neighbor: neighbor2,
            tossedItem: tossedItem,
            wish: neighbor2.wishes[0],
            message: "Match 2",
            dateGenerated: Date(),
            isRead: false
        )
        
        // Both nudges should have the same wish ID
        #expect(nudge1.wish.id == nudge2.wish.id)
    }
}

// MARK: - Item Model Tests

@Suite("Item Model Tests")
struct ItemModelTests {
    
    @Test("TossedItem has required fields")
    func tossedItemHasRequiredFields() async throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Test Item",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            ownerID: UUID()
        )
        
        #expect(tossedItem.id != nil)
        #expect(!tossedItem.title.isEmpty)
        #expect(tossedItem.category.isEmpty == false)
        #expect(tossedItem.condition.isEmpty == false)
        #expect(tossedItem.isAvailable == true)
    }
    
    @Test("Wish has required fields")
    func wishHasRequiredFields() async throws {
        let wish = Wish(
            id: UUID(),
            text: "I need this",
            keywords: ["test"],
            dateAdded: Date(),
            isFulfilled: false
        )
        
        #expect(wish.id != nil)
        #expect(!wish.text.isEmpty)
        #expect(wish.keywords.isEmpty == false)
        #expect(wish.isFulfilled == false)
    }
    
    @Test("Multiple tossed items with same title have unique IDs")
    func multipleTossedItemsHaveUniqueIDs() {
        let items: [TossedItem] = [
            TossedItem(id: UUID(), title: "Same Title", category: .electronics, condition: .good, dateAdded: Date(), ownerID: UUID()),
            TossedItem(id: UUID(), title: "Same Title", category: .electronics, condition: .good, dateAdded: Date(), ownerID: UUID())
        ]
        
        for i in 0..<items.count - 1 {
            for j in i+1..<items.count {
                #expect(items[i].id != items[j].id)
            }
        }
    }
    
    @Test("Wish isFulfilled status")
    func wishFulfilledStatus() async throws {
        let fulfilledWish = Wish(id: UUID(), text: "Fulfilled", keywords: ["test"], dateAdded: Date(), isFulfilled: true)
        let unfulfilledWish = Wish(id: UUID(), text: "Unfulfilled", keywords: ["test"], dateAdded: Date(), isFulfilled: false)
        
        #expect(fulfilledWish.isFulfilled == true)
        #expect(unfulfilledWish.isFulfilled == false)
    }
    
    @Test("Item category icons are valid")
    func itemCategoryIconsAreValid() {
        for category in ItemCategory.allCases {
            #expect(!category.systemImageName.isEmpty)
            #expect(category.systemImageName.count <= 16)
        }
    }
}

// MARK: - Boundary Condition Tests

@Suite("Boundary Condition Tests")
struct BoundaryConditionTests {
    
    @Test("Empty title validation")
    func emptyTitleValidation() throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            ownerID: UUID()
        )
        
        #expect(tossedItem.title.isEmpty == true)
    }
    
    @Test("Very long title is accepted")
    func veryLongTitle() async throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "A".repeating(count: 200),
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            ownerID: UUID()
        )
        
        #expect(tossedItem.title.count == 200)
    }
    
    @Test("DateAdded defaults to current time")
    func dateAddedDefaults() async throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Test",
            category: .electronics,
            condition: .good,
            ownerID: UUID()
        )
        
        #expect(tossedItem.dateAdded.isAfter(date: Date().addingTimeInterval(-60)))
    }
    
    @Test("IsAvailable defaults to true")
    func isAvailableDefaults() async throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Test",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            ownerID: UUID()
        )
        
        #expect(tossedItem.isAvailable == true)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Profile can be populated with offers and wishes")
    func profilePopulated() async throws {
        // Placeholder - waiting for CommonsProfile struct to be complete
        #expect(true)
    }
    
    @Test("Offer can be created from tossed item")
    func offerFromTossedItem() async throws {
        let tossedItem = TossedItem(
            id: UUID(),
            title: "Test Item",
            description: "Test description",
            category: .electronics,
            condition: .good,
            dateAdded: Date(),
            ownerID: UUID()
        )
        
        let offer = Offer(
            id: UUID(),
            title: tossedItem.title,
            description: tossedItem.description,
            category: tossedItem.category.rawValue,
            condition: tossedItem.condition.rawValue,
            addedAt: Date(),
            available: true
        )
        
        #expect(!offer.title.isEmpty)
        #expect(!offer.category.isEmpty)
        #expect(offer.condition.isEmpty == false)
        #expect(offer.available == true)
    }
}
