import Foundation

@MainActor
enum CaptureHaptics {
    static func success(_ haptics: HapticService) {
        haptics.notify(.success)
    }
}
