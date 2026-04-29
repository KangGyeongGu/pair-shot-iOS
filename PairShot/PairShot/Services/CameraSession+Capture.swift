@preconcurrency import AVFoundation
import Foundation
import OSLog

nonisolated extension CameraSession {
    func capturePhoto() async throws -> CapturedPhoto {
        let captureContext = await runOnSessionQueue { [weak self] () -> CaptureContext? in
            guard let self,
                  let photoOutput,
                  let device = activeDevice
            else {
                return nil
            }

            let settings = AVCapturePhotoSettings()
            let outputMax = photoOutput.maxPhotoDimensions
            if outputMax.width > 0, outputMax.height > 0 {
                settings.maxPhotoDimensions = outputMax
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
                lens: Self.lensIdentifier(for: device)
            )
        }

        guard let captureContext else {
            AppLogger.camera.error("Camera capturePhoto failed: not configured")
            throw CameraSessionError.notConfigured
        }

        let queue = sessionQueue

        return try await withCheckedThrowingContinuation { cont in
            let id = UUID()
            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }
                sessionQueue.async { [weak self] in
                    self?.inFlightDelegates.removeValue(forKey: id)
                }
                switch result {
                    case let .success(data):
                        cont.resume(returning: CapturedPhoto(
                            jpegData: data,
                            zoomFactor: captureContext.zoom,
                            lensIdentifier: captureContext.lens,
                            capturedAt: .now
                        ))

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
        let raw = device.deviceType.rawValue
        let stripped = raw.replacingOccurrences(of: "AVCaptureDeviceType", with: "")
        let position = switch device.position {
            case .back: "back"
            case .front: "front"
            case .unspecified: "unspecified"
            @unknown default: "unknown"
        }
        return "\(stripped).\(position)"
    }
}

nonisolated private final class CaptureContext: @unchecked Sendable {
    let photoOutput: AVCapturePhotoOutput
    let settings: AVCapturePhotoSettings
    let zoom: Double
    let lens: String

    init(photoOutput: AVCapturePhotoOutput, settings: AVCapturePhotoSettings, zoom: Double, lens: String) {
        self.photoOutput = photoOutput
        self.settings = settings
        self.zoom = zoom
        self.lens = lens
    }
}

nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, CameraSessionError>) -> Void
    private let lock = NSLock()
    private var didFinish = false

    init(completion: @escaping @Sendable (Result<Data, CameraSessionError>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            finish(with: .failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            finish(with: .failure(.noPhotoData))
            return
        }
        finish(with: .success(data))
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishCaptureFor _: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            finish(with: .failure(.captureFailed(error.localizedDescription)))
        }
    }

    private func finish(with result: Result<Data, CameraSessionError>) {
        lock.lock()
        if didFinish {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()
        completion(result)
    }
}
