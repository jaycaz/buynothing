import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct SkeletonView: View {
    @State private var isAnimating = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: isAnimating ? 200 : -200)
            .clipped()
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct CableCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(cornerRadius: 16)
                .frame(height: 180)
            
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView()
                    .frame(height: 20)
                
                HStack {
                    SkeletonView()
                        .frame(width: 80, height: 16)
                    
                    Spacer()
                    
                    SkeletonView()
                        .frame(width: 60, height: 16)
                }
                
                SkeletonView()
                    .frame(width: 100, height: 16)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct PulsingView: View {
    @State private var isPulsing = false
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView(message: "Detecting USB cables...")
        
        CableCardSkeleton()
        
        EmptyStateView(
            icon: "cable.connector",
            title: "No Cables Detected",
            message: "Point your camera at a USB cable to start detecting",
            actionTitle: "Start Scanning",
            action: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}