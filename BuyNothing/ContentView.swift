import SwiftUI

struct ContentView: View {
    @State private var showingDetectionView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("BuyNothing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("The most beautiful sharing experience")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Starting with USB Cable Detection")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                
                Button("Start Cable Detection") {
                    showingDetectionView = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
        }
        .fullScreenCover(isPresented: $showingDetectionView) {
            CableDetectionView()
        }
    }
}

#Preview {
    ContentView()
}