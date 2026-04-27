import Foundation
import Observation

@MainActor
@Observable
final class CameraSessionHolder {
    let session: CameraSession
    var cachedExposureRange: ClosedRange<Float>?
    var availablePresets: [ZoomPresetSpec] = []
    var firstSwitchOver: Double = 1.0

    init() {
        session = CameraSession()
    }

    func refreshCapabilities() async {
        cachedExposureRange = await session.exposureBiasRange
        availablePresets = await session.availablePresets
        firstSwitchOver = await session.firstSwitchOver
    }
}
