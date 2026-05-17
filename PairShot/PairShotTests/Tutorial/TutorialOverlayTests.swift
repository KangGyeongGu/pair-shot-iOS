@testable import PairShot
import SwiftUI
import Testing

@MainActor
struct TutorialOverlayTests {
    @Test
    func `SpotlightAnchorKey defaultValue 는 빈 사전`() {
        #expect(SpotlightAnchorKey.defaultValue.isEmpty)
    }

    @Test
    func `SpotlightAnchorKey reduce 는 빈 nextValue 입력 시 기존 값을 유지한다`() {
        var acc: [String: Anchor<CGRect>] = SpotlightAnchorKey.defaultValue
        SpotlightAnchorKey.reduce(value: &acc) { [:] }
        #expect(acc.isEmpty)
    }

    @Test
    func `TutorialStepCopy 는 모달 표시 step 에 비어있지 않은 텍스트 제공`() {
        let hiddenModalSteps: Set<TutorialStep> = [.afterCameraInProgress]
        for step in TutorialStep.allCases where !hiddenModalSteps.contains(step) {
            let text = TutorialStepCopy.text(for: step)
            #expect(!text.isEmpty, "step \(step) text must not be empty")
        }
    }

    @Test
    func `TutorialStepCopy 매핑은 멱등하다`() {
        let first = TutorialStepCopy.text(for: .captureGuidePortrait)
        let second = TutorialStepCopy.text(for: .captureGuidePortrait)
        #expect(first == second)
    }

    @Test
    func `TutorialStepCopy 는 모든 step 에 대해 매핑 호출 가능`() {
        for step in TutorialStep.allCases {
            _ = TutorialStepCopy.text(for: step)
        }
    }

    @Test
    func `TutorialCoordinator 기본 상태에서 isActive false`() {
        let coord = TutorialCoordinator()
        #expect(coord.isActive == false)
    }

    @Test
    func `TutorialCoordinator start 후 isActive true`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(coord.isActive == true)
    }

    @Test
    func `TutorialOverlay 인스턴스 생성은 가능하다`() {
        let view = TutorialOverlay(anchors: [:])
        _ = view
    }

    @Test
    func `tutorialOverlay modifier 는 어떤 View 에도 적용 가능`() {
        let view = Color.clear.tutorialOverlay()
        _ = view
    }

    @Test
    func `tutorialAnchor modifier 는 어떤 View 에도 적용 가능`() {
        let view = Color.clear.tutorialAnchor("test_id")
        _ = view
    }

    @Test
    func `TutorialMessageModal 구성 가능하다`() {
        let view = TutorialMessageModal(
            text: "테스트",
            progress: (current: 1, total: 13),
            showsSkip: true,
            showsNext: true,
            nextButtonLabelKey: "tutorial_button_next",
            phoneOrientationAngle: nil,
            placement: .bottom,
            targetRect: CGRect(x: 100, y: 100, width: 80, height: 80),
            containerSize: CGSize(width: 400, height: 800),
            safeAreaInsets: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
            onSkip: {},
            onNext: {},
        )
        _ = view
    }
}
