@preconcurrency import AVFoundation
import CoreImage
import Observation
import UIKit

private enum LowLightThreshold {
    nonisolated static let lowLight: Float = 800
    nonisolated static let veryDarkNoise: Float = 1200
    nonisolated static let torchActivation: Float = 1200
    nonisolated static let maxExposureBias: Float = 2.0
    nonisolated static let torchLevel: Float = 0.4
    nonisolated static let batteryDisableThreshold: Float = 0.20
    nonisolated static let shadowAmount: Float = 1.5
    nonisolated static let noiseReductionLevel: Float = 0.5
    nonisolated static let noiseReductionSharpness: Float = 0.4
}

@Observable
@MainActor
final class LowLightManager: NSObject {
    private(set) var isLowLight: Bool = false
    private(set) var isTorchActive: Bool = false

    private weak var observedDevice: AVCaptureDevice?
    private var isoObservation: NSKeyValueObservation?
    private(set) var lastISO: Float = 0

    private var isTorchSuppressedByBattery: Bool = false

    override init() {
        super.init()
        observeBatteryLevel()
    }

    nonisolated deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startMonitoring(device: AVCaptureDevice) {
        stopMonitoring()
        observedDevice = device

        isoObservation = device.observe(\.iso, options: [.new]) { [weak self] _, change in
            guard let self, let iso = change.newValue else { return }
            // KVO 콜백은 임의 스레드 — MainActor로 전환하여 상태 업데이트
            Task { @MainActor [weak self] in
                self?.handleISOChange(iso)
            }
        }
    }

    func stopMonitoring() {
        isoObservation?.invalidate()
        isoObservation = nil
        observedDevice = nil
    }

    private func handleISOChange(_ iso: Float) {
        lastISO = iso
        isLowLight = iso > LowLightThreshold.lowLight
    }

    func configure(device: AVCaptureDevice, on sessionQueue: DispatchQueue) {
        let suppressed = isTorchSuppressedByBattery
        // AVCaptureDevice는 non-Sendable이지만 sessionQueue 전용 사용이므로 안전
        nonisolated(unsafe) let capturedDevice = device
        sessionQueue.async { [weak self] in
            Self.applyLowLightSettings(to: capturedDevice, suppressTorch: suppressed) { torchOn in
                Task { @MainActor [weak self] in
                    self?.isTorchActive = torchOn
                }
            }
        }
    }

    func reset(device: AVCaptureDevice, on sessionQueue: DispatchQueue) {
        // AVCaptureDevice는 non-Sendable이지만 sessionQueue 전용 사용이므로 안전
        nonisolated(unsafe) let capturedDevice = device
        sessionQueue.async { [weak self] in
            Self.restoreSettings(on: capturedDevice)
            Task { @MainActor [weak self] in
                self?.isTorchActive = false
            }
        }
    }

    private nonisolated static func applyLowLightSettings(
        to device: AVCaptureDevice,
        suppressTorch: Bool,
        torchStateHandler: @escaping (Bool) -> Void
    ) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let biasClamped = min(device.maxExposureTargetBias, LowLightThreshold.maxExposureBias)
            device.setExposureTargetBias(biasClamped)

            let currentISO = device.iso
            let needsTorch = currentISO > LowLightThreshold.torchActivation && !suppressTorch

            if needsTorch {
                if device.hasTorch, device.isTorchAvailable {
                    do {
                        try device.setTorchModeOn(level: LowLightThreshold.torchLevel)
                        torchStateHandler(true)
                    } catch {}
                }
            } else if device.hasTorch, device.isTorchAvailable, device.torchMode != .off {
                // 밝아졌거나 배터리 부족 → 토치 끔
                device.torchMode = .off
                torchStateHandler(false)
            }
        } catch {}
    }

    private nonisolated static func restoreSettings(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.setExposureTargetBias(0.0)
            if device.hasTorch, device.isTorchAvailable, device.torchMode != .off {
                device.torchMode = .off
            }
        } catch {}
    }

    func disableTorch(device: AVCaptureDevice, on sessionQueue: DispatchQueue) {
        // AVCaptureDevice는 non-Sendable이지만 sessionQueue 전용 사용이므로 안전
        nonisolated(unsafe) let capturedDevice = device
        sessionQueue.async { [weak self] in
            do {
                try capturedDevice.lockForConfiguration()
                defer { capturedDevice.unlockForConfiguration() }
                if capturedDevice.hasTorch, capturedDevice.isTorchAvailable {
                    capturedDevice.torchMode = .off
                }
            } catch {}
            Task { @MainActor [weak self] in
                self?.isTorchActive = false
            }
        }
    }

    func enhance(image: CIImage) -> CIImage {
        var result = image
        result = applyShadowHighlight(to: result) ?? result
        if lastISO > LowLightThreshold.veryDarkNoise {
            result = applyNoiseReduction(to: result) ?? result
        }
        return result
    }

    private func applyShadowHighlight(to image: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(LowLightThreshold.shadowAmount, forKey: "inputShadowAmount")
        return filter.outputImage
    }

    private func applyNoiseReduction(to image: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CINoiseReduction") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(LowLightThreshold.noiseReductionLevel, forKey: "inputNoiseLevel")
        filter.setValue(LowLightThreshold.noiseReductionSharpness, forKey: "inputSharpness")
        return filter.outputImage
    }

    func apply(to settings: AVCapturePhotoSettings) {
        // Deep Fusion / Smart HDR 활성화를 위해 최고 화질 우선
        settings.photoQualityPrioritization = .quality
    }

    private func observeBatteryLevel() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        updateBatterySuppression()
    }

    @objc private nonisolated func handleBatteryLevelDidChange(_: Notification) {
        Task { @MainActor [weak self] in
            self?.updateBatterySuppression()
        }
    }

    private func updateBatterySuppression() {
        let level = UIDevice.current.batteryLevel
        // batteryLevel은 모니터링 불가 시 -1 반환 — 이 경우 억제하지 않음
        let isLow = level >= 0 && level < LowLightThreshold.batteryDisableThreshold
        isTorchSuppressedByBattery = isLow

        if isLow, isTorchActive, let device = observedDevice {
            forceDisableTorch(on: device)
        }
    }

    private func forceDisableTorch(on device: AVCaptureDevice) {
        // AVCaptureDevice는 non-Sendable이지만 batteryQueue 전용 사용이므로 안전
        nonisolated(unsafe) let capturedDevice = device
        let batteryQueue = DispatchQueue(label: "com.pairshot.lowlight.battery", qos: .utility)
        batteryQueue.async { [weak self] in
            Self.restoreSettings(on: capturedDevice)
            Task { @MainActor [weak self] in
                self?.isTorchActive = false
            }
        }
    }
}
