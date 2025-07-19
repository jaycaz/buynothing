import Foundation
import UIKit
import CoreGraphics

#if DEBUG
struct TestImageGenerator {
    
    static func generateAllTestImages() {
        let testImagesURL = Bundle.main.url(forResource: "TestImages", withExtension: nil)
        guard let baseURL = testImagesURL else {
            print("TestImages directory not found")
            return
        }
        
        // Generate images for each cable type
        for cableType in USBCableType.allCases {
            generateImagesForCableType(cableType, baseURL: baseURL)
        }
        
        // Generate special test cases
        generateSpecialTestCases(baseURL: baseURL)
    }
    
    private static func generateImagesForCableType(_ cableType: USBCableType, baseURL: URL) {
        let typeDirectory = baseURL.appendingPathComponent(cableType.rawValue)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: typeDirectory, withIntermediateDirectories: true)
        
        // Generate different scenarios
        let scenarios = [
            ("clear", 1.0, UIColor.systemBackground),
            ("partial", 0.7, UIColor.systemGray6),
            ("dark", 0.3, UIColor.systemGray),
            ("angled", 1.0, UIColor.systemBackground)
        ]
        
        for (index, (scenario, brightness, background)) in scenarios.enumerated() {
            if let imageData = generateCableImage(
                type: cableType,
                scenario: scenario,
                brightness: brightness,
                backgroundColor: background,
                size: CGSize(width: 400, height: 300)
            ) {
                let filename = "\(cableType.rawValue.lowercased())-\(scenario)-\(String(format: "%02d", index + 1)).jpg"
                let fileURL = typeDirectory.appendingPathComponent(filename)
                
                try? imageData.write(to: fileURL)
                print("Generated: \(filename)")
            }
        }
    }
    
    private static func generateSpecialTestCases(baseURL: URL) {
        let testCasesDirectory = baseURL.appendingPathComponent("Test-Cases")
        try? FileManager.default.createDirectory(at: testCasesDirectory, withIntermediateDirectories: true)
        
        // Multiple cables image
        if let multipleImage = generateMultipleCablesImage() {
            let multipleURL = testCasesDirectory.appendingPathComponent("multiple-cables-01.jpg")
            try? multipleImage.write(to: multipleURL)
            print("Generated: multiple-cables-01.jpg")
        }
        
        // No cable image (just background)
        if let noImage = generateNoCableImage() {
            let noURL = testCasesDirectory.appendingPathComponent("no-cable-01.jpg")
            try? noImage.write(to: noURL)
            print("Generated: no-cable-01.jpg")
        }
        
        // Blurry image
        if let blurryImage = generateBlurryImage() {
            let blurryURL = testCasesDirectory.appendingPathComponent("blurry-cable-01.jpg")
            try? blurryImage.write(to: blurryURL)
            print("Generated: blurry-cable-01.jpg")
        }
    }
    
    private static func generateCableImage(
        type: USBCableType,
        scenario: String,
        brightness: CGFloat,
        backgroundColor: UIColor,
        size: CGSize
    ) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Background
            backgroundColor.withAlphaComponent(brightness).setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Draw cable based on scenario
            switch scenario {
            case "angled":
                drawAngledCable(type: type, context: cgContext, size: size, brightness: brightness)
            case "partial":
                drawPartialCable(type: type, context: cgContext, size: size, brightness: brightness)
            default:
                drawStandardCable(type: type, context: cgContext, size: size, brightness: brightness)
            }
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    private static func drawStandardCable(type: USBCableType, context: CGContext, size: CGSize, brightness: CGFloat) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Cable color based on brightness
        UIColor.label.withAlphaComponent(brightness).setFill()
        UIColor.label.withAlphaComponent(brightness).setStroke()
        
        let connectorRect = getConnectorRect(for: type, centerX: centerX, centerY: centerY)
        
        // Draw connector
        if type == .usbC || type == .lightning {
            context.fillEllipse(in: connectorRect)
        } else {
            context.fill(connectorRect)
        }
        
        // Draw cable wire
        context.setLineWidth(4)
        context.move(to: CGPoint(x: connectorRect.maxX, y: centerY))
        context.addLine(to: CGPoint(x: size.width - 30, y: centerY))
        context.strokePath()
    }
    
    private static func drawAngledCable(type: USBCableType, context: CGContext, size: CGSize, brightness: CGFloat) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Rotate context for angled view
        context.saveGState()
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: .pi / 6) // 30 degrees
        context.translateBy(x: -centerX, y: -centerY)
        
        drawStandardCable(type: type, context: context, size: size, brightness: brightness)
        
        context.restoreGState()
    }
    
    private static func drawPartialCable(type: USBCableType, context: CGContext, size: CGSize, brightness: CGFloat) {
        // Draw cable partially obscured
        drawStandardCable(type: type, context: context, size: size, brightness: brightness)
        
        // Add obstruction
        UIColor.systemGray.withAlphaComponent(0.6).setFill()
        let obstructionRect = CGRect(x: size.width * 0.3, y: size.height * 0.2, width: size.width * 0.4, height: size.height * 0.6)
        context.fill(obstructionRect)
    }
    
    private static func generateMultipleCablesImage() -> Data? {
        let size = CGSize(width: 500, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Background
            UIColor.systemBackground.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Draw multiple cables
            let cables: [(USBCableType, CGPoint)] = [
                (.usbC, CGPoint(x: 150, y: 100)),
                (.lightning, CGPoint(x: 350, y: 150)),
                (.usbA, CGPoint(x: 250, y: 200))
            ]
            
            for (type, position) in cables {
                UIColor.label.setFill()
                let rect = getConnectorRect(for: type, centerX: position.x, centerY: position.y)
                
                if type == .usbC || type == .lightning {
                    cgContext.fillEllipse(in: rect)
                } else {
                    cgContext.fill(rect)
                }
            }
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    private static func generateNoCableImage() -> Data? {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Just background with some random objects
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some noise/objects
            UIColor.systemGray4.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 30, height: 20))
            context.fill(CGRect(x: 300, y: 200, width: 40, height: 15))
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    private static func generateBlurryImage() -> Data? {
        // Generate a standard cable image then apply blur effect
        guard let standardImage = TestUtilities.generateMockCableImage(type: .usbC) else { return nil }
        guard let uiImage = UIImage(data: standardImage) else { return nil }
        
        // Apply blur filter
        let ciImage = CIImage(image: uiImage)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = 5.0
        
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        let blurredUIImage = UIImage(cgImage: cgImage)
        return blurredUIImage.jpegData(compressionQuality: 0.8)
    }
    
    private static func getConnectorRect(for type: USBCableType, centerX: CGFloat, centerY: CGFloat) -> CGRect {
        switch type {
        case .usbA:
            return CGRect(x: centerX - 40, y: centerY - 12, width: 80, height: 24)
        case .usbC:
            return CGRect(x: centerX - 30, y: centerY - 8, width: 60, height: 16)
        case .lightning:
            return CGRect(x: centerX - 25, y: centerY - 6, width: 50, height: 12)
        case .microUSB:
            return CGRect(x: centerX - 20, y: centerY - 5, width: 40, height: 10)
        case .miniUSB:
            return CGRect(x: centerX - 15, y: centerY - 4, width: 30, height: 8)
        case .usb30:
            return CGRect(x: centerX - 40, y: centerY - 12, width: 80, height: 24)
        case .thunderbolt:
            return CGRect(x: centerX - 35, y: centerY - 10, width: 70, height: 20)
        }
    }
}
#endif