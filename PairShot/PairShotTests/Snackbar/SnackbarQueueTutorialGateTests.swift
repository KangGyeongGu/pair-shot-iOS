import Foundation
@testable import PairShot
import Testing

@MainActor
struct SnackbarQueueTutorialGateTests {
    @Test
    func `init 시 주입한 tutorialCoordinator 가 활성이면 enqueue 차단`() {
        let coord = TutorialCoordinator()
        coord.start()
        let queue = SnackbarQueue(tutorialCoordinator: coord)

        queue.enqueue(.watermarkSetupRequired)

        #expect(queue.current == nil)
    }

    @Test
    func `init 시 주입한 tutorialCoordinator 가 비활성이면 enqueue 통과`() {
        let coord = TutorialCoordinator()
        let queue = SnackbarQueue(tutorialCoordinator: coord)

        queue.enqueue(.watermarkSetupRequired)

        #expect(queue.current != nil)
    }

    @Test
    func `tutorialCoordinator nil 일 때 enqueue 통과`() {
        let queue = SnackbarQueue()

        queue.enqueue(.watermarkSetupRequired)

        #expect(queue.current != nil)
    }

    @Test
    func `튜토리얼 활성 중 enqueueProgress 도 차단되어 handle 만 반환`() {
        let coord = TutorialCoordinator()
        coord.start()
        let queue = SnackbarQueue(tutorialCoordinator: coord)

        let handle = queue.enqueueProgress(.share, token: "tok-1")

        #expect(handle.token == "tok-1")
        #expect(queue.current == nil)
    }
}
