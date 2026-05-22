import Foundation
@testable import PairShot
import Testing

@MainActor
struct RewardedAdManagerWaitTests {
    @Test
    func `waitForLoad 는 미로드 상태에서 sleeper 의 timeout 직후 false 를 반환한다`() async {
        let manager = RewardedAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )

        let result = await manager.waitForLoad(timeout: 0.2)

        #expect(result == false)
    }

    @Test
    func `presentForReward 는 미로드 시 sleeper 의 timeout 후 not-loaded 를 반환한다`() async {
        let manager = RewardedAdManager(
            trackingService: nil,
            tutorialCoordinator: nil,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        let outcome = await manager.presentForReward(
            .compositionSettings,
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
        )

        if case let .failed(reason) = outcome {
            #expect(reason == "not-loaded")
        } else {
            Issue.record("expected .failed(not-loaded), got \(outcome)")
        }
    }

    @Test
    func `presentForReward 는 튜토리얼 활성 시 sessionUnlocks 에 등록 후 granted 반환한다`() async {
        let coord = TutorialCoordinator()
        coord.start()
        let manager = RewardedAdManager(
            trackingService: nil,
            tutorialCoordinator: coord,
            sleeper: InstantSleeper(),
        )
        let coordinator = FullscreenAdCoordinator()

        let outcome = await manager.presentForReward(
            .compositionSettings,
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
        )

        #expect(outcome == .granted)
        #expect(manager.sessionUnlocks.contains(.compositionSettings))
    }
}
