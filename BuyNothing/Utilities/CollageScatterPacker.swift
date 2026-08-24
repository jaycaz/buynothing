import CoreGraphics

/// A deterministic pseudo-random generator (SplitMix64) so a given set of
/// item sizes always packs into the same layout for a given seed -- needed
/// so appending new items to an already-displayed collage doesn't cause
/// already-placed items to jump around, and so this file's tests are
/// reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A "flea market table" packer: items are scaled to a randomized size, then
/// dropped into whichever column span currently has the least stuff piled on
/// it (masonry skyline), with a little vertical overlap, horizontal jitter,
/// and rotation for an organic, chaotic feel -- the opposite aesthetic of
/// `CollageJustifiedPacker`'s tidy rows.
///
/// Item `i`'s placement depends only on items `0..<i` (the skyline state
/// left behind by everything packed before it) and on `config.seed`, so
/// calling `pack` again with more items appended to the end never changes
/// the placements already computed for the earlier items -- required for a
/// live-growing scroll feed to not visually jump around as more items load.
enum CollageScatterPacker {

    struct Config {
        var columnWidth: CGFloat = 60
        var targetItemHeight: CGFloat = 140
        var minScale: CGFloat = 0.75
        var maxScale: CGFloat = 1.4
        var overlapAllowance: CGFloat = 10
        var maxRotationDegrees: Double = 10
        var seed: UInt64 = 20260823
    }

    static func pack(itemSizes: [CGSize], canvasWidth: CGFloat, config: Config = Config()) -> CollageLayout {
        guard !itemSizes.isEmpty, canvasWidth > 0 else {
            return CollageLayout(placements: [], canvasSize: .zero)
        }

        let numColumns = max(1, Int((canvasWidth / config.columnWidth).rounded(.down)))
        let actualColumnWidth = canvasWidth / CGFloat(numColumns)
        var columnHeights = [CGFloat](repeating: 0, count: numColumns)
        var rng = SplitMix64(seed: config.seed)
        var placements: [CollagePlacement] = []
        placements.reserveCapacity(itemSizes.count)

        for (i, size) in itemSizes.enumerated() {
            let aspect = size.width / max(size.height, 1)
            let scale = CGFloat.random(in: config.minScale...config.maxScale, using: &rng)
            var itemHeight = config.targetItemHeight * scale
            var itemWidth = itemHeight * aspect

            // Never let a single item be wider than the whole canvas -- keeps every
            // placement's rect within [0, canvasWidth] regardless of source aspect ratio.
            if itemWidth > canvasWidth {
                let shrink = canvasWidth / itemWidth
                itemWidth *= shrink
                itemHeight *= shrink
            }

            let spanColumns = max(1, min(numColumns, Int((itemWidth / actualColumnWidth).rounded(.up))))

            var bestStart = 0
            var bestHeight = CGFloat.greatestFiniteMagnitude
            for start in 0...(numColumns - spanColumns) {
                let windowMax = columnHeights[start..<(start + spanColumns)].max() ?? 0
                if windowMax < bestHeight {
                    bestHeight = windowMax
                    bestStart = start
                }
            }

            let overlap = min(config.overlapAllowance, itemHeight * 0.25)
            let y = max(0, bestHeight - overlap)

            let windowWidth = actualColumnWidth * CGFloat(spanColumns)
            let maxJitter = max(0, (windowWidth - itemWidth) / 2)
            let jitter = CGFloat.random(in: -maxJitter...maxJitter, using: &rng)
            let x = actualColumnWidth * CGFloat(bestStart) + (windowWidth - itemWidth) / 2 + jitter

            let rotation = Double.random(in: -config.maxRotationDegrees...config.maxRotationDegrees, using: &rng)

            placements.append(CollagePlacement(
                index: i,
                rect: CGRect(x: x, y: y, width: itemWidth, height: itemHeight),
                rotationDegrees: rotation
            ))

            let newBottom = y + itemHeight
            for col in bestStart..<(bestStart + spanColumns) {
                columnHeights[col] = max(columnHeights[col], newBottom)
            }
        }

        let canvasHeight = columnHeights.max() ?? 0
        return CollageLayout(placements: placements, canvasSize: CGSize(width: canvasWidth, height: canvasHeight))
    }
}
