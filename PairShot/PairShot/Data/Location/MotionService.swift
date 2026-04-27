import CoreMotion
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class MotionService {
    var rollDegrees: Double = 0

    private(set) var isStreaming: Bool = false

    let updateInterval: TimeInterval

    private let manager: CMMotionManager
    private let isManagerOwned: Bool

    init(updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        manager = CMMotionManager()
        isManagerOwned = true
    }

    init(manager: CMMotionManager, updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        self.manager = manager
        isManagerOwned = false
    }

    func start() {
        guard !isStreaming else { return }
        guard manager.isDeviceMotionAvailable else {
            AppLogger.camera.info("MotionService: deviceMotion unavailable")
            return
        }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            MainActor.assumeIsolated {
                self.rollDegrees = motion.attitude.roll * 180 / .pi
            }
        }
        isStreaming = true
    }

    func stop() {
        guard isStreaming else { return }
        manager.stopDeviceMotionUpdates()
        isStreaming = false
        rollDegrees = 0
    }

    func isLevel(tolerance: Double = 1.5) -> Bool {
        abs(rollDegrees) <= tolerance
    }

    deinit {
        if isManagerOwned, manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }
}
