import Foundation
import CoreGraphics
import UIKit

#if DEBUG
struct TestUtilities {
    
    // MARK: - Test Image Generation
    
    static func generateMockCableImage(type: USBCableType, size: CGSize = CGSize(width: 300, height: 200)) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Cable representation based on type
            drawCableShape(for: type, in: context, size: size)
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    private static func drawCableShape(for type: USBCableType, in context: UIGraphicsImageRendererContext, size: CGSize) {
        let cgContext = context.cgContext
        
        // Set cable color
        UIColor.label.setFill()
        UIColor.label.setStroke()
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        switch type {
        case .usbA:
            // Draw rectangular USB-A connector
            let rect = CGRect(x: centerX - 40, y: centerY - 10, width: 80, height: 20)
            cgContext.fillEllipse(in: rect)
            
        case .usbC:
            // Draw oval USB-C connector
            let rect = CGRect(x: centerX - 30, y: centerY - 8, width: 60, height: 16)
            cgContext.fillEllipse(in: rect)
            
        case .lightning:
            // Draw thin Lightning connector
            let rect = CGRect(x: centerX - 25, y: centerY - 6, width: 50, height: 12)
            cgContext.fillEllipse(in: rect)
            
        case .microUSB:
            // Draw trapezoid-like Micro-USB
            let rect = CGRect(x: centerX - 20, y: centerY - 5, width: 40, height: 10)
            cgContext.fillEllipse(in: rect)
            
        case .miniUSB:
            // Draw smaller mini-USB
            let rect = CGRect(x: centerX - 15, y: centerY - 4, width: 30, height: 8)
            cgContext.fillEllipse(in: rect)
            
        case .usb30:
            // Draw USB 3.0 (similar to USB-A but with blue accent)
            let rect = CGRect(x: centerX - 40, y: centerY - 10, width: 80, height: 20)
            cgContext.fillEllipse(in: rect)
            UIColor.systemBlue.setFill()
            let innerRect = CGRect(x: centerX - 35, y: centerY - 5, width: 70, height: 10)
            cgContext.fillEllipse(in: innerRect)
            
        case .thunderbolt:
            // Draw larger Thunderbolt connector
            let rect = CGRect(x: centerX - 35, y: centerY - 8, width: 70, height: 16)
            cgContext.fillEllipse(in: rect)
        }
        
        // Draw cable wire
        UIColor.secondaryLabel.setStroke()
        cgContext.setLineWidth(3)
        cgContext.move(to: CGPoint(x: centerX + 50, y: centerY))
        cgContext.addLine(to: CGPoint(x: size.width - 20, y: centerY))
        cgContext.strokePath()
    }
    
    // MARK: - Test Data Helpers
    
    static func createTestCableDetectionResult(
        type: USBCableType = .usbC,
        confidence: Float = 0.85,
        boundingBox: CGRect? = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4),
        alternativeCount: Int = 1
    ) -> CableDetectionResult {
        
        var alternatives: [CableDetectionResult.AlternativeDetection] = []
        
        if alternativeCount > 0 {
            let alternativeTypes = USBCableType.allCases.filter { $0 != type }
            for i in 0..<min(alternativeCount, alternativeTypes.count) {
                alternatives.append(
                    CableDetectionResult.AlternativeDetection(
                        type: alternativeTypes[i],
                        confidence: max(0.1, confidence - Float(i + 1) * 0.2),
                        boundingBox: boundingBox
                    )
                )
            }
        }
        
        return CableDetectionResult(
            detectedType: type,
            confidence: confidence,
            boundingBox: boundingBox,
            alternativeDetections: alternatives,
            processingTime: 0.1
        )
    }
    
    // MARK: - Test Image Hashes
    
    static func createImageHash(for type: USBCableType, scenario: String = "default") -> String {
        return "\(type.rawValue.lowercased())-\(scenario)"
    }
    
    // MARK: - Async Test Helpers
    
    static func waitForCondition(
        timeout: TimeInterval = 1.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        throw TestError.timeoutExceeded
    }
    
    enum TestError: Error {
        case timeoutExceeded
        case invalidTestData
        case mockSetupFailed
        
        var localizedDescription: String {
            switch self {
            case .timeoutExceeded:
                return "Test condition timeout exceeded"
            case .invalidTestData:
                return "Test data is invalid"
            case .mockSetupFailed:
                return "Failed to set up mock data"
            }
        }
    }
}

// MARK: - Test Image Constants

extension TestUtilities {
    enum TestImageKey {
        static let usbCClear = "usb-c-clear"
        static let lightningPartial = "lightning-partial"
        static let unclearCable = "unclear-cable"
        static let multipleConnectors = "multiple-connectors"
        static let noConnector = "no-connector"
        static let blurryImage = "blurry-image"
        static let badLighting = "bad-lighting"
    }
}
#endif