import Foundation
import CoreGraphics

actor MockImageAnalysisService: ImageAnalysisProtocol {
    private var confidenceThreshold: Float = 0.6
    private var shouldReturnError = false
    private var mockResults: [String: CableDetectionResult] = [:]
    private var processingDelay: TimeInterval = 0.1
    
    init() {
        setupMockResults()
    }
    
    func analyzeImage(_ image: Data) async throws -> CableDetectionResult {
        try await processImage(with: "mock-data-hash")
    }
    
    func analyzeImage(_ image: CGImage) async throws -> CableDetectionResult {
        try await processImage(with: "mock-cgimage-hash")
    }
    
    func setConfidenceThreshold(_ threshold: Float) {
        self.confidenceThreshold = threshold
    }
    
    // MARK: - Test Configuration Methods
    
    func setShouldReturnError(_ shouldError: Bool) {
        self.shouldReturnError = shouldError
    }
    
    func setProcessingDelay(_ delay: TimeInterval) {
        self.processingDelay = delay
    }
    
    func setMockResult(for imageHash: String, result: CableDetectionResult) {
        mockResults[imageHash] = result
    }
    
    func clearMockResults() {
        mockResults.removeAll()
        setupMockResults()
    }
    
    // MARK: - Private Methods
    
    private func processImage(with hash: String) async throws -> CableDetectionResult {
        let startTime = Date()
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw ImageAnalysisError.noDetectionFound
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        if let mockResult = mockResults[hash] {
            return CableDetectionResult(
                detectedType: mockResult.detectedType,
                confidence: mockResult.confidence,
                boundingBox: mockResult.boundingBox,
                alternativeDetections: mockResult.alternativeDetections,
                processingTime: processingTime
            )
        }
        
        // Default mock result
        return createDefaultMockResult(processingTime: processingTime)
    }
    
    private func setupMockResults() {
        // High confidence USB-C detection
        mockResults["usb-c-clear"] = CableDetectionResult(
            detectedType: .usbC,
            confidence: 0.95,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4),
            alternativeDetections: [
                CableDetectionResult.AlternativeDetection(
                    type: .usb30,
                    confidence: 0.15,
                    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4)
                )
            ],
            processingTime: 0.08
        )
        
        // Medium confidence Lightning detection
        mockResults["lightning-partial"] = CableDetectionResult(
            detectedType: .lightning,
            confidence: 0.72,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
            alternativeDetections: [
                CableDetectionResult.AlternativeDetection(
                    type: .microUSB,
                    confidence: 0.28,
                    boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6)
                )
            ],
            processingTime: 0.12
        )
        
        // Low confidence detection
        mockResults["unclear-cable"] = CableDetectionResult(
            detectedType: .usbA,
            confidence: 0.45,
            boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2),
            alternativeDetections: [
                CableDetectionResult.AlternativeDetection(
                    type: .miniUSB,
                    confidence: 0.42,
                    boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2)
                ),
                CableDetectionResult.AlternativeDetection(
                    type: .microUSB,
                    confidence: 0.38,
                    boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2)
                )
            ],
            processingTime: 0.15
        )
    }
    
    private func createDefaultMockResult(processingTime: TimeInterval) -> CableDetectionResult {
        return CableDetectionResult(
            detectedType: .usbC,
            confidence: 0.85,
            boundingBox: CGRect(x: 0.25, y: 0.35, width: 0.5, height: 0.3),
            alternativeDetections: [],
            processingTime: processingTime
        )
    }
}