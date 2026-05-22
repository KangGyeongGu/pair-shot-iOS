import Foundation
@testable import PairShot
import Testing

@MainActor
struct AppOpenAdManagerWaitTests {
    @Test
    func `로딩되지 않은 상태에서 presentIfReady 는 sleeper timeout 후 false 를 반환한다`() async {
        let manager = AppOpenAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        let result = await manager.presentIfReady(
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
            now: .now,
        )

        #expect(result == false)
    }
}
