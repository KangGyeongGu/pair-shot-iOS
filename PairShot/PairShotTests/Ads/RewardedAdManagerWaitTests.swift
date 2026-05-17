import Foundation
@testable import PairShot
import Testing

@MainActor
struct RewardedAdManagerWaitTests {
    @Test
    func `waitForLoad 는 미로드 상태에서 타임아웃 후 false 를 반환한다`() async {
        let manager = RewardedAdManager(trackingService: nil, tutorialCoordinator: nil)

        let start = Date()
        let result = await manager.waitForLoad(timeout: 0.2)
        let elapsed = Date().timeIntervalSince(start)

        #expect(result == false)
        #expect(elapsed >= 0.15)
        #expect(elapsed < 2)
    }

    @Test
    func `presentForReward 는 미로드 시 waitForLoad 후 not-loaded 를 반환한다`() async {
        let manager = RewardedAdManager(trackingService: nil, tutorialCoordinator: nil)
        let coordinator = FullscreenAdCoordinator()

        let start = Date()
        let outcome = await manager.presentForReward(
            .compositionSettings,
            from: nil,
            coordinator: coordinator,
            promotionStore: nil,
            subscriptionStore: nil,
            adUnitID: "test-unit",
        )
        let elapsed = Date().timeIntervalSince(start)

        if case let .failed(reason) = outcome {
            #expect(reason == "not-loaded")
        } else {
            Issue.record("expected .failed(not-loaded), got \(outcome)")
        }
        #expect(elapsed < 6)
    }

    @Test
    func `presentForReward 는 튜토리얼 활성 시 sessionUnlocks 에 등록 후 granted 반환한다`() async {
        let coord = TutorialCoordinator()
        coord.start()
        let manager = RewardedAdManager(trackingService: nil, tutorialCoordinator: coord)
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
