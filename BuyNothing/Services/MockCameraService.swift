import Foundation
import UIKit
import AVFoundation

@MainActor
final class MockCameraService: CameraServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var isSessionRunning = false
    private(set) var currentCameraPosition: CameraPosition = .back
    private(set) var permissionStatus: CameraPermissionStatus = .notDetermined
    
    // MARK: - Mock Configuration
    
    var shouldFailPermissionRequest = false
    var shouldFailSessionStart = false
    var shouldFailPhotoCapture = false
    var shouldFailCameraSwitch = false
    var permissionRequestDelay: TimeInterval = 0.1
    var sessionStartDelay: TimeInterval = 0.2
    var photoCaptureDelay: TimeInterval = 0.5
    var cameraSwitchDelay: TimeInterval = 0.3
    
    // MARK: - Test Utilities
    
    var permissionRequestCount = 0
    var sessionStartCount = 0
    var sessionStopCount = 0
    var photoCaptureCount = 0
    var cameraSwitchCount = 0
    
    // MARK: - CameraServiceProtocol Implementation
    
    func requestCameraPermission() async -> CameraPermissionStatus {
        permissionRequestCount += 1
        
        if permissionRequestDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(permissionRequestDelay * 1_000_000_000))
        }
        
        if shouldFailPermissionRequest {
            permissionStatus = .denied
            return .denied
        }
        
        permissionStatus = .granted
        return .granted
    }
    
    func startSession() async throws {
        sessionStartCount += 1
        
        if permissionStatus != .granted {
            let status = await requestCameraPermission()
            guard status == .granted else {
                throw CameraError.permissionDenied
            }
        }
        
        if shouldFailSessionStart {
            throw CameraError.sessionConfigurationFailed
        }
        
        if sessionStartDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(sessionStartDelay * 1_000_000_000))
        }
        
        isSessionRunning = true
    }
    
    func stopSession() async {
        sessionStopCount += 1
        isSessionRunning = false
    }
    
    func capturePhoto() async throws -> CapturedPhoto {
        photoCaptureCount += 1
        
        guard isSessionRunning else {
            throw CameraError.captureSessionNotRunning
        }
        
        if shouldFailPhotoCapture {
            throw CameraError.photoCaptureFailed
        }
        
        if photoCaptureDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(photoCaptureDelay * 1_000_000_000))
        }
        
        return createMockPhoto()
    }
    
    func switchCamera(to position: CameraPosition) async throws {
        cameraSwitchCount += 1
        
        if shouldFailCameraSwitch {
            throw CameraError.deviceSwitchFailed
        }
        
        if cameraSwitchDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(cameraSwitchDelay * 1_000_000_000))
        }
        
        currentCameraPosition = position
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        // Return nil for mock - UI tests should handle preview differently
        return nil
    }
    
    // MARK: - Test Utilities
    
    func reset() {
        isSessionRunning = false
        currentCameraPosition = .back
        permissionStatus = .notDetermined
        
        shouldFailPermissionRequest = false
        shouldFailSessionStart = false
        shouldFailPhotoCapture = false
        shouldFailCameraSwitch = false
        
        permissionRequestCount = 0
        sessionStartCount = 0
        sessionStopCount = 0
        photoCaptureCount = 0
        cameraSwitchCount = 0
    }
    
    func setPermissionStatus(_ status: CameraPermissionStatus) {
        permissionStatus = status
    }
    
    // MARK: - Private Methods
    
    private func createMockPhoto() -> CapturedPhoto {
        // Create a simple 1x1 red pixel image
        let image = UIImage.pixelImage(color: .red)
        let imageData = image.pngData() ?? Data()
        
        return CapturedPhoto(
            imageData: imageData,
            metadata: [:],
            captureTime: Date(),
            orientation: .up
        )
    }
}

// MARK: - UIImage Extension for Mock

private extension UIImage {
    static func pixelImage(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}