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

                Section("Last captured item (debug)") {
                    if let debug = model.lastCaptureDebug {
                        VStack(spacing: 8) {
                            Image(decorative: debug.annotatedPhoto, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Red = pixels the strategy removed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(decorative: debug.cutout, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Final cutout.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Capture a held object in Vision − Skin mode to preview the removed pixels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
