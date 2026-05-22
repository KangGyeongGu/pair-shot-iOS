import Foundation
@testable import PairShot
import Testing

@MainActor
struct AppOpenAdManagerFirstForegroundTests {
    @Test
    func `firstForegroundFired 는 초기값 false`() {
        let manager = AppOpenAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )
        #expect(manager.firstForegroundFired == false)
    }

    @Test
    func `presentColdStartIfReady 첫 호출은 firstForegroundFired 를 true 로 설정한다`() async {
        let manager = AppOpenAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        _ = await manager.presentColdStartIfReady(
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
            loadTimeout: 0.1,
            now: .now,
        )

        #expect(manager.firstForegroundFired == true)
    }

    @Test
    func `presentColdStartIfReady 두 번째 호출은 즉시 false 를 반환한다 (멱등성)`() async {
        let manager = AppOpenAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        _ = await manager.presentColdStartIfReady(
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
            loadTimeout: 0.1,
            now: .now,
        )

        let result = await manager.presentColdStartIfReady(
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
            loadTimeout: 5,
            now: .now,
        )

        #expect(result == false)
    }

    @Test
    func `presentColdStartIfReady 는 튜토리얼 활성 시 false 를 반환하지만 firstForegroundFired 는 소비된다`() async {
        let coord = TutorialCoordinator()
        coord.start()
        let manager = AppOpenAdManager(
            trackingService: nil,
            tutorialCoordinator: coord,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        let result = await manager.presentColdStartIfReady(
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
            loadTimeout: 0.1,
            now: .now,
        )

        #expect(result == false)
        #expect(manager.firstForegroundFired == true)
    }
}
