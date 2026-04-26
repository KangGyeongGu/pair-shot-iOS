import Foundation
import Observation

@MainActor
@Observable
final class CameraSessionHolder {
    let session: CameraSession
    var cachedExposureRange: ClosedRange<Float>?
    private var supportedPresets: Set<ZoomPreset> = []

    init() {
        session = CameraSession()
    }

    func refreshCapabilities() async {
        cachedExposureRange = await session.exposureBiasRange

        var supported: Set<ZoomPreset> = []
        for preset in ZoomPreset.allCases where await session.isPresetSupported(preset) {
            supported.insert(preset)
        }
        supportedPresets = supported
    }

    nonisolated func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        MainActor.assumeIsolated { supportedPresets.contains(preset) }
    }
}
