import Testing
import SwiftUI
@testable import BuyNothing

@MainActor
@Suite("CollageCanvasView Tests")
struct CollageCanvasViewTests {

    @Test("renders to an image sized to the layout's canvas size")
    func rendersAtCanvasSize() {
        let items = [
            CollageBrowserItem(image: CollageBrowserModelTests.makeTestImage(width: 80, height: 100), isUserCaptured: false),
            CollageBrowserItem(image: CollageBrowserModelTests.makeTestImage(width: 60, height: 120), isUserCaptured: false),
        ]
        let sizes = items.map { CGSize(width: $0.image.width, height: $0.image.height) }
        let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 300, targetRowHeight: 120)

        let view = CollageCanvasView(items: items, layout: layout)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let rendered = renderer.uiImage
        #expect(rendered != nil)
        if let rendered {
            #expect(abs(rendered.size.width - layout.canvasSize.width) < 2)
            #expect(abs(rendered.size.height - layout.canvasSize.height) < 2)
        }
    }

    @Test("empty items renders without crashing")
    func emptyItemsDoesNotCrash() {
        let view = CollageCanvasView(items: [], layout: CollageLayout(placements: [], canvasSize: .zero))
        let renderer = ImageRenderer(content: view)
        _ = renderer.uiImage
    }
}
