import SwiftUI
import CollagePipeline

/// Live-tunable knobs for one pipeline step. Today that's only Segmentation;
/// future steps (delighting, relighting, shadow removal, perspective correction) get their
/// own section here as they're added to CollagePipeline.
struct ParamsPanel: View {
    @EnvironmentObject var model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section: Segmentation — sibling sections for future stages attach here.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Segmentation").font(.headline)
                    Spacer()
                    Button("Reset to Defaults") { model.resetParams() }
                        .font(.caption)
                }

                Picker("Strategy", selection: $model.strategy) {
                    ForEach(SegmentationStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.strategy) { _, _ in model.scheduleReprocessSelected() }

                Text(strategyCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                floatSlider("Skin sensitivity", $model.params.skinRBGap, 0...0.6)
                floatSlider("Skin brightness floor", $model.params.skinValMin, 0...1)
                intSlider("Feather edges", $model.params.featherRadius, 0...1)
                intSlider("Drop specks below (px)", $model.params.minComponentPixels, 0...5000)

                Toggle("Fill holes", isOn: $model.params.fillHoles)
                    .font(.caption)
                    .onChange(of: model.params.fillHoles) { _, _ in model.scheduleReprocessSelected() }
            }
        }
    }

    /// Which of the five knobs the selected strategy actually honours.
    private var strategyCaption: String {
        switch model.strategy {
        case .raw:
            return "Raw honours none of the parameters below."
        case .vision:
            return "Vision honours none of the parameters below."
        case .handRemover:
            return "Hand Remover honours skin sensitivity, skin brightness floor and the speck threshold."
        case .visionMinusSkin:
            return "Vision − Skin honours all five parameters."
        }
    }

    private func floatSlider(_ label: String, _ value: Binding<Float>, _ range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
                .onChange(of: value.wrappedValue) { _, _ in model.scheduleReprocessSelected() }
        }
    }

    private func intSlider(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .onChange(of: value.wrappedValue) { _, _ in model.scheduleReprocessSelected() }
        }
    }
}
