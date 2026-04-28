@preconcurrency import AVFoundation
import Foundation
import OSLog

extension CameraSession {
    func zoomSnapshot() async -> CameraZoomSnapshot {
        guard let device = activeDevice else { return CameraZoomSnapshot.empty }
        return await runOnSessionQueue {
            let presets = ZoomPresetBuilder.build(for: device)
            let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors
                .first.map { Double(truncating: $0) } ?? 1.0
            return CameraZoomSnapshot(
                minFactor: Double(device.minAvailableVideoZoomFactor),
                maxFactor: CameraZoomCapabilities.recommendedMaxFactor(for: device),
                currentFactor: Double(device.videoZoomFactor),
                firstSwitchOver: firstSwitch,
                displayMultiplier: CameraZoomCapabilities.displayMultiplier(for: device),
                presets: presets,
                exposureBiasRange: device.minExposureTargetBias ... device.maxExposureTargetBias
            )
        }
    }

    var minZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue { Double(device.minAvailableVideoZoomFactor) }
        }
    }

    var maxZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue {
                CameraZoomCapabilities.recommendedMaxFactor(for: device)
            }
        }
    }

    var currentZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue { Double(device.videoZoomFactor) }
        }
    }

    var ultraWideSwitchOverFactor: Double? {
        get async {
            guard let device = activeDevice else { return nil }
            return await runOnSessionQueue {
                device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) }
            }
        }
    }

    var firstSwitchOver: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue {
                device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) } ?? 1.0
            }
        }
    }

    var availablePresets: [ZoomPresetSpec] {
        get async {
            guard let device = activeDevice else { return [] }
            return await runOnSessionQueue { ZoomPresetBuilder.build(for: device) }
        }
    }

    func ramp(toZoomFactor factor: Double, rate: Float = 4.0) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            let minF = Double(device.minAvailableVideoZoomFactor)
            let maxF = Double(device.maxAvailableVideoZoomFactor)
            let clamped = max(minF, min(factor, maxF))
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.ramp(toVideoZoomFactor: CGFloat(clamped), withRate: rate)
            } catch {
                AppLogger.camera.error("Camera zoom ramp failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func setZoomFactor(_ factor: Double) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            let minF = Double(device.minAvailableVideoZoomFactor)
            let maxF = Double(device.maxAvailableVideoZoomFactor)
            let clamped = max(minF, min(factor, maxF))
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.videoZoomFactor = CGFloat(clamped)
            } catch {
                AppLogger.camera.error("Camera zoom set failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }
}
