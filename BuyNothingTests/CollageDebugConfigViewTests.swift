import Testing
import SwiftUI
@testable import BuyNothing

@MainActor
@Suite("CollageDebugConfigView Tests")
struct CollageDebugConfigViewTests {

    @Test("constructs and renders without crashing")
    func rendersWithoutCrashing() {
        let model = CollageBrowserModel()
        let view = CollageDebugConfigView(model: model)
        let renderer = ImageRenderer(content: view)
        _ = renderer.uiImage // must not crash
    }
}
