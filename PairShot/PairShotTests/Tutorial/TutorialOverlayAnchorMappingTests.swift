@testable import PairShot
import Testing

@MainActor
struct TutorialOverlayAnchorMappingTests {
    @Test
    func `AnchorID 상수들은 고유 문자열`() {
        let ids = [
            TutorialAnchorID.cameraShutter,
            TutorialAnchorID.cameraHomeButton,
            TutorialAnchorID.homeFirstPairCard,
            TutorialAnchorID.afterShutter,
            TutorialAnchorID.afterHomeButton,
            TutorialAnchorID.afterStrip,
            TutorialAnchorID.afterActiveCard,
        ]
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(!id.isEmpty)
        }
    }

    @Test
    func `cameraShutter id 는 namespace 형식`() {
        #expect(TutorialAnchorID.cameraShutter == "camera.shutter")
        #expect(TutorialAnchorID.cameraHomeButton == "camera.homeButton")
        #expect(TutorialAnchorID.homeFirstPairCard == "home.firstPairCard")
        #expect(TutorialAnchorID.afterShutter == "after.shutter")
        #expect(TutorialAnchorID.afterHomeButton == "after.homeButton")
        #expect(TutorialAnchorID.afterStrip == "after.strip")
        #expect(TutorialAnchorID.afterActiveCard == "after.activeCard")
    }

    @Test
    func `step copy 는 P3 step 모두 비어있지 않음`() {
        let p3Steps: [TutorialStep] = [
            .captureGuidePortrait,
            .captureGuideLeft,
            .captureGuideRight,
            .backToHome,
            .tapPairCard,
            .afterCameraStrip,
            .afterCameraStripLongPressHint,
            .afterCameraGuide,
            .backToHome2,
        ]
        for step in p3Steps {
            #expect(!TutorialStepCopy.text(for: step).isEmpty)
        }
    }
}
