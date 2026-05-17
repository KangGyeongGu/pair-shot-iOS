@testable import PairShot
import SwiftUI
import Testing

@MainActor
struct TutorialMessageModalSkipNextTests {
    private static let defaultContainer = CGSize(width: 400, height: 800)
    private static let defaultRect = CGRect(x: 100, y: 700, width: 80, height: 80)
    private static let defaultInsets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)

    @Test
    func `skip 콜백은 호출 시 카운트 증가`() {
        var skipCount = 0
        let modal = TutorialMessageModal(
            text: "x",
            progress: (current: 1, total: 13),
            showsSkip: true,
            showsNext: true,
            nextButtonLabelKey: "tutorial_button_next",
            phoneOrientationAngle: nil,
            placement: .top,
            targetRect: Self.defaultRect,
            containerSize: Self.defaultContainer,
            safeAreaInsets: Self.defaultInsets,
            onSkip: { skipCount += 1 },
            onNext: {},
        )
        _ = modal
        modal.onSkip()
        modal.onSkip()
        #expect(skipCount == 2)
    }

    @Test
    func `next 콜백은 호출 시 카운트 증가`() {
        var nextCount = 0
        let modal = TutorialMessageModal(
            text: "x",
            progress: (current: 1, total: 13),
            showsSkip: true,
            showsNext: true,
            nextButtonLabelKey: "tutorial_button_next",
            phoneOrientationAngle: nil,
            placement: .top,
            targetRect: Self.defaultRect,
            containerSize: Self.defaultContainer,
            safeAreaInsets: Self.defaultInsets,
            onSkip: {},
            onNext: { nextCount += 1 },
        )
        modal.onNext()
        #expect(nextCount == 1)
    }

    @Test
    func `showsNext 는 선택 모드 4 옵션 step 및 done 에서 true`() {
        #expect(TutorialMessageModal.showsNext(for: .selectionShare) == true)
        #expect(TutorialMessageModal.showsNext(for: .selectionSave) == true)
        #expect(TutorialMessageModal.showsNext(for: .selectionDelete) == true)
        #expect(TutorialMessageModal.showsNext(for: .selectionExport) == true)
        #expect(TutorialMessageModal.showsNext(for: .done) == true)
        #expect(TutorialMessageModal.showsNext(for: .captureGuidePortrait) == false)
        #expect(TutorialMessageModal.showsNext(for: .captureGuideLeft) == false)
        #expect(TutorialMessageModal.showsNext(for: .captureGuideRight) == false)
        #expect(TutorialMessageModal.showsNext(for: .backToHome) == false)
        #expect(TutorialMessageModal.showsNext(for: .tapPairCard) == false)
        #expect(TutorialMessageModal.showsNext(for: .afterCameraGuide) == false)
        #expect(TutorialMessageModal.showsNext(for: .backToHome2) == false)
        #expect(TutorialMessageModal.showsNext(for: .enterSelectionMode) == false)
        #expect(TutorialMessageModal.showsNext(for: .goSettings) == false)
    }

    @Test
    func `placement 은 anchor 가 화면 하단이면 top`() {
        let container = CGSize(width: 400, height: 800)
        let bottomRect = CGRect(x: 100, y: 700, width: 80, height: 80)
        #expect(TutorialMessageModal.placement(for: bottomRect, containerSize: container) == .top)
    }

    @Test
    func `placement 은 anchor 가 화면 상단이면 bottom`() {
        let container = CGSize(width: 400, height: 800)
        let topRect = CGRect(x: 100, y: 100, width: 80, height: 80)
        #expect(TutorialMessageModal.placement(for: topRect, containerSize: container) == .bottom)
    }

    @Test
    func `tutorial_button_skip 키 localize 가능`() {
        let label = String(localized: "tutorial_button_skip")
        #expect(!label.isEmpty)
        #expect(label != "tutorial_button_skip")
    }

    @Test
    func `tutorial_button_next 키 localize 가능`() {
        let label = String(localized: "tutorial_button_next")
        #expect(!label.isEmpty)
        #expect(label != "tutorial_button_next")
    }

    @Test
    func `cancel 호출은 current 를 nil 로 만든다 (skip 동작 시뮬)`() {
        let coord = TutorialCoordinator(current: .captureGuidePortrait)
        coord.cancel()
        #expect(coord.current == nil)
        #expect(coord.isActive == false)
    }

    @Test
    func `cardCenterY top placement 은 anchor 위쪽에 배치된다`() {
        let container = CGSize(width: 400, height: 800)
        let shutterRect = CGRect(x: 160, y: 700, width: 80, height: 80)
        let insets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
        let cardHeight: CGFloat = 240

        let y = TutorialMessageModal.cardCenterY(input: TutorialMessageModal.CardCenterYInput(
            placement: .top,
            targetRect: shutterRect,
            containerSize: container,
            safeAreaInsets: insets,
            cardHeight: cardHeight,
            gap: 16,
            edgePadding: 20,
        ))

        #expect(y + cardHeight / 2 <= shutterRect.minY)
        #expect(y - cardHeight / 2 >= insets.top + 20 - 0.01)
    }

    @Test
    func `cardCenterY bottom placement 은 anchor 아래쪽에 배치된다`() {
        let container = CGSize(width: 400, height: 800)
        let topRect = CGRect(x: 160, y: 100, width: 80, height: 80)
        let insets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
        let cardHeight: CGFloat = 240

        let y = TutorialMessageModal.cardCenterY(input: TutorialMessageModal.CardCenterYInput(
            placement: .bottom,
            targetRect: topRect,
            containerSize: container,
            safeAreaInsets: insets,
            cardHeight: cardHeight,
            gap: 16,
            edgePadding: 20,
        ))

        #expect(y - cardHeight / 2 >= topRect.maxY)
        #expect(y + cardHeight / 2 <= container.height - insets.bottom - 20 + 0.01)
    }

    @Test
    func `cardCenterY 작은 화면에서 safe area top 한계를 침범하지 않는다`() {
        let container = CGSize(width: 320, height: 568)
        let shutterRect = CGRect(x: 120, y: 470, width: 80, height: 80)
        let insets = EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        let cardHeight: CGFloat = 260

        let y = TutorialMessageModal.cardCenterY(input: TutorialMessageModal.CardCenterYInput(
            placement: .top,
            targetRect: shutterRect,
            containerSize: container,
            safeAreaInsets: insets,
            cardHeight: cardHeight,
            gap: 16,
            edgePadding: 20,
        ))

        #expect(y - cardHeight / 2 >= insets.top + 20 - 0.01)
        #expect(y + cardHeight / 2 <= container.height - insets.bottom - 20 + 0.01)
    }

    @Test
    func `cardCenterY 카드 공간 부족 시 가용 공간 큰 쪽으로 폴백한다`() {
        let container = CGSize(width: 400, height: 800)
        let midRectHighSpaceBelow = CGRect(x: 160, y: 200, width: 80, height: 80)
        let insets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
        let cardHeight: CGFloat = 240

        let y = TutorialMessageModal.cardCenterY(input: TutorialMessageModal.CardCenterYInput(
            placement: .top,
            targetRect: midRectHighSpaceBelow,
            containerSize: container,
            safeAreaInsets: insets,
            cardHeight: cardHeight,
            gap: 16,
            edgePadding: 20,
        ))

        #expect(y >= midRectHighSpaceBelow.maxY)
    }
}
