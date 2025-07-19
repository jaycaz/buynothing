import SwiftUI

struct DetectionOverlayView: View {
    let detectionResults: [CableDetectionResult]
    let previewSize: CGSize
    @State private var animatingDetections: Set<UUID> = []
    
    var body: some View {
        ZStack {
            ForEach(detectionResults) { detection in
                DetectionBoundingBox(
                    detection: detection,
                    previewSize: previewSize,
                    isAnimating: animatingDetections.contains(detection.id)
                )
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animatingDetections.insert(detection.id)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            animatingDetections.remove(detection.id)
                        }
                    }
                }
            }
            
            // Detection Stats Overlay
            if !detectionResults.isEmpty {
                VStack {
                    DetectionStatsView(detectionResults: detectionResults)
                        .padding(.top, 60)
                    
                    Spacer()
                }
            }
        }
    }
}

struct DetectionBoundingBox: View {
    let detection: CableDetectionResult
    let previewSize: CGSize
    let isAnimating: Bool
    @State private var pulseAnimation = false
    
    private var boundingBoxRect: CGRect {
        let box = detection.boundingBox
        return CGRect(
            x: box.origin.x * previewSize.width,
            y: box.origin.y * previewSize.height,
            width: box.width * previewSize.width,
            height: box.height * previewSize.height
        )
    }
    
    private var confidenceColor: Color {
        if detection.confidence >= 0.8 { return .green }
        else if detection.confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        ZStack {
            // Main bounding box
            Rectangle()
                .stroke(confidenceColor, lineWidth: 3)
                .frame(width: boundingBoxRect.width, height: boundingBoxRect.height)
                .position(
                    x: boundingBoxRect.midX,
                    y: boundingBoxRect.midY
                )
                .opacity(isAnimating ? 1.0 : 0.0)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Corner indicators
            ForEach(0..<4, id: \.self) { corner in
                CornerIndicator(
                    color: confidenceColor,
                    corner: corner,
                    rect: boundingBoxRect,
                    isAnimating: isAnimating
                )
            }
            
            // Detection label
            VStack {
                HStack {
                    DetectionLabel(detection: detection)
                        .position(
                            x: boundingBoxRect.minX + 8,
                            y: boundingBoxRect.minY - 20
                        )
                    
                    Spacer()
                }
                Spacer()
            }
            .opacity(isAnimating ? 1.0 : 0.0)
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

struct CornerIndicator: View {
    let color: Color
    let corner: Int
    let rect: CGRect
    let isAnimating: Bool
    
    private var cornerOffset: CGPoint {
        let size: CGFloat = 20
        switch corner {
        case 0: // Top-left
            return CGPoint(x: rect.minX - size/2, y: rect.minY - size/2)
        case 1: // Top-right
            return CGPoint(x: rect.maxX - size/2, y: rect.minY - size/2)
        case 2: // Bottom-left
            return CGPoint(x: rect.minX - size/2, y: rect.maxY - size/2)
        case 3: // Bottom-right
            return CGPoint(x: rect.maxX - size/2, y: rect.maxY - size/2)
        default:
            return CGPoint.zero
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 20, height: 20)
            .position(cornerOffset)
            .opacity(isAnimating ? 1.0 : 0.0)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(corner) * 0.1), value: isAnimating)
    }
}

struct DetectionLabel: View {
    let detection: CableDetectionResult
    
    private var backgroundColor: Color {
        if detection.confidence >= 0.8 { return .green }
        else if detection.confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detection.cable.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(detection.confidencePercentage)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.9))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DetectionStatsView: View {
    let detectionResults: [CableDetectionResult]
    
    private var averageConfidence: Double {
        guard !detectionResults.isEmpty else { return 0 }
        return detectionResults.reduce(0) { $0 + $1.confidence } / Double(detectionResults.count)
    }
    
    private var highConfidenceCount: Int {
        detectionResults.filter { $0.isHighConfidence }.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            StatsBubble(
                icon: "viewfinder",
                title: "Detected",
                value: "\(detectionResults.count)"
            )
            
            StatsBubble(
                icon: "checkmark.circle.fill",
                title: "High Confidence",
                value: "\(highConfidenceCount)"
            )
            
            StatsBubble(
                icon: "brain.head.profile",
                title: "Avg Confidence",
                value: String(format: "%.0f%%", averageConfidence * 100)
            )
        }
        .padding(.horizontal, 20)
    }
}

struct StatsBubble: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    let sampleDetections = [
        CableDetectionResult(
            cable: USBCable(connectorType1: .usbC, connectorType2: .lightning, brand: "Apple"),
            confidence: 0.95,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2)
        ),
        CableDetectionResult(
            cable: USBCable(connectorType1: .microUSB, length: .short),
            confidence: 0.78,
            boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.25, height: 0.15)
        )
    ]
    
    DetectionOverlayView(
        detectionResults: sampleDetections,
        previewSize: CGSize(width: 375, height: 667)
    )
    .background(Color.black)
}