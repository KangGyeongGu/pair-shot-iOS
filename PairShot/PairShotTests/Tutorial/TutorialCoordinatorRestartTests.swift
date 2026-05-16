@testable import PairShot
import Testing

@MainActor
struct TutorialCoordinatorRestartTests {
    @Test
    func `advanceIfPostureMatches 는 단일 진입점으로 동작 (portrait)`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(advanced == true)
        #expect(coord.current == .captureGuideLeft)
    }

    @Test
    func `advanceIfPostureMatches 는 단일 진입점으로 동작 (mismatch)`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 90)
        #expect(advanced == false)
        #expect(coord.current == .captureGuidePortrait)
    }

    @Test
    func `restart 후 advanceIfPostureMatches 는 첫 step 에서는 자세 미요구`() {
        let coord = TutorialCoordinator()
        coord.start()
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(advanced == false)
        #expect(coord.current == .homeCaptureHighlight)
    }

    @Test
    func `restart 후 4번 advance 시 다시 backToHome 도달 (회귀 0 검증)`() {
        let coord = TutorialCoordinator()
        coord.start()
        coord.advance()
        coord.advance()
        coord.advance()
        coord.advance()
        #expect(coord.current == .backToHome)
        coord.restart()
        #expect(coord.current == .homeCaptureHighlight)
        coord.advance()
        coord.advance()
        coord.advance()
        coord.advance()
        #expect(coord.current == .backToHome)
    }
}
