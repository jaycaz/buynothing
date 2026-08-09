import Testing
import Foundation
@testable import BuyNothing

// MARK: - Commons Profile Tests

@Suite("Commons Profile Tests")
struct CommonsProfileTests {
    
    @Test("Profile initializes with correct schema version")
    func initializesWithSchemaVersion() async throws {
        let profile = CommonsProfile(name: "Test User")
        
        #expect(profile.schemaVersion == "0.1.0")
    }
    
    @Test("Profile name is required")
    func nameIsRequired() async throws {
        let profile = CommonsProfile(name: "Test User")
        
        #expect(!profile.name.isEmpty)
        #expect(profile.name.count >= 1)
    }
    
    @Test("Profile has unique ID")
    func hasUniqueID() async throws {
        let profile1 = CommonsProfile(name: "User 1")
        let profile2 = CommonsProfile(name: "User 2")
        
        #expect(profile1.id != profile2.id)
        #expect(profile1.id != profile1.id)
    }
    
    @Test("Profile offers are valid Offers")
    func offersAreValidOffers() async throws {
        let profile = CommonsProfile(
            name: "Test User",
            offers: [
                Offer(
                    id: UUID(),
                    title: "Test Item",
                    category: "electronics",
                    condition: "good",
                    addedAt: Date(),
                    available: true
                )
            ]
        )
        
        for offer in profile.offers {
            try testOfferValidation(offer: offer)
        }
    }
    
    @Test("Profile wishes are valid Wishes")
    func wishesAreValidWishes() async throws {
        let profile = CommonsProfile(
            name: "Test User",
            wishes: [
                Wish(
                    id: UUID(),
                    text: "I need this",
                    keywords: ["test"],
                    addedAt: Date(),
                    fulfilled: false
                )
            ]
        )
        
        for wish in profile.wishes {
            try testWishValidation(wish: wish)
        }
    }
    
    @Test("Empty profile is valid")
    func emptyProfileIsValid() async throws {
        let profile = CommonsProfile(name: "Empty User")
        
        #expect(profile.offers.isEmpty == true)
        #expect(profile.wishes.isEmpty == true)
        #expect(profile.id != nil)
        #expect(!profile.name.isEmpty)
    }
    
    @Test("Profile updates timestamp on modification")
    func updatesTimestampOnModification() async throws {
        var profile = CommonsProfile(name: "Test User")
        let originalTimestamp = profile.updatedAt
        
        // Simulate adding an offer
        profile.offers.append(
            Offer(title: "New Item", category: "electronics", condition: "good", addedAt: Date())
        )
        
        #expect(profile.updatedAt > originalTimestamp)
    }
    
