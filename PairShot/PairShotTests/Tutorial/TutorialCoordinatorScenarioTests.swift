@testable import PairShot
import Testing

@MainActor
struct TutorialCoordinatorScenarioTests {
    @Test
    func `시나리오 1~5 step 순서 확인 (homeCaptureHighlight → backToHome2)`() throws {
        let coord = TutorialCoordinator()
        coord.start()
        let expected: [TutorialStep] = [
            .homeCaptureHighlight,
            .captureGuidePortrait,
            .captureGuideLeft,
            .captureGuideRight,
            .backToHome,
            .tapPairCard,
            .afterCameraGuide,
            .backToHome2,
        ]
        var actual: [TutorialStep] = []
        try actual.append(#require(coord.current))
        for _ in 0 ..< (expected.count - 1) {
            coord.advance()
            try actual.append(#require(coord.current))
        }
        #expect(actual == expected)
    }

    @Test
    func `advanceIfPostureMatches 는 portrait step + portrait roll 시 advance`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(advanced)
        #expect(coord.current == .captureGuideLeft)
    }

    @Test
    func `advanceIfPostureMatches 는 portrait step + landscape roll 시 advance 안 함`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 90)
        #expect(!advanced)
        #expect(coord.current == .captureGuidePortrait)
    }

    @Test
    func `advanceIfPostureMatches 는 left step + left roll 시 advance`() {
        let coord = TutorialCoordinator(current: .captureGuideLeft)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: -90)
        #expect(advanced)
        #expect(coord.current == .captureGuideRight)
    }

    @Test
    func `advanceIfPostureMatches 는 right step + right roll 시 advance`() {
        let coord = TutorialCoordinator(current: .captureGuideRight)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 90)
        #expect(advanced)
        #expect(coord.current == .backToHome)
    }

    @Test
    func `advanceIfPostureMatches 는 자세 요구 안 하는 step 에서 advance 안 함`() {
        let coord = TutorialCoordinator(current: .homeCaptureHighlight)
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(!advanced)
        #expect(coord.current == .homeCaptureHighlight)
    }

    @Test
    func `advanceIfPostureMatches 는 nil current 에서 false`() {
        let coord = TutorialCoordinator()
        let advanced = coord.advanceIfPostureMatches(rollDegrees: 0)
        #expect(!advanced)
        #expect(coord.current == nil)
    }

    @Test
    func `isAtStep 정확성`() {
        let coord = TutorialCoordinator(current: .tapPairCard)
        #expect(coord.isAtStep(.tapPairCard))
        #expect(!coord.isAtStep(.backToHome))
    }

    @Test
    func `isAtStep 은 nil current 에서 false`() {
        let coord = TutorialCoordinator()
        #expect(!coord.isAtStep(.homeCaptureHighlight))
    }
}
