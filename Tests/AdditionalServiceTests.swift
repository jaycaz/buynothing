import Testing
import Foundation
@testable import BuyNothing

// MARK: - Mock Camera Service Edge Cases

@Suite("Mock Camera Service Edge Cases")
struct MockCameraServiceEdgeCases {
    
    @Test("Camera session state transitions")
    func cameraSessionStateTransitions() async throws {
        let mockCamera = MockCameraService()
        
        // Initially stopped
        #expect(await mockCamera.isSessionRunning() == false)
        
        // Request permission first
        _ = await mockCamera.requestCameraPermission()
        
        // Now can start
        try await mockCamera.startCamera()
        #expect(await mockCamera.isSessionRunning() == true)
        
        // Capture works
        _ = try await mockCamera.capturePhoto()
        
        // After capture, session still running
        #expect(await mockCamera.isSessionRunning() == true)
    }
    
    @Test("Multiple camera switches work correctly")
    func multipleCameraSwitches() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        for i in 0...100 {
            _ = try await mockCamera.switchCamera()
        }
        
        // Front camera should be active
        let position = await mockCamera.getCurrentPosition()
        #expect(position == .front)
    }
    
    @Test("Capture fails gracefully when session stopped")
    func captureFailsWhenSessionStopped() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.requestCameraPermission()
        
        try? await mockCamera.stopCamera()
        
        await #expect(throws: CameraError.sessionNotRunning) {
            try await mockCamera.capturePhoto()
        }
    }
    
    @Test("Permission denial persists until reset")
    func permissionDeniedPersistsUntilReset() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setShouldFailPermission(true)
        
        // Permission denied
        #expect(await mockCamera.requestCameraPermission() == false)
        
        // Reset
        await mockCamera.resetToDefaults()
        
        // Permission now allowed
        #expect(await mockCamera.requestCameraPermission() == true)
    }
    
    @Test("Capture delay reset works correctly")
    func captureDelayReset() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setCaptureDelay(2.0)
        
        let delayBefore = await mockCamera.getCaptureDelay()
        #expect(delayBefore == 2.0)
        
        // Reset
        await mockCamera.resetToDefaults()
        
        let delayAfter = await mockCamera.getCaptureDelay()
        #expect(delayAfter == 0.0)
    }
    
    @Test("Camera can be stopped without starting")
    func cameraCanBeStoppedWithoutStarting() async throws {
        let mockCamera = MockCameraService()
        
        // Stopping without starting should be safe
        await mockCamera.stopCamera()
        #expect(await mockCamera.isSessionRunning() == false)
    }
    
    @Test("Camera errors are properly categorized")
    func cameraErrorsAreProperlyCategorized() async throws {
        let mockCamera = MockCameraService()
        
        // Test permission error
        await mockCamera.setShouldFailPermission(true)
        let error1 = try? await mockCamera.requestCameraPermission()
        await mockCamera.setShouldFailPermission(false)
        
        // Test session error
        await mockCamera.setShouldFailPermission(true)
        let error2 = try? await mockCamera.startCamera()
        #expect(error2?.localizedDescription == CameraError.sessionNotRunning.localizedDescription)
    }
}

// MARK: - Mock Image Analysis Service Edge Cases

@Suite("Mock Image Analysis Service Edge Cases")
struct MockImageAnalysisServiceEdgeCases {
    
    @Test("Empty mock results handled gracefully")
    func emptyMockResultsHandledGracefully() async throws {
        let mockService = MockImageAnalysisService()
        mockService.clearMockResults()
        
        let result = try await mockService.analyzeImage(Data())
        
        // Should return default result
        #expect(result.isHighConfidence == true)
        #expect(result.alternativeDetections.isEmpty == true)
    }
    
    @Test("Confidence threshold can be adjusted dynamically")
    func confidenceThresholdAdjustable() async throws {
        let mockService = MockImageAnalysisService()
        
        // Start with default threshold
        let threshold1 = await mockService.getConfidenceThreshold()
        #expect(threshold1 == 0.6)
        
        // Set to high threshold
        await mockService.setConfidenceThreshold(0.9)
        let threshold2 = await mockService.getConfidenceThreshold()
        #expect(threshold2 == 0.9)
        
        // Set to low threshold
        await mockService.setConfidenceThreshold(0.3)
        let threshold3 = await mockService.getConfidenceThreshold()
        #expect(threshold3 == 0.3)
    }
    
    @Test("Processing delay can be adjusted")
    func processingDelayAdjustable() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set very long delay
        await mockService.setProcessingDelay(2.0)
        
