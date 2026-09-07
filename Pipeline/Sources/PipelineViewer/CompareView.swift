import SwiftUI
import CollagePipeline

/// Side-by-side comparison of every segmentation strategy over the selected
/// photo: one cell per `SegmentationStrategy.allCases`, each showing the
/// cutout over the shared checkerboard plus its kept fraction and duration.
struct CompareView: View {
    @EnvironmentObject var model: ReviewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(SegmentationStrategy.allCases, id: \.self) { strategy in
                    cell(for: strategy)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(for strategy: SegmentationStrategy) -> some View {
        VStack(spacing: 6) {
            Text(strategy.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                CheckerboardView()
                if let cutout = model.compareResults[strategy] {
                    Image(decorative: cutout, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let error = failureText(for: strategy) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                } else if model.isComparing {
                    ProgressView()
                }
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))

            footer(for: strategy)
        }
        .frame(width: 260)
    }

    private func failureText(for strategy: SegmentationStrategy) -> String? {
        model.compareMeasurements
            .first { $0.strategy == strategy }?
            .error
    }

    @ViewBuilder
    private func footer(for strategy: SegmentationStrategy) -> some View {
        if let m = model.compareMeasurements.first(where: { $0.strategy == strategy }), m.error == nil {
            Text("kept \(Int(m.keptFraction * 100))% · \(Int(m.milliseconds)) ms")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
