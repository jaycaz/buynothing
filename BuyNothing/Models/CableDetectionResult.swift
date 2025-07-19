import Foundation
import CoreGraphics

struct CableDetectionResult: Identifiable, Codable {
    let id = UUID()
    let cable: USBCable
    let confidence: Double
    let boundingBox: CGRect
    let timestamp: Date
    let imageData: Data?
    
    init(
        cable: USBCable,
        confidence: Double,
        boundingBox: CGRect,
        imageData: Data? = nil
    ) {
        self.cable = cable
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.timestamp = Date()
        self.imageData = imageData
    }
    
    var confidencePercentage: String {
        return String(format: "%.0f%%", confidence * 100)
    }
    
    var isHighConfidence: Bool {
        return confidence >= 0.8
    }
    
    var isMediumConfidence: Bool {
        return confidence >= 0.6 && confidence < 0.8
    }
    
    var isLowConfidence: Bool {
        return confidence < 0.6
    }
}