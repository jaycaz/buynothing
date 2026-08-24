import Testing
import Foundation
@testable import BuyNothing

// MARK: - Snapshot Collage Preview Plan Tests

@Suite("SnapshotCollageModel Tests")
struct SnapshotCollageModelTests {

    @Test("previewPlan uses the identified query when identification is available")
    func previewPlanIdentified() {
        let plan = SnapshotCollageModel.previewPlan(
            for: ItemIdentifier.Identification(name: "white ceramic mug", searchQuery: "ceramic mug")
        )
        #expect(plan.previewMode == false)
        #expect(plan.queries == ["ceramic mug"])
        #expect(plan.perQuery == SnapshotCollageModel.maxSourcedItems)
    }

    @Test("previewPlan falls back to everyday objects when identification is unavailable")
    func previewPlanFallback() {
        let plan = SnapshotCollageModel.previewPlan(for: nil)
        #expect(plan.previewMode == true)
        #expect(plan.queries.count >= 3)
        #expect(!plan.queries.isEmpty)
    }

    @Test("previewPlan falls back when the search query is blank")
    func previewPlanBlankQuery() {
        let plan = SnapshotCollageModel.previewPlan(
            for: ItemIdentifier.Identification(name: "mystery", searchQuery: "   ")
        )
        #expect(plan.previewMode == true)
        #expect(plan.queries == SnapshotCollageModel.fallbackPreviewQueries)
    }

    @Test("fallback queries are everyday objects, not one repeated query")
    func fallbackQueriesAreVaried() {
        let queries = SnapshotCollageModel.fallbackPreviewQueries
        #expect(queries.count == Set(queries.map { $0.lowercased() }).count)
    }
}
