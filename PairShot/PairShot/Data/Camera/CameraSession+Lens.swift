@preconcurrency import AVFoundation
import Foundation
import OSLog

nonisolated extension CameraSession {
    func switchLens(to position: CameraLensPosition) async {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        let session = box.session

        await runOnSessionQueueVoid { [weak self] in
            guard let self, didConfigure else { return }
            guard let device = Self.preferredDevice(for: avPosition) else { return }

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if let priorInput = activeInput {
                session.removeInput(priorInput)
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { return }
                session.addInput(input)
                Self.applyDefaultZoom(to: device)
                if let currentPhotoOutput = photoOutput {
                    Self.applyMaxPhotoDimensions(to: currentPhotoOutput, device: device)
                }
                activeDevice = device
                activeInput = input
                hasInputInternal = true
                AppLogger.camera.debug("Camera lens switched to \(position.rawValue, privacy: .public)")
            } catch {
                AppLogger.camera.error("Camera lens switch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        await MainActor.run { [weak self] in
            self?.setupRotationCoordinator()
        }
    }

    nonisolated static func preferredDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
        ]
        for type in preferredTypes {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                return device
            }
        }
        return nil
    }

    nonisolated static func applyDefaultZoom(to device: AVCaptureDevice) {
        guard let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors.first else { return }
        let target = CGFloat(truncating: firstSwitch)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = max(target, device.minAvailableVideoZoomFactor)
        } catch {
            AppLogger.camera.error("Default zoom set failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated static func applyMaxPhotoDimensions(
        to output: AVCapturePhotoOutput,
        device: AVCaptureDevice
    ) {
        guard let largest = resolveMaxPhotoDimensions(for: device) else { return }
        output.maxPhotoDimensions = largest
    }

    nonisolated static func resolveMaxPhotoDimensions(
        for device: AVCaptureDevice
    ) -> CMVideoDimensions? {
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        guard !supported.isEmpty else { return nil }
        let valid = supported.filter { $0.width > 0 && $0.height > 0 }
        guard !valid.isEmpty else { return nil }
        return valid.max { lhs, rhs in
            Int64(lhs.width) * Int64(lhs.height) < Int64(rhs.width) * Int64(rhs.height)
        }
    }
}
