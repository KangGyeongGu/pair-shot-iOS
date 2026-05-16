import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportCompletionCoordinatorTests {
    @Test
    func `Register then notify invokes the registered closure`() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.notifyCompleted()

        #expect(callCount == 1)
    }

    @Test
    func `Notify clears the pending closure so subsequent notifications are no-ops`() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.notifyCompleted()
        coordinator.notifyCompleted()

        #expect(callCount == 1)
    }

    @Test
    func `Notify without prior registration is a no-op`() {
        let coordinator = ExportCompletionCoordinator()

        coordinator.notifyCompleted()
    }

    @Test
    func `Cancel pending prevents subsequent notification from invoking closure`() {
        let coordinator = ExportCompletionCoordinator()
        var callCount = 0
        coordinator.register { callCount += 1 }

        coordinator.cancelPending()
        coordinator.notifyCompleted()

        #expect(callCount == 0)
    }

    @Test
    func `Second register replaces the first closure (single-slot invariant)`() {
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
