import Foundation

/// A curated pool of everyday-object search queries used to source the
/// collage browser's "randomly chosen objects" feed via DuckDuckGo image
/// search (see `EverydayObjectFeed`). Deliberately diverse across rooms/uses
/// so a long scroll session doesn't feel repetitive.
enum EverydayObjectQueries {
    static let pool: [String] = [
        "ceramic mug", "sneakers", "backpack", "potted houseplant", "wireless headphones",
        "notebook", "desk lamp", "throw pillow", "cast iron skillet", "yoga mat",
        "bicycle helmet", "board game box", "coffee grinder", "wool sweater", "hiking boots",
        "vinyl record", "acoustic guitar", "camera", "toolbox", "picture frame",
        "umbrella", "watering can", "table lamp", "vintage suitcase", "skateboard",
        "tennis racket", "wooden chair", "sunglasses", "teapot", "alarm clock",
        "record player", "stack of books", "wicker basket", "electric kettle", "snow boots",
    ]

    /// Returns up to `count` distinct queries drawn from `pool`, shuffled fresh each call.
    /// Entries in `avoiding` are used as a soft preference (pushed to the back), so
    /// back-to-back pages tend not to repeat -- but if `count` exceeds the number of
    /// non-avoided entries, avoided ones fill the rest rather than returning fewer than
    /// `count`. `count` must not exceed `pool.count`.
    static func randomPage(
        count: Int,
        avoiding: Set<String> = [],
        using rng: inout some RandomNumberGenerator
    ) -> [String] {
        precondition(count <= pool.count, "count must not exceed pool.count")
        let preferred = pool.filter { !avoiding.contains($0) }.shuffled(using: &rng)
        let fallback = pool.filter { avoiding.contains($0) }.shuffled(using: &rng)
        return Array((preferred + fallback).prefix(count))
    }
}
