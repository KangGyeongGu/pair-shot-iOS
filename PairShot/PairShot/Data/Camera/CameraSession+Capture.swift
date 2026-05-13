@preconcurrency import AVFoundation
import Foundation
import OSLog

nonisolated extension CameraSession {
    func capturePhoto(
        metadata: [String: Any] = [:]
    ) async throws -> CapturedPhoto {
        let metadataBox = CaptureMetadataBox(metadata)
        let captureContext = await runOnSessionQueue { [weak self] () -> CaptureContext? in
            guard let self,
                  let photoOutput,
                  let device = activeDevice
            else {
                return nil
            }

            let settings = AVCapturePhotoSettings()
            if !metadataBox.value.isEmpty {
                settings.metadata = metadataBox.value
            }
            if device.hasFlash {
                switch flashMode {
                    case .auto: settings.flashMode = .auto
                    case .on: settings.flashMode = .on
                    case .off, .torch: settings.flashMode = .off
                }
            }
            return CaptureContext(
                photoOutput: photoOutput,
                settings: settings,
                zoom: Double(device.videoZoomFactor),
                lens: Self.lensIdentifier(for: device),
                aspectRatio: currentAspectRatio
            )
        }

        guard let captureContext else {
            AppLogger.camera.error("Camera capturePhoto failed: not configured")
            throw CameraSessionError.notConfigured
        }

        let queue = sessionQueue
        let trackedSettings = captureContext.settings
        let settingsUniqueID = trackedSettings.uniqueID

        await MainActor.run { [weak self] in
            self?.readinessCoordinator?.startTrackingCaptureRequest(using: trackedSettings)
        }

        return try await withCheckedThrowingContinuation { cont in
            let id = UUID()
            let aspect = captureContext.aspectRatio
            let delegate = PhotoCaptureDelegate { [weak self] result in
                queue.async { [weak self] in
                    self?.inFlightDelegates.removeValue(forKey: id)
                }
                Task { @MainActor [weak self] in
                    self?.readinessCoordinator?.stopTrackingCaptureRequest(using: settingsUniqueID)
                }
                switch result {
                    case let .success(payload):
                        let finalData = AspectRatioCropper.cropJPEG(
                            data: payload.data,
                            targetAspect: aspect
                        )
                        cont.resume(
                            returning: CapturedPhoto(
                                jpegData: finalData,
                                zoomFactor: captureContext.zoom,
                                lensIdentifier: captureContext.lens,
                                isDeferredProxy: payload.isDeferredProxy && aspect == .fourThree
                            )
                        )

                    case let .failure(err):
                        AppLogger.camera
                            .error("Camera capturePhoto failed: \(String(describing: err), privacy: .public)")
                        cont.resume(throwing: err)
                }
            }
            queue.async { [weak self] in
                self?.inFlightDelegates[id] = delegate
                captureContext.photoOutput.capturePhoto(with: captureContext.settings, delegate: delegate)
            }
        }
    }

    nonisolated static func lensIdentifier(for device: AVCaptureDevice) -> String {
        let position =
            switch device.position {
                case .back: "back"
                case .front: "front"
                case .unspecified: "unspecified"
                @unknown default: "unknown"
            }
        return "\(device.deviceType.rawValue).\(position)"
    }
}

private final nonisolated class CaptureContext: @unchecked Sendable {
    let photoOutput: AVCapturePhotoOutput
    let settings: AVCapturePhotoSettings
    let zoom: Double
    let lens: String
    let aspectRatio: AspectRatio

    init(
        photoOutput: AVCapturePhotoOutput,
        settings: AVCapturePhotoSettings,
        zoom: Double,
        lens: String,
        aspectRatio: AspectRatio
    ) {
        self.photoOutput = photoOutput
        self.settings = settings
        self.zoom = zoom
        self.lens = lens
        self.aspectRatio = aspectRatio
    }
}

private final nonisolated class CaptureMetadataBox: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) {
        self.value = value
    }
}

nonisolated struct CapturedPhotoPayload {
    let data: Data
    let isDeferredProxy: Bool
}

final nonisolated class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<CapturedPhotoPayload, CameraSessionError>) -> Void
    private var didDeliver = false

    init(completion: @escaping @Sendable (Result<CapturedPhotoPayload, CameraSessionError>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if didDeliver { return }
        if let error {
            didDeliver = true
            completion(.failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            didDeliver = true
            completion(.failure(.noPhotoData))
            return
        }
        didDeliver = true
        completion(.success(CapturedPhotoPayload(data: data, isDeferredProxy: false)))
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishCapturingDeferredPhotoProxy proxy: AVCaptureDeferredPhotoProxy?,
        error: Error?
    ) {
        if didDeliver { return }
        if let error {
            didDeliver = true
            completion(.failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let proxy, let data = proxy.fileDataRepresentation() else {
            didDeliver = true
            completion(.failure(.noPhotoData))
            return
        }
        didDeliver = true
        completion(.success(CapturedPhotoPayload(data: data, isDeferredProxy: true)))
    }
}
