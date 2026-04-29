@preconcurrency import AVFoundation
import Foundation
import OSLog

extension CameraSession {
    func capturePhoto() async throws -> CapturedPhoto {
        guard let photoOutput, let device = activeDevice else {
            AppLogger.camera.error("Camera capturePhoto failed: not configured")
            throw CameraSessionError.notConfigured
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

        let zoom = Double(device.videoZoomFactor)
        let lens = lensIdentifier(for: device)
        let queue = sessionQueue

        return try await withCheckedThrowingContinuation { cont in
            let id = UUID()
            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }
                Task { await self.removeDelegate(id: id) }
                switch result {
                    case let .success(data):
                        cont.resume(returning: CapturedPhoto(
                            jpegData: data,
                            zoomFactor: zoom,
                            lensIdentifier: lens,
                            capturedAt: .now
                        ))

                    case let .failure(err):
                        AppLogger.camera
                            .error("Camera capturePhoto failed: \(String(describing: err), privacy: .public)")
                        cont.resume(throwing: err)
                }
            }
            inFlightDelegates[id] = delegate
            queue.async {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    func removeDelegate(id: UUID) {
        inFlightDelegates.removeValue(forKey: id)
    }

    func lensIdentifier(for device: AVCaptureDevice) -> String {
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

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, CameraSessionError>) -> Void
    private let lock = NSLock()
    private nonisolated(unsafe) var didFinish = false

    nonisolated init(completion: @escaping @Sendable (Result<Data, CameraSessionError>) -> Void) {
        self.completion = completion
    }

    nonisolated func photoOutput(
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

    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishCaptureFor _: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            finish(with: .failure(.captureFailed(error.localizedDescription)))
        } else {
            finish(with: .failure(.captureFailed("capture finished without photo data")))
        }
    }

    private nonisolated func finish(with result: Result<Data, CameraSessionError>) {
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
