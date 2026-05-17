import Foundation
import Observation

@MainActor
@Observable
final class TutorialCoordinator {
    static var totalProgressSteps: Int {
        TutorialStep.allCases.count - 1
    }

    private(set) var current: TutorialStep?
    var cleanupService: TutorialCleanupService?

    var isActive: Bool {
        current != nil && current != .done
    }

    var mode: TutorialMode {
        current.map { .running($0) } ?? .off
    }

    init(current: TutorialStep? = nil, cleanupService: TutorialCleanupService? = nil) {
        self.current = current
        self.cleanupService = cleanupService
    }

    func start() {
        current = .captureGuidePortrait
    }

    func restart() {
        current = nil
        runCleanupAsync()
        start()
    }

    func advance() {
        guard let cur = current, let nxt = TutorialStep(rawValue: cur.rawValue + 1) else { return }
        current = nxt
    }

    func cancel() {
        current = nil
        runCleanupAsync()
    }

    func complete() {
        current = .done
    }

    func finishAndCleanup() {
        complete()
        runCleanupAsync { [weak self] in
            self?.current = nil
        }
    }

    private func runCleanupAsync(_ continuation: (@MainActor () -> Void)? = nil) {
        let service = cleanupService
        Task {
            if let service {
                try? await service.deleteAllTutorialPairs()
            }
            continuation?()
        }
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

    func progress(for step: TutorialStep) -> (current: Int, total: Int)? {
        guard step != .done else { return nil }
        guard let index = TutorialStep.allCases.firstIndex(of: step) else { return nil }
        return (current: index + 1, total: Self.totalProgressSteps)
    }
}
