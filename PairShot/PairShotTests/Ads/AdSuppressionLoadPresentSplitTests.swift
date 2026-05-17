import Foundation
@testable import PairShot
import Testing

@MainActor
struct AdSuppressionLoadPresentSplitTests {
    @Test
    func `isLoadSuppressed 는 튜토리얼 활성 여부와 무관하게 동작한다`() {
        #expect(
            AdSuppression.isLoadSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
            ) == false,
        )
    }

    @Test
    func `isLoadSuppressed 는 nil 스토어에서 false 를 반환한다`() {
        #expect(
            AdSuppression.isLoadSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
            ) == false,
        )
    }

    @Test
    func `present 시 isSuppressed 는 튜토리얼 활성에서 true 를 반환한다`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(
            AdSuppression.isSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
                tutorialCoordinator: coord,
            ) == true,
        )
    }

    @Test
    func `load 시 isLoadSuppressed 는 튜토리얼 활성에서도 false 를 반환한다`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(coord.isActive == true)
        #expect(
            AdSuppression.isLoadSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
            ) == false,
        )
    }
}
