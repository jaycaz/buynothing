import XCTest
import SwiftUI
@testable import BuyNothing

class CableUIComponentsTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testUSBCableDisplayName() {
        let cable1 = USBCable(connectorType1: .usbC, connectorType2: .lightning)
        XCTAssertEqual(cable1.displayName, "USB-C to Lightning")
        
        let cable2 = USBCable(connectorType1: .microUSB)
        XCTAssertEqual(cable2.displayName, "Micro-USB")
    }
    
    func testUSBCableDescription() {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .lightning,
            length: .medium,
            brand: "Apple"
        )
        XCTAssertEqual(cable.description, "USB-C to Lightning (1-3ft) - Apple")
    }
    
    func testCableDetectionResultConfidence() {
        let cable = USBCable(connectorType1: .usbC)
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.85,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        
        XCTAssertEqual(detection.confidencePercentage, "85%")
        XCTAssertTrue(detection.isHighConfidence)
        XCTAssertFalse(detection.isMediumConfidence)
        XCTAssertFalse(detection.isLowConfidence)
    }
    
    func testCableDetectionResultMediumConfidence() {
        let cable = USBCable(connectorType1: .microUSB)
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.7,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        
        XCTAssertEqual(detection.confidencePercentage, "70%")
        XCTAssertFalse(detection.isHighConfidence)
        XCTAssertTrue(detection.isMediumConfidence)
        XCTAssertFalse(detection.isLowConfidence)
    }
    
    func testCableDetectionResultLowConfidence() {
        let cable = USBCable(connectorType1: .usbA)
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.5,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        
        XCTAssertEqual(detection.confidencePercentage, "50%")
        XCTAssertFalse(detection.isHighConfidence)
        XCTAssertFalse(detection.isMediumConfidence)
        XCTAssertTrue(detection.isLowConfidence)
    }
    
    // MARK: - ViewModel Tests
    
    func testCableDetectionViewModelAddDetection() {
        let viewModel = CableDetectionViewModel()
        let initialCableCount = viewModel.cables.count
        let initialDetectionCount = viewModel.detectionResults.count
        
        let cable = USBCable(connectorType1: .thunderbolt, brand: "Apple")
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.92,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        )
        
        viewModel.addDetection(detection)
        
        XCTAssertEqual(viewModel.cables.count, initialCableCount + 1)
        XCTAssertEqual(viewModel.detectionResults.count, initialDetectionCount + 1)
        XCTAssertEqual(viewModel.detectionResults.last?.cable.id, cable.id)
    }
    
    func testCableDetectionViewModelFeaturedDetection() {
        let viewModel = CableDetectionViewModel()
        viewModel.clearAll() // Start with empty state
        
        // Add low confidence detection
        let lowConfidenceCable = USBCable(connectorType1: .microUSB)
        let lowConfidenceDetection = CableDetectionResult(
            cable: lowConfidenceCable,
            confidence: 0.6,
            boundingBox: CGRect.zero
        )
        viewModel.addDetection(lowConfidenceDetection)
        
        // Should not be featured
        XCTAssertNil(viewModel.featuredDetection)
        
        // Add high confidence detection
        let highConfidenceCable = USBCable(connectorType1: .usbC, brand: "Apple")
        let highConfidenceDetection = CableDetectionResult(
            cable: highConfidenceCable,
            confidence: 0.9,
            boundingBox: CGRect.zero
        )
        viewModel.addDetection(highConfidenceDetection)
        
        // Should be featured
        XCTAssertNotNil(viewModel.featuredDetection)
        XCTAssertEqual(viewModel.featuredDetection?.cable.id, highConfidenceCable.id)
    }
    
    func testCableDetectionViewModelRecentDetections() {
        let viewModel = CableDetectionViewModel()
        viewModel.clearAll()
        
        // Add multiple detections
        for i in 0..<7 {
            let cable = USBCable(connectorType1: .usbA)
            let detection = CableDetectionResult(
                cable: cable,
                confidence: 0.8,
                boundingBox: CGRect.zero
            )
            viewModel.addDetection(detection)
        }
        
        // Should return max 5 recent detections
        XCTAssertEqual(viewModel.recentDetections.count, 5)
        
        // Should be in reverse chronological order (most recent first)
        let timestamps = viewModel.recentDetections.map { $0.timestamp }
        for i in 0..<timestamps.count-1 {
            XCTAssertGreaterThanOrEqual(timestamps[i], timestamps[i+1])
        }
    }
    
    func testCableDetectionViewModelClearAll() {
        let viewModel = CableDetectionViewModel()
        
        // Add some data
        let cable = USBCable(connectorType1: .lightning)
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.85,
            boundingBox: CGRect.zero
        )
        viewModel.addDetection(detection)
        
        XCTAssertFalse(viewModel.cables.isEmpty)
        XCTAssertFalse(viewModel.detectionResults.isEmpty)
        
        // Clear all
        viewModel.clearAll()
        
        XCTAssertTrue(viewModel.cables.isEmpty)
        XCTAssertTrue(viewModel.detectionResults.isEmpty)
    }
    
    // MARK: - Cable Type Tests
    
    func testUSBCableTypeMaxSpeed() {
        XCTAssertEqual(USBCableType.usbA.maxSpeed, "480 Mbps")
        XCTAssertEqual(USBCableType.usbC.maxSpeed, "10 Gbps")
        XCTAssertEqual(USBCableType.lightning.maxSpeed, "480 Mbps")
        XCTAssertEqual(USBCableType.microUSB.maxSpeed, "480 Mbps")
        XCTAssertEqual(USBCableType.miniUSB.maxSpeed, "480 Mbps")
        XCTAssertEqual(USBCableType.usb30.maxSpeed, "5 Gbps")
        XCTAssertEqual(USBCableType.thunderbolt.maxSpeed, "40 Gbps")
    }
    
    func testUSBCableTypeDisplayName() {
        XCTAssertEqual(USBCableType.usbA.displayName, "USB-A")
        XCTAssertEqual(USBCableType.usbC.displayName, "USB-C")
        XCTAssertEqual(USBCableType.lightning.displayName, "Lightning")
        XCTAssertEqual(USBCableType.microUSB.displayName, "Micro-USB")
        XCTAssertEqual(USBCableType.miniUSB.displayName, "Mini-USB")
        XCTAssertEqual(USBCableType.usb30.displayName, "USB 3.0")
        XCTAssertEqual(USBCableType.thunderbolt.displayName, "Thunderbolt")
    }
    
    // MARK: - UI Component Integration Tests
    
    func testCableCardViewInitialization() {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .lightning,
            length: .medium,
            condition: .likeNew,
            brand: "Apple"
        )
        
        // Test that we can create the view without crashing
        let cardView = CableCardView(cable: cable, isDetected: true, confidence: 0.9)
        XCTAssertNotNil(cardView)
    }
    
    func testCableHeroViewInitialization() {
        let cable = USBCable(connectorType1: .thunderbolt, brand: "Apple")
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.95,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2)
        )
        
        // Test that we can create the view without crashing
        let heroView = CableHeroView(detectionResult: detection)
        XCTAssertNotNil(heroView)
    }
    
    func testDetectionOverlayViewInitialization() {
        let detections = [
            CableDetectionResult(
                cable: USBCable(connectorType1: .usbC),
                confidence: 0.9,
                boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
            )
        ]
        
        // Test that we can create the view without crashing
        let overlayView = DetectionOverlayView(
            detectionResults: detections,
            previewSize: CGSize(width: 375, height: 667)
        )
        XCTAssertNotNil(overlayView)
    }
    
    // MARK: - Performance Tests
    
    func testDetectionResultsPerformance() {
        let viewModel = CableDetectionViewModel()
        viewModel.clearAll()
        
        measure {
            // Add many detections to test performance
            for _ in 0..<100 {
                let cable = USBCable(connectorType1: .usbA)
                let detection = CableDetectionResult(
                    cable: cable,
                    confidence: Double.random(in: 0.5...1.0),
                    boundingBox: CGRect.zero
                )
                viewModel.addDetection(detection)
            }
        }
    }
    
    func testRecentDetectionsPerformance() {
        let viewModel = CableDetectionViewModel()
        viewModel.clearAll()
        
        // Add many detections
        for _ in 0..<1000 {
            let cable = USBCable(connectorType1: .microUSB)
            let detection = CableDetectionResult(
                cable: cable,
                confidence: 0.8,
                boundingBox: CGRect.zero
            )
            viewModel.addDetection(detection)
        }
        
        measure {
            _ = viewModel.recentDetections
        }
    }
}

// MARK: - Test Extensions

extension CableDetectionViewModel {
    convenience init(withSampleData: Bool = true) {
        self.init()
        if !withSampleData {
            clearAll()
        }
    }
}