@testable import PairShot
import Testing

struct ReviewRequestGateTests {
    @Test
    func `실행 횟수 3 미만 → 호출 안 함 (사용자가 앱 가치 못 느낀 시점 ambush 방지)`() {
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 0, didRequest: false, tutorialActive: false))
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 1, didRequest: false, tutorialActive: false))
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 2, didRequest: false, tutorialActive: false))
    }

    @Test
    func `실행 횟수 정확히 3 + 미요청 + 튜토리얼 비활성 → 호출 함 (정상 진입)`() {
        #expect(ReviewRequestGate.shouldRequest(launchCount: 3, didRequest: false, tutorialActive: false))
    }

    @Test
    func `이미 요청한 적 있으면 차단 (실행 횟수가 늘어나도 재호출 안 함)`() {
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 5, didRequest: true, tutorialActive: false))
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 100, didRequest: true, tutorialActive: false))
    }

    @Test
    func `튜토리얼 진행 중이면 차단 (앱 가치 체험 전 ambush 방지)`() {
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 3, didRequest: false, tutorialActive: true))
        #expect(!ReviewRequestGate.shouldRequest(launchCount: 10, didRequest: false, tutorialActive: true))
    }
}
