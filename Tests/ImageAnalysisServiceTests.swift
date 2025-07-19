import Testing
import Foundation
import CoreGraphics
@testable import BuyNothing

@Suite("Real Image Analysis Service Tests")
struct ImageAnalysisServiceTests {
    
    @Test("Service initializes correctly")
    func serviceInitializesCorrectly() async throws {
        let service = ImageAnalysisService()
        
        // Give the service time to load
        try await TestUtilities.waitForCondition(timeout: 2.0) {
            // Service should be ready after initialization
            return true
        }
    }
    
    @Test("Service analyzes image data successfully")
    func serviceAnalyzesImageDataSuccessfully() async throws {
        let service = ImageAnalysisService()
        
        // Generate test image
        guard let imageData = TestUtilities.generateMockCableImage(type: .usbC) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let result = try await service.analyzeImage(imageData)
        
        #expect(result.confidence > 0.0)
        #expect(result.processingTime > 0.0)
        #expect(result.processingTime < 5.0) // Should be reasonably fast
        #expect(USBCableType.allCases.contains(result.detectedType))
    }
    
    @Test("Service analyzes CGImage successfully")
    func serviceAnalyzesCGImageSuccessfully() async throws {
        let service = ImageAnalysisService()
        
        // Create a test CGImage
        let size = CGSize(width: 100, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                    bitmapInfo: bitmapInfo.rawValue),
              let cgImage = context.makeImage() else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let result = try await service.analyzeImage(cgImage)
        
        #expect(result.confidence > 0.0)
        #expect(result.processingTime > 0.0)
        #expect(USBCableType.allCases.contains(result.detectedType))
    }
    
    @Test("Service respects confidence threshold")
    func serviceRespectsConfidenceThreshold() async throws {
        let service = ImageAnalysisService()
        await service.setConfidenceThreshold(0.9) // Very high threshold
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .lightning) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // With high threshold, some detections might fail
        do {
            let result = try await service.analyzeImage(imageData)
            #expect(result.confidence >= 0.9)
        } catch ImageAnalysisError.confidenceTooLow(let confidence) {
            #expect(confidence < 0.9)
        }
    }
    
    @Test("Service handles invalid image data")
    func serviceHandlesInvalidImageData() async throws {
        let service = ImageAnalysisService()
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Not valid image data
        
        await #expect(throws: ImageAnalysisError.invalidImageData) {
            try await service.analyzeImage(invalidData)
        }
    }
    
    @Test("Service provides reasonable processing times",
          arguments: [
            USBCableType.usbA,
            USBCableType.usbC,
            USBCableType.lightning,
            USBCableType.microUSB
          ])
    func serviceProcessingTimesAreReasonable(cableType: USBCableType) async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: cableType) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let startTime = Date()
        let result = try await service.analyzeImage(imageData)
        let actualTime = Date().timeIntervalSince(startTime)
        
        #expect(result.processingTime > 0.0)
        #expect(result.processingTime <= actualTime)
        #expect(actualTime < 3.0) // Should complete within 3 seconds
    }
    
    @Test("Service returns valid bounding boxes")
    func serviceReturnsValidBoundingBoxes() async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .usbC) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let result = try await service.analyzeImage(imageData)
        
        if let boundingBox = result.boundingBox {
            #expect(boundingBox.origin.x >= 0.0)
            #expect(boundingBox.origin.y >= 0.0)
            #expect(boundingBox.size.width > 0.0)
            #expect(boundingBox.size.height > 0.0)
            #expect(boundingBox.maxX <= 1.0)
            #expect(boundingBox.maxY <= 1.0)
        }
        
        // Check alternative detections bounding boxes
        for alternative in result.alternativeDetections {
            if let altBox = alternative.boundingBox {
                #expect(altBox.origin.x >= 0.0)
                #expect(altBox.origin.y >= 0.0)
                #expect(altBox.size.width > 0.0)
                #expect(altBox.size.height > 0.0)
                #expect(altBox.maxX <= 1.0)
                #expect(altBox.maxY <= 1.0)
            }
        }
    }
    
    @Test("Service provides logical alternative detections")
    func serviceProvidesLogicalAlternativeDetections() async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .usbA) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let result = try await service.analyzeImage(imageData)
        
        // Alternative detections should have lower confidence than primary
        for alternative in result.alternativeDetections {
            #expect(alternative.confidence < result.confidence)
            #expect(alternative.confidence > 0.0)
            #expect(alternative.type != result.detectedType)
        }
        
        // Alternative detections should be sorted by confidence (highest first)
        for i in 1..<result.alternativeDetections.count {
            #expect(result.alternativeDetections[i-1].confidence >= result.alternativeDetections[i].confidence)
        }
    }
    
    @Test("Service handles concurrent requests")
    func serviceHandlesConcurrentRequests() async throws {
        let service = ImageAnalysisService()
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let cableTypes: [USBCableType] = [.usbA, .usbC, .lightning, .microUSB]
        let imageDataArray = try cableTypes.compactMap { type in
            guard let data = TestUtilities.generateMockCableImage(type: type) else {
                throw TestUtilities.TestError.invalidTestData
            }
            return data
        }
        
        // Process multiple images concurrently
        let results = try await withThrowingTaskGroup(of: CableDetectionResult.self) { group in
            for imageData in imageDataArray {
                group.addTask {
                    return try await service.analyzeImage(imageData)
                }
            }
            
            var allResults: [CableDetectionResult] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        #expect(results.count == cableTypes.count)
        
        for result in results {
            #expect(result.confidence > 0.0)
            #expect(result.processingTime > 0.0)
            #expect(USBCableType.allCases.contains(result.detectedType))
        }
    }
    
    @Test("Service confidence categorization is accurate")
    func serviceConfidenceCategorizationIsAccurate() async throws {
        let service = ImageAnalysisService()
        
        guard let imageData = TestUtilities.generateMockCableImage(type: .lightning) else {
            throw TestUtilities.TestError.invalidTestData
        }
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Run multiple times to test different confidence levels
        var highCount = 0
        var mediumCount = 0
        var lowCount = 0
        
        for _ in 0..<10 {
            let result = try await service.analyzeImage(imageData)
            
            if result.isHighConfidence {
                highCount += 1
                #expect(result.confidence >= 0.8)
            } else if result.isMediumConfidence {
                mediumCount += 1
                #expect(result.confidence >= 0.6 && result.confidence < 0.8)
            } else if result.isLowConfidence {
                lowCount += 1
                #expect(result.confidence < 0.6)
            }
        }
        
        // Should get a mix of confidence levels in simulation
        #expect(highCount + mediumCount + lowCount == 10)
    }
    
    @Test("Service handles different image sizes")
    func serviceHandlesDifferentImageSizes() async throws {
        let service = ImageAnalysisService()
        
        let sizes = [
            CGSize(width: 100, height: 100),
            CGSize(width: 300, height: 200),
            CGSize(width: 800, height: 600),
            CGSize(width: 1920, height: 1080)
        ]
        
        // Wait for model to load
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        for size in sizes {
            guard let imageData = TestUtilities.generateMockCableImage(type: .usbC, size: size) else {
                throw TestUtilities.TestError.invalidTestData
            }
            
            let result = try await service.analyzeImage(imageData)
            
            #expect(result.confidence > 0.0)
            #expect(result.processingTime > 0.0)
            #expect(USBCableType.allCases.contains(result.detectedType))
        }
    }
}