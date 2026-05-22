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
        #expect(coord.current == .captureGuidePortrait)
        #expect(coord.isActive == true)
        #expect(coord.mode == .running(.captureGuidePortrait))
    }

    @Test
    func `advance() 호출 시 .done 에 도달하고 isActive == false`() {
        let coord = TutorialCoordinator()
        coord.start()
        let advanceCount = TutorialStep.allCases.count - 1
        for _ in 0 ..< advanceCount {
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
        #expect(coord.mode == .running(.captureGuidePortrait))
        coord.advance()
        #expect(coord.mode == .running(.captureGuideLeft))
        coord.complete()
        #expect(coord.mode == .running(.done))
    }

    @Test
    func `step rawValue 순서가 끊김 없이 연속`() {
        let all = TutorialStep.allCases
        #expect(all.count == 17)
        #expect(all.first == .captureGuidePortrait)
        #expect(all.last == .done)
        for (idx, step) in all.enumerated() {
            #expect(step.rawValue == idx)
        }
    }
}
