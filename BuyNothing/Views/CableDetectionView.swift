import SwiftUI

struct CableDetectionView: View {
    @StateObject private var viewModel = CableDetectionViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera Detection Tab
            NavigationView {
                CameraDetectionTab(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "viewfinder")
                Text("Detect")
            }
            .tag(0)
            
            // Cable Collection Tab
            NavigationView {
                CableCollectionTab(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "rectangle.grid.2x2")
                Text("Collection")
            }
            .tag(1)
            
            // Hero View Tab
            NavigationView {
                HeroViewTab(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "star.fill")
                Text("Featured")
            }
            .tag(2)
        }
        .accentColor(.blue)
    }
}

struct CameraDetectionTab: View {
    @ObservedObject var viewModel: CableDetectionViewModel
    
    var body: some View {
        ZStack {
            CameraPreviewContainerView { detection in
                viewModel.addDetection(detection)
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("Cable Detection")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

struct CableCollectionTab: View {
    @ObservedObject var viewModel: CableDetectionViewModel
    
    var body: some View {
        Group {
            if viewModel.cables.isEmpty {
                EmptyStateView(
                    icon: "cable.connector",
                    title: "No Cables Yet",
                    message: "Use the camera to detect and add USB cables to your collection",
                    actionTitle: "Start Detecting",
                    action: {
                        // Switch to camera tab
                    }
                )
            } else {
                CableGridView(
                    cables: viewModel.cables,
                    detectionResults: viewModel.detectionResults,
                    onRefresh: {
                        viewModel.refreshCollection()
                    }
                )
            }
        }
        .navigationTitle("My Cables")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.clearAll) {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.cables.isEmpty)
            }
        }
    }
}

struct HeroViewTab: View {
    @ObservedObject var viewModel: CableDetectionViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if let featuredDetection = viewModel.featuredDetection {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Featured Detection")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                // Navigate to collection
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        CableHeroView(detectionResult: featuredDetection)
                            .padding(.horizontal, 20)
                    }
                } else {
                    EmptyStateView(
                        icon: "star",
                        title: "No Featured Cables",
                        message: "Detect cables with high confidence to see them featured here",
                        actionTitle: "Start Detecting",
                        action: {
                            // Switch to camera tab
                        }
                    )
                    .padding(.top, 100)
                }
                
                // Recent Detections
                if !viewModel.recentDetections.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Detections")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.recentDetections) { detection in
                                    CableCardView(
                                        cable: detection.cable,
                                        isDetected: true,
                                        confidence: detection.confidence
                                    )
                                    .frame(width: 280)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle("Featured")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.refreshCollection()
        }
    }
}

class CableDetectionViewModel: ObservableObject {
    @Published var cables: [USBCable] = []
    @Published var detectionResults: [CableDetectionResult] = []
    @Published var isLoading = false
    
    var featuredDetection: CableDetectionResult? {
        detectionResults
            .filter { $0.confidence >= 0.85 }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }
    
    var recentDetections: [CableDetectionResult] {
        Array(detectionResults
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5))
    }
    
    init() {
        loadSampleData()
    }
    
    func addDetection(_ detection: CableDetectionResult) {
        // Add to detections
        detectionResults.append(detection)
        
        // Add cable if not already in collection
        if !cables.contains(where: { $0.id == detection.cable.id }) {
            cables.append(detection.cable)
        }
        
        // Keep only recent detections (last 20)
        if detectionResults.count > 20 {
            detectionResults = Array(detectionResults.suffix(20))
        }
        
        // Trigger haptic feedback for high confidence detections
        if detection.confidence >= 0.8 {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
    func refreshCollection() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
        }
    }
    
    func clearAll() {
        cables.removeAll()
        detectionResults.removeAll()
    }
    
    private func loadSampleData() {
        let sampleCables = [
            USBCable(
                connectorType1: .usbC,
                connectorType2: .lightning,
                length: .medium,
                condition: .likeNew,
                brand: "Apple"
            ),
            USBCable(
                connectorType1: .microUSB,
                length: .short,
                condition: .good
            ),
            USBCable(
                connectorType1: .usbA,
                connectorType2: .usbC,
                length: .long,
                condition: .likeNew,
                brand: "Anker"
            )
        ]
        
        cables = sampleCables
        
        detectionResults = [
            CableDetectionResult(
                cable: sampleCables[0],
                confidence: 0.95,
                boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2)
            ),
            CableDetectionResult(
                cable: sampleCables[2],
                confidence: 0.88,
                boundingBox: CGRect(x: 0.4, y: 0.5, width: 0.25, height: 0.15)
            )
        ]
    }
}

#Preview {
    CableDetectionView()
}