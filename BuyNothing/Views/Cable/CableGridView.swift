import SwiftUI

struct CableGridView: View {
    let cables: [USBCable]
    let detectionResults: [CableDetectionResult]
    @State private var selectedCable: USBCable?
    @State private var isRefreshing = false
    let onRefresh: () -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(cables) { cable in
                    let detectionResult = detectionResults.first { $0.cable.id == cable.id }
                    
                    CableGridItemView(
                        cable: cable,
                        detectionResult: detectionResult
                    )
                    .onTapGesture {
                        selectedCable = cable
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            await performRefresh()
        }
        .sheet(item: $selectedCable) { cable in
            if let detectionResult = detectionResults.first(where: { $0.cable.id == cable.id }) {
                CableDetailSheet(detectionResult: detectionResult)
            } else {
                CableDetailSheet(cable: cable)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cables.count)
    }
    
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        onRefresh()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

struct CableGridItemView: View {
    let cable: USBCable
    let detectionResult: CableDetectionResult?
    @State private var isAnimating = false
    
    var isDetected: Bool {
        detectionResult != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundGradient)
                    .frame(height: 120)
                
                if let imageData = cable.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: cableIcon)
                        .font(.system(size: 32))
                        .foregroundColor(iconColor)
                }
                
                // Detection Indicator
                if isDetected {
                    VStack {
                        HStack {
                            Spacer()
                            DetectionIndicator()
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Confidence Badge
                if let confidence = detectionResult?.confidence {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CompactConfidenceBadge(confidence: confidence)
                                .padding(8)
                        }
                    }
                }
            }
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isAnimating)
            
            // Cable Info
            VStack(alignment: .leading, spacing: 4) {
                Text(cable.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(cable.length.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let brand = cable.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        .onAppear {
            if isDetected {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double.random(in: 0...0.3))) {
                    isAnimating = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isAnimating = false
                    }
                }
            }
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if isDetected {
            return LinearGradient(
                colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var cableIcon: String {
        switch cable.connectorType1 {
        case .usbC, .thunderbolt:
            return "cable.connector"
        case .lightning:
            return "bolt"
        case .usbA, .usb30:
            return "rectangle.connected.to.line.below"
        case .microUSB, .miniUSB:
            return "cable.connector.horizontal"
        }
    }
    
    private var iconColor: Color {
        isDetected ? .green : .blue
    }
    
    private var shadowColor: Color {
        isDetected ? .green.opacity(0.2) : .black.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        isDetected ? 8 : 4
    }
    
    private var shadowOffset: CGFloat {
        isDetected ? 4 : 2
    }
}

struct DetectionIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct CompactConfidenceBadge: View {
    let confidence: Double
    
    var badgeColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        Text(String(format: "%.0f%%", confidence * 100))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(6)
    }
}

struct CableDetailSheet: View {
    let cable: USBCable
    let detectionResult: CableDetectionResult?
    @Environment(\.dismiss) private var dismiss
    
    init(cable: USBCable) {
        self.cable = cable
        self.detectionResult = nil
    }
    
    init(detectionResult: CableDetectionResult) {
        self.cable = detectionResult.cable
        self.detectionResult = detectionResult
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let detectionResult = detectionResult {
                        CableHeroView(detectionResult: detectionResult)
                    } else {
                        CableCardView(cable: cable, isDetected: false, confidence: nil)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Cable Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleCables = [
        USBCable(connectorType1: .usbC, connectorType2: .lightning, length: .medium, brand: "Apple"),
        USBCable(connectorType1: .microUSB, length: .short, condition: .good),
        USBCable(connectorType1: .usbA, connectorType2: .usbC, length: .long, brand: "Anker"),
        USBCable(connectorType1: .thunderbolt, length: .medium, condition: .likeNew, brand: "Apple")
    ]
    
    let detectionResults = [
        CableDetectionResult(
            cable: sampleCables[0],
            confidence: 0.95,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        ),
        CableDetectionResult(
            cable: sampleCables[2],
            confidence: 0.78,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
    ]
    
    CableGridView(
        cables: sampleCables,
        detectionResults: detectionResults,
        onRefresh: {}
    )
    .background(Color(.systemGroupedBackground))
}