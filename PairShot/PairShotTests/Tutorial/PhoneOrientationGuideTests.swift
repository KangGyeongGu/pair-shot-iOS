@testable import PairShot
import SwiftUI
import Testing

@MainActor
struct PhoneOrientationGuideTests {
    @Test
    func `captureGuidePortrait targetRotation 은 작은 양수`() {
        let rotation = PhoneOrientationGuide.targetRotation(for: .captureGuidePortrait)
        #expect(rotation == .degrees(5))
    }

    @Test
    func `captureGuideLeft targetRotation 은 음수 90도`() {
        let rotation = PhoneOrientationGuide.targetRotation(for: .captureGuideLeft)
        #expect(rotation == .degrees(-90))
    }

    @Test
    func `captureGuideRight targetRotation 은 양수 90도`() {
        let rotation = PhoneOrientationGuide.targetRotation(for: .captureGuideRight)
        #expect(rotation == .degrees(90))
    }

    @Test
    func `자세 가이드 외 step 의 targetRotation 은 nil`() {
        let nonPostureSteps: [TutorialStep] = [
            .backToHome,
            .tapPairCard,
            .afterCameraGuide,
            .backToHome2,
            .enterSelectionMode,
            .selectionShare,
            .selectionSave,
            .selectionDelete,
            .selectionExport,
            .goSettings,
            .done,
        ]
        for step in nonPostureSteps {
            #expect(
                PhoneOrientationGuide.targetRotation(for: step) == nil,
                "step \(step) should not show orientation guide",
            )
        }
    }

    @Test
    func `PhoneOrientationGuide 인스턴스 생성 가능`() {
        let view = PhoneOrientationGuide(targetRotation: .degrees(-90))
        _ = view
    }
}
