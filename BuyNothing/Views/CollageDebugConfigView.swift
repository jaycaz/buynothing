import SwiftUI

/// Debug controls for tuning the collage browser's segmentation and packing algorithms live.
struct CollageDebugConfigView: View {
    @ObservedObject var model: CollageBrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Segmentation") {
                    Picker("Algorithm", selection: $model.segmentationMode) {
                        ForEach(CollageSegmentationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Text("Only affects newly loaded items, not ones already on screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Packing") {
                    Picker("Algorithm", selection: $model.packingAlgorithm) {
                        ForEach(CollagePackingAlgorithm.allCases) { algorithm in
                            Text(algorithm.displayName).tag(algorithm)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        model.resetFeed()
                    } label: {
                        Label("Reset Feed", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Collage Debug Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