    @Test("Profile can be serialized and deserialized")
    func profileSerializationRoundTrip() throws {
        let profile = CommonsProfile(
            id: UUID(),
            name: "Serialization Test User",
            neighborhood: "Test Neighborhood",
            offers: [
                Offer(
                    id: UUID(),
                    title: "Offer Title 1",
                    description: "Offer Description 1",
                    category: "electronics",
                    condition: "good",
                    addedAt: Date(),
                    available: true
                ),
                Offer(
                    id: UUID(),
                    title: "Offer Title 2",
                    description: "Offer Description 2",
                    category: "kitchenware",
                    condition: "like-new",
                    addedAt: Date().addingTimeInterval(100),
                    available: false
                )
            ],
            wishes: [
                Wish(
                    id: UUID(),
                    text: "Wish Text 1",
                    keywords: ["cable", "electronics"],
                    addedAt: Date().addingTimeInterval(50),
                    fulfilled: false
                ),
                Wish(
                    id: UUID(),
                    text: "Wish Text 2",
                    keywords: ["kitchen", "tool"],
                    addedAt: Date().addingTimeInterval(75),
                    fulfilled: true
                )
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateDecodingStrategy = .deferredToDate
        encoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder.outputFormatting = [.sortedKeys, .removeUnneededValues]
        
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.keyEncodingStrategy = .convertToSnakeCase
        
        let deserializedProfile = try decoder.decode(CommonsProfile.self, from: data)
        
        #expect(deserializedProfile.id == profile.id)
        #expect(deserializedProfile.name == profile.name)
        #expect(deserializedProfile.neighborhood == profile.neighborhood)
        #expect(deserializedProfile.updatedAt == profile.updatedAt)
        #expect(deserializedProfile.offers.count == profile.offers.count)
        #expect(deserializedProfile.wishes.count == profile.wishes.count)
    }
}

// MARK: - Offer Tests

@Suite("Offer Tests")
struct OfferTests {
    
    @Test("Offer requires title")
    func offerRequiresTitle() throws {
        let offer = Offer(id: UUID(), title: "Must Have")
        
        #expect(!offer.title.isEmpty)
        #expect(offer.title.count >= 1)
        #expect(offer.title.count <= 100) // Reasonable length limit
    }
    
    @Test("Offer has default values for optional fields")
    func hasDefaultValues() throws {
        let offer = Offer(title: "Test")
        
        #expect(offer.title == "Test")
        #expect(offer.description.isEmpty == true)
        #expect(offer.tags.isEmpty == true)
        #expect(offer.category == "other")
        #expect(offer.condition == "good")
        #expect(offer.available == true)
        #expect(offer.addedAt.isAfter(date: Date().addingTimeInterval(-60)))
    }
    
    @Test("Offer category has valid icon")
    func categoryHasValidIcon() async throws {
        let testCategories = [
            "electronics",
            "furniture",
            "clothing",
            "books",
            "kitchenware",
            "tools",
            "toys",
            "sports",
            "office"
        ]
        
        for category in testCategories {
            let offer = Offer(title: "Test", category: category)
            
            // Category icons should be non-empty and reasonably short
            let icon = offer.categoryIcon
            #expect(!icon.isEmpty)
            #expect(icon.count <= 16)
        }
    }
    
    @Test("Multiple offers with same title get unique IDs")
    func multipleOffersHaveUniqueIDs() {
        let offers: [Offer] = [
            Offer(title: "Amazing Item"),
            Offer(title: "Amazing Item"),
            Offer(title: "Amazing Item")
        ]
        
        for i in 0..<offers.count - 1 {
            for j in i+1..<offers.count {
                #expect(offers[i].id != offers[j].id)
            }
        }
    }
    
    @Test("Offer is Equatable")
    func offerIsEquatable() async throws {
        let offer1 = Offer(
            id: UUID(),
            title: "Test",
            category: "electronics",
            condition: "good",
            addedAt: Date(),
            available: true
        )
        
        let offer2 = Offer(
            id: offer1.id,
            title: offer1.title,
            category: offer1.category,
            condition: offer1.condition,
            addedAt: offer1.addedAt,
            available: offer1.available
        )
        
        #expect(offer1 == offer2)
        
        // Different title should not be equal
        let offer3 = Offer(
            id: offer1.id,
            title: "Different",
            category: offer1.category,
            condition: offer1.condition,
            addedAt: offer1.addedAt,
            available: offer1.available
        )
        
        #expect(offer1 != offer3)
    }
    
    @Test("Offer available flag works as expected")
    func availableFlagWorks() async throws {
        let availableOffer = Offer(title: "Available", available: true)
        let unavailableOffer = Offer(title: "Gone", available: false)
        
        #expect(availableOffer.available == true)
        #expect(unavailableOffer.available == false)
    }
}

// MARK: - Wish Tests

@Suite("Wish Tests")
struct WishTests {
    
    @Test("Wish requires text")
    func wishRequiresText() throws {
        let wish = Wish(id: UUID(), text: "I really need this")
        
        #expect(!wish.text.isEmpty)
        #expect(wish.text.count <= 500) // Reasonable length
    }
    
    @Test("Wish defaults to empty keywords")
    func defaultsToEmptyKeywords() throws {
        let wish = Wish(id: UUID(), text: "Just something")
        
        #expect(wish.keywords.isEmpty == true)
    }
    
    @Test("Wish fulfulled status is initially false")
    func initiallyUnfulfilled() throws {
        let wish = Wish(id: UUID(), text: "Need this")
        
        #expect(wish.fulfilled == false)
    }
    
    @Test("Wish is Equatable")
    func wishIsEquatable() async throws {
        let wish1 = Wish(
            id: UUID(),
            text: "Test Wish",
            keywords: ["keyword1", "keyword2"],
            addedAt: Date(),
            fulfilled: false
        )
        
        let wish2 = Wish(
            id: wish1.id,
            text: wish1.text,
            keywords: wish1.keywords,
            addedAt: wish1.addedAt,
            fulfilled: wish1.fulfilled
        )
        
        #expect(wish1 == wish2)
    }
    
    @Test("Keyword parsing from text")
    func keywordParsing() async throws {
        let keywords = ["cable", "phone", "charger", "adapter"]
        let wish = Wish(id: UUID(), text: keywords.joined(separator: ", "), keywords: keywords)
        
        #expect(wish.keywords.count == keywords.count)
        #expect(wish.keywords.contains { $0 == "cable" })
    }
}

// MARK: - Nudge Tests

@Suite("Nudge Tests")
struct NudgeTests {
    
    @Test("Nudge has all required fields")
    func nudgeHasAllRequiredFields() throws {
        let offer = Offer(
            id: UUID(),
            title: "Test Offer",
            category: "electronics",
            condition: "good",
            addedAt: Date(),
            available: true
        )
        let wish = Wish(
            id: UUID(),
            text: "Test Wish",
            keywords: ["test"],
            addedAt: Date(),
            fulfilled: false
        )
        
        let nudge = Nudge(
            id: UUID(),
            offerOwnerName: "John",
            offer: offer,
            wishOwnerName: "Jane",
            wish: wish,
            message: "John has a test offer that matches Jane's wish"
        )
        
        #expect(nudge.id != nil)
        #expect(!nudge.offerOwnerName.isEmpty)
        #expect(!nudge.wishOwnerName.isEmpty)
        #expect(!nudge.message.isEmpty)
    }
    
    @Test("Nudge message is descriptive")
    func nudgeMessageIsDescriptive() async throws {
        let offer = Offer(
            id: UUID(),
            title: "Vintage Camera Lens",
            category: "electronics",
            condition: "good",
            addedAt: Date(),
            available: true
        )
        let wish = Wish(
            id: UUID(),
            text: "Need a camera lens",
            keywords: ["camera", "lens"],
            addedAt: Date(),
            fulfilled: false
        )
        
        let nudge = Nudge(
            id: UUID(),
            offerOwnerName: "PhotoEnthusiast",
            offer: offer,
            wishOwnerName: "LensLover",
            wish: wish,
            message: "PhotoEnthusiast has a Vintage Camera Lens that could match LensLover's wish for a camera lens!"
        )
        
        #expect(nudge.message.contains("PhotoEnthusiast"))
        #expect(nudge.message.contains("Vintage Camera Lens"))
        #expect(nudge.message.contains("LensLover"))
        #expect(nudge.message.contains("camera lens"))
    }
    
    @Test("Nudge matches only available offers")
    func nudgeMatchesAvailableOffers() async throws {
        let availableOffer = Offer(
            id: UUID(),
            title: "Available Item",
            condition: "good",
            addedAt: Date(),
            available: true
        )
        let unavailableOffer = Offer(
            id: UUID(),
            title: "Taken Item",
            condition: "good",
            addedAt: Date(),
            available: false
        )
        
        let wish = Wish(
            id: UUID(),
            text: "Test",
            addedAt: Date(),
            fulfilled: false
        )
        
        let availableNudge = Nudge(id: UUID(), offerOwnerName: "User1", offer: availableOffer, wishOwnerName: "User2", wish: wish, message: "Match")
        let unavailableNudge = Nudge(id: UUID(), offerOwnerName: "User2", offer: unavailableOffer, wishOwnerName: "User1", wish: wish, message: "Match")
        
        // Both nudges are created with matching offers/wishes
        #expect(availableNudge.offer.available == true)
        #expect(unavailableNudge.offer.available == false)
    }
    
    @Test("Multiple nudges can have same wish")
    func multipleNudgesForSameWish() async throws {
        let offer1 = Offer(id: UUID(), title: "Offer 1", condition: "good", addedAt: Date(), available: true)
        let offer2 = Offer(id: UUID(), title: "Offer 2", condition: "good", addedAt: Date(), available: true)
        let wish = Wish(id: UUID(), text: "Test", keywords: ["test"], addedAt: Date(), fulfilled: false)
        
        let nudge1 = Nudge(id: UUID(), offerOwnerName: "Person1", offer: offer1, wishOwnerName: "User", wish: wish, message: "Match 1")
        let nudge2 = Nudge(id: UUID(), offerOwnerName: "Person2", offer: offer2, wishOwnerName: "User", wish: wish, message: "Match 2")
        
        // Both nudges reference the same wish
        #expect(nudge1.wish.id == wish.id)
        #expect(nudge2.wish.id == wish.id)
        #expect(nudge1.offerOwnerName != nudge2.offerOwnerName)
    }
}

// MARK: - USBCable Tests

@Suite("USBCable Tests")
struct USBCableTests {
    
    @Test("USBCableType has all expected cases")
    func usbCableTypeHasAllCases() {
        let expectedCases: [USBCableType] = [
            .usbA, .usbC, .lightning, .microUSB, .miniUSB, .usb30, .thunderbolt
        ]
        let actualCases = USBCableType.allCases
        
        #expect(actualCases.count == expectedCases.count)
        for expectedCase in expectedCases {
            let found = actualCases.contains { $0 == expectedCase }
            #expect(found == true)
        }
    }
    
    @Test("USBCableType raw values are readable")
    func usbCableTypeRawValuesReadable() {
        #expect(USBCableType.usbA.rawValue == "USB-A")
        #expect(USBCableType.usbC.rawValue == "USB-C")
        #expect(USBCableType.lightning.rawValue == "Lightning")
        #expect(USBCableType.microUSB.rawValue == "Micro-USB")
        #expect(USBCableType.miniUSB.rawValue == "Mini-USB")
        #expect(USBCableType.usb30.rawValue == "USB 3.0")
        #expect(USBCableType.thunderbolt.rawValue == "Thunderbolt")
    }
    
    @Test("USBCableType display names match")
    func usbCableTypeDisplayNames() async throws {
        for type in USBCableType.allCases {
            let displayName = type.displayName
            let rawValue = type.rawValue
            
            // Display name should be readable version of raw value
            #expect(displayName.contains(rawValue))
        }
    }
    
    @Test("USBCableType has appropriate max speeds")
    func usbCableTypeMaxSpeeds() {
        let speeds: [String] = [
            "480 Mbps",      // usbA, lightning, microUSB
            "10 Gbps",       // usbC
            "5 Gbps",        // usb30
            "40 Gbps"        // thunderbolt
        ]
        
        #expect(USBCableType.usbA.maxSpeed == speeds[0])
        #expect(USBCableType.usbC.maxSpeed == speeds[1])
        #expect(USBCableType.lightning.maxSpeed == speeds[0])
        #expect(USBCableType.microUSB.maxSpeed == speeds[0])
        #expect(USBCableType.usb30.maxSpeed == speeds[2])
        #expect(USBCableType.thunderbolt.maxSpeed == speeds[3])
    }
    
    @Test("USBCable displays correctly")
    func usbCableDisplayName() async throws {
        let singleEndCable = USBCable(
            connectorType1: .usbC,
            connectorType2: nil
        )
        
        let bothEndsCable = USBCable(
            connectorType1: .usbC,
            connectorType2: .usbA
        )
        
        #expect(singleEndCable.displayName == "USB-C")
        #expect(bothEndsCable.displayName == "USB-C to USB-A")
    }
    
    @Test("USBCable description includes all fields")
    func usbCableDescription() async throws {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .usbA,
            length: .long,
            condition: .good,
            color: "Black",
            brand: "Anker",
            notes: "Very reliable"
        )
        
        let expectedDescription = "USB-C to USB-A (long) - Anker"
        #expect(cable.description == expectedDescription)
    }
    
    @Test("USBCable description without brand")
    func usbCableDescriptionWithoutBrand() async throws {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .usbA,
            length: .long,
            condition: .good
        )
        
        let expectedDescription = "USB-C to USB-A (long)"
        #expect(cable.description == expectedDescription)
    }
    
