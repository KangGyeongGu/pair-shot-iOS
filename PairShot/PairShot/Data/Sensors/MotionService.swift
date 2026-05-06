@preconcurrency import CoreMotion
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class MotionService {
    var rollDegrees: Double = 0
    var screenRotationDegrees: Double = 90

    private(set) var isStreaming: Bool = false

    let updateInterval: TimeInterval

    private let manager: CMMotionManager
    private let motionQueue: OperationQueue
    private var subscriberCount: Int = 0

    init(updateInterval: TimeInterval = 0.05) {
        self.updateInterval = updateInterval
        manager = CMMotionManager()
        motionQueue = OperationQueue()
        motionQueue.name = "com.pairshot.motion"
        motionQueue.qualityOfService = .utility
        motionQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }

    func start() {
        subscriberCount += 1
        guard !isStreaming else { return }
        guard manager.isDeviceMotionAvailable else {
            AppLogger.camera.info("MotionService: deviceMotion unavailable")
            return
        }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: motionQueue) { @Sendable [weak self] motion, _ in
            guard let motion else { return }
            let rollDegrees = motion.attitude.roll * 180 / .pi
            let rawAngle = atan2(motion.gravity.x, motion.gravity.y) * 180 / .pi
            let normalized = (rawAngle - 90 + 360).truncatingRemainder(dividingBy: 360)
            Task { @MainActor [weak self] in
                self?.rollDegrees = rollDegrees
                self?.screenRotationDegrees = normalized
            }
        }
        isStreaming = true
    }

    func stop() {
        guard subscriberCount > 0 else { return }
        subscriberCount -= 1
        guard subscriberCount == 0, isStreaming else { return }
        manager.stopDeviceMotionUpdates()
        isStreaming = false
        rollDegrees = 0
        screenRotationDegrees = 90
    }

    func isLevel(tolerance: Double = 1.5) -> Bool {
        abs(rollDegrees) <= tolerance
    }
}
