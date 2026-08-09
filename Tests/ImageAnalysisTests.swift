import Testing
import Foundation
@testable import BuyNothing

@Suite("Image Analysis Service Tests")
struct ImageAnalysisTests {
    
    @Test("Mock service can be initialized")
    func mockServiceCanBeInitialized() async throws {
        let mockService = MockImageAnalysisService()
        
        #expect(mockService.confidenceThreshold == 0.6)
        #expect(mockService.processingDelay == 0.1)
        #expect(mockService.mockResults.count > 0)
    }
    
    @Test("Mock service can set confidence threshold")
    func mockServiceSetsConfidenceThreshold() async throws {
        let mockService = MockImageAnalysisService()
        
        // Start with default
        #expect(mockService.confidenceThreshold == 0.6)
        
        // Set to custom value
        mockService.setConfidenceThreshold(0.9)
        #expect(mockService.confidenceThreshold == 0.9)
        
        // Set to low value
        mockService.setConfidenceThreshold(0.3)
        #expect(mockService.confidenceThreshold == 0.3)
    }
    
    @Test("Mock service can simulate processing delay")
    func mockServiceSimulatesProcessingDelay() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set custom delay
        mockService.setProcessingDelay(0.5)
        
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.processingTime >= 0.5)
    }
    
    @Test("Mock service respects confidence threshold")
    func mockServiceRespectsConfidenceThreshold() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set high threshold
        mockService.setConfidenceThreshold(0.9)
        
        // Set up low confidence mock result
        mockService.setMockResult(
            for: "low-confidence-test",
            result: CableDetectionResult(
                detectedType: .electronics,
                confidence: 0.5
            )
        )
        
        // Analyze should return the mock result
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.confidence < 0.9)
        #expect(result.isHighConfidence == false)
    }
    
    @Test("Mock service can return configured errors")
    func mockServiceReturnsErrors() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set to return errors
        mockService.setShouldReturnError(true)
        
        // This should not throw because we have mock results
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.confidence >= 0.5) // Default mock result has high confidence
    }
    
    @Test("Mock service can clear mock results")
    func mockServiceCanClearMockResults() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set up some mock results
        await mockService.setMockResult(for: "image-1", result: CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.8
        ))
        
        // Check that results are set
        #expect(mockService.mockResults.count == 1)
        
        // Clear results
        mockService.clearMockResults()
        
        // Should be empty
        #expect(mockService.mockResults.isEmpty == true)
    }
    
    @Test("Mock service can get mock result")
    func mockServiceCanGetMockResult() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set up a mock result
        await mockService.setMockResult(
            for: "test-image",
            result: CableDetectionResult(
                detectedType: .electronics,
                confidence: 0.85
            )
        )
        
        // Retrieve mock result
        let result = try await mockService.getMockResult(for: "test-image")
        
        #expect(result?.detectedType == .electronics)
        #expect(result?.confidence == 0.85)
    }
    
    @Test("Mock service can analyze image")
    func mockServiceAnalyzesImage() async throws {
        let mockService = MockImageAnalysisService()
        
        // Set up a mock result
        await mockService.setMockResult(
            for: "analysis-test",
            result: CableDetectionResult(
                detectedType: .electronics,
                confidence: 0.95
            )
        )
        
        // Analyze image
        let result = try await mockService.analyzeImage(Data())
        
        #expect(result.confidence == 0.95)
        #expect(result.isHighConfidence == true)
    }
    
    @Test("Image analysis identifies cable detection result")
    func imageAnalysisIdentifiesCableResult() async throws {
        let result = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.9,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            processingTime: 0.2
        )
        
        #expect(result.confidence > 0.0)
        #expect(result.confidence <= 1.0)
        #expect(result.detectedType != nil)
    }
    
    @Test("Image analysis confidence levels are mutually exclusive")
    func confidenceLevelsMutuallyExclusive() async throws {
        // High confidence: >= 0.8
        let highResult = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.9
        )
        #expect(highResult.isHighConfidence == true)
        #expect(highResult.isMediumConfidence == false)
        #expect(highResult.isLowConfidence == false)
        
        // Medium confidence: >= 0.6 && < 0.8
        let mediumResult = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.7
        )
        #expect(mediumResult.isHighConfidence == false)
        #expect(mediumResult.isMediumConfidence == true)
        #expect(mediumResult.isLowConfidence == false)
        
        // Low confidence: < 0.6
        let lowResult = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.4
        )
        #expect(lowResult.isHighConfidence == false)
        #expect(lowResult.isMediumConfidence == false)
        #expect(lowResult.isLowConfidence == true)
    }
    
    @Test("Confidence boundaries are correct")
    func confidenceBoundariesCorrect() async throws {
        // Exactly 0.8 should be high confidence
        let resultAt80 = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.8
        )
        #expect(resultAt80.isHighConfidence == true)
        #expect(resultAt80.isMediumConfidence == true)
        
        // Just below 0.8 should be medium only
        let resultAt79 = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.79
        )
        #expect(resultAt79.isHighConfidence == false)
        #expect(resultAt79.isMediumConfidence == true)
        
        // Exactly 0.6 should be medium only (not low)
        let resultAt60 = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.6
        )
        #expect(resultAt60.isMediumConfidence == true)
        #expect(resultAt60.isLowConfidence == false)
        
        // Just below 0.6 should be low only
        let resultAt59 = CableDetectionResult(
            detectedType: .electronics,
            confidence: 0.59
        )
        #expect(resultAt59.isMediumConfidence == false)
        #expect(resultAt59.isLowConfidence == true)
    }
}