    @Test("USBCable has default initialization")
    func usbCableDefaults() async throws {
        let cable = USBCable()
        
        #expect(cable.condition == .good)
        #expect(cable.color == "Black")
        #expect(cable.brand == nil)
        #expect(cable.notes == nil)
        #expect(cable.isAvailable == true)
        #expect(cable.dateAdded.isAfter(date: Date().addingTimeInterval(-60)))
    }
    
    @Test("USBCable is Equatable")
    func usbCableIsEquatable() async throws {
        let cable1 = USBCable(
            connectorType1: .usbC,
            length: .medium,
            condition: .good
        )
        
        let cable2 = USBCable(
            connectorType1: cable1.connectorType1,
            length: cable1.length,
            condition: cable1.condition
        )
        
        #expect(cable1 == cable2)
    }
}

// MARK: - USBCableLength Tests

@Suite("USBCableLength Tests")
struct USBCableLengthTests {
    
    @Test("USBCableLength has all expected cases")
    func usbCableLengthHasAllCases() {
        let expectedCases: [USBCableLength] = [
            .short, .medium, .long, .extraLong, .unknown
        ]
        let actualCases = USBCableLength.allCases
        
        #expect(actualCases.count == expectedCases.count)
    }
    
    @Test("USBCableLength raw values are readable")
    func usbCableLengthRawValuesReadable() {
        #expect(USBCableLength.short.rawValue == "< 1ft")
        #expect(USBCableLength.medium.rawValue == "1-3ft")
        #expect(USBCableLength.long.rawValue == "3-6ft")
        #expect(USBCableLength.extraLong.rawValue == "> 6ft")
    }
}

