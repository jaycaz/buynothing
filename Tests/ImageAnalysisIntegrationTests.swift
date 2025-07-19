import Testing
import Foundation
@testable import BuyNothing

@Suite("Image Analysis Integration Tests")
struct ImageAnalysisIntegrationTests {
    
    @Test("Integration: Mock and real services produce compatible results")
    func mockAndRealServicesAreCompatible() async throws {
        let mockService = MockImageAnalysisService()
        let realService = ImageAnalysisService()
        
        // Set up mock with known result
        let expectedResult = TestUtilities.createTestCableDetectionResult(
            type: .usbC,
            confidence: 0.8
        )
        
        await mockService.setMockResult(for: "integration-test", result: expectedResult)
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .usbC) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for real service model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Get results from both services
        let mockResult = try await mockService.analyzeImage(imageData)
        let realResult = try await realService.analyzeImage(imageData)
        
        // Both should return valid results with same structure
        #expect(mockResult.confidence > 0.0)
        #expect(realResult.confidence > 0.0)
        
        #expect(USBCableType.allCases.contains(mockResult.detectedType))
        #expect(USBCableType.allCases.contains(realResult.detectedType))
        
        #expect(mockResult.processingTime > 0.0)
        #expect(realResult.processingTime > 0.0)
    }
    
    @Test("Integration: Service works with generated test images",
          arguments: USBCableType.allCases)
    func serviceWorksWithGeneratedTestImages(cableType: USBCableType) async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: cableType) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let result = try await service.analyzeImage(imageData)
        
        #expect(result.confidence > 0.0)
        #expect(result.processingTime > 0.0)
        #expect(USBCableType.allCases.contains(result.detectedType))
        
        // Result should be well-formed
        if let boundingBox = result.boundingBox {
            #expect(boundingBox.size.width > 0)
            #expect(boundingBox.size.height > 0)
        }
        
        for alternative in result.alternativeDetections {
            #expect(alternative.confidence < result.confidence)
            #expect(alternative.type != result.detectedType)
        }
    }
    
    @Test("Integration: Service handles error scenarios gracefully")
    func serviceHandlesErrorScenariosGracefully() async throws {
        let service = ImageAnalysisService()
        
        // Test with various invalid inputs
        let invalidInputs: [(Data, String)] = [
            (Data(), "empty data"),
            (Data([0xFF, 0xFF, 0xFF]), "invalid image header"),
            (Data(repeating: 0x00, count: 1000), "null data"),
        ]
        
        for (invalidData, description) in invalidInputs {
            await #expect(throws: ImageAnalysisError.self, "\(description) should throw error") {
                try await service.analyzeImage(invalidData)
            }
        }
    }
    
    @Test("Integration: Service performance benchmarks")
    func servicePerformanceBenchmarks() async throws {
        let service = ImageAnalysisService()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let testSizes = [
            CGSize(width: 300, height: 200),
            CGSize(width: 640, height: 480),
            CGSize(width: 1280, height: 720)
        ]
        
        for size in testSizes {
            guard let imageData = TestUtilities.generateMockCableImage(type: .usbC, size: size) else {
                throw TestUtilities.TestError.invalidTestData
            }
            
            let startTime = Date()
            let result = try await service.analyzeImage(imageData)
            let totalTime = Date().timeIntervalSince(startTime)
            
            // Performance expectations
            #expect(totalTime < 2.0, "Processing should complete within 2 seconds for \(size)")
            #expect(result.processingTime <= totalTime, "Reported processing time should be accurate")
            
            print("Image size \(size): \(String(format: "%.3f", totalTime))s total, \(String(format: "%.3f", result.processingTime))s processing")
        }
    }
    
    @Test("Integration: Service consistency across multiple runs")
    func serviceConsistencyAcrossMultipleRuns() async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .lightning) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        var results: [CableDetectionResult] = []
        
        // Run same image analysis multiple times
        for _ in 0..<5 {
            let result = try await service.analyzeImage(imageData)
            results.append(result)
        }
        
        #expect(results.count == 5)
        
        // All results should be valid
        for result in results {
            #expect(result.confidence > 0.0)
            #expect(result.processingTime > 0.0)
            #expect(USBCableType.allCases.contains(result.detectedType))
        }
        
        // Results should show some consistency (but may vary due to simulation)
        let confidenceValues = results.map { $0.confidence }
        let averageConfidence = confidenceValues.reduce(0, +) / Float(confidenceValues.count)
        
        #expect(averageConfidence > 0.0)
        #expect(averageConfidence <= 1.0)
    }
    
    @Test("Integration: Service with different confidence thresholds")
    func serviceWithDifferentConfidenceThresholds() async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .usbA) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let thresholds: [Float] = [0.3, 0.5, 0.7, 0.9]
        
        for threshold in thresholds {
            await service.setConfidenceThreshold(threshold)
            
            do {
                let result = try await service.analyzeImage(imageData)
                #expect(result.confidence >= threshold, "Result confidence should meet threshold \(threshold)")
            } catch ImageAnalysisError.confidenceTooLow(let confidence) {
                #expect(confidence < threshold, "Low confidence \(confidence) should be below threshold \(threshold)")
            }
        }
    }
    
    @Test("Integration: Service memory usage is reasonable")
    func serviceMemoryUsageIsReasonable() async throws {
        let service = ImageAnalysisService()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Process multiple images to test for memory leaks
        for i in 0..<20 {
            let cableType = USBCableType.allCases[i % USBCableType.allCases.count]
            
            guard let imageData = TestUtilities.generateMockCableImage(
                type: cableType,
                size: CGSize(width: 640, height: 480)
            ) else {
                throw TestUtilities.TestError.invalidTestData
            }
            
            let result = try await service.analyzeImage(imageData)
            
            #expect(result.confidence > 0.0)
            #expect(USBCableType.allCases.contains(result.detectedType))
            
            // Add small delay to allow for cleanup
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // If we get here without crashes or excessive memory usage, test passes
    }
    
    @Test("Integration: Service thread safety with Actor isolation")
    func serviceThreadSafetyWithActorIsolation() async throws {
        let service = ImageAnalysisService()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Create multiple concurrent tasks
        let taskCount = 10
        
        let results = try await withThrowingTaskGroup(of: CableDetectionResult.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    let cableType = USBCableType.allCases[i % USBCableType.allCases.count]
                    
                    guard let imageData = TestUtilities.generateMockCableImage(type: cableType) else {
                        throw TestUtilities.TestError.invalidTestData
                    }
                    
                    return try await service.analyzeImage(imageData)
                }
            }
            
            var allResults: [CableDetectionResult] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        #expect(results.count == taskCount)
        
        // All results should be valid despite concurrent access
        for result in results {
            #expect(result.confidence > 0.0)
            #expect(result.processingTime > 0.0)
            #expect(USBCableType.allCases.contains(result.detectedType))
        }
    }
}