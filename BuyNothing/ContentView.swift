import SwiftUI

struct ContentView: View {
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
                
                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}

#Preview {
    ContentView()
}