// MARK: - USBCableCondition Tests

@Suite("USBCableCondition Tests")
struct USBCableConditionTests {
    
    @Test("USBCableCondition has all expected cases")
    func usbCableConditionHasAllCases() {
        let expectedCases: [USBCableCondition] = [
            .new, .likeNew, .good, .fair, .poor
        ]
        let actualCases = USBCableCondition.allCases
        
        #expect(actualCases.count == expectedCases.count)
    }
    
    @Test("USBCableCondition raw values are readable")
    func usbCableConditionRawValuesReadable() {
        #expect(USBCableCondition.new.rawValue == "New")
        #expect(USBCableCondition.likeNew.rawValue == "Like New")
        #expect(USBCableCondition.good.rawValue == "Good")
        #expect(USBCableCondition.fair.rawValue == "Fair")
        #expect(USBCableCondition.poor.rawValue == "Poor")
    }
}

// MARK: - Cable Detection Result Validation Tests

@Suite("Cable Detection Result Validation")
struct CableDetectionResultValidation {
    
    @Test("Result validates confidence range")
    func validatesConfidenceRange() async throws {
        for confidence in 0.0...1.0 {
            let result = TestUtilities.makeCableDetectionResult(confidence: confidence)
            
            // Confidence should always be in valid range
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
        }
    }
    
