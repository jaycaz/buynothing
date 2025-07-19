import Foundation
import UIKit
import AVFoundation

enum CameraError: Error, LocalizedError {
    case permissionDenied
    case permissionRestricted
    case cameraUnavailable
    case sessionConfigurationFailed
    case captureSessionNotRunning
    case photoCaptureFailed
    case deviceSwitchFailed
    case invalidCameraPosition
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Please enable camera access in Settings to take photos."
        case .permissionRestricted:
            return "Camera access is restricted on this device."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session. Please try again."
        case .captureSessionNotRunning:
            return "Camera session is not running. Please restart the camera."
        case .photoCaptureFailed:
            return "Failed to capture photo. Please try again."
        case .deviceSwitchFailed:
            return "Failed to switch camera. Please try again."
        case .invalidCameraPosition:
            return "Invalid camera position selected."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Camera and enable access for BuyNothing."
        case .permissionRestricted:
            return "Contact your device administrator to enable camera access."
        case .cameraUnavailable:
            return "This feature requires a camera-enabled device."
        case .sessionConfigurationFailed, .captureSessionNotRunning:
            return "Try restarting the app or check if another app is using the camera."
        case .photoCaptureFailed, .deviceSwitchFailed:
            return "Ensure the camera is not being used by another app and try again."
        case .invalidCameraPosition:
            return "Select either front or back camera."
        }
    }
}

enum CameraPosition {
    case front
    case back
    
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

enum CameraPermissionStatus {
    case notDetermined
    case granted
    case denied
    case restricted
    
    init(from status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .granted
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }
}

struct CapturedPhoto {
    let imageData: Data
    let metadata: [String: Any]
    let captureTime: Date
    let orientation: UIImage.Orientation
    
    var image: UIImage? {
        return UIImage(data: imageData)
    }
}

@MainActor
protocol CameraServiceProtocol: AnyObject {
    var isSessionRunning: Bool { get }
    var currentCameraPosition: CameraPosition { get }
    var permissionStatus: CameraPermissionStatus { get }
    
    func requestCameraPermission() async -> CameraPermissionStatus
    func startSession() async throws
    func stopSession() async
    func capturePhoto() async throws -> CapturedPhoto
    func switchCamera(to position: CameraPosition) async throws
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer?
}