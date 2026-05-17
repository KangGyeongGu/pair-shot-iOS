@testable import PairShot
import Testing

@MainActor
struct TutorialStepProgressTests {
    @Test
    func `totalProgressSteps 는 done 제외 allCases 개수`() {
        #expect(TutorialCoordinator.totalProgressSteps == TutorialStep.allCases.count - 1)
        #expect(TutorialCoordinator.totalProgressSteps == 13)
    }

    @Test
    func `첫 step 진행 카운트는 1 over total`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        let progress = coord.progress(for: .captureGuidePortrait)
        #expect(progress?.current == 1)
        #expect(progress?.total == TutorialCoordinator.totalProgressSteps)
    }

    @Test
    func `마지막 직전 step 진행 카운트는 total over total`() {
        let lastBeforeDone = TutorialStep.allCases[TutorialStep.allCases.count - 2]
        let coord = TutorialCoordinator(current: lastBeforeDone)
        let progress = coord.progress(for: lastBeforeDone)
        #expect(progress?.current == TutorialCoordinator.totalProgressSteps)
        #expect(progress?.total == TutorialCoordinator.totalProgressSteps)
    }

    @Test
    func `done step 진행 카운트는 nil`() {
        let coord = TutorialCoordinator(current: .done)
        #expect(coord.progress(for: .done) == nil)
    }

    @Test
    func `중간 step 진행 카운트는 index plus 1`() {
        let mid = TutorialStep.tapPairCard
        let coord = TutorialCoordinator(current: mid)
        let progress = coord.progress(for: mid)
        let expectedIndex = (TutorialStep.allCases.firstIndex(of: mid) ?? 0) + 1
        #expect(progress?.current == expectedIndex)
    }
}
