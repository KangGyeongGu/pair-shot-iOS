@preconcurrency import AVFoundation
import Foundation
import OSLog

extension CameraSession {
    func switchLens(to position: CameraLensPosition) async {
        guard didConfigure else { return }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        let session = box.session
        let priorInput = activeInput
        let currentPhotoOutput = photoOutput

        let result = await runOnSessionQueue { () -> SwitchLensResult? in
            guard let device = Self.preferredDevice(for: avPosition) else { return nil }

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if let priorInput {
                session.removeInput(priorInput)
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { return nil }
                session.addInput(input)
                Self.applyDefaultZoom(to: device)
                if let currentPhotoOutput {
                    Self.applyMaxPhotoDimensions(to: currentPhotoOutput, device: device)
                }
                return SwitchLensResult(device: device, input: input)
            } catch {
                AppLogger.camera.error("Camera lens switch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        guard let result else { return }
        activeDevice = result.device
        activeInput = result.input
        updateLensPosition(position)
        hasInputInternal = true
        AppLogger.camera.debug("Camera lens switched to \(position.rawValue, privacy: .public)")
    }

    static func preferredDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
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
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        guard let largest = supported.last else { return }
        output.maxPhotoDimensions = largest
    }
}

final class SwitchLensResult: @unchecked Sendable {
    nonisolated(unsafe) let device: AVCaptureDevice
    nonisolated(unsafe) let input: AVCaptureDeviceInput

    nonisolated init(device: AVCaptureDevice, input: AVCaptureDeviceInput) {
        self.device = device
        self.input = input
    }
}
