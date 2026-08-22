import Foundation
import CoreGraphics

/// Tight object packing for the collage: a justified-row layout (the same family of algorithm
/// Google Photos / Flickr use for gapless photo grids). Each aligned, background-removed cutout
/// is scaled to a common row height, rows are filled left-to-right, and once a row is full its
/// items are rescaled just enough that the row's total width exactly matches the canvas width —
/// so every row packs edge-to-edge with only a thin gutter between items, no matter how each
/// item's aspect ratio varies.
///
/// Cross-platform: pure CoreGraphics, so it compiles for macOS and iOS alike.
public enum CollageJustifiedPacker {

    public struct Placement {
        public let index: Int
        public let rect: CGRect
    }

    public struct Layout {
        public let placements: [Placement]
        public let canvasSize: CGSize
    }

    public static func pack(
        itemSizes: [CGSize],
        canvasWidth: CGFloat,
        targetRowHeight: CGFloat,
        spacing: CGFloat = 6,
        maxRowHeightScale: CGFloat = 1.35
    ) -> Layout {
        guard !itemSizes.isEmpty else { return Layout(placements: [], canvasSize: .zero) }

        var placements: [Placement] = []
        var y: CGFloat = 0
        var rowStartIndex = 0
        var rowWidths: [CGFloat] = []

        func flushRow(endIndex: Int, stretchToFill: Bool) {
            guard endIndex > rowStartIndex else { return }
            let count = endIndex - rowStartIndex
            let totalGutter = spacing * CGFloat(count - 1)
            let naturalWidth = rowWidths.reduce(0, +)
            let availableWidth = canvasWidth - totalGutter

            var scale = availableWidth / max(naturalWidth, 1)
            if !stretchToFill {
                scale = min(scale, maxRowHeightScale)
            }
            let rowHeight = targetRowHeight * scale

            var x: CGFloat = 0
            for i in rowStartIndex..<endIndex {
                let scaledWidth = rowWidths[i - rowStartIndex] * scale
                placements.append(Placement(index: i, rect: CGRect(x: x, y: y, width: scaledWidth, height: rowHeight)))
                x += scaledWidth + spacing
            }
            y += rowHeight + spacing
        }

        for (i, size) in itemSizes.enumerated() {
            let aspect = size.width / max(size.height, 1)
            let widthAtTargetHeight = targetRowHeight * aspect
            rowWidths.append(widthAtTargetHeight)

            let countSoFar = i - rowStartIndex + 1
            let widthSoFar = rowWidths.reduce(0, +) + spacing * CGFloat(countSoFar - 1)
            if widthSoFar >= canvasWidth {
                flushRow(endIndex: i + 1, stretchToFill: true)
                rowStartIndex = i + 1
                rowWidths.removeAll()
            }
        }
        // Final partial row: don't stretch-distort a lone leftover item.
        if rowStartIndex < itemSizes.count {
            flushRow(endIndex: itemSizes.count, stretchToFill: false)
        }

        let canvasHeight = max(0, y - spacing)
        return Layout(placements: placements, canvasSize: CGSize(width: canvasWidth, height: canvasHeight))
    }
}
