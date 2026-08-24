import CoreGraphics

/// One item's placement within a packed collage layout, produced by either
/// `CollageJustifiedPacker` or `CollageScatterPacker`.
struct CollagePlacement {
    /// Index into the caller's original `itemSizes`/items array.
    let index: Int
    let rect: CGRect
    /// Visual-only rotation in degrees, applied via `.rotationEffect` at render time.
    /// `CollageJustifiedPacker` always produces 0; `CollageScatterPacker` varies it.
    var rotationDegrees: Double = 0
}

/// The full result of packing a set of item sizes into a canvas.
struct CollageLayout {
    let placements: [CollagePlacement]
    let canvasSize: CGSize
}
