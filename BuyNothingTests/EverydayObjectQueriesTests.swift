import Testing
import Foundation
@testable import BuyNothing

/// A fixed, deterministic RNG so these tests never flake.
struct FixedTestRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("EverydayObjectQueries Tests")
struct EverydayObjectQueriesTests {

    @Test("pool has at least 30 distinct, non-blank entries")
    func poolIsDiverse() {
        let pool = EverydayObjectQueries.pool
        #expect(pool.count >= 30)
        #expect(Set(pool.map { $0.lowercased() }).count == pool.count)
        #expect(pool.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    @Test("randomPage returns the requested count, all distinct")
    func randomPageDistinct() {
        var rng = FixedTestRNG(state: 42)
        let page = EverydayObjectQueries.randomPage(count: 6, using: &rng)
        #expect(page.count == 6)
        #expect(Set(page).count == 6)
        #expect(page.allSatisfy { EverydayObjectQueries.pool.contains($0) })
    }

    @Test("randomPage falls back to avoided entries when too few non-avoided remain")
    func randomPageFallsBackWhenMostlyAvoided() {
        var rng = FixedTestRNG(state: 7)
        let avoided = Set(EverydayObjectQueries.pool.prefix(EverydayObjectQueries.pool.count - 2))
        let page = EverydayObjectQueries.randomPage(count: 6, avoiding: avoided, using: &rng)
        #expect(page.count == 6)
        #expect(Set(page).count == 6)
    }

    @Test("randomPage prefers non-avoided entries when enough are available")
    func randomPagePrefersNonAvoided() {
        var rng = FixedTestRNG(state: 99)
        // Avoid everything except 6 specific entries.
        let keep = Set(EverydayObjectQueries.pool.prefix(6))
        let avoided = Set(EverydayObjectQueries.pool).subtracting(keep)
        let page = EverydayObjectQueries.randomPage(count: 6, avoiding: avoided, using: &rng)
        #expect(Set(page) == keep)
    }
}
