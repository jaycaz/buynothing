import Foundation
import AVFoundation
import UIKit

protocol CameraServiceProtocol: Actor {
    func requestCameraPermission() async -> Bool
    func startCamera() async throws
    func stopCamera() async
    func capturePhoto() async throws -> Data
    func isSessionRunning() async -> Bool
    func switchCamera() async throws
}

enum CameraError: Error, Sendable {
    case permissionDenied
    case deviceNotAvailable
    case sessionNotRunning
    case captureSessionError(Error)
    case invalidCaptureOutput
    case cameraConfigurationFailed
    case switchCameraFailed
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Camera permission is required to detect USB cables"
        case .deviceNotAvailable:
            return "Camera is not available on this device"
        case .sessionNotRunning:
            return "Camera session is not running"
        case .captureSessionError(let error):
            return "Camera capture failed: \(error.localizedDescription)"
        case .invalidCaptureOutput:
            return "Invalid camera capture output"
        case .cameraConfigurationFailed:
            return "Failed to configure camera settings"
        case .switchCameraFailed:
            return "Failed to switch camera"
        }
    }
}

enum CameraPosition: Sendable {
    case front
    case back
    case unspecified
}