import Testing
import Foundation
@testable import BuyNothing

@Suite("Camera Service Tests")
struct CameraServiceTests {
    
    @Test("Mock camera service requests permission successfully")
    func mockCameraRequestsPermission() async throws {
        let mockCamera = MockCameraService()
        
        let hasPermission = await mockCamera.requestCameraPermission()
        
        #expect(hasPermission == true)
    }
    
    @Test("Mock camera service handles permission denial")
    func mockCameraHandlesPermissionDenial() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setShouldFailPermission(true)
        
        let hasPermission = await mockCamera.requestCameraPermission()
        
        #expect(hasPermission == false)
    }
    
    @Test("Camera service starts and stops correctly")
    func cameraStartsAndStops() async throws {
        let mockCamera = MockCameraService()
        
        // Grant permission first
        let hasPermission = await mockCamera.requestCameraPermission()
        #expect(hasPermission == true)
        
        // Start camera
        try await mockCamera.startCamera()
        let isRunning = await mockCamera.isSessionRunning()
        #expect(isRunning == true)
        
        // Stop camera
        await mockCamera.stopCamera()
        let isStopped = await mockCamera.isSessionRunning()
        #expect(isStopped == false)
    }
    
    @Test("Camera service requires permission to start")
    func cameraRequiresPermissionToStart() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setShouldFailPermission(true)
        
        // Try to start without permission
        await #expect(throws: CameraError.permissionDenied) {
            try await mockCamera.startCamera()
        }
    }
    
    @Test("Camera service captures photo successfully")
    func cameraServiceCapturesPhoto() async throws {
        let mockCamera = MockCameraService()
        
        // Set up camera
        _ = await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        // Capture photo
        let imageData = try await mockCamera.capturePhoto()
        
        #expect(imageData.count > 0)
    }
    
    @Test("Camera service handles capture failures")
    func cameraServiceHandlesCaptureFailures() async throws {
        let mockCamera = MockCameraService()
        
        // Set up camera
        _ = await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        // Configure to fail capture
        await mockCamera.setShouldFailCapture(true)
        
        await #expect(throws: CameraError.captureSessionError) {
            try await mockCamera.capturePhoto()
        }
    }
    
    @Test("Camera service requires running session for capture")
    func cameraRequiresRunningSessionForCapture() async throws {
        let mockCamera = MockCameraService()
        
        // Grant permission but don't start camera
        _ = await mockCamera.requestCameraPermission()
        
        await #expect(throws: CameraError.sessionNotRunning) {
            try await mockCamera.capturePhoto()
        }
    }
    
    @Test("Camera service can switch cameras")
    func cameraServiceCanSwitchCameras() async throws {
        let mockCamera = MockCameraService()
        
        // Set up camera
        _ = await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        let initialPosition = await mockCamera.getCurrentPosition()
        #expect(initialPosition == .back)
        
        // Switch camera
        try await mockCamera.switchCamera()
        
        let newPosition = await mockCamera.getCurrentPosition()
        #expect(newPosition == .front)
    }
    
    @Test("Camera service handles switch camera errors")
    func cameraServiceHandlesSwitchCameraErrors() async throws {
        let mockCamera = MockCameraService()
        
        // Try to switch without permission
        await #expect(throws: CameraError.permissionDenied) {
            try await mockCamera.switchCamera()
        }
        
        // Try to switch without running session
        _ = await mockCamera.requestCameraPermission()
        
        await #expect(throws: CameraError.sessionNotRunning) {
            try await mockCamera.switchCamera()
        }
    }
    
    @Test("Camera service respects capture delay configuration")
    func cameraServiceRespectsConfiguredDelay() async throws {
        let mockCamera = MockCameraService()
        await mockCamera.setCaptureDelay(0.1) // 100ms
        
        // Set up camera
        _ = await mockCamera.requestCameraPermission()
        try await mockCamera.startCamera()
        
        let startTime = Date()
        _ = try await mockCamera.capturePhoto()
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(elapsed >= 0.1)
        #expect(elapsed < 0.5) // Should not take too long
    }
    
    @Test("Camera service can reset to defaults")
    func cameraServiceCanResetToDefaults() async throws {
        let mockCamera = MockCameraService()
        
        // Change some settings
        await mockCamera.setShouldFailPermission(true)
        await mockCamera.setShouldFailCapture(true)
        await mockCamera.setCaptureDelay(1.0)
        
        // Reset to defaults
        await mockCamera.resetToDefaults()
        
        // Test that defaults are restored
        let hasPermission = await mockCamera.requestCameraPermission()
        #expect(hasPermission == true)
        
        try await mockCamera.startCamera()
        let imageData = try await mockCamera.capturePhoto()
        #expect(imageData.count > 0)
    }
}