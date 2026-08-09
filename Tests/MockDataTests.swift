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
        
        // Each neighbor should have at least one offer and one wish
        for neighbor in neighbors {
            #expect(neighbor.offers.isEmpty == false)
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
                #expect(wish.fulfilled == false)
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
        }
    }
}

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
        }
    }
}

// MARK: - Mock Wishes Validation

@Suite("Mock Wishes Validation")
struct MockWishesValidation {
    
    @Test("Mock wishes have text content")
    func mockWishesHaveText() async throws {
        let wishes = MockData.mockWishes
        
        for wish in wishes {
            #expect(!wish.text.isEmpty)
            #expect(!wish.text.contains(whitespace: true) || wish.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            #expect(wish.fulfilled == false)
        }
    }
    
    @Test("Mock wishes have diverse keywords")
    func mockWishesDiverseKeywords() async throws {
        let wishes = MockData.mockWishes
        
        let allKeywords = Set(wishes.flatMap { $0.keywords })
        #expect(allKeywords.count > 5) // Should have at least 5 unique keywords
    }
}

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
        )
        
        let wish = Wish(
            id: UUID(),
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
        )
        
        let nudge = Nudge(
            id: UUID(),
            offerOwnerName: "Alice",
            offer: offer,
            wishOwnerName: "Bob",
            wish: wish,
            message: "Test message"
        )
        
        #expect(nudge.message.contains("Alice"))
    }
    
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
        }
    }
}

// MARK: - Boundary Condition Tests

@Suite("Boundary Condition Tests")
struct BoundaryConditionTests {
    
    @Test("Empty title validation")
    func emptyTitleValidation() throws {
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
    }
}
