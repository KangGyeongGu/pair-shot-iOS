@preconcurrency import AVFoundation
import Foundation
import OSLog

nonisolated extension CameraSession {
    func zoomSnapshot() async -> CameraZoomSnapshot {
        await runOnSessionQueue { [weak self] in
            guard let device = self?.activeDevice else { return CameraZoomSnapshot.empty }
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
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return 1.0 }
                return Double(device.minAvailableVideoZoomFactor)
            }
        }
    }

    var maxZoomFactor: Double {
        get async {
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return 1.0 }
                return CameraZoomCapabilities.recommendedMaxFactor(for: device)
            }
        }
    }

    var currentZoomFactor: Double {
        get async {
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return 1.0 }
                return Double(device.videoZoomFactor)
            }
        }
    }

    var ultraWideSwitchOverFactor: Double? {
        get async {
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return nil }
                return device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) }
            }
        }
    }

    var firstSwitchOver: Double {
        get async {
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return 1.0 }
                return device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) } ?? 1.0
            }
        }
    }

    var availablePresets: [ZoomPresetSpec] {
        get async {
            await runOnSessionQueue { [weak self] in
                guard let device = self?.activeDevice else { return [] }
                return ZoomPresetBuilder.build(for: device)
            }
        }
    }

    func ramp(toZoomFactor factor: Double, rate: Float = 4.0) async {
        await runOnSessionQueueVoid { [weak self] in
            guard let device = self?.activeDevice else { return }
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
        await runOnSessionQueueVoid { [weak self] in
            guard let device = self?.activeDevice else { return }
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
