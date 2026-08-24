import Testing
import CoreGraphics
@testable import BuyNothing

@Suite("CollageScatterPacker Tests")
struct CollageScatterPackerTests {

    static func sampleSizes(_ n: Int) -> [CGSize] {
        (0..<n).map { i in
            let w: CGFloat = [80, 120, 60, 150, 100, 90][i % 6]
            let h: CGFloat = [100, 80, 140, 90, 110, 130][i % 6]
            return CGSize(width: w, height: h)
        }
    }

    @Test("empty input produces an empty layout with zero canvas size")
    func emptyInput() {
        let layout = CollageScatterPacker.pack(itemSizes: [], canvasWidth: 390)
        #expect(layout.placements.isEmpty)
        #expect(layout.canvasSize == .zero)
    }

    @Test("packing the same sizes twice with the default seed is identical")
    func deterministic() {
        let sizes = CollageScatterPackerTests.sampleSizes(12)
        let a = CollageScatterPacker.pack(itemSizes: sizes, canvasWidth: 390)
        let b = CollageScatterPacker.pack(itemSizes: sizes, canvasWidth: 390)
        #expect(a.canvasSize == b.canvasSize)
        #expect(a.placements.count == b.placements.count)
        for (pa, pb) in zip(a.placements, b.placements) {
            #expect(pa.index == pb.index)
            #expect(pa.rect == pb.rect)
            #expect(pa.rotationDegrees == pb.rotationDegrees)
        }
    }

    @Test("every placement's rect stays within the canvas horizontally, and y is never negative")
    func inBounds() {
        let canvasWidth: CGFloat = 390
        let layout = CollageScatterPacker.pack(itemSizes: CollageScatterPackerTests.sampleSizes(20), canvasWidth: canvasWidth)
        for p in layout.placements {
            #expect(p.rect.minX >= -0.01)
            #expect(p.rect.maxX <= canvasWidth + 0.01)
            #expect(p.rect.minY >= -0.01)
        }
    }

    @Test("canvas height matches the lowest point of any placement")
    func canvasHeightMatchesContent() {
        let layout = CollageScatterPacker.pack(itemSizes: CollageScatterPackerTests.sampleSizes(15), canvasWidth: 390)
        let expectedHeight = layout.placements.map { $0.rect.maxY }.max() ?? 0
        #expect(abs(layout.canvasSize.height - expectedHeight) < 0.01)
    }

    @Test("placements for the first k items are unchanged when more items are appended")
    func prefixStability() {
        let sizes = CollageScatterPackerTests.sampleSizes(16)
        let full = CollageScatterPacker.pack(itemSizes: sizes, canvasWidth: 390)
        let prefix = CollageScatterPacker.pack(itemSizes: Array(sizes.prefix(5)), canvasWidth: 390)
        #expect(prefix.placements.count == 5)
        for i in 0..<5 {
            #expect(full.placements[i].rect == prefix.placements[i].rect)
            #expect(full.placements[i].rotationDegrees == prefix.placements[i].rotationDegrees)
        }
    }

    @Test("an item wider than the canvas is shrunk to fit")
    func extremeAspectRatioIsClamped() {
        // A very wide, short item (aspect ratio 10:1).
        let sizes = [CGSize(width: 1000, height: 100)]
        let layout = CollageScatterPacker.pack(itemSizes: sizes, canvasWidth: 300)
        #expect(layout.placements.count == 1)
        #expect(layout.placements[0].rect.width <= 300.01)
    }
}