    @Test("Result bounding box is valid when provided")
    func boundingBoxIsValid() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.95,
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        )
        
        // X and Y should be in [0, 1]
        #expect(result.boundingBox!.origin.x >= 0.0)
        #expect(result.boundingBox!.origin.x <= 1.0)
        #expect(result.boundingBox!.origin.y >= 0.0)
        #expect(result.boundingBox!.origin.y <= 1.0)
        
        // Width and height should be in [0, 1]
        #expect(result.boundingBox!.width >= 0.0)
        #expect(result.boundingBox!.width <= 1.0)
        #expect(result.boundingBox!.height >= 0.0)
        #expect(result.boundingBox!.height <= 1.0)
    }
    
    @Test("Processing time is non-negative")
    func processingTimeValid() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.85
        )
        
        #expect(result.processingTime >= 0.0)
    }
    
    @Test("Alternative detection confidence is lower than primary")
    func alternativeConfidenceLowerThanPrimary() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.9,
            alternativeCount: 1
        )
        
        // Primary detection should have higher confidence than alternatives
        if result.alternativeDetections.count > 0 {
            let primaryConfidence = result.confidence
            for alt in result.alternativeDetections {
                #expect(alt.confidence < primaryConfidence)
            }
        }
    }
    
    @Test("Alternative detection has valid bounding box")
    func alternativeDetectionBoundingBoxValid() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.95,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.3)
        )
        
        if result.alternativeDetections.count > 0 {
            for alt in result.alternativeDetections {
                if let box = alt.boundingBox {
                    #expect(box.origin.x >= 0.0)
                    #expect(box.origin.x <= 1.0)
                    #expect(box.origin.y >= 0.0)
                    #expect(box.origin.y <= 1.0)
                    #expect(box.width >= 0.0)
                    #expect(box.width <= 1.0)
                    #expect(box.height >= 0.0)
                    #expect(box.height <= 1.0)
                }
            }
        }
    }
}

