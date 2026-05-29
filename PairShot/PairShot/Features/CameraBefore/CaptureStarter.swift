import Foundation

@MainActor
protocol CaptureStarter: AnyObject {
    var membership: Membership { get }
    var snackbarQueue: SnackbarQueue { get }
    var pairRepo: PhotoPairRepository { get }
    var showPaywall: Bool { get set }
    var beforeCameraTargetPairId: UUID? { get set }
    var showBeforeCamera: Bool { get set }
}

extension CaptureStarter {
    func startCapture() async {
        if !membership.proIsActive {
            let count = await todayCreatedCountOrZero()
            guard count < PairLimitGate.freeTierDailyLimit else {
                snackbarQueue.enqueue(
                    .dailyLimitGate,
                    debounceKey: "pro_gate_daily_limit",
                )
                showPaywall = true
                return
            }
        }
        beforeCameraTargetPairId = nil
        showBeforeCamera = true
    }

    func todayCreatedCountOrZero() async -> Int {
        let dayStart = PairLimitGate.startOfToday()
        return await (try? pairRepo.countCreated(since: dayStart)) ?? 0
    }
}
