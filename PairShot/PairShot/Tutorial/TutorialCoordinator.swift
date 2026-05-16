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
}
