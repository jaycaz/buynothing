import SwiftUI

// Sources photos from the DEBUG-only SyntheticToolImageGenerator (see CollageDemoModel).
#if DEBUG
/// A working spike of the "toss a photo, it joins the collage" experience:
/// segment the object out of its background, normalize its rotation, and tightly pack it
/// alongside every other tossed item of the same kind. Screwdrivers stand in for the first
/// item type while the app doesn't yet have a real camera pipeline wired up.
struct CollageDemoView: View {
    @StateObject private var model = CollageDemoModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let message = model.statusMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .padding(.horizontal)
                    }

                    if !model.stages.isEmpty {
                        pipelineSection
                    }

                    if let collage = model.collageImage {
                        collageSection(collage)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Collage Prototype")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.regenerate()
                    } label: {
                        if model.isProcessing {
                            ProgressView()
                        } else {
                            Label("Toss 6 more", systemImage: "camera.fill")
                        }
                    }
                    .disabled(model.isProcessing)
                }
            }
        }
        .task {
            if model.stages.isEmpty {
                model.regenerate()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Screwdrivers, tossed in")
                .font(.title2.bold())
            Text("Each photo runs through: segment the object off its background → rotate to a shared orientation → pack tightly into the collage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var pipelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pipeline, per item", icon: "wand.and.stars")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(model.stages) { stage in
                        PipelineStageCard(stage: stage)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func collageSection(_ collage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "The commons' screwdriver collage", icon: "square.grid.2x2")
                .padding(.horizontal)
            Image(uiImage: collage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
        }
    }
}

private struct PipelineStageCard: View {
    let stage: CollageDemoModel.PipelineResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            stageThumb(stage.original, label: "photo")
            if let mask = stage.mask {
                stageThumb(mask, label: "mask", checkerboard: false)
            }
            if let aligned = stage.aligned {
                stageThumb(aligned, label: "aligned", checkerboard: true)
            }
            if let error = stage.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(width: 110, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func stageThumb(_ cgImage: CGImage, label: String, checkerboard: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if checkerboard {
                    CheckerboardBackground()
                }
                Image(uiImage: UIImage(cgImage: cgImage))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 8
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = 0
                var col = 0
                while x < size.width {
                    let isDark = (row + col).isMultiple(of: 2)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: tile, height: tile)),
                        with: .color(isDark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                    x += tile
                    col += 1
                }
                y += tile
                row += 1
            }
        }
    }
}

#Preview {
    CollageDemoView()
}
#endif
