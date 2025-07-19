import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @Binding var session: AVCaptureSession?
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = UIColor.black
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let session = session {
            uiView.setSession(session)
        }
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewLayer()
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            layer.addSublayer(previewLayer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func setSession(_ session: AVCaptureSession) {
        previewLayer?.session = session
    }
}

struct CameraPreviewContainerView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    let onDetection: (CableDetectionResult) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: $cameraManager.session)
                        .onAppear {
                            cameraManager.startSession()
                        }
                        .onDisappear {
                            cameraManager.stopSession()
                        }
                    
                    DetectionOverlayView(
                        detectionResults: cameraManager.detectionResults,
                        previewSize: geometry.size
                    )
                } else {
                    CameraPermissionView {
                        cameraManager.requestPermission { granted in
                            if !granted {
                                showingPermissionAlert = true
                            }
                        }
                    }
                }
                
                // Camera Controls
                VStack {
                    Spacer()
                    
                    CameraControlsView(
                        isScanning: cameraManager.isScanning,
                        onToggleScanning: {
                            cameraManager.toggleScanning()
                        },
                        onCapture: {
                            cameraManager.capturePhoto()
                        }
                    )
                    .padding(.bottom, 50)
                }
            }
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow camera access in Settings to detect USB cables.")
        }
        .onReceive(cameraManager.$latestDetection) { detection in
            if let detection = detection {
                onDetection(detection)
            }
        }
    }
}

struct CameraPermissionView: View {
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Allow camera access to detect USB cables in real-time")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Enable Camera") {
                onRequestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct CameraControlsView: View {
    let isScanning: Bool
    let onToggleScanning: () -> Void
    let onCapture: () -> Void
    
    var body: some View {
        HStack(spacing: 40) {
            Button(action: onToggleScanning) {
                VStack(spacing: 8) {
                    Image(systemName: isScanning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isScanning ? .red : .green)
                    
                    Text(isScanning ? "Stop" : "Scan")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            Button(action: onCapture) {
                VStack(spacing: 8) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                        )
                    
                    Text("Capture")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            Button(action: {}) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    Text("Gallery")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var session: AVCaptureSession?
    @Published var isAuthorized = false
    @Published var isScanning = false
    @Published var detectionResults: [CableDetectionResult] = []
    @Published var latestDetection: CableDetectionResult?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            requestPermission { _ in }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.setupSession()
                }
                completion(granted)
            }
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            let session = AVCaptureSession()
            session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  session.canAddInput(videoInput) else {
                return
            }
            
            session.addInput(videoInput)
            session.commitConfiguration()
            
            DispatchQueue.main.async {
                self?.session = session
            }
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.session?.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session?.stopRunning()
        }
    }
    
    func toggleScanning() {
        isScanning.toggle()
        
        if isScanning {
            startDetectionSimulation()
        }
    }
    
    func capturePhoto() {
        simulateDetection()
    }
    
    private func startDetectionSimulation() {
        guard isScanning else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1...3)) {
            if self.isScanning {
                self.simulateDetection()
                self.startDetectionSimulation()
            }
        }
    }
    
    private func simulateDetection() {
        let sampleCables = [
            USBCable(connectorType1: .usbC, connectorType2: .lightning, brand: "Apple"),
            USBCable(connectorType1: .microUSB, length: .short),
            USBCable(connectorType1: .usbA, connectorType2: .usbC, brand: "Anker"),
            USBCable(connectorType1: .thunderbolt, brand: "Apple")
        ]
        
        let randomCable = sampleCables.randomElement()!
        let confidence = Double.random(in: 0.6...0.98)
        let boundingBox = CGRect(
            x: Double.random(in: 0.1...0.7),
            y: Double.random(in: 0.2...0.6),
            width: Double.random(in: 0.2...0.4),
            height: Double.random(in: 0.1...0.3)
        )
        
        let detection = CableDetectionResult(
            cable: randomCable,
            confidence: confidence,
            boundingBox: boundingBox
        )
        
        detectionResults.append(detection)
        latestDetection = detection
        
        if detectionResults.count > 5 {
            detectionResults.removeFirst()
        }
    }
}

#Preview {
    CameraPreviewContainerView { detection in
        print("Detected: \(detection.cable.displayName) with \(detection.confidencePercentage) confidence")
    }
}