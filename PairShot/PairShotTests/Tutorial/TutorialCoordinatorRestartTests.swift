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
    func `restart 후 첫 step 은 captureGuidePortrait 이며 자세 검증 step`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(coord.current == .captureGuidePortrait)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(advanced == true)
        #expect(coord.current == .captureGuideLeft)
    }

    @Test
    func `restart 후 3번 advance 시 backToHome 도달 (회귀 0 검증)`() async {
        let coord = TutorialCoordinator()
        coord.start()
        coord.advance()
        coord.advance()
        coord.advance()
        #expect(coord.current == .backToHome)
        coord.restart()
        await Task.yield()
        await Task.yield()
        #expect(coord.current == .captureGuidePortrait)
        coord.advance()
        coord.advance()
        coord.advance()
        #expect(coord.current == .backToHome)
    }
}
