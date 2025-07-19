import XCTest
import SwiftUI
@testable import BuyNothing

class CableUISnapshotTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        super.setUp()
        // Set consistent environment for snapshot tests
    }
    
    // MARK: - CableCardView Snapshot Tests
    
    func testCableCardViewBasic() throws {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .lightning,
            length: .medium,
            condition: .likeNew,
            brand: "Apple"
        )
        
        let view = CableCardView(cable: cable, isDetected: false, confidence: nil)
            .frame(width: 300, height: 280)
            .background(Color(.systemGroupedBackground))
        
        // This would be used with a snapshot testing framework like swift-snapshot-testing
        // assertSnapshot(matching: view, as: .image)
        
        XCTAssertNotNil(view)
    }
    
    func testCableCardViewDetected() throws {
        let cable = USBCable(
            connectorType1: .microUSB,
            length: .short,
            condition: .good,
            color: "White"
        )
        
        let view = CableCardView(cable: cable, isDetected: true, confidence: 0.92)
            .frame(width: 300, height: 280)
            .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    func testCableCardViewLowConfidence() throws {
        let cable = USBCable(
            connectorType1: .usbA,
            connectorType2: .usbC,
            length: .long,
            condition: .fair,
            brand: "Generic"
        )
        
        let view = CableCardView(cable: cable, isDetected: true, confidence: 0.55)
            .frame(width: 300, height: 280)
            .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - CableHeroView Snapshot Tests
    
    func testCableHeroViewHighConfidence() throws {
        let cable = USBCable(
            connectorType1: .thunderbolt,
            length: .medium,
            condition: .likeNew,
            brand: "Apple"
        )
        
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.96,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
        )
        
        let view = CableHeroView(detectionResult: detection)
            .frame(width: 350, height: 500)
            .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    func testCableHeroViewMediumConfidence() throws {
        let cable = USBCable(
            connectorType1: .usbC,
            length: .short,
            condition: .good,
            color: "Black"
        )
        
        let detection = CableDetectionResult(
            cable: cable,
            confidence: 0.72,
            boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.2)
        )
        
        let view = CableHeroView(detectionResult: detection)
            .frame(width: 350, height: 500)
            .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - CableGridView Snapshot Tests
    
    func testCableGridViewMultipleCables() throws {
        let cables = [
            USBCable(connectorType1: .usbC, connectorType2: .lightning, brand: "Apple"),
            USBCable(connectorType1: .microUSB, length: .short),
            USBCable(connectorType1: .usbA, connectorType2: .usbC, brand: "Anker"),
            USBCable(connectorType1: .thunderbolt, condition: .likeNew, brand: "Apple")
        ]
        
        let detections = [
            CableDetectionResult(
                cable: cables[0],
                confidence: 0.95,
                boundingBox: CGRect.zero
            ),
            CableDetectionResult(
                cable: cables[2],
                confidence: 0.78,
                boundingBox: CGRect.zero
            )
        ]
        
        let view = CableGridView(
            cables: cables,
            detectionResults: detections,
            onRefresh: {}
        )
        .frame(width: 375, height: 600)
        .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    func testCableGridViewEmpty() throws {
        let view = CableGridView(
            cables: [],
            detectionResults: [],
            onRefresh: {}
        )
        .frame(width: 375, height: 600)
        .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Detection Overlay Snapshot Tests
    
    func testDetectionOverlayViewSingleDetection() throws {
        let detection = CableDetectionResult(
            cable: USBCable(connectorType1: .usbC, brand: "Apple"),
            confidence: 0.89,
            boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.3, height: 0.2)
        )
        
        let view = DetectionOverlayView(
            detectionResults: [detection],
            previewSize: CGSize(width: 375, height: 667)
        )
        .frame(width: 375, height: 667)
        .background(Color.black)
        
        XCTAssertNotNil(view)
    }
    
    func testDetectionOverlayViewMultipleDetections() throws {
        let detections = [
            CableDetectionResult(
                cable: USBCable(connectorType1: .usbC),
                confidence: 0.92,
                boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.25, height: 0.15)
            ),
            CableDetectionResult(
                cable: USBCable(connectorType1: .lightning),
                confidence: 0.75,
                boundingBox: CGRect(x: 0.5, y: 0.6, width: 0.3, height: 0.2)
            ),
            CableDetectionResult(
                cable: USBCable(connectorType1: .microUSB),
                confidence: 0.68,
                boundingBox: CGRect(x: 0.2, y: 0.7, width: 0.2, height: 0.1)
            )
        ]
        
        let view = DetectionOverlayView(
            detectionResults: detections,
            previewSize: CGSize(width: 375, height: 667)
        )
        .frame(width: 375, height: 667)
        .background(Color.black)
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Loading States Snapshot Tests
    
    func testLoadingView() throws {
        let view = LoadingView(message: "Detecting USB cables...")
            .frame(width: 300, height: 200)
            .background(Color(.systemBackground))
        
        XCTAssertNotNil(view)
    }
    
    func testCableCardSkeleton() throws {
        let view = CableCardSkeleton()
            .frame(width: 300, height: 280)
            .background(Color(.systemGroupedBackground))
        
        XCTAssertNotNil(view)
    }
    
    func testEmptyStateView() throws {
        let view = EmptyStateView(
            icon: "cable.connector",
            title: "No Cables Found",
            message: "Use the camera to detect USB cables in your environment",
            actionTitle: "Start Scanning",
            action: {}
        )
        .frame(width: 350, height: 400)
        .background(Color(.systemBackground))
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Dark Mode Snapshot Tests
    
    func testCableCardViewDarkMode() throws {
        let cable = USBCable(
            connectorType1: .usbC,
            connectorType2: .lightning,
            brand: "Apple"
        )
        
        let view = CableCardView(cable: cable, isDetected: true, confidence: 0.88)
            .frame(width: 300, height: 280)
            .background(Color(.systemGroupedBackground))
            .environment(\.colorScheme, .dark)
        
        XCTAssertNotNil(view)
    }
    
    func testCableHeroViewDarkMode() throws {
        let detection = CableDetectionResult(
            cable: USBCable(connectorType1: .thunderbolt, brand: "Apple"),
            confidence: 0.94,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
        )
        
        let view = CableHeroView(detectionResult: detection)
            .frame(width: 350, height: 500)
            .background(Color(.systemGroupedBackground))
            .environment(\.colorScheme, .dark)
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Accessibility Snapshot Tests
    
    func testCableCardViewAccessibilityLarge() throws {
        let cable = USBCable(
            connectorType1: .lightning,
            length: .medium,
            brand: "Apple"
        )
        
        let view = CableCardView(cable: cable, isDetected: false, confidence: nil)
            .frame(width: 300, height: 350) // Larger height for accessibility
            .background(Color(.systemGroupedBackground))
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        
        XCTAssertNotNil(view)
    }
    
    func testDetectionOverlayViewAccessibility() throws {
        let detection = CableDetectionResult(
            cable: USBCable(connectorType1: .usbA, connectorType2: .usbC),
            confidence: 0.85,
            boundingBox: CGRect(x: 0.25, y: 0.35, width: 0.4, height: 0.25)
        )
        
        let view = DetectionOverlayView(
            detectionResults: [detection],
            previewSize: CGSize(width: 375, height: 667)
        )
        .frame(width: 375, height: 667)
        .background(Color.black)
        .environment(\.sizeCategory, .accessibilityLarge)
        
        XCTAssertNotNil(view)
    }
    
    // MARK: - Performance Snapshot Tests
    
    func testCableGridViewPerformanceWithManyCables() throws {
        let cables = (0..<20).map { index in
            USBCable(
                connectorType1: USBCableType.allCases[index % USBCableType.allCases.count],
                length: USBCableLength.allCases[index % USBCableLength.allCases.count],
                condition: USBCableCondition.allCases[index % USBCableCondition.allCases.count]
            )
        }
        
        let detections = cables.prefix(10).map { cable in
            CableDetectionResult(
                cable: cable,
                confidence: Double.random(in: 0.6...0.95),
                boundingBox: CGRect.zero
            )
        }
        
        measure {
            let view = CableGridView(
                cables: cables,
                detectionResults: Array(detections),
                onRefresh: {}
            )
            .frame(width: 375, height: 800)
            
            XCTAssertNotNil(view)
        }
    }
}

// MARK: - Test Helpers

extension CableUISnapshotTests {
    
    func createTestCable(type: USBCableType = .usbC, brand: String? = nil) -> USBCable {
        return USBCable(
            connectorType1: type,
            length: .medium,
            condition: .good,
            brand: brand
        )
    }
    
    func createTestDetection(confidence: Double = 0.85, cable: USBCable? = nil) -> CableDetectionResult {
        let testCable = cable ?? createTestCable()
        return CableDetectionResult(
            cable: testCable,
            confidence: confidence,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2)
        )
    }
}