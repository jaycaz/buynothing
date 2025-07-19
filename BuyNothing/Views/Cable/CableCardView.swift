import SwiftUI

struct CableCardView: View {
    let cable: USBCable
    let isDetected: Bool
    let confidence: Double?
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero Image Section
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 180)
                
                if let imageData = cable.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(16)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        Text(cable.connectorType1.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Confidence Badge
                if let confidence = confidence {
                    VStack {
                        HStack {
                            Spacer()
                            ConfidenceBadge(confidence: confidence)
                                .padding(.top, 12)
                                .padding(.trailing, 12)
                        }
                        Spacer()
                    }
                }
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimating)
            
            // Cable Information
            VStack(alignment: .leading, spacing: 8) {
                Text(cable.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack {
                    Label(cable.length.rawValue, systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(cable.condition.rawValue, systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let brand = cable.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Speed Information
                Text("Max Speed: \(cable.connectorType1.maxSpeed)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            if isDetected {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                    isAnimating = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        isAnimating = false
                    }
                }
            }
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var badgeColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        Text(String(format: "%.0f%%", confidence * 100))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        CableCardView(
            cable: USBCable(
                connectorType1: .usbC,
                connectorType2: .lightning,
                length: .medium,
                condition: .likeNew,
                brand: "Apple"
            ),
            isDetected: true,
            confidence: 0.95
        )
        
        CableCardView(
            cable: USBCable(
                connectorType1: .microUSB,
                length: .short,
                condition: .good
            ),
            isDetected: false,
            confidence: nil
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}