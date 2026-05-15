import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportCompletionCoordinatorTests {
    @Test("Register then notify invokes the registered closure")
    func registerThenNotifyInvokesClosure() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.notifyCompleted()

        #expect(callCount == 1)
    }

    @Test("Notify clears the pending closure so subsequent notifications are no-ops")
    func notifyClearsPendingClosure() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.notifyCompleted()
        coordinator.notifyCompleted()

        #expect(callCount == 1)
    }

    @Test("Notify without prior registration is a no-op")
    func notifyWithoutRegisterIsNoOp() {
        let coordinator = ExportCompletionCoordinator()

        coordinator.notifyCompleted()
    }

    @Test("Cancel pending prevents subsequent notification from invoking closure")
    func cancelPendingSuppressesNextNotification() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.cancelPending()
        coordinator.notifyCompleted()

        #expect(callCount == 0)
    }

    @Test("Second register replaces the first closure (single-slot invariant)")
    func registerReplacesPriorClosure() {
        let coordinator = ExportCompletionCoordinator()
        var firstCount = 0
        var secondCount = 0
        coordinator.register { firstCount += 1 }
        coordinator.register { secondCount += 1 }

        coordinator.notifyCompleted()

        #expect(firstCount == 0)
        #expect(secondCount == 1)
    }
}
