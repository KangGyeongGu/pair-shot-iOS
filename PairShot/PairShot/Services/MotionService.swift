import CoreMotion
import Foundation
import Observation

/// Streams the device's roll angle (degrees) for the level-indicator overlay.
///
/// Only `attitude.roll` is consumed — we do not read pitch/yaw or gravity, in
/// keeping with the architectural invariant that sensor input is limited to
/// roll.
///
/// Polling runs at 1Hz (deviceMotion update interval = 1.0s). The lower the
/// frequency the less battery we spend and the less Info.plist NSMotionUsage
/// risk we take; users only need a coarse "are we level?" hint.
@MainActor
@Observable
final class MotionService {
    /// Latest roll in **degrees**, signed. Positive = rolled clockwise (right
    /// edge down) from the screen's perspective when held in portrait.
    var rollDegrees: Double = 0

    /// `true` when CoreMotion is actively delivering updates.
    private(set) var isStreaming: Bool = false

    /// Update interval in seconds. Public for tests.
    let updateInterval: TimeInterval

    private let manager: CMMotionManager
    private let isManagerOwned: Bool

    /// Default initialiser — owns its own `CMMotionManager`.
    /// Use `init(manager:updateInterval:)` in tests to inject a stub.
    init(updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        manager = CMMotionManager()
        isManagerOwned = true
    }

    /// Test seam: inject a (real or fake) `CMMotionManager`.
    init(manager: CMMotionManager, updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        self.manager = manager
        isManagerOwned = false
    }

    /// Starts polling. No-op on simulators where deviceMotion isn't available.
    /// Idempotent — calling twice is safe.
    func start() {
        guard !isStreaming else { return }
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // The block is delivered on the main queue, so we can hop onto
            // `MainActor` synchronously to update observable state.
            MainActor.assumeIsolated {
                // CMAttitude.roll is in radians; convert to degrees for the UI.
                self.rollDegrees = motion.attitude.roll * 180 / .pi
            }
        }
        isStreaming = true
    }

    /// Stops polling. Safe to call when not streaming.
    func stop() {
        guard isStreaming else { return }
        manager.stopDeviceMotionUpdates()
        isStreaming = false
        rollDegrees = 0
    }

    /// Convenience: `true` when the device is within `tolerance` degrees of
    /// horizontal. Used to highlight the level indicator green.
    func isLevel(tolerance: Double = 1.5) -> Bool {
        abs(rollDegrees) <= tolerance
    }

    deinit {
        if isManagerOwned, manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }
}
