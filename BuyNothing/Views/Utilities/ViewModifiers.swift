import SwiftUI

// MARK: - Detection Animation Modifiers

struct DetectionAppearModifier: ViewModifier {
    let isDetected: Bool
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared ? 1.0 : 0.8)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasAppeared)
            .onAppear {
                if isDetected {
                    withAnimation {
                        hasAppeared = true
                    }
                } else {
                    hasAppeared = true
                }
            }
    }
}

struct ConfidencePulseModifier: ViewModifier {
    let confidence: Double
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(.easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                if confidence >= 0.8 {
                    isPulsing = true
                }
            }
    }
    
    private var pulseSpeed: Double {
        if confidence >= 0.9 { return 0.5 }
        else if confidence >= 0.8 { return 0.8 }
        else { return 1.0 }
    }
}

// MARK: - Haptic Feedback Modifiers

struct HapticFeedbackModifier: ViewModifier {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    let impactFeedback = UIImpactFeedbackGenerator(style: style)
                    impactFeedback.impactOccurred()
                }
            }
    }
}

struct DetectionHapticModifier: ViewModifier {
    let confidence: Double
    let isNewDetection: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isNewDetection) { _, newValue in
                if newValue {
                    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
                    if confidence >= 0.8 {
                        feedbackStyle = .heavy
                    } else if confidence >= 0.6 {
                        feedbackStyle = .medium
                    } else {
                        feedbackStyle = .light
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: feedbackStyle)
                    impactFeedback.impactOccurred()
                }
            }
    }
}

// MARK: - Accessibility Modifiers

struct CableAccessibilityModifier: ViewModifier {
    let cable: USBCable
    let confidence: Double?
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
    }
    
    private var accessibilityLabel: String {
        var label = "USB Cable: \(cable.displayName)"
        if let confidence = confidence {
            label += ", detected with \(Int(confidence * 100)) percent confidence"
        }
        return label
    }
    
    private var accessibilityHint: String {
        "Double tap for cable details"
    }
}

struct DetectionAccessibilityModifier: ViewModifier {
    let detectionResult: CableDetectionResult
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Detected \(detectionResult.cable.displayName) with \(detectionResult.confidencePercentage) confidence")
            .accessibilityHint("Cable detection result")
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Dynamic Type Support

struct ScaledFontModifier: ViewModifier {
    let name: String
    let size: CGFloat
    let weight: Font.Weight
    
    func body(content: Content) -> some View {
        content
            .font(.custom(name, size: size, relativeTo: .body))
            .fontWeight(weight)
    }
}

// MARK: - Dark Mode Adaptive Colors

struct AdaptiveColorModifier: ViewModifier {
    let lightColor: Color
    let darkColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(adaptiveColor)
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveColor: Color {
        colorScheme == .dark ? darkColor : lightColor
    }
}

// MARK: - View Extension for Easy Usage

extension View {
    func detectionAppear(isDetected: Bool) -> some View {
        modifier(DetectionAppearModifier(isDetected: isDetected))
    }
    
    func confidencePulse(_ confidence: Double) -> some View {
        modifier(ConfidencePulseModifier(confidence: confidence))
    }
    
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle, trigger: Bool) -> some View {
        modifier(HapticFeedbackModifier(style: style, trigger: trigger))
    }
    
    func detectionHaptic(confidence: Double, isNewDetection: Bool) -> some View {
        modifier(DetectionHapticModifier(confidence: confidence, isNewDetection: isNewDetection))
    }
    
    func cableAccessibility(_ cable: USBCable, confidence: Double? = nil) -> some View {
        modifier(CableAccessibilityModifier(cable: cable, confidence: confidence))
    }
    
    func detectionAccessibility(_ detectionResult: CableDetectionResult) -> some View {
        modifier(DetectionAccessibilityModifier(detectionResult: detectionResult))
    }
    
    func scaledFont(name: String = "SF Pro Display", size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFontModifier(name: name, size: size, weight: weight))
    }
    
    func adaptiveColor(light: Color, dark: Color) -> some View {
        modifier(AdaptiveColorModifier(lightColor: light, darkColor: dark))
    }
}

// MARK: - Custom Button Styles

struct DetectionButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.green : Color.blue)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Shapes

struct CableBorderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cornerRadius: CGFloat = 16
        let connectorWidth: CGFloat = 8
        let connectorHeight: CGFloat = 20
        
        // Main rounded rectangle
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        // Add connector shapes on the sides
        let leftConnector = CGRect(
            x: rect.minX - connectorWidth/2,
            y: rect.midY - connectorHeight/2,
            width: connectorWidth,
            height: connectorHeight
        )
        path.addRoundedRect(in: leftConnector, cornerSize: CGSize(width: 4, height: 4))
        
        let rightConnector = CGRect(
            x: rect.maxX - connectorWidth/2,
            y: rect.midY - connectorHeight/2,
            width: connectorWidth,
            height: connectorHeight
        )
        path.addRoundedRect(in: rightConnector, cornerSize: CGSize(width: 4, height: 4))
        
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Detection Animation")
            .detectionAppear(isDetected: true)
        
        Circle()
            .fill(Color.green)
            .frame(width: 50, height: 50)
            .confidencePulse(0.95)
        
        Button("Haptic Button") {}
            .buttonStyle(DetectionButtonStyle(isActive: true))
            .hapticFeedback(style: .medium, trigger: true)
        
        Rectangle()
            .fill(Color.blue)
            .frame(width: 200, height: 100)
            .clipShape(CableBorderShape())
    }
    .padding()
}