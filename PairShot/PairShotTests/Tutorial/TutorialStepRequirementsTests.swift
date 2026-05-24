@testable import PairShot
import SwiftUI
import Testing

struct TutorialStepRequirementsTests {
    @Test
    func `selection 4 step 모두 selection mode 요구`() {
        let selectionSteps: [TutorialStep] = [
            .selectionShare, .selectionSave, .selectionDelete, .selectionExport,
        ]
        for step in selectionSteps {
            #expect(TutorialStepRequirements.requiresSelectionMode(step))
        }
    }

    @Test
    func `selection step 이 아닌 step 은 selection mode 요구하지 않음`() {
        for step in TutorialStep.allCases {
            let isSelectionStep = [
                TutorialStep.selectionShare, .selectionSave, .selectionDelete, .selectionExport,
            ].contains(step)
            if !isSelectionStep {
                #expect(!TutorialStepRequirements.requiresSelectionMode(step))
            }
        }
    }

    @Test
    func `afterCameraStrip 계열 step 은 첫 페어 선택 요구`() {
        #expect(TutorialStepRequirements.requiresFirstPairSelected(.afterCameraStrip))
        #expect(TutorialStepRequirements.requiresFirstPairSelected(.afterCameraStripLongPressHint))
    }

    @Test
    func `strip 계열이 아닌 step 은 첫 페어 선택 요구하지 않음`() {
        for step in TutorialStep.allCases {
            let isStripStep = step == .afterCameraStrip || step == .afterCameraStripLongPressHint
            if !isStripStep {
                #expect(!TutorialStepRequirements.requiresFirstPairSelected(step))
            }
        }
    }

    @Test
    func `step 별 화면 매핑 — selection 류는 home`() {
        #expect(TutorialStepRequirements.screen(for: .selectionShare) == .home)
        #expect(TutorialStepRequirements.screen(for: .selectionExport) == .home)
        #expect(TutorialStepRequirements.screen(for: .tapPairCard) == .home)
    }

    @Test
    func `step 별 화면 매핑 — afterCamera 류는 afterCamera`() {
        #expect(TutorialStepRequirements.screen(for: .afterCameraStrip) == .afterCamera)
        #expect(TutorialStepRequirements.screen(for: .afterCameraGuide) == .afterCamera)
        #expect(TutorialStepRequirements.screen(for: .afterCameraInProgress) == .afterCamera)
    }

    @Test
    func `step 별 화면 매핑 — beforeCamera 류는 beforeCamera`() {
        #expect(TutorialStepRequirements.screen(for: .captureGuidePortrait) == .beforeCamera)
        #expect(TutorialStepRequirements.screen(for: .captureGuideLeft) == .beforeCamera)
        #expect(TutorialStepRequirements.screen(for: .backToHome) == .beforeCamera)
    }

    @Test
    func `done step 은 any 화면 (centered fallback)`() {
        #expect(TutorialStepRequirements.screen(for: .done) == .any)
    }
}

struct TutorialCoordinatorResumeTests {
    @Test
    func `resume at 중간 step — current 가 해당 step 으로 설정`() async {
        let coord = await TutorialCoordinator()
        await coord.resume(at: .afterCameraStrip)
        let current = await coord.current
        #expect(current == .afterCameraStrip)
    }

    @Test
    func `resume at done — current 변경 안 됨`() async {
        let coord = await TutorialCoordinator()
        await coord.resume(at: .done)
        let current = await coord.current
        #expect(current == nil)
    }
}

@MainActor
struct TutorialMessageModalLayoutTests {
    @Test
    func `cardMaxHeight — 컨테이너 작을 때 최소 120 clamp`() {
        let result = TutorialMessageModal.cardMaxHeight(
            containerSize: CGSize(width: 320, height: 100),
            safeAreaInsets: EdgeInsets(),
            edgePadding: 20,
        )
        #expect(result >= 120)
    }

    @Test
    func `cardMaxHeight — 일반 화면에서 70 percent ratio`() {
        let result = TutorialMessageModal.cardMaxHeight(
            containerSize: CGSize(width: 390, height: 844),
            safeAreaInsets: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
            edgePadding: 20,
        )
        let usable: CGFloat = 844 - 47 - 34 - 40
        #expect(abs(result - usable * 0.7) < 0.5)
    }

    @Test
    func `cardCenterY — spaceAbove spaceBelow 둘 다 부족 시 화면 중앙 fallback`() {
        let container = CGSize(width: 390, height: 400)
        let input = TutorialMessageModal.CardCenterYInput(
            placement: .top,
            targetRect: CGRect(x: 0, y: 100, width: 390, height: 200),
            containerSize: container,
            safeAreaInsets: EdgeInsets(),
            cardHeight: 350,
            gap: 36,
            edgePadding: 20,
        )
        let result = TutorialMessageModal.cardCenterY(input: input)
        #expect(abs(result - container.height / 2) < 1.0)
    }
}

struct AppTextSizeMappingTests {
    @Test
    func `4 단계 모두 unique 한 DynamicTypeSize 매핑`() {
        let mappings = AppTextSize.allCases.map(\.dynamicTypeSize)
        let unique = Set(mappings.map(\.hashValue))
        #expect(unique.count == AppTextSize.allCases.count)
    }

    @Test
    func `medium 이 default`() {
        #expect(AppTextSize.default == .medium)
    }
}