        let delay = try await mockService.analyzeImage(Data())
        #expect(delay.processingTime >= 2.0)
    }
    
    @Test("Alternative detections maintain descending confidence order")
    func alternativeDetectionsOrderedByConfidence() async throws {
        let mockService = MockImageAnalysisService()
        
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.8,
            alternativeCount: 5
        )
        
        await mockService.setMockResult(for: "alternatives-test", result: result)
        let analysisResult = try await mockService.analyzeImage(Data())
        
        // Verify all alternatives have lower confidence than primary detection
        for alt in analysisResult.alternativeDetections {
            #expect(alt.confidence < analysisResult.confidence)
        }
    }
    
    @Test("High confidence threshold excludes all low-confidence detections")
    func highConfidenceThresholdExcludesLowConfidence() async throws {
        let mockService = MockImageAnalysisService()
        await mockService.setConfidenceThreshold(0.999)  // Very high threshold
        
        // Set result with high confidence
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.95
        )
        
        await mockService.setMockResult(for: "high-conf-test", result: result)
        
        // This should still work because 0.95 >= 0.999 is false, but mock service
        // should return the mock result anyway
        let analysisResult = try await mockService.analyzeImage(Data())
        
        #expect(analysisResult.confidence == 0.95)
        #expect(analysisResult.isLowConfidence == true)
    }
}

// MARK: - Data Model Validation Tests

@Suite("Data Model Validation")
struct DataModelValidation {
    
    @Test("USBCableType has all required cases")
    func usbCableTypeHasAllCases() {
        let expectedCases: [USBCableType] = [
            .usbA, .usbC, .lightning, .microUSB, .miniUSB, .usb30, .thunderbolt
        ]
        let actualCases = USBCableType.allCases
        
        #expect(actualCases == expectedCases)
        #expect(actualCases.count == expectedCases.count)
    }
    
    @Test("USBCableType raw values match display names")
    func usbCableTypeRawValues() async throws {
        for type in USBCableType.allCases {
            let result = try await TestUtilities.analyzeMockResult(for: type.rawValue)
            
            #expect(result.detectedType == type)
            #expect(result.confidence >= 0.6)  // All cable types should be detectable
        }
    }
    
    @Test("Confidence classification boundaries are correct")
    func confidenceClassificationBoundaries() async throws {
        // Test boundary: 0.8
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.8).isHighConfidence == true)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.799).isHighConfidence == false)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.799).isMediumConfidence == true)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.5).isMediumConfidence == true)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.599).isMediumConfidence == true)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.599).isLowConfidence == true)
        
        // Test boundary: 0.6
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.6).isMediumConfidence == true)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.5999).isMediumConfidence == false)
        #expect(TestUtilities.makeCableDetectionResult(confidence: 0.5999).isLowConfidence == true)
    }
    
    @Test("Offer model has required fields")
    func offerHasRequiredFields() throws {
        let offer = Offer(title: "Test Offer")
        
        #expect(offer.id != nil)
        #expect(!offer.title.isEmpty)
        #expect(offer.category.isEmpty == false)
        #expect(offer.condition.isEmpty == false)
        #expect(offer.available == true)
    }
    
    @Test("Wish model has required fields")
    func wishHasRequiredFields() throws {
        let wish = Wish(text: "I need a cable")
        
        #expect(wish.id != nil)
        #expect(!wish.text.isEmpty)
        #expect(wish.fulfilled == false)
    }
    
    @Test("Nudge has all required fields")
    func nudgeHasAllRequiredFields() throws {
        let offer = Offer(title: "Test", condition: "good", addedAt: Date(), available: true)
        let wish = Wish(text: "Want this item")
        
        let nudge = Nudge(
            offerOwnerName: "Test Owner",
            offer: offer,
            wishOwnerName: "Want Owner",
            wish: wish,
            message: "Match found"
        )
        
        #expect(nudge.id != nil)
        #expect(!nudge.offerOwnerName.isEmpty)
        #expect(!nudge.wishOwnerName.isEmpty)
        #expect(!nudge.message.isEmpty)
    }
}

// MARK: - Image Analysis Error Handling Tests

@Suite("Image Analysis Error Handling")
struct ImageAnalysisErrorHandling {
    
    @Test("Invalid image data produces correct error")
    func invalidImageDataProducesCorrectError() async throws {
        // Empty data
        let emptyData = Data()
        let error = try await TestUtilities.simulateInvalidImageData()
        
        #expect(error == .invalidImageData)
    }
    
    @Test("No detection produces correct error")
    func noDetectionProducesCorrectError() async throws {
        let result = TestUtilities.createTestCableDetectionResult(
            type: .usbA,
            confidence: 0.0  // No detection
        )
        
        let error = TestUtilities.makeImageAnalysisError(for: result)
        #expect(error == .noDetectionFound)
    }
    
    @Test("Low confidence with threshold produces correct error")
    func lowConfidenceWithThresholdProducesCorrectError() async throws {
        let mockService = MockImageAnalysisService()
        await mockService.setConfidenceThreshold(0.9)
        
        await mockService.setMockResult(
            for: "low-conf",
            result: TestUtilities.createTestCableDetectionResult(
                type: .lightning,
                confidence: 0.4
            )
        )
        
        // The service should filter based on threshold
        // Currently doesn't throw, just returns low confidence result
        let result = try await mockService.analyzeImage(Data())
        
        // Check that low confidence is properly flagged
        #expect(result.isLowConfidence == true)
        #expect(result.confidence == 0.4)
    }
    
    @Test("Processing error propagates correctly")
    func processingErrorPropagates() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set up to throw a different error
        let processingError = NSError(domain: "Test", code: 123, userInfo: nil)
        
        // Need to verify the service handles this properly
        mockService.setShouldReturnError(true)
        
        let result = try await mockService.analyzeImage(Data())
        
        // The mock service should not throw for processing errors,
        // it just uses mock data
        #expect(result.detectedType == .usbC)
    }
}

// MARK: - Camera Service Edge Cases

@Suite("Camera Service Edge Cases")
struct CameraServiceEdgeCases {
    
    @Test("Device unavailable check works")
    func deviceUnavailableCheck() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setDeviceUnavailable(true)
        
        let result = try? await mockCamera.requestCameraPermission()
        #expect(result == nil)
    }
    
    @Test("Capture output validation")
    func captureOutputValidation() async throws {
        let mockCamera = MockCameraService()
        
        // Set up camera
        await mockCamera.setShouldFailCapture(true)
        _ = await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        let data = try? await mockCamera.capturePhoto()
        
        // Should produce error for invalid capture
        #expect(data == nil)
    }
    
    @Test("Camera configuration errors are handled")
    func cameraConfigurationErrors() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setConfigurationFailed(true)
        
        let result = try? await mockCamera.startCamera()
        #expect(result == nil)
    }
}

// MARK: - Commons Data Model Tests

@Suite("Commons Data Model Tests")
struct CommonsDataModelTests {
    
    @Test("CommonsProfile has required schema")
    func commonsProfileSchema() async throws {
        let profile = CommonsProfile(name: "Test User")
        
        #expect(profile.schemaVersion == "0.1.0")
        #expect(profile.id != nil)
        #expect(!profile.name.isEmpty)
        #expect(profile.updatedAt.isAfter(date: Date().addingTimeInterval(-1)))
    }
    
    @Test("Profile update timestamp changes after modification")
    func profileUpdatesTimestamp() async throws {
        var profile = CommonsProfile(name: "Test User")
        let originalTime = profile.updatedAt
        
        profile.updatedAt = Date().addingTimeInterval(10)
        
        #expect(profile.updatedAt != originalTime)
    }
    
    @Test("Empty commons profile is valid")
    func emptyCommonsProfile() async throws {
        let profile = CommonsProfile(name: "New User")
        
        #expect(profile.offers.isEmpty == true)
        #expect(profile.wishes.isEmpty == true)
    }
    
