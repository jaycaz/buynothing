//
//  SnapshotCollageView.swift
//  BuyNothing
//
//  DEBUG-only screen for testing the one-shot personalized collage flow:
//  capture → segment → align → identify → search → pack → show.
//
//  ⚠️ Requires API keys in Secrets.swift and iOS 17+ for segmentation.
//

import SwiftUI
import UIKit

struct SnapshotCollageView: View {
    @StateObject private var model = SnapshotCollageModel()
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var alertMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.showResult {
                    resultView
                } else if model.isProcessing {
                    processingView
                } else {
                    captureView
                }
            }
            .navigationTitle("Snapshot Collage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraCaptureView(onPhoto: { photo in
                    showingCamera = false
                    Task { await model.capturePhoto(photo) }
                })
            }
            .sheet(isPresented: $showingLibrary) {
                PhotoPicker(onPhoto: { photo in
                    showingLibrary = false
                    Task { await model.selectLibraryPhoto(photo) }
                })
            }
            .task {
                if model.isAlerting {
                    alertMessage = model.pipelineError
                }
            }
            .alert("Snapshot Collage", isPresented: Binding<Bool>(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = alertMessage {
                    Text("Error: \(error)")
                }
            }
        }
    }

    private var captureView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("Snap a photo of something you own")
                    .font(.title2.bold())
                Text("We'll cut it out, find similar items, and make a collage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingLibrary = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)

            if let stage = model.pipelineStage {
                Text(stage)
                    .font(.headline)
            }

            if !model.messages.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.messages, id: \.self) { msg in
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 120)
            }

            Spacer()
        }
        .padding()
    }

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let collage = model.collageImage {
                    Text("Your Collage")
                        .font(.title2.bold())

                    Image(uiImage: collage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .background(Color(.secondarySystemBackground))
                }

                if let userItem = model.userAlignedItem {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Item")
                            .font(.headline)
                        Image(uiImage: UIImage(cgImage: userItem))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .background(Color(.tertiarySystemBackground))
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    if model.isStreaming {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Found \(model.sourcedCount) similar items — more streaming in…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Found \(model.sourcedCount) similar items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Button {
                    model.reset()
                } label: {
                    Label("Try Another Item", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Camera Capture

struct CameraCaptureView: View {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CameraCapturePicker { photo in
            onPhoto(photo)
        }
    }
}

struct CameraCapturePicker: UIViewControllerRepresentable {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapturePicker

        init(parent: CameraCapturePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoPicker: View {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PhotoLibraryPicker { photo in
            onPhoto(photo)
        }
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoLibraryPicker

        init(parent: PhotoLibraryPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
