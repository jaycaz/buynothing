import SwiftUI

/// Renders `items` positioned according to `layout`, inside a fixed-size canvas matching
/// `layout.canvasSize`. Pure presentation -- the caller wraps this in a ScrollView and
/// supplies `onItemAppear` to drive infinite-scroll paging.
struct CollageCanvasView: View {
    let items: [CollageBrowserItem]
    let layout: CollageLayout
    var onItemAppear: (UUID) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.placements, id: \.index) { placement in
                if placement.index < items.count {
                    let item = items[placement.index]
                    Image(decorative: item.image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: placement.rect.width, height: placement.rect.height)
                        .rotationEffect(.degrees(placement.rotationDegrees))
                        .position(x: placement.rect.midX, y: placement.rect.midY)
                        .onAppear { onItemAppear(item.id) }
                }
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
    }
}
