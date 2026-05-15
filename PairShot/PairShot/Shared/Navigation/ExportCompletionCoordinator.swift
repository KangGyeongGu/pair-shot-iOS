import Foundation
import Observation

@MainActor
@Observable
final class ExportCompletionCoordinator {
    private var pendingClosure: (() -> Void)?

    init() {}

    func register(onCompletion: @escaping () -> Void) {
        pendingClosure = onCompletion
    }

    func notifyCompleted() {
        let closure = pendingClosure
        pendingClosure = nil
        closure?()
    }

    func cancelPending() {
        pendingClosure = nil
    }
}
