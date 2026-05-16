@preconcurrency import AVFoundation
import Foundation

nonisolated enum ZoomPresetBuilder {
    static func build(for device: AVCaptureDevice) -> [ZoomPresetSpec] {
        let minFactor = Double(device.minAvailableVideoZoomFactor)
        let maxFactor = Double(device.maxAvailableVideoZoomFactor)
        let switchovers = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { Double(truncating: $0) }
            .sorted()
        let secondaryNative = device.activeFormat.secondaryNativeResolutionZoomFactors
            .map { Double($0) }
            .sorted()
        let allFixedFactors = (switchovers + secondaryNative).sorted()
        let firstSwitch = switchovers.first ?? 1.0

        var presets: [ZoomPresetSpec] = []

        if minFactor < firstSwitch - 0.05 {
            presets.append(
                ZoomPresetSpec(
                    id: "uw",
                    factor: minFactor,
                    label: formatLabel(minFactor / firstSwitch),
                ),
            )
        }

        presets.append(ZoomPresetSpec(id: "w", factor: firstSwitch, label: "1x"))

        let twoX = firstSwitch * 2.0
        if twoX <= maxFactor + 0.05 {
            presets.append(ZoomPresetSpec(id: "2x", factor: twoX, label: "2x"))
        }

        if let topFactor = allFixedFactors.last, topFactor > twoX + 0.05 {
            presets.append(
                ZoomPresetSpec(
                    id: "tele",
                    factor: topFactor,
                    label: formatLabel(topFactor / firstSwitch),
                ),
            )
        }

        return presets
    }

    static func formatLabel(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded()))x"
        }
        return String(format: "%.1fx", value)
    }
}
