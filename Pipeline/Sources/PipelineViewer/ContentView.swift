import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: ReviewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Choose Folder…") { chooseFolder() }
            }
            ToolbarItem {
                Button {
                    Task { await model.reprocessAll() }
                } label: {
                    if model.isBatchProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Reprocess All \(model.items.count)", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.items.isEmpty || model.isBatchProcessing)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        Group {
            if model.items.isEmpty {
                emptyState
            } else {
                List(model.items, selection: Binding(
                    get: { model.selectedID },
                    set: { if let id = $0 { model.select(id) } }
                )) { item in
                    row(for: item).tag(item.id)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    private func row(for item: ReviewItem) -> some View {
        HStack(spacing: 8) {
            thumbnail(item.inputImage, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).font(.caption).lineLimit(1)
                if let error = item.error {
                    Text(error).font(.caption2).foregroundStyle(.red).lineLimit(1)
                } else if let r = item.areaRatio {
                    Text(String(format: "%.0f%% kept", r * 100))
                        .font(.caption2)
                        .foregroundStyle(item.flagged ? .orange : .secondary)
                } else {
                    Text("processing…").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if item.flagged {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack").font(.largeTitle).foregroundStyle(.secondary)
            Text("Choose a folder of test photos to review").foregroundStyle(.secondary)
            Button("Choose Folder…") { chooseFolder() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let item = model.selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.url.lastPathComponent).font(.title3.bold())
                        Text(model.strategy.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        labeledPane("Input", image: item.inputImage, checkerboard: false, size: item.inputSize)
                        labeledPane("Cutout", image: item.cutoutImage, checkerboard: true, size: item.outputSize)
                    }

                    if let error = item.error {
                        Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                    } else {
                        HStack(spacing: 16) {
                            if let ms = item.ms { Text(String(format: "%.0f ms", ms)) }
                            if let r = item.areaRatio { Text(String(format: "kept %.0f%% of frame area", r * 100)) }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Divider()
                    ParamsPanel()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            emptyState
        }
    }

    private func labeledPane(_ label: String, image: CGImage?, checkerboard: Bool, size: CGSize) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            imagePane(image, checkerboard: checkerboard)
            if size != .zero {
                Text("\(Int(size.width))×\(Int(size.height))").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func imagePane(_ cg: CGImage?, checkerboard: Bool) -> some View {
        ZStack {
            if checkerboard { CheckerboardView() }
            if let cg {
                Image(decorative: cg, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .frame(width: 380, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
    }

    private func thumbnail(_ cg: CGImage?, size: CGFloat) -> some View {
        Group {
            if let cg {
                Image(decorative: cg, scale: 1).resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            model.load(urls: panel.urls)
        }
    }
}
