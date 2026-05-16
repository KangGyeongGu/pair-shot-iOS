@testable import PairShot
import Testing

@MainActor
struct TutorialCoordinatorTests {
    @Test
    func `초기 상태는 비활성`() {
        let coord = TutorialCoordinator()
        #expect(coord.current == nil)
        #expect(coord.isActive == false)
        #expect(coord.mode == .off)
    }

    @Test
    func `start() 호출 시 첫 step 진입`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(coord.current == .homeCaptureHighlight)
        #expect(coord.isActive == true)
        #expect(coord.mode == .running(.homeCaptureHighlight))
    }

    @Test
    func `advance() 16회 호출 시 .done 에 도달하고 isActive == false`() {
        let coord = TutorialCoordinator()
        coord.start()
        for _ in 0 ..< 15 {
            coord.advance()
        }
        #expect(coord.current == .done)
        #expect(coord.isActive == false)
    }

    @Test
    func `done 상태에서 advance() 는 no-op`() {
        let coord = TutorialCoordinator()
        coord.complete()
        #expect(coord.current == .done)
        coord.advance()
        #expect(coord.current == .done)
    }

    @Test
    func `cancel() 호출 시 nil 로 복귀`() {
        let coord = TutorialCoordinator()
        coord.start()
        coord.advance()
        coord.cancel()
        #expect(coord.current == nil)
        #expect(coord.isActive == false)
        #expect(coord.mode == .off)
    }

    @Test
    func `mode 는 current 와 동기화된다`() {
        let coord = TutorialCoordinator()
        #expect(coord.mode == .off)
        coord.start()
        #expect(coord.mode == .running(.homeCaptureHighlight))
        coord.advance()
        #expect(coord.mode == .running(.captureGuidePortrait))
        coord.complete()
        #expect(coord.mode == .running(.done))
    }

    @Test
    func `step rawValue 순서가 16개로 끊김 없이 연속`() {
        let all = TutorialStep.allCases
        #expect(all.count == 16)
        #expect(all.first == .homeCaptureHighlight)
        #expect(all.last == .done)
        for (idx, step) in all.enumerated() {
            #expect(step.rawValue == idx)
        }
    }
}
