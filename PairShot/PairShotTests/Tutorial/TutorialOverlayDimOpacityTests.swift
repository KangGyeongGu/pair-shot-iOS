@testable import PairShot
import Testing

@MainActor
struct TutorialOverlayDimOpacityTests {
    @Test
    func `카메라 실습 step 은 dim opacity 0 을 반환한다`() {
        let dimlessSteps: [TutorialStep] = [
            .captureGuidePortrait,
            .captureGuideLeft,
            .captureGuideRight,
            .afterCameraGuide,
            .backToHome,
            .backToHome2,
        ]
        for step in dimlessSteps {
            #expect(TutorialOverlay.dimOpacity(for: step) == 0, "step \(step) must have dim 0")
        }
    }

    @Test
    func `홈 list step 은 표준 dim opacity 를 유지한다`() {
        let listSteps: [TutorialStep] = [
            .tapPairCard,
            .enterSelectionMode,
            .selectionShare,
            .selectionSave,
            .selectionDelete,
            .selectionExport,
            .goSettings,
        ]
        for step in listSteps {
            #expect(TutorialOverlay.dimOpacity(for: step) > 0, "step \(step) must dim")
        }
    }

    @Test
    func `done step 은 표준 dim opacity 를 유지한다`() {
        #expect(TutorialOverlay.dimOpacity(for: .done) > 0)
    }
}
