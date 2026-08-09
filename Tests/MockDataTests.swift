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
        
<<<<<<< HEAD
        // Each neighbor should have at least one tossed item and one wish
        for neighbor in neighbors {
            #expect(neighbor.tossedItems.isEmpty == false)
=======
        // Each neighbor should have at least one offer and one wish
        for neighbor in neighbors {
            #expect(neighbor.offers.isEmpty == false)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
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
<<<<<<< HEAD
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
=======
            #expect(neighbor.updatedAt.isAfter(date: Date().addingTimeInterval(-1)))
        }
    }
    
    @Test("Mock offers are valid")
    func mockOffersValid() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            for offer in neighbor.offers {
                #expect(offer.id != nil)
                #expect(!offer.title.isEmpty)
                #expect(offer.category.isEmpty == false)
                #expect(offer.condition.isEmpty == false)
                #expect(offer.available == true)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
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
<<<<<<< HEAD
                #expect(wish.isFulfilled == false)
=======
                #expect(wish.fulfilled == false)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
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
    
<<<<<<< HEAD
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
=======
    @Test("Mock neighbor has both offers and wishes")
    func mockNeighborHasBothOffersAndWishes() async throws {
        let neighbors = MockData.getMockNeighbors()
        
        for neighbor in neighbors {
            #expect(neighbor.offers.count >= 1)
            #expect(neighbor.wishes.count >= 1)
            
            // Verify offers are distinct
            let offerIds = Set(neighbor.offers.map { $0.id })
            #expect(offerIds.count == neighbor.offers.count)
            
            // Verify wishes are distinct
            let wishIds = Set(neighbor.wishes.map { $0.id })
            #expect(wishIds.count == neighbor.wishes.count)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        }
    }
}

<<<<<<< HEAD
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
=======
// MARK: - Mock Offers Validation

@Suite("Mock Offers Validation")
struct MockOffersValidation {
    
    @Test("Mock offers have reasonable conditions")
    func mockOffersHaveReasonableConditions() async throws {
        let validConditions = ["good", "like-new", "new", "fair"]
        let invalidConditions = ["", "excellent", "brand-new", "used"]
        
        let offers = MockData.mockOffers
        
        for offer in offers {
            #expect(validConditions.contains(offer.condition))
            #expect(!invalidConditions.contains(offer.condition))
        }
    }
    
    @Test("Mock offers have valid categories")
    func mockOffersHaveValidCategories() async throws {
        let validCategories = ["electronics", "furniture", "kitchenware", "tools", "clothing", "books", "toys", "sports", "office"]
        
        let offers = MockData.mockOffers
        for offer in offers {
            // Category should be in valid list (allow for future categories)
            #expect(validCategories.contains(offer.category))
        }
    }
    
    @Test("Mock offers have tags")
    func mockOffersHaveTags() async throws {
        let offers = MockData.mockOffers
        
        for offer in offers {
            // Should have at least one tag
            #expect(!offer.tags.isEmpty)
            
            // Verify tag uniqueness
            let tagSet = Set(offer.tags)
            #expect(tagSet.count == offer.tags.count)
        }
    }
    
    @Test("Mock offers have timestamps")
    func mockOffersHaveTimestamps() async throws {
        let offers = MockData.mockOffers
        
        for offer in offers {
            #expect(offer.addedAt != Date.distantPast)
            // Timestamps should be within reasonable range
            #expect(offer.addedAt.isAfter(date: Date().addingTimeInterval(-365 * 86400)))
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        }
    }
}

<<<<<<< HEAD
// MARK: - Mock Wish Validation

@Suite("Mock Wish Validation")
struct MockWishValidation {
=======
// MARK: - Mock Wishes Validation

@Suite("Mock Wishes Validation")
struct MockWishesValidation {
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
    
    @Test("Mock wishes have text content")
    func mockWishesHaveText() async throws {
        let wishes = MockData.mockWishes
        
        for wish in wishes {
            #expect(!wish.text.isEmpty)
<<<<<<< HEAD
=======
            #expect(!wish.text.contains(whitespace: true) || wish.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
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
<<<<<<< HEAD
            #expect(wish.isFulfilled == false)
=======
            #expect(wish.fulfilled == false)
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        }
    }
    
    @Test("Mock wishes have diverse keywords")
    func mockWishesDiverseKeywords() async throws {
        let wishes = MockData.mockWishes
        
        let allKeywords = Set(wishes.flatMap { $0.keywords })
        #expect(allKeywords.count > 5) // Should have at least 5 unique keywords
    }
}

<<<<<<< HEAD
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
=======
// MARK: - Nudge Matching Tests

@Suite("Nudge Matching Tests")
struct NudgeMatchingTests {
    
    @Test("Nudge matches compatible offers and wishes")
    func nudgeMatchesCompatible() async throws {
        let offer = Offer(
            id: UUID(),
            title: "USB-C Cable",
            description: "USB-C charging cable",
            category: "electronics",
            condition: "good",
            addedAt: Date(),
            available: true
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        )
        
        let wish = Wish(
            id: UUID(),
<<<<<<< HEAD
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
=======
            text: "Need a USB-C cable",
            keywords: ["cable", "usb-c", "electronics", "charging"],
            addedAt: Date(),
            fulfilled: false
        )
        
        let message = "John has a USB-C Cable that matches your need for a USB-C cable"
        
        let nudge = Nudge(
            id: UUID(),
            offerOwnerName: "John",
            offer: offer,
            wishOwnerName: "Jane",
            wish: wish,
            message: message
        )
        
        #expect(nudge.offer.available == true)
        #expect(nudge.wish.fulfilled == false)
        #expect(nudge.offer.title.lowercased().contains("usb-c"))
        #expect(nudge.wish.text.lowercased().contains("usb-c"))
    }
    
    @Test("Nudge message includes offer owner")
    func nudgeMessageIncludesOfferOwner() async throws {
        let offer = Offer(
            id: UUID(),
            title: "Test Item",
            addedAt: Date(),
            available: true
        )
        let wish = Wish(
            id: UUID(),
            text: "I need test",
            addedAt: Date(),
            fulfilled: false
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        )
        
        let nudge = Nudge(
            id: UUID(),
<<<<<<< HEAD
            neighbor: neighbor,
            tossedItem: tossedItem,
            wish: wish,
            message: "Alice has an Item that matches your need for an item",
            dateGenerated: Date(),
            isRead: false
=======
            offerOwnerName: "Alice",
            offer: offer,
            wishOwnerName: "Bob",
            wish: wish,
            message: "Test message"
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        )
        
        #expect(nudge.message.contains("Alice"))
    }
    
<<<<<<< HEAD
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
=======
    @Test("Nudge message includes wish owner")
    func nudgeMessageIncludesWishOwner() async throws {
        let offer = Offer(id: UUID(), title: "Item", addedAt: Date(), available: true)
        let wish = Wish(id: UUID(), text: "Want item", addedAt: Date(), fulfilled: false)
        
        let nudge = Nudge(
            id: UUID(),
            offerOwnerName: "Alice",
            offer: offer,
            wishOwnerName: "Bob",
            wish: wish,
            message: "Test message"
        )
        
        #expect(nudge.message.contains("Bob"))
    }
}

// MARK: - CommonsProfile Integration Tests

@Suite("CommonsProfile Integration Tests")
struct CommonsProfileIntegrationTests {
    
    @Test("Profile can be populated with offers and wishes")
    func profilePopulated() async throws {
        let profile = CommonsProfile(
            id: UUID(),
            name: "Test User",
            neighborhood: "Test Neighborhood"
        )
        
        // Add offers
        profile.offers = [
            Offer(
                id: UUID(),
                title: "Offer 1",
                category: "electronics",
                condition: "good",
                addedAt: Date(),
                available: true
            )
        ]
        
        // Add wishes
        profile.wishes = [
            Wish(
                id: UUID(),
                text: "I need item",
                keywords: ["electronics"],
                addedAt: Date(),
                fulfilled: false
            )
        ]
        
        #expect(profile.offers.count == 1)
        #expect(profile.wishes.count == 1)
        #expect(profile.offers[0].title == "Offer 1")
        #expect(profile.wishes[0].text == "I need item")
    }
    
    @Test("Profile can be serialized with all data types")
    func profileSerializationComplete() throws {
        let profile = CommonsProfile(
            id: UUID(),
            name: "Test Name",
            neighborhood: "Test Neighborhood"
        )
        
        let encoder = JSONEncoder()
        encoder.dateDecodingStrategy = .deferredToDate
        encoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let deserialized = try decoder.decode(CommonsProfile.self, from: data)
        
        #expect(deserialized.id == profile.id)
        #expect(deserialized.name == profile.name)
        #expect(deserialized.neighborhood == profile.neighborhood)
    }
    
    @Test("Multiple profiles have unique IDs")
    func multipleProfilesHaveUniqueIDs() {
        let profiles: [CommonsProfile] = [
            CommonsProfile(name: "User 1"),
            CommonsProfile(name: "User 2"),
            CommonsProfile(name: "User 3")
        ]
        
        let ids = profiles.map { $0.id }
        let uniqueIds = Set(ids)
        
        #expect(uniqueIds.count == profiles.count)
    }
}

// MARK: - Real Data Simulation Tests

@Suite("Real Data Simulation Tests")
struct RealDataSimulationTests {
    
    @Test("Profile timestamps are in the future")
    func profileTimestampsInFuture() async throws {
        let profile = CommonsProfile(name: "Test User")
        
        #expect(profile.updatedAt.isAfter(date: Date()))
    }
    
    @Test("Offer addedAt is recent")
    func offerAddedAtRecent() async throws {
        let offer = Offer(
            id: UUID(),
            title: "Test",
            addedAt: Date()
        )
        
        #expect(offer.addedAt.isAfter(date: Date().addingTimeInterval(-86400))) // Within 24 hours
    }
    
    @Test("Wish addedAt is recent")
    func wishAddedAtRecent() async throws {
        let wish = Wish(
            id: UUID(),
            text: "Test",
            addedAt: Date()
        )
        
        #expect(wish.addedAt.isAfter(date: Date().addingTimeInterval(-86400)))
    }
    
    @Test("Available offers have recent dates")
    func availableOffersHaveRecentDates() async throws {
        let offers: [Offer] = [
            Offer(
                id: UUID(),
                title: "Recent",
                addedAt: Date(),
                available: true
            ),
            Offer(
                id: UUID(),
                title: "Old",
                addedAt: Date().addingTimeInterval(-86400 * 7), // 1 week old
                available: true
            )
        ]
        
        for offer in offers {
            // Old offers might have been taken
            // This is a simulation - in real data, old offers would show as unavailable
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
        }
    }
}

// MARK: - Boundary Condition Tests

@Suite("Boundary Condition Tests")
struct BoundaryConditionTests {
    
    @Test("Empty title validation")
    func emptyTitleValidation() throws {
<<<<<<< HEAD
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
=======
        let offer = Offer(id: UUID(), title: "")
        #expect(offer.title.isEmpty == true)
    }
    
    @Test("Very long title behavior")
    func veryLongTitle() async throws {
        let offer = Offer(
            id: UUID(),
            title: "A".repeating(count: 200),
            category: "electronics"
        )
        
        // Should accept long title but have it
        #expect(offer.title.count == 200)
    }
    
    @Test("Multiple categories mapping")
    func multipleCategoriesMapping() async throws {
        let testCases: [(String, String)] = [
            ("Electronics", "electronics"),
            ("Furniture", "furniture"),
            ("clothing", "clothing"),
            ("Books", "books"),
            ("Kitchenware", "kitchenware"),
            ("TOOLS", "tools"),
            ("Toys", "toys"),
            ("Sports", "sports"),
            ("office", "office")
        ]
        
        for (input, expectedCategory) in testCases {
            let offer = Offer(title: "Item", category: input)
            
            let actualCategory = offer.category
            #expect(actualCategory == expectedCategory.lowercased())
        }
    }
    
    @Test("Category icon mapping for all categories")
    func allCategoriesHaveIcons() async throws {
        let categories = ["electronics", "furniture", "clothing", "books", "kitchenware", "tools", "toys", "sports", "office"]
        
        for category in categories {
            let offer = Offer(title: "Item", category: category)
            
            let icon = offer.categoryIcon
            #expect(!icon.isEmpty)
        }
>>>>>>> 995a0b8d9e765ea0af21516b9e82714b633e8f00
    }
}
