@preconcurrency import CoreMotion
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
    private let motionQueue: OperationQueue

    init(updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        manager = CMMotionManager()
        isManagerOwned = true
        motionQueue = OperationQueue()
        motionQueue.name = "com.pairshot.motion"
        motionQueue.qualityOfService = .utility
        motionQueue.maxConcurrentOperationCount = 1
    }

    init(manager: CMMotionManager, updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
        self.manager = manager
        isManagerOwned = false
        motionQueue = OperationQueue()
        motionQueue.name = "com.pairshot.motion"
        motionQueue.qualityOfService = .utility
        motionQueue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard !isStreaming else { return }
        guard manager.isDeviceMotionAvailable else {
            AppLogger.camera.info("MotionService: deviceMotion unavailable")
            return
        }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let motion else { return }
            let degrees = motion.attitude.roll * 180 / .pi
            Task { @MainActor [weak self] in
                self?.rollDegrees = degrees
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
}
