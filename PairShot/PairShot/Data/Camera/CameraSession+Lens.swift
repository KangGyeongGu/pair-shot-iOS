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
}
