@preconcurrency import AVFoundation
import Foundation
import OSLog

nonisolated extension CameraSession {
    func focus(at point: CGPoint) async {
        await runOnSessionQueueVoid { [weak self] in
            guard let device = self?.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.autoFocus)
                {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.autoExpose)
                {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
            } catch {
                AppLogger.camera.error("Camera focus configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func setExposureBias(_ bias: Float) async {
        let queue = sessionQueue
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                guard let device = self?.activeDevice else {
                    cont.resume()
                    return
                }
                do {
                    try device.lockForConfiguration()
                    let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
                    device.setExposureTargetBias(clamped) { _ in
                        device.unlockForConfiguration()
                        cont.resume()
                    }
                } catch {
                    AppLogger.camera
                        .error("Camera exposure bias set failed: \(error.localizedDescription, privacy: .public)")
                    cont.resume()
                }
            }
        }
    }

    func cycleFlashMode() async -> CameraFlashMode {
        let next = await runOnSessionQueue { [weak self] () -> CameraFlashMode in
            guard let self else { return .off }
            let value = flashMode.next
            flashMode = value
            return value
        }
        await applyTorchState()
        return next
    }

    func setLowLightBoost(enabled: Bool) async {
        await runOnSessionQueueVoid { [weak self] in
            guard let device = self?.activeDevice, device.isLowLightBoostSupported else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.automaticallyEnablesLowLightBoostWhenAvailable = enabled
            } catch {
                AppLogger.camera
                    .error("Camera low-light boost configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func applyTorchState() async {
        await runOnSessionQueueVoid { [weak self] in
            guard let self,
                  let device = activeDevice,
                  device.hasTorch
            else {
                return
            }
            let mode = flashMode
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                switch mode {
                    case .torch:
                        if device.isTorchModeSupported(.on) {
                            device.torchMode = .on
                        }

                    case .off, .on, .auto:
                        if device.isTorchModeSupported(.off) {
                            device.torchMode = .off
                        }
                }
            } catch {
                AppLogger.camera.error("Camera torch configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }
}
