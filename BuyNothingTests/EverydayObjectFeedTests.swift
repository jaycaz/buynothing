import Testing
@testable import BuyNothing

@Suite("CollageSegmentationMode Tests")
struct CollageSegmentationModeTests {

    @Test("visionCutout maps to segment=true, raw maps to segment=false")
    func segmentFlagMapping() {
        #expect(CollageSegmentationMode.visionCutout.segmentFlag == true)
        #expect(CollageSegmentationMode.raw.segmentFlag == false)
    }

    @Test("both modes have distinct, non-empty display names")
    func displayNames() {
        let names = Set(CollageSegmentationMode.allCases.map { $0.displayName })
        #expect(names.count == CollageSegmentationMode.allCases.count)
        #expect(names.allSatisfy { !$0.isEmpty })
    }
}
