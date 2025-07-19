import SwiftUI

struct CableHeroView: View {
    let detectionResult: CableDetectionResult
    @State private var isAnimating = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Hero Image Section
            ZStack {
                if let imageData = detectionResult.imageData ?? detectionResult.cable.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 300)
                        .overlay {
                            VStack(spacing: 16) {
                                Image(systemName: "cable.connector")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                
                                Text("Detected Cable")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .shadow(radius: 1)
                            }
                        }
                }
                
                // Overlay Gradients
                VStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    
                    Spacer()
                    
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                
                // Top Bar
                VStack {
                    HStack {
                        ConfidenceIndicator(confidence: detectionResult.confidence)
                        
                        Spacer()
                        
                        Button(action: { showDetails.toggle() }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                // Bottom Info
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detectionResult.cable.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            
                            Text("Detected \(detectionResult.timestamp, formatter: timeFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 1)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .cornerRadius(24, corners: [.topLeft, .topRight])
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
            
            // Details Section
            if showDetails {
                CableDetailsSection(cable: detectionResult.cable, confidence: detectionResult.confidence)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: showDetails)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                    isAnimating = false
                }
            }
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var confidenceText: String {
        if confidence >= 0.8 { return "High Confidence" }
        else if confidence >= 0.6 { return "Medium Confidence" }
        else { return "Low Confidence" }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(confidenceText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(String(format: "%.0f%%", confidence * 100))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }
}

struct CableDetailsSection: View {
    let cable: USBCable
    let confidence: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "ruler",
                    title: "Length",
                    value: cable.length.rawValue
                )
                
                DetailRow(
                    icon: "checkmark.seal",
                    title: "Condition",
                    value: cable.condition.rawValue
                )
                
                DetailRow(
                    icon: "speedometer",
                    title: "Max Speed",
                    value: cable.connectorType1.maxSpeed
                )
                
                if let brand = cable.brand {
                    DetailRow(
                        icon: "tag",
                        title: "Brand",
                        value: brand
                    )
                }
                
                DetailRow(
                    icon: "brain.head.profile",
                    title: "Detection Confidence",
                    value: String(format: "%.1f%%", confidence * 100)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let sampleCable = USBCable(
        connectorType1: .usbC,
        connectorType2: .lightning,
        length: .medium,
        condition: .likeNew,
        brand: "Apple"
    )
    
    let detectionResult = CableDetectionResult(
        cable: sampleCable,
        confidence: 0.92,
        boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    
    CableHeroView(detectionResult: detectionResult)
        .padding()
        .background(Color(.systemGroupedBackground))
}