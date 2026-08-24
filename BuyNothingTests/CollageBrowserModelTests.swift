import Testing
import CoreGraphics
@testable import BuyNothing

@MainActor
@Suite("CollageBrowserModel Tests")
struct CollageBrowserModelTests {

    static func makeTestImage(width: Int, height: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    @Test("insertionIndex picks the placement nearest the given y")
    func insertionIndexNearest() {
        let placements = [
            CollagePlacement(index: 0, rect: CGRect(x: 0, y: 0, width: 100, height: 100)),
            CollagePlacement(index: 1, rect: CGRect(x: 0, y: 100, width: 100, height: 100)),
            CollagePlacement(index: 2, rect: CGRect(x: 0, y: 200, width: 100, height: 100)),
        ]
        // midYs are 50, 150, 250
        #expect(CollageBrowserModel.insertionIndex(nearestToY: 40, placements: placements, itemCount: 3) == 1)
        #expect(CollageBrowserModel.insertionIndex(nearestToY: 160, placements: placements, itemCount: 3) == 2)
        #expect(CollageBrowserModel.insertionIndex(nearestToY: 900, placements: placements, itemCount: 3) == 3)
    }

    @Test("insertionIndex appends when there are no placements yet")
    func insertionIndexEmpty() {
        #expect(CollageBrowserModel.insertionIndex(nearestToY: 50, placements: [], itemCount: 0) == 0)
        #expect(CollageBrowserModel.insertionIndex(nearestToY: 50, placements: [], itemCount: 4) == 4)
    }

    @Test("switching packing algorithm repacks without changing item count")
    func switchingAlgorithmRepacks() {
        let model = CollageBrowserModel()
        let items = (0..<8).map { _ in
            CollageBrowserItem(image: Self.makeTestImage(width: 100, height: 120), isUserCaptured: false)
        }
        model.seedForTesting(items: items, canvasWidth: 390)
        let rowsLayout = model.layout
        #expect(model.packingAlgorithm == .justifiedRows)
        #expect(rowsLayout.placements.count == 8)

        model.packingAlgorithm = .scatter
        #expect(model.items.count == 8)
        #expect(model.layout.placements.count == 8)
        let sameGeometry = model.layout.canvasSize == rowsLayout.canvasSize
            && model.layout.placements.map(\.rect) == rowsLayout.placements.map(\.rect)
        #expect(!sameGeometry)
    }

    @Test("resizing canvasWidth repacks")
    func canvasResizeRepacks() {
        let model = CollageBrowserModel()
        let items = (0..<5).map { _ in
            CollageBrowserItem(image: Self.makeTestImage(width: 100, height: 100), isUserCaptured: false)
        }
        model.seedForTesting(items: items, canvasWidth: 390)
        let before = model.layout.canvasSize
        model.canvasWidth = 700
        #expect(model.layout.canvasSize != before)
    }
}
