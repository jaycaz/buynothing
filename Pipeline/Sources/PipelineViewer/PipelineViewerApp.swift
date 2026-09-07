import SwiftUI

@main
struct PipelineViewerApp: App {
    @StateObject private var model = ReviewModel()

    var body: some Scene {
        WindowGroup("Pipeline Viewer") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 720)
        }
    }
}
