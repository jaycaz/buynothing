import XCTest
@testable import BuyNothing

@MainActor
final class CameraServicePerformanceTests: XCTestCase {
    
    var cameraService: MockCameraService!
    
    override func setUp() {
        super.setUp()
        cameraService = MockCameraService()
        cameraService.setPermissionStatus(.granted)
    }
    
    override func tearDown() {
        cameraService = nil
        super.tearDown()
    }
    
    // MARK: - Session Performance Tests
    
    func testSessionStartPerformance() async throws {
        cameraService.sessionStartDelay = 0.05
        
        measure {
            let expectation = XCTestExpectation(description: "Session start")
            
            Task {
                do {
                    try await cameraService.startSession()
                    await cameraService.stopSession()
                    expectation.fulfill()
                } catch {
                    XCTFail("Session start failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testSessionStartupBenchmark() async throws {
        cameraService.sessionStartDelay = 0.1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        try await cameraService.startSession()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Camera should start within 1 second (requirement from issue)
        XCTAssertLessThan(timeElapsed, 1.0, "Camera startup should be under 1 second")
        
        await cameraService.stopSession()
    }
    
    // MARK: - Photo Capture Performance Tests
    
    func testPhotoCaptureBenchmark() async throws {
        cameraService.photoCaptureDelay = 0.1
        try await cameraService.startSession()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await cameraService.capturePhoto()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Photo capture should be under 500ms (requirement from issue)
        XCTAssertLessThan(timeElapsed, 0.5, "Photo capture should be under 500ms")
        
        await cameraService.stopSession()
    }
    
    func testPhotoCapturePerformance() async throws {
        try await cameraService.startSession()
        cameraService.photoCaptureDelay = 0.01
        
        measure {
            let expectation = XCTestExpectation(description: "Photo capture")
            
            Task {
                do {
                    _ = try await cameraService.capturePhoto()
                    expectation.fulfill()
                } catch {
                    XCTFail("Photo capture failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
        
        await cameraService.stopSession()
    }
    
    func testMultiplePhotoCapturePerformance() async throws {
        try await cameraService.startSession()
        cameraService.photoCaptureDelay = 0.05
        
        let photoCount = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<photoCount {
            _ = try await cameraService.capturePhoto()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(photoCount)
        
        XCTAssertLessThan(averageTime, 0.5, "Average photo capture should be under 500ms")
        
        await cameraService.stopSession()
    }
    
    func testConcurrentPhotoCapturePerformance() async throws {
        try await cameraService.startSession()
        cameraService.photoCaptureDelay = 0.1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        async let photo1 = cameraService.capturePhoto()
        async let photo2 = cameraService.capturePhoto()
        async let photo3 = cameraService.capturePhoto()
        async let photo4 = cameraService.capturePhoto()
        async let photo5 = cameraService.capturePhoto()
        
        let photos = try await [photo1, photo2, photo3, photo4, photo5]
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertEqual(photos.count, 5)
        XCTAssertLessThan(timeElapsed, 2.0, "5 concurrent captures should complete within 2 seconds")
        
        await cameraService.stopSession()
    }
    
    // MARK: - Camera Switching Performance Tests
    
    func testCameraSwitchPerformance() async throws {
        cameraService.cameraSwitchDelay = 0.05
        
        measure {
            let expectation = XCTestExpectation(description: "Camera switch")
            
            Task {
                do {
                    try await cameraService.switchCamera(to: .front)
                    try await cameraService.switchCamera(to: .back)
                    expectation.fulfill()
                } catch {
                    XCTFail("Camera switch failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testCameraSwitchBenchmark() async throws {
        cameraService.cameraSwitchDelay = 0.1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        try await cameraService.switchCamera(to: .front)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 0.5, "Camera switch should be under 500ms")
    }
    
    func testRapidCameraSwitching() async throws {
        cameraService.cameraSwitchDelay = 0.02
        
        let switchCount = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<switchCount {
            let position: CameraPosition = (i % 2 == 0) ? .front : .back
            try await cameraService.switchCamera(to: position)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(switchCount)
        
        XCTAssertLessThan(averageTime, 0.5, "Average camera switch should be under 500ms")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringCapture() async throws {
        try await cameraService.startSession()
        
        let memoryBefore = getMemoryUsage()
        
        // Capture multiple photos to test memory usage
        for _ in 0..<20 {
            _ = try await cameraService.capturePhoto()
        }
        
        let memoryAfter = getMemoryUsage()
        let memoryIncrease = memoryAfter - memoryBefore
        
        // Memory increase should be reasonable (less than 50MB for mock photos)
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory usage should not increase dramatically")
        
        await cameraService.stopSession()
    }
    
    func testMemoryLeaksDuringSessionCycle() async throws {
        let initialMemory = getMemoryUsage()
        
        // Perform multiple session cycles
        for _ in 0..<5 {
            try await cameraService.startSession()
            _ = try await cameraService.capturePhoto()
            await cameraService.stopSession()
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                // Empty pool to encourage cleanup
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory should not significantly increase after cleanup
        XCTAssertLessThan(memoryIncrease, 10_000_000, "Memory leaks detected during session cycles")
    }
    
    // MARK: - Stress Tests
    
    func testStressTest_RapidOperations() async throws {
        let operationCount = 100
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<operationCount {
            switch i % 4 {
            case 0:
                try await cameraService.startSession()
            case 1:
                _ = try await cameraService.capturePhoto()
            case 2:
                try await cameraService.switchCamera(to: (i % 2 == 0) ? .front : .back)
            case 3:
                await cameraService.stopSession()
            default:
                break
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(operationCount)
        
        XCTAssertLessThan(averageTime, 0.1, "Average operation time should be under 100ms under stress")
    }
    
    func testStressTest_ConcurrentSessions() async throws {
        // Test that multiple camera services can be created without issues
        let serviceCount = 10
        var services: [MockCameraService] = []
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<serviceCount {
            let service = MockCameraService()
            service.setPermissionStatus(.granted)
            services.append(service)
        }
        
        // Start all sessions concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for service in services {
                group.addTask {
                    try await service.startSession()
                }
            }
            
            try await group.waitForAll()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 2.0, "Multiple concurrent session starts should complete quickly")
        
        // Clean up
        for service in services {
            await service.stopSession()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}