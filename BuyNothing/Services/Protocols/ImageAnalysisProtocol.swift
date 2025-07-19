import Foundation
import CoreML
import Vision

protocol ImageAnalysisProtocol: Actor {
    func analyzeImage(_ image: Data) async throws -> CableDetectionResult
    func analyzeImage(_ image: CGImage) async throws -> CableDetectionResult
    func setConfidenceThreshold(_ threshold: Float)
}

struct CableDetectionResult: Equatable, Sendable {
    let detectedType: USBCableType
    let confidence: Float
    let boundingBox: CGRect?
    let alternativeDetections: [AlternativeDetection]
    let processingTime: TimeInterval
    
    struct AlternativeDetection: Equatable, Sendable {
        let type: USBCableType
        let confidence: Float
        let boundingBox: CGRect?
    }
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
    
    var isMediumConfidence: Bool {
        confidence >= 0.6 && confidence < 0.8
    }
    
    var isLowConfidence: Bool {
        confidence < 0.6
    }
}

enum ImageAnalysisError: Error, Sendable {
    case invalidImageData
    case noDetectionFound
    case confidenceTooLow(Float)
    case modelNotLoaded
    case processingFailed(Error)
    case unsupportedImageFormat
    
    var localizedDescription: String {
        switch self {
        case .invalidImageData:
            return "The image data is invalid or corrupted"
        case .noDetectionFound:
            return "No USB cable detected in the image"
        case .confidenceTooLow(let confidence):
            return "Detection confidence too low (\(confidence))"
        case .modelNotLoaded:
            return "Machine learning model is not loaded"
        case .processingFailed(let error):
            return "Image processing failed: \(error.localizedDescription)"
        case .unsupportedImageFormat:
            return "Image format is not supported"
        }
    }
}