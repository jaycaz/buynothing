//
//  SnapshotCollageView.swift
//  BuyNothing
//
//  DEBUG-only screen for testing the one-shot personalized collage flow:
//  capture → segment → align → identify → search → pack → show.
//
//  ⚠️ Requires API keys in Secrets.swift.
//

import SwiftUI

// MARK: - PlaceholderCameraPicker

struct PlaceholderCameraPicker: View {
    @State private var capturedPhoto: UIImage?
    
    var body: some View {
        ZStack {
            HStack {
                Button {
                    capturedPhoto = UIImage(cgImage: generatePlaceholderImage())
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    capturedPhoto = UIImage(cgImage: generatePlaceholderImage())
                } label: {
                    Label("Library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func generatePlaceholderImage() -> CGImage {
        guard let context = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8,
                                     bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CGImage()
        }
        
        context.fill(CGRect(x: 0, y: 0, width: 512, height: 512),
                   with: .patternColor(patternColor: UIColor.systemBlue),
                   option: .intoFill)
        
        return context.makeImage()!
    }
}

// MARK: - PhotoLibraryPicker

struct PhotoLibraryPicker: View {
    
    var body: some View {
        ZStack {
            Text("Select a photo from your library")
                .font(.headline)
                .foregroundColor(.primary)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.7))
                .frame(width: 200, height: 200)
        }
    }
}

// MARK: - SnapshotCollageView

struct SnapshotCollageView: View {
    @StateObject private var model = SnapshotCollageModel()
    @State private var showingAlert = false
    
    var body: some View {
        Group {
            if model.showCamera {
                cameraView
            } else if model.showLibrary {
                libraryView
            } else if model.showResult {
                resultView
            } else {
                processingView
            }
        }
        .alert("Snapshot Collage", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            model.pipelineError.map { "Error: \($0)" }
        }
    }
    
    private var cameraView: some View {
        PlaceholderCameraPicker
            .frame(maxWidth: 500)
        Text("Tap Capture or Library to take a photo.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 16)
    }
    
    private var libraryView: some View {
        PhotoLibraryPicker
            .frame(maxWidth: 500)
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(model.isProcessing ? 1.1 : 1.0)
                .animation(.spring(), value: model.isProcessing)
            
            if let error = model.pipelineError {
                Text(error)
                    .font(.headline)
                    .foregroundColor(.red)
            } else {
                Text(model.pipelineStage ?? "Processing...")
                    .font(.headline)
            }
            
            if !model.messages.isEmpty {
                ForEach(model.messages, id: \.self) { msg in
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            
            if model.showCamera {
                Button("Tap Capture or Library") {}
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var resultView: some View {
        VStack(spacing: 24) {
            if let collage = model.collageImage {
                Text("Your Personalized Collage")
                    .font(.title2.bold())
                    .padding(.bottom, 8)
                
                Image(uiImage: collage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .background(Color(.secondarySystemBackground))
            }
            
            if let userItem = model.userAlignedItem,
               let idx = model.collageItems.firstIndex(where: { item in
                   return item == userItem
               }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your item was included in the collage!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("It's sitting among \(model.collageItems.count) similar items we found online.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Try Another Item") {
                model.reset()
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .padding()
    }
}

// MARK: - CollageRendererPreview

struct CollageRendererPreview: View {
    let collage: UIImage
    
    var body: some View {
        Image(uiImage: collage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .background(Color(.secondarySystemBackground))
    }
}
