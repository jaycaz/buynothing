import Testing
import SwiftUI
@testable import BuyNothing

@MainActor
@Suite("CollageBrowserView Tests")
struct CollageBrowserViewTests {

    @Test("constructs and renders without crashing given a pre-seeded model")
    func rendersWithoutCrashing() {
        // `CollageBrowserView` requires iOS 18+ (`onScrollGeometryChange`). The Swift Testing
        // macros can't be applied to `@available`-gated declarations, so gate the body instead.
        guard #available(iOS 18.0, *) else { return }

        let model = CollageBrowserModel()
        let items = (0..<4).map { _ in
            CollageBrowserItem(image: CollageBrowserModelTests.makeTestImage(width: 90, height: 100), isUserCaptured: false)
        }
        model.seedForTesting(items: items, canvasWidth: 390)

        let view = CollageBrowserView(model: model)
        let renderer = ImageRenderer(content: view)
        _ = renderer.uiImage // must not crash; geometry may legitimately be zero off-screen
    }
}
