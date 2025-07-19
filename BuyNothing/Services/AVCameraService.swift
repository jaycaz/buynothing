import Foundation
import UIKit
import AVFoundation

@MainActor
final class AVCameraService: NSObject, CameraServiceProtocol {
    
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    private(set) var isSessionRunning = false
    private(set) var currentCameraPosition: CameraPosition = .back
    private(set) var permissionStatus: CameraPermissionStatus = .notDetermined
    
    // MARK: - Private Properties
    
    private var photoCaptureCompletions: [Int64: (Result<CapturedPhoto, Error>) -> Void] = [:]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        updatePermissionStatus()
    }
    
    deinit {
        Task {
            await stopSession()
        }
    }
    
    // MARK: - CameraServiceProtocol Implementation
    
    func requestCameraPermission() async -> CameraPermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            let newStatus: CameraPermissionStatus = granted ? .granted : .denied
            permissionStatus = newStatus
            return newStatus
        }
        
        let currentStatus = CameraPermissionStatus(from: status)
        permissionStatus = currentStatus
        return currentStatus
    }
    
    func startSession() async throws {
        guard permissionStatus == .granted else {
            let status = await requestCameraPermission()
            guard status == .granted else {
                throw status == .denied ? CameraError.permissionDenied : CameraError.permissionRestricted
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                    return
                }
                
                do {
                    try self.configureSession()
                    self.captureSession.startRunning()
                    
                    Task { @MainActor in
                        self.isSessionRunning = self.captureSession.isRunning
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func stopSession() async {
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                
                Task { @MainActor in
                    self.isSessionRunning = false
                    continuation.resume()
                }
            }
        }
    }
    
    func capturePhoto() async throws -> CapturedPhoto {
        guard isSessionRunning else {
            throw CameraError.captureSessionNotRunning
        }
        
        guard let photoOutput = photoOutput else {
            throw CameraError.photoCaptureFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                settings.isHighResolutionPhotoEnabled = true
                
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings.photoCodecType = .hevc
                }
                
                let uniqueID = settings.uniqueID
                self.photoCaptureCompletions[uniqueID] = { result in
                    continuation.resume(with: result)
                }
                
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    func switchCamera(to position: CameraPosition) async throws {
        guard position != currentCameraPosition else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.deviceSwitchFailed)
                    return
                }
                
                do {
                    try self.switchCameraDevice(to: position)
                    Task { @MainActor in
                        self.currentCameraPosition = position
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer
    }
    
    // MARK: - Private Methods
    
    private func updatePermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = CameraPermissionStatus(from: status)
    }
    
    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        captureSession.sessionPreset = .photo
        
        // Configure video input
        try configureVideoInput()
        
        // Configure photo output
        try configurePhotoOutput()
    }
    
    private func configureVideoInput() throws {
        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        guard let videoDevice = getCamera(for: currentCameraPosition) else {
            throw CameraError.cameraUnavailable
        }
        
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        } else {
            throw CameraError.sessionConfigurationFailed
        }
    }
    
    private func configurePhotoOutput() throws {
        if let currentOutput = photoOutput {
            captureSession.removeOutput(currentOutput)
        }
        
        let photoOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            self.photoOutput = photoOutput
        } else {
            throw CameraError.sessionConfigurationFailed
        }
    }
    
    private func switchCameraDevice(to position: CameraPosition) throws {
        guard let newDevice = getCamera(for: position) else {
            throw CameraError.deviceSwitchFailed
        }
        
        let newInput = try AVCaptureDeviceInput(device: newDevice)
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            videoDeviceInput = newInput
        } else {
            throw CameraError.deviceSwitchFailed
        }
    }
    
    private func getCamera(for position: CameraPosition) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position.avPosition
        )
        
        return discoverySession.devices.first
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension AVCameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let uniqueID = photo.resolvedSettings.uniqueID
        
        defer {
            photoCaptureCompletions.removeValue(forKey: uniqueID)
        }
        
        guard let completion = photoCaptureCompletions[uniqueID] else { return }
        
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.photoCaptureFailed))
            return
        }
        
        let metadata = photo.metadata
        let captureTime = Date()
        let orientation = getImageOrientation()
        
        let capturedPhoto = CapturedPhoto(
            imageData: imageData,
            metadata: metadata,
            captureTime: captureTime,
            orientation: orientation
        )
        
        completion(.success(capturedPhoto))
    }
    
    private func getImageOrientation() -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        let isFrontCamera = currentCameraPosition == .front
        
        switch deviceOrientation {
        case .portrait:
            return isFrontCamera ? .leftMirrored : .right
        case .portraitUpsideDown:
            return isFrontCamera ? .rightMirrored : .left
        case .landscapeLeft:
            return isFrontCamera ? .downMirrored : .up
        case .landscapeRight:
            return isFrontCamera ? .upMirrored : .down
        default:
            return isFrontCamera ? .leftMirrored : .right
        }
    }
}