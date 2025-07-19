import Foundation
import AVFoundation

actor MockCameraService: CameraServiceProtocol {
    private var hasPermission = false
    private var isRunning = false
    private var shouldFailPermission = false
    private var shouldFailCapture = false
    private var currentPosition: CameraPosition = .back
    private var captureDelay: TimeInterval = 0.2
    
    // Mock image data for testing
    private let mockImageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
    
    init() {}
    
    func requestCameraPermission() async -> Bool {
        // Simulate permission request delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if shouldFailPermission {
            hasPermission = false
            return false
        }
        
        hasPermission = true
        return true
    }
    
    func startCamera() async throws {
        guard hasPermission else {
            throw CameraError.permissionDenied
        }
        
        // Simulate camera startup delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        isRunning = true
    }
    
    func stopCamera() async {
        isRunning = false
    }
    
    func capturePhoto() async throws -> Data {
        guard hasPermission else {
            throw CameraError.permissionDenied
        }
        
        guard isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        if shouldFailCapture {
            throw CameraError.captureSessionError(
                NSError(domain: "MockCameraError", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "Mock capture failure"
                ])
            )
        }
        
        // Simulate capture processing time
        try await Task.sleep(nanoseconds: UInt64(captureDelay * 1_000_000_000))
        
        return mockImageData
    }
    
    func isSessionRunning() async -> Bool {
        return isRunning
    }
    
    func switchCamera() async throws {
        guard hasPermission else {
            throw CameraError.permissionDenied
        }
        
        guard isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        // Simulate camera switch delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        currentPosition = currentPosition == .back ? .front : .back
    }
    
    // MARK: - Test Configuration Methods
    
    func setShouldFailPermission(_ shouldFail: Bool) {
        self.shouldFailPermission = shouldFail
    }
    
    func setShouldFailCapture(_ shouldFail: Bool) {
        self.shouldFailCapture = shouldFail
    }
    
    func setCaptureDelay(_ delay: TimeInterval) {
        self.captureDelay = delay
    }
    
    func getCurrentPosition() async -> CameraPosition {
        return currentPosition
    }
    
    func resetToDefaults() {
        hasPermission = false
        isRunning = false
        shouldFailPermission = false
        shouldFailCapture = false
        currentPosition = .back
        captureDelay = 0.2
    }
}