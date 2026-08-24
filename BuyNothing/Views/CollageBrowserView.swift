import SwiftUI

/// The main collage-browsing screen: an infinitely-scrolling canvas of randomly sourced
/// everyday objects. Requires iOS 18+ for `onScrollGeometryChange`; callers gate availability
/// themselves (see ContentView, Phase 09).
@available(iOS 18.0, *)
struct CollageBrowserView: View {
    @ObservedObject var model: CollageBrowserModel

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    CollageCanvasView(items: model.items, layout: model.layout) { id in
                        model.itemDidAppear(id: id)
                    }
                    .padding(.horizontal, 8)

                    if model.isLoadingPage {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height / 2
            } action: { _, centerY in
                model.viewportCenterY = centerY
            }
            .onAppear {
                model.canvasWidth = max(0, proxy.size.width - 16)
                model.start()
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                model.canvasWidth = max(0, newWidth - 16)
            }
        }
    }
}
