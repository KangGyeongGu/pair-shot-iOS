@preconcurrency import AVFoundation
import Foundation
import OSLog

extension CameraSession {
    var exposureBiasRange: ClosedRange<Float>? {
        get async {
            guard let device = activeDevice else { return nil }
            return await runOnSessionQueue {
                device.minExposureTargetBias ... device.maxExposureTargetBias
            }
        }
    }

    func focus(at point: CGPoint) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
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
        guard let device = activeDevice else { return }
        let queue = sessionQueue
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
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

    func setFlashMode(_ mode: CameraFlashMode) async {
        flashMode = mode
        await applyTorchState()
    }

    func cycleFlashMode() async -> CameraFlashMode {
        let next = flashMode.next
        await setFlashMode(next)
        return next
    }

    func setLowLightBoost(enabled: Bool) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            guard device.isLowLightBoostSupported else { return }
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
        guard let device = activeDevice else { return }
        let mode = flashMode
        await runOnSessionQueueVoid {
            guard device.hasTorch else { return }
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
