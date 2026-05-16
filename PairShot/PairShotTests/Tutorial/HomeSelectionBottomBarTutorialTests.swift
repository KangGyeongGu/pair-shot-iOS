@testable import PairShot
import Testing

@MainActor
struct HomeSelectionBottomBarTutorialTests {
    @Test
    func `튜토리얼 active 시 share 콜백은 advance 만 수행`() {
        let coord = TutorialCoordinator(current: .selectionShare)
        var actionInvoked = false
        let onShare = makeGuardedAction(coord: coord) { actionInvoked = true }

        onShare()

        #expect(coord.current == .selectionSave)
        #expect(!actionInvoked)
    }

    @Test
    func `튜토리얼 active 시 save 콜백은 advance 만 수행`() {
        let coord = TutorialCoordinator(current: .selectionSave)
        var actionInvoked = false
        let onSave = makeGuardedAction(coord: coord) { actionInvoked = true }

        onSave()

        #expect(coord.current == .selectionDelete)
        #expect(!actionInvoked)
    }

    @Test
    func `튜토리얼 active 시 delete 콜백은 advance 만 수행`() {
        let coord = TutorialCoordinator(current: .selectionDelete)
        var actionInvoked = false
        let onDelete = makeGuardedAction(coord: coord) { actionInvoked = true }

        onDelete()

        #expect(coord.current == .selectionExport)
        #expect(!actionInvoked)
    }

    @Test
    func `튜토리얼 active 시 export 콜백은 advance 만 수행`() {
        let coord = TutorialCoordinator(current: .selectionExport)
        var actionInvoked = false
        let onExport = makeGuardedAction(coord: coord) { actionInvoked = true }

        onExport()

        #expect(coord.current == .saveToDevice)
        #expect(!actionInvoked)
    }

    @Test
    func `튜토리얼 비활성 시 콜백은 본래 액션을 실행`() {
        let coord = TutorialCoordinator()
        var actionInvoked = false
        let onShare = makeGuardedAction(coord: coord) { actionInvoked = true }

        onShare()

        #expect(coord.current == nil)
        #expect(actionInvoked)
    }

    @Test
    func `done 상태에서 콜백은 본래 액션을 실행`() {
        let coord = TutorialCoordinator(current: .done)
        var actionInvoked = false
        let onShare = makeGuardedAction(coord: coord) { actionInvoked = true }

        onShare()

        #expect(actionInvoked)
    }

    private func makeGuardedAction(
        coord: TutorialCoordinator,
        baseAction: @escaping () -> Void,
    ) -> () -> Void {
        {
            if coord.isActive { coord.advance(); return }
            baseAction()
        }
    }
}
