import Foundation
import Observation

/// Audit-B — extracted from ``BeforeCameraView`` so the view stays
/// under the 250-line cap (`.claude/refs/swiftui-patterns.md`) once
/// the scenePhase background/foreground handlers were added.
///
/// Holds the camera ``CameraSession`` actor plus cached, view-side
/// capability snapshots (exposure bias range, supported zoom presets)
/// so SwiftUI gesture closures and label predicates can read them
/// synchronously without an `await` hop.
///
/// Shared by ``BeforeCameraView`` and ``AfterCameraView`` — neither
/// view should construct its own snapshot cache directly.
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
        // SwiftUI calls this from view body — read the cached snapshot.
        // Captured via MainActor.assumeIsolated to satisfy strict concurrency.
        MainActor.assumeIsolated { supportedPresets.contains(preset) }
    }
}