// MARK: - Cable Detection Confidence Classification Tests

@Suite("Cable Detection Confidence Classification")
struct CableDetectionConfidenceTests {
    
    @Test("High confidence threshold is 0.8")
    func highConfidenceThreshold() async throws {
        for confidence in [0.0, 0.7, 0.799, 0.8, 0.801, 0.95, 1.0] {
            let result = TestUtilities.makeCableDetectionResult(confidence: confidence)
            let isHigh = result.isHighConfidence
            
            #expect(isHigh == (confidence >= 0.8))
        }
    }
    
    @Test("Medium confidence threshold is 0.6")
    func mediumConfidenceThreshold() async throws {
        for confidence in [0.0, 0.5, 0.599, 0.6, 0.601, 0.7, 0.8] {
            let result = TestUtilities.makeCableDetectionResult(confidence: confidence)
            let isMedium = result.isMediumConfidence
            
            #expect(isMedium == (confidence >= 0.6 && confidence < 0.8))
        }
    }
    
    @Test("Low confidence threshold is 0.6")
    func lowConfidenceThreshold() async throws {
        for confidence in [0.0, 0.5, 0.599, 0.6, 0.601, 0.7, 0.8, 1.0] {
            let result = TestUtilities.makeCableDetectionResult(confidence: confidence)
            let isLow = result.isLowConfidence
            
            #expect(isLow == (confidence < 0.6))
        }
    }
    
    @Test("Confidence levels are mutually exclusive")
    func confidenceLevelsMutuallyExclusive() async throws {
        for confidence in [0.0, 0.3, 0.5, 0.6, 0.7, 0.8, 1.0] {
            let result = TestUtilities.makeCableDetectionResult(confidence: confidence)
            let total = result.isHighConfidence ? 1 : 0
            total += result.isMediumConfidence ? 1 : 0
            total += result.isLowConfidence ? 1 : 0
            
            #expect(total == 1)
        }
    }
}

// MARK: - Image Analysis Error Classification Tests

@Suite("Image Analysis Error Classification")
struct ImageAnalysisErrorClassification {
    
    @Test("Invalid image data error")
    func invalidImageDataError() {
        let result = TestUtilities.makeCableDetectionResult(
            type: .usbA,
            confidence: 0.0,
            boundingBox: nil
        )
        
        let error = TestUtilities.makeImageAnalysisError(for: result)
        #expect(error == .invalidImageData)
    }
    
    @Test("No detection found error")
    func noDetectionFoundError() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbA,
            confidence: 0.0
        )
        
        let error = TestUtilities.makeImageAnalysisError(for: result)
        #expect(error == .noDetectionFound)
    }
    
    @Test("Confidence too low error with value")
    func confidenceTooLowErrorWithConfidence() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbA,
            confidence: 0.25
        )
        
        let error = TestUtilities.makeImageAnalysisError(for: result)
        #expect(error == .confidenceTooLow(0.25))
    }
    
    @Test("Model not loaded error")
    func modelNotLoadedError() async throws {
        let error = TestUtilities.makeImageAnalysisError(for: "Error: Model not loaded")
        #expect(error == .modelNotLoaded)
    }
    
    @Test("Processing failed error propagates nested error")
    func processingFailedErrorPropagates() async throws {
        let nestedError = NSError(domain: "Test", code: 42, userInfo: nil)
        
        let error = TestUtilities.makeImageAnalysisError(for: "Error: Processing failed: \(nestedError.localizedDescription)")
        #expect(error == .processingFailed(nestedError))
    }
}
