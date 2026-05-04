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

        let captureAngle: CGFloat = await MainActor.run { [weak self] in
            self?.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
        }
        let exifOrientation = ExifOrientationCodec.fromCaptureAngle(captureAngle)
        AppLogger.camera
            .info(
                "[CAM-ROT-CAP] captureAngle=\(captureAngle, privacy: .public), exif=\(exifOrientation.rawValue, privacy: .public)"
            )

        let queue = sessionQueue

        return try await withCheckedThrowingContinuation { cont in
            let id = UUID()
            let delegate = PhotoCaptureDelegate { [weak self] result in
                queue.async { [weak self] in
                    self?.inFlightDelegates.removeValue(forKey: id)
                }
                switch result {
                    case let .success(rawJpeg):
                        let processedJpeg = ExifOrientationCodec.write(exifOrientation, to: rawJpeg) ?? rawJpeg
                        cont.resume(returning: CapturedPhoto(
                            jpegData: processedJpeg,
                            zoomFactor: captureContext.zoom,
                            lensIdentifier: captureContext.lens,
                            captureAngleDegrees: Double(captureAngle),
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

private final nonisolated class CaptureContext: @unchecked Sendable {
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

final nonisolated class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, CameraSessionError>) -> Void

    init(completion: @escaping @Sendable (Result<Data, CameraSessionError>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(.noPhotoData))
            return
        }
        completion(.success(data))
    }
}
