import XCTest
import AVFoundation
@testable import BuyNothing

@MainActor
final class CameraServiceIntegrationTests: XCTestCase {
    
    var realCameraService: AVCameraService!
    var mockCameraService: MockCameraService!
    
    override func setUp() {
        super.setUp()
        realCameraService = AVCameraService()
        mockCameraService = MockCameraService()
    }
    
    override func tearDown() {
        Task {
            await realCameraService?.stopSession()
        }
        realCameraService = nil
        mockCameraService = nil
        super.tearDown()
    }
    
    // MARK: - Real Camera Tests (Only run if camera is available)
    
    func testRealCamera_InitialState_IsCorrect() {
        XCTAssertFalse(realCameraService.isSessionRunning)
        XCTAssertEqual(realCameraService.currentCameraPosition, .back)
        
        // Permission status depends on device/simulator state
        let validStatuses: [CameraPermissionStatus] = [.notDetermined, .granted, .denied, .restricted]
        XCTAssertTrue(validStatuses.contains(realCameraService.permissionStatus))
    }
    
    func testRealCamera_PreviewLayer_IsAvailable() {
        let previewLayer = realCameraService.getPreviewLayer()
        XCTAssertNotNil(previewLayer)
        XCTAssertEqual(previewLayer?.videoGravity, .resizeAspectFill)
    }
    
    func testRealCamera_SessionLifecycle_WorksOnSimulator() async throws {
        // This test works on simulator but won't actually capture photos
        let initialStatus = realCameraService.permissionStatus
        
        if initialStatus == .granted {
            try await realCameraService.startSession()
            XCTAssertTrue(realCameraService.isSessionRunning)
            
            await realCameraService.stopSession()
            XCTAssertFalse(realCameraService.isSessionRunning)
        } else {
            // On simulator without camera access, we expect permission errors
            do {
                try await realCameraService.startSession()
                // If this succeeds, great! Otherwise we expect specific errors
            } catch let error as CameraError {
                let expectedErrors: [CameraError] = [.permissionDenied, .permissionRestricted, .cameraUnavailable]
                XCTAssertTrue(expectedErrors.contains(error))
            }
        }
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testBothServices_ConformToProtocol() {
        XCTAssertTrue(realCameraService is CameraServiceProtocol)
        XCTAssertTrue(mockCameraService is CameraServiceProtocol)
    }
    
    func testBothServices_HaveSameInterface() {
        let realService: CameraServiceProtocol = realCameraService
        let mockService: CameraServiceProtocol = mockCameraService
        
        // Test that both services expose the same properties
        XCTAssertEqual(type(of: realService.isSessionRunning), type(of: mockService.isSessionRunning))
        XCTAssertEqual(type(of: realService.currentCameraPosition), type(of: mockService.currentCameraPosition))
        XCTAssertEqual(type(of: realService.permissionStatus), type(of: mockService.permissionStatus))
    }
    
    // MARK: - Mock vs Real Service Behavior Tests
    
    func testMockService_BehavesConsistentlyWithRealService() async throws {
        // Test initial states are similar
        XCTAssertFalse(mockCameraService.isSessionRunning)
        XCTAssertFalse(realCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.currentCameraPosition, .back)
        XCTAssertEqual(realCameraService.currentCameraPosition, .back)
        
        // Test preview layer behavior
        let mockPreview = mockCameraService.getPreviewLayer()
        let realPreview = realCameraService.getPreviewLayer()
        
        // Mock returns nil, real returns layer
        XCTAssertNil(mockPreview)
        XCTAssertNotNil(realPreview)
    }
    
    // MARK: - Service Factory Pattern Tests
    
    func testCameraServiceFactory_CreatesCorrectService() {
        let mockFactory = CameraServiceFactory(useMock: true)
        let realFactory = CameraServiceFactory(useMock: false)
        
        let mockService = mockFactory.createCameraService()
        let realService = realFactory.createCameraService()
        
        XCTAssertTrue(mockService is MockCameraService)
        XCTAssertTrue(realService is AVCameraService)
    }
    
    // MARK: - Memory Management Tests
    
    func testCameraService_DeallocationCleansUp() async throws {
        var service: AVCameraService? = AVCameraService()
        weak var weakService = service
        
        // Start session if possible
        if service?.permissionStatus == .granted {
            try await service?.startSession()
        }
        
        // Release service
        service = nil
        
        // Wait for deallocation
        await Task.yield()
        
        // Verify it was deallocated
        XCTAssertNil(weakService, "Camera service should be deallocated")
    }
    
    // MARK: - Thread Safety Tests
    
    func testCameraService_ConcurrentAccess_IsSafe() async throws {
        mockCameraService.setPermissionStatus(.granted)
        
        // Start multiple concurrent operations
        async let task1 = mockCameraService.startSession()
        async let task2 = mockCameraService.requestCameraPermission()
        async let task3 = mockCameraService.switchCamera(to: .front)
        
        // Wait for all to complete
        try await task1
        _ = await task2
        try await task3
        
        // Verify final state is consistent
        XCTAssertTrue(mockCameraService.isSessionRunning)
        XCTAssertEqual(mockCameraService.currentCameraPosition, .front)
        XCTAssertEqual(mockCameraService.permissionStatus, .granted)
    }
    
    // MARK: - Error Recovery Tests
    
    func testCameraService_ErrorRecovery_WorksCorrectly() async throws {
        mockCameraService.setPermissionStatus(.granted)
        
        // Start session successfully
        try await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning)
        
        // Fail photo capture
        mockCameraService.shouldFailPhotoCapture = true
        do {
            _ = try await mockCameraService.capturePhoto()
            XCTFail("Expected photo capture to fail")
        } catch {
            // Expected failure
        }
        
        // Recover and capture successfully
        mockCameraService.shouldFailPhotoCapture = false
        let photo = try await mockCameraService.capturePhoto()
        XCTAssertNotNil(photo.imageData)
        
        // Session should still be running
        XCTAssertTrue(mockCameraService.isSessionRunning)
    }
    
    // MARK: - Configuration Tests
    
    func testCameraService_HandlesDifferentConfigurations() async throws {
        // Test with different permission scenarios
        let scenarios: [CameraPermissionStatus] = [.notDetermined, .granted, .denied, .restricted]
        
        for scenario in scenarios {
            let service = MockCameraService()
            service.setPermissionStatus(scenario)
            
            if scenario == .granted {
                try await service.startSession()
                XCTAssertTrue(service.isSessionRunning)
                await service.stopSession()
            } else {
                do {
                    try await service.startSession()
                    if scenario == .notDetermined {
                        // Should request permission and succeed (in mock)
                        XCTAssertTrue(service.isSessionRunning)
                    } else {
                        XCTFail("Expected error for permission status: \(scenario)")
                    }
                } catch {
                    // Expected for denied/restricted
                    XCTAssertTrue([CameraPermissionStatus.denied, .restricted].contains(scenario) || 
                                service.shouldFailPermissionRequest)
                }
            }
        }
    }
}

// MARK: - Camera Service Factory

class CameraServiceFactory {
    private let useMock: Bool
    
    init(useMock: Bool = false) {
        self.useMock = useMock
    }
    
    @MainActor
    func createCameraService() -> CameraServiceProtocol {
        if useMock {
            return MockCameraService()
        } else {
            return AVCameraService()
        }
    }
}