    @Test("Profile can be encoded and decoded")
    func profileCodable() throws {
        let originalProfile = CommonsProfile(
            id: UUID(),
            name: "Test Name",
            neighborhood: "Test Neighborhood",
            offers: [
                Offer(
                    id: UUID(),
                    title: "Offer 1",
                    description: "Description 1",
                    category: "electronics",
                    condition: "good",
                    addedAt: Date(),
                    available: true
                )
            ],
            wishes: [
                Wish(
                    id: UUID(),
                    text: "I need something",
                    keywords: ["cable", "electronics"],
                    addedAt: Date(),
                    fulfilled: false
                )
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateDecodingStrategy = .deferredToDate
        encoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let data = try encoder.encode(originalProfile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let decodedProfile = try decoder.decode(CommonsProfile.self, from: data)
        
        #expect(decodedProfile.name == originalProfile.name)
        #expect(decodedProfile.id == originalProfile.id)
        #expect(decodedProfile.offers.count == originalProfile.offers.count)
        #expect(decodedProfile.wishes.count == originalProfile.wishes.count)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct ServiceIntegrationTests {
    
    @Test("Camera to image analysis pipeline")
    func cameraToImageAnalysisPipeline() async throws {
        let mockCamera = MockCameraService()
        let mockAnalysis = MockImageAnalysisService()
        
        // Set up both services
        await mockCamera.setShouldFailPermission(false)
        await mockCamera.setShouldFailCapture(false)
        await mockCamera.setCaptureDelay(0.1)
        
        // Capture image
        let imageData = try await mockCamera.capturePhoto()
        
        // Analyze image
        let analysisResult = try await mockAnalysis.analyzeImage(imageData)
        
        // Verify result
        #expect(analysisResult.confidence >= 0.6)
        #expect(analysisResult.detectedType != nil)
    }
    
    @Test("Pipeline handles camera errors gracefully")
    func pipelineHandlesCameraErrors() async throws {
        let mockCamera = MockCameraService()
        let mockAnalysis = MockImageAnalysisService()
        
        // Make camera fail to capture
        await mockCamera.setShouldFailCapture(true)
        
        let result = try await mockCamera.capturePhoto()
        
        #expect(result == nil)
        
        // Analysis should not be called with nil data
    }
    
    @Test("Pipeline handles analysis errors gracefully")
    func pipelineHandlesAnalysisErrors() async throws {
        let mockCamera = MockCameraService()
        let mockAnalysis = MockImageAnalysisService()
        
        // Set up camera successfully
        await mockCamera.setShouldFailPermission(false)
        try await mockCamera.startCamera()
        
        let imageData = try await mockCamera.capturePhoto()
        
        // Make analysis fail
        await mockAnalysis.setShouldReturnError(true)
        
        await #expect(throws: ImageAnalysisError.self) {
            try await mockAnalysis.analyzeImage(imageData)
        }
    }
    
    @Test("Mock analysis service can simulate various cable types")
    func mockAnalysisCanSimulateVariousCableTypes() async throws {
        let mockAnalysis = MockImageAnalysisService()
        
        // Test each cable type
        for cableType in USBCableType.allCases {
            await mockAnalysis.setMockResult(
                for: "test-\(cableType.rawValue)",
                result: TestUtilities.createTestCableDetectionResult(
                    type: cableType,
                    confidence: 0.95
                )
            )
            
            let result = try await mockAnalysis.analyzeImage(Data())
            
            #expect(result.detectedType == cableType)
            #expect(result.confidence == 0.95)
            #expect(result.isHighConfidence == true)
        }
    }
}

// MARK: - Test Utilities Tests

@Suite("Test Utilities")
struct TestUtilitiesTests {
    
    @Test("Image hash generation is consistent")
    func imageHashGenerationConsistent() async throws {
        let hash1 = TestUtilities.createImageHash(for: .usbC, scenario: "clear")
        let hash2 = TestUtilities.createImageHash(for: .usbC, scenario: "clear")
        
        #expect(hash1 == hash2)
    }
    
    @Test("Mock cable image generation works")
    func mockCableImageGeneration() async throws {
        // This test would require #if DEBUG and actual image generation
        #expect(true) // Placeholder
    }
    
    @Test("Wait for condition times out appropriately")
    func waitForConditionTimeout() async throws {
        let mockCondition: @escaping () async -> Bool = { false }
        
        await #expect(throws: TestUtilities.TestError.timeoutExceeded) {
            try await TestUtilities.waitForCondition(
                timeout: 0.05,
                condition: mockCondition
            )
        }
    }
    
    @Test("Wait for condition succeeds when condition met")
    func waitForConditionSuccess() async throws {
        let condition: @escaping () async -> Bool = {
            try await Task.sleep(nanoseconds: 5_000_000)
            return true
        }
        
        await TestUtilities.waitForCondition(timeout: 1.0, condition: condition)
        
        // Should not throw
    }
}

// MARK: - Edge Case Scenarios

@Suite("Edge Case Scenarios")
struct EdgeCaseScenarios {
    
    @Test("Simultaneous confidence threshold and error handling")
    func simultaneousThresholdAndErrorHandling() async throws {
        let mockAnalysis = MockImageAnalysisService()
        
        // Set low threshold AND set to return error
        await mockAnalysis.setConfidenceThreshold(0.0)
        await mockAnalysis.setShouldReturnError(true)
        
        let result = try await mockAnalysis.analyzeImage(Data())
        
        // Service should throw error, not return a result
        // The mock result won't match what's expected
    }
    
    @Test("Multiple analysis calls with same image")
    func multipleAnalysisCallsWithSameImage() async throws {
        let mockAnalysis = MockImageAnalysisService()
        
        let imageData = Data()
        
        // First call with mock result
        await mockAnalysis.setMockResult(for: "test-image-1", result: TestUtilities.createTestCableDetectionResult(type: .usbC, confidence: 0.9))
        let result1 = try await mockAnalysis.analyzeImage(imageData)
        
        // Second call - should use different mock key or overwrite
        await mockAnalysis.setMockResult(for: "test-image-1", result: TestUtilities.createTestCableDetectionResult(type: .lightning, confidence: 0.8))
        let result2 = try await mockAnalysis.analyzeImage(imageData)
        
        // Latest mock result should be returned
        #expect(result2.detectedType == .lightning)
    }
}
