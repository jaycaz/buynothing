import Testing
import Foundation
@testable import BuyNothing

@Suite("Image Analysis Service Tests")
struct ImageAnalysisTests {
    
    @Test("Mock service returns expected cable types")
    func mockServiceDetectsKnownCables() async throws {
        let mockService = MockImageAnalysisService()
        
        // Test high confidence USB-C detection
        await mockService.setMockResult(
            for: "usb-c-test",
            result: TestUtilities.createTestCableDetectionResult(
                type: .usbC,
                confidence: 0.95
            )
        )
        
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.detectedType == .usbC)
        #expect(result.confidence >= 0.8)
        #expect(result.isHighConfidence == true)
    }
    
    @Test("Service respects confidence threshold")
    func serviceRespectsConfidenceThreshold() async throws {
        let mockService = MockImageAnalysisService()
        
        await mockService.setConfidenceThreshold(0.8)
        
        // Set up low confidence result
        await mockService.setMockResult(
            for: "low-confidence-test",
            result: TestUtilities.createTestCableDetectionResult(
                type: .lightning,
                confidence: 0.5
            )
        )
        
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.confidence < 0.8)
        #expect(result.isLowConfidence == true)
    }
    
    @Test("Service handles multiple cable type detection",
          arguments: [
            USBCableType.usbA,
            USBCableType.usbC,
            USBCableType.lightning,
            USBCableType.microUSB,
            USBCableType.miniUSB
          ])
    func serviceDetectsAllCableTypes(cableType: USBCableType) async throws {
        let mockService = MockImageAnalysisService()
        
        await mockService.setMockResult(
            for: "test-\(cableType.rawValue)",
            result: TestUtilities.createTestCableDetectionResult(
                type: cableType,
                confidence: 0.9
            )
        )
        
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.detectedType == cableType)
        #expect(result.isHighConfidence == true)
    }
    
    @Test("Service provides alternative detections")
    func serviceProvidesAlternativeDetections() async throws {
        let mockService = MockImageAnalysisService()
        
        await mockService.setMockResult(
            for: "alternatives-test",
            result: TestUtilities.createTestCableDetectionResult(
                type: .usbC,
                confidence: 0.7,
                alternativeCount: 2
            )
        )
        
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.detectedType == .usbC)
        #expect(result.alternativeDetections.count == 2)
        #expect(result.alternativeDetections[0].confidence < result.confidence)
    }
    
    @Test("Service handles error conditions")
    func serviceHandlesErrors() async throws {
        let mockService = MockImageAnalysisService()
        await mockService.setShouldReturnError(true)
        
        await #expect(throws: ImageAnalysisError.self) {
            try await mockService.analyzeImage(Data())
        }
    }
    
    @Test("Service processing time is reasonable")
    func serviceProcessingTimeIsReasonable() async throws {
        let mockService = MockImageAnalysisService()
        await mockService.setProcessingDelay(0.05) // 50ms
        
        let startTime = Date()
        let result = try await mockService.analyzeImage(Data())
        let actualTime = Date().timeIntervalSince(startTime)
        
        #expect(result.processingTime > 0)
        #expect(actualTime < 1.0) // Should complete within 1 second
    }
    
    @Test("Confidence levels are correctly categorized")
    func confidenceLevelsAreCorrect() async throws {
        let highConfidenceResult = TestUtilities.createTestCableDetectionResult(confidence: 0.9)
        let mediumConfidenceResult = TestUtilities.createTestCableDetectionResult(confidence: 0.7)
        let lowConfidenceResult = TestUtilities.createTestCableDetectionResult(confidence: 0.4)
        
        #expect(highConfidenceResult.isHighConfidence == true)
        #expect(highConfidenceResult.isMediumConfidence == false)
        #expect(highConfidenceResult.isLowConfidence == false)
        
        #expect(mediumConfidenceResult.isHighConfidence == false)
        #expect(mediumConfidenceResult.isMediumConfidence == true)
        #expect(mediumConfidenceResult.isLowConfidence == false)
        
        #expect(lowConfidenceResult.isHighConfidence == false)
        #expect(lowConfidenceResult.isMediumConfidence == false)
        #expect(lowConfidenceResult.isLowConfidence == true)
    }
}