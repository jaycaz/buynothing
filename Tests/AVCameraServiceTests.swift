import XCTest
import AVFoundation
@testable import BuyNothing

@MainActor
final class AVCameraServiceTests: XCTestCase {
    
    var mockCameraService: MockCameraService!
    
    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
    }
    
    override func tearDown() {
        mockCameraService = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testRequestCameraPermission_WhenGranted_ReturnsGranted() async throws {
        mockCameraService.shouldFailPermissionRequest = false
        
        let status = await mockCameraService.requestCameraPermission()
        
        XCTAssertEqual(status, .granted)
        XCTAssertEqual(mockCameraService.permissionStatus, .granted)
        XCTAssertEqual(mockCameraService.permissionRequestCount, 1)
    }
    
    func testRequestCameraPermission_WhenDenied_ReturnsDenied() async throws {
        mockCameraService.shouldFailPermissionRequest = true
        
        let status = await mockCameraService.requestCameraPermission()
        
        XCTAssertEqual(status, .denied)
        XCTAssertEqual(mockCameraService.permissionStatus, .denied)
        XCTAssertEqual(mockCameraService.permissionRequestCount, 1)
    }
    
    func testRequestCameraPermission_MultipleRequests_OnlyRequestsOnce() async throws {
        mockCameraService.setPermissionStatus(.granted)
        
        let status1 = await mockCameraService.requestCameraPermission()
        let status2 = await mockCameraService.requestCameraPermission()
        
        XCTAssertEqual(status1, .granted)
        XCTAssertEqual(status2, .granted)
        XCTAssertEqual(mockCameraService.permissionRequestCount, 2)
    }
    
    // MARK: - Session Management Tests
    
    func testStartSession_WithPermission_StartsSuccessfully() async throws {
        mockCameraService.setPermissionStatus(.granted)
        
        try await mockCameraService.startSession()
        
        XCTAssertTrue(mockCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.sessionStartCount, 1)
    }
    
    func testStartSession_WithoutPermission_RequestsPermissionFirst() async throws {
        mockCameraService.setPermissionStatus(.notDetermined)
        
        try await mockCameraService.startSession()
        
        XCTAssertTrue(mockCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.permissionRequestCount, 1)
        XCTAssertEqual(mockCameraService.sessionStartCount, 1)
    }
    
    func testStartSession_WhenPermissionDenied_ThrowsError() async throws {
        mockCameraService.setPermissionStatus(.denied)
        
        do {
            try await mockCameraService.startSession()
            XCTFail("Expected error to be thrown")
        } catch let error as CameraError {
            XCTAssertEqual(error, .permissionDenied)
            XCTAssertFalse(mockCameraService.isSessionRunning)
        }
    }
    
    func testStartSession_WhenConfigurationFails_ThrowsError() async throws {
        mockCameraService.setPermissionStatus(.granted)
        mockCameraService.shouldFailSessionStart = true
        
        do {
            try await mockCameraService.startSession()
            XCTFail("Expected error to be thrown")
        } catch let error as CameraError {
            XCTAssertEqual(error, .sessionConfigurationFailed)
            XCTAssertFalse(mockCameraService.isSessionRunning)
        }
    }
    
    func testStopSession_WhenRunning_StopsSuccessfully() async throws {
        mockCameraService.setPermissionStatus(.granted)
        try await mockCameraService.startSession()
        
        await mockCameraService.stopSession()
        
        XCTAssertFalse(mockCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.sessionStopCount, 1)
    }
    
    func testStopSession_WhenNotRunning_DoesNotThrow() async throws {
        await mockCameraService.stopSession()
        
        XCTAssertFalse(mockCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.sessionStopCount, 1)
    }
    
    // MARK: - Photo Capture Tests
    
    func testCapturePhoto_WhenSessionRunning_ReturnsPhoto() async throws {
        mockCameraService.setPermissionStatus(.granted)
        try await mockCameraService.startSession()
        
        let photo = try await mockCameraService.capturePhoto()
        
        XCTAssertNotNil(photo.imageData)
        XCTAssertNotNil(photo.image)
        XCTAssertEqual(mockCameraService.photoCaptureCount, 1)
    }
    
    func testCapturePhoto_WhenSessionNotRunning_ThrowsError() async throws {
        do {
            _ = try await mockCameraService.capturePhoto()
            XCTFail("Expected error to be thrown")
        } catch let error as CameraError {
            XCTAssertEqual(error, .captureSessionNotRunning)
        }
    }
    
    func testCapturePhoto_WhenCaptureFails_ThrowsError() async throws {
        mockCameraService.setPermissionStatus(.granted)
        try await mockCameraService.startSession()
        mockCameraService.shouldFailPhotoCapture = true
        
        do {
            _ = try await mockCameraService.capturePhoto()
            XCTFail("Expected error to be thrown")
        } catch let error as CameraError {
            XCTAssertEqual(error, .photoCaptureFailed)
        }
    }
    
    func testCapturePhoto_MultipleConcurrentRequests_HandlesCorrectly() async throws {
        mockCameraService.setPermissionStatus(.granted)
        try await mockCameraService.startSession()
        
        async let photo1 = mockCameraService.capturePhoto()
        async let photo2 = mockCameraService.capturePhoto()
        async let photo3 = mockCameraService.capturePhoto()
        
        let results = try await [photo1, photo2, photo3]
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(mockCameraService.photoCaptureCount, 3)
        
        for photo in results {
            XCTAssertNotNil(photo.imageData)
            XCTAssertNotNil(photo.image)
        }
    }
    
    // MARK: - Camera Switching Tests
    
    func testSwitchCamera_ToFront_UpdatesPosition() async throws {
        XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        
        try await mockCameraService.switchCamera(to: .front)
        
        XCTAssertEqual(mockCameraService.currentCameraPosition, .front)
        XCTAssertEqual(mockCameraService.cameraSwitchCount, 1)
    }
    
    func testSwitchCamera_ToSamePosition_DoesNothing() async throws {
        XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        
        try await mockCameraService.switchCamera(to: .back)
        
        XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        XCTAssertEqual(mockCameraService.cameraSwitchCount, 1)
    }
    
    func testSwitchCamera_WhenFails_ThrowsError() async throws {
        mockCameraService.shouldFailCameraSwitch = true
        
        do {
            try await mockCameraService.switchCamera(to: .front)
            XCTFail("Expected error to be thrown")
        } catch let error as CameraError {
            XCTAssertEqual(error, .deviceSwitchFailed)
            XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        }
    }
    
    func testSwitchCamera_BackAndForth_UpdatesCorrectly() async throws {
        try await mockCameraService.switchCamera(to: .front)
        XCTAssertEqual(mockCameraService.currentCameraPosition, .front)
        
        try await mockCameraService.switchCamera(to: .back)
        XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        
        XCTAssertEqual(mockCameraService.cameraSwitchCount, 2)
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow_StartCaptureStop_WorksCorrectly() async throws {
        // Start session
        mockCameraService.setPermissionStatus(.granted)
        try await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning)
        
        // Capture photo
        let photo = try await mockCameraService.capturePhoto()
        XCTAssertNotNil(photo.imageData)
        
        // Switch camera
        try await mockCameraService.switchCamera(to: .front)
        XCTAssertEqual(mockCameraService.currentCameraPosition, .front)
        
        // Capture another photo
        let photo2 = try await mockCameraService.capturePhoto()
        XCTAssertNotNil(photo2.imageData)
        
        // Stop session
        await mockCameraService.stopSession()
        XCTAssertFalse(mockCameraService.isSessionRunning)
        
        // Verify counts
        XCTAssertEqual(mockCameraService.sessionStartCount, 1)
        XCTAssertEqual(mockCameraService.photoCaptureCount, 2)
        XCTAssertEqual(mockCameraService.cameraSwitchCount, 1)
        XCTAssertEqual(mockCameraService.sessionStopCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testCameraError_LocalizedDescription_IsUserFriendly() {
        let errors: [CameraError] = [
            .permissionDenied,
            .permissionRestricted,
            .cameraUnavailable,
            .sessionConfigurationFailed,
            .captureSessionNotRunning,
            .photoCaptureFailed,
            .deviceSwitchFailed,
            .invalidCameraPosition
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    func testCameraPosition_AVPositionMapping_IsCorrect() {
        XCTAssertEqual(CameraPosition.front.avPosition, .front)
        XCTAssertEqual(CameraPosition.back.avPosition, .back)
    }
    
    func testCameraPermissionStatus_InitFromAVStatus_IsCorrect() {
        XCTAssertEqual(CameraPermissionStatus(from: .notDetermined), .notDetermined)
        XCTAssertEqual(CameraPermissionStatus(from: .authorized), .granted)
        XCTAssertEqual(CameraPermissionStatus(from: .denied), .denied)
        XCTAssertEqual(CameraPermissionStatus(from: .restricted), .restricted)
    }
    
    // MARK: - Performance Tests
    
    func testCapturePhotoPerformance() async throws {
        mockCameraService.setPermissionStatus(.granted)
        mockCameraService.photoCaptureDelay = 0.1
        try await mockCameraService.startSession()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10 {
            _ = try await mockCameraService.capturePhoto()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(timeElapsed, 2.0, "10 photo captures should complete within 2 seconds")
    }
    
    func testSessionStartPerformance() async throws {
        mockCameraService.setPermissionStatus(.granted)
        mockCameraService.sessionStartDelay = 0.1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await mockCameraService.startSession()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(timeElapsed, 1.0, "Session start should complete within 1 second")
    }
}