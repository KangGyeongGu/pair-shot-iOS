@preconcurrency import AVFoundation
import Foundation

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
                return
            }
        }
    }
}
