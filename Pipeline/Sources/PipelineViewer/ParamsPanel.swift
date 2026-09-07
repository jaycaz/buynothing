import SwiftUI
import CollagePipeline

/// Live-tunable knobs for one pipeline step. Today that's only Hand & Distraction Removal;
/// future steps (delighting, relighting, shadow removal, perspective correction) get their
/// own section here as they're added to CollagePipeline.
struct ParamsPanel: View {
    @EnvironmentObject var model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hand & Distraction Removal").font(.headline)
                Spacer()
                Button("Reset to Defaults") { model.resetParams() }
                    .font(.caption)
            }

            floatSlider("Skin R−B gap", $model.params.skinRBGap, 0...0.6)
            floatSlider("Skin value min", $model.params.skinValMin, 0...1)
            floatSlider("Skin saturation max", $model.params.skinSatMax, 0...1)
            floatSlider("Blue saturation min", $model.params.blueSatMin, 0...1)
            floatSlider("Blue B min", $model.params.blueBMin, 0...1)
            floatSlider("Red saturation min", $model.params.redSatMin, 0...1)
            floatSlider("Red R−B gap", $model.params.redRGBap, 0...0.6)
            intSlider("Texture radius (px)", $model.params.textureRadius, 1...80)
            floatSlider("Texture threshold", $model.params.textureThreshold, 0...50)
            intSlider("Closing iterations", $model.params.closingIterations, 0...10)
            intSlider("Opening iterations", $model.params.openingIterations, 0...10)
            intSlider("Min component (px)", $model.params.minComponentPixels, 0...5000)
            intSlider("Rescue min component (px)", $model.params.rescueMinComponentPixels, 0...2000)
            floatSlider("Min fill ratio", $model.params.minFillRatio, 0...1)
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
