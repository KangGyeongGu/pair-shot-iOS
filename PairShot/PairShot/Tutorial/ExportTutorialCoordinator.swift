import Foundation
import Observation

@MainActor
@Observable
final class ExportTutorialCoordinator {
    private(set) var current: ExportTutorialStep?

    var isActive: Bool {
        current != nil
    }

    static var totalSteps: Int {
        ExportTutorialStep.allCases.count
    }

    init(current: ExportTutorialStep? = nil) {
        self.current = current
    }

    func start() {
        current = .includes
    }

    func advance() {
        guard let cur = current, let nxt = ExportTutorialStep(rawValue: cur.rawValue + 1) else {
            current = nil
            return
        }
        current = nxt
    }

    func cancel() {
        current = nil
    }

    func progress(for step: ExportTutorialStep) -> (current: Int, total: Int) {
        (current: step.rawValue + 1, total: Self.totalSteps)
    }
}
