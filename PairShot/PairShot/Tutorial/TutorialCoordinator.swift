import Foundation
import Observation

@MainActor
@Observable
final class TutorialCoordinator {
    private(set) var current: TutorialStep?

    var isActive: Bool {
        current != nil && current != .done
    }

    var mode: TutorialMode {
        current.map { .running($0) } ?? .off
    }

    init(current: TutorialStep? = nil) {
        self.current = current
    }

    func start() {
        current = .homeCaptureHighlight
    }

    func advance() {
        guard let cur = current, let nxt = TutorialStep(rawValue: cur.rawValue + 1) else { return }
        current = nxt
    }

    func cancel() {
        current = nil
    }

    func complete() {
        current = .done
    }

    @discardableResult
    func advanceIfPostureMatches(rollDegrees: Double) -> Bool {
        guard let step = current else { return false }
        guard TutorialMotionGuide.postureRequiringStep(step) else { return false }
        let posture = TutorialMotionGuide.posture(forRollDegrees: rollDegrees)
        guard TutorialMotionGuide.matches(step: step, posture: posture) else { return false }
        advance()
        return true
    }

    func isAtStep(_ step: TutorialStep) -> Bool {
        current == step
    }
}
