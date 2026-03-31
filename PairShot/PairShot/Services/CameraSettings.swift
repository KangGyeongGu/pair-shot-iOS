import AVFoundation
import Observation

enum AspectRatio: CaseIterable {
    case ratio4_3
    case ratio16_9
    case ratio1_1

    /// 프리뷰/저장 시 4:3 센서 출력에 적용할 정규화된 크롭 영역
    var cropRect: CGRect {
        switch self {
            case .ratio4_3:
                return CGRect(x: 0, y: 0, width: 1, height: 1)
            case .ratio16_9:
                // 4:3 → 16:9: 상하를 균등하게 잘라낸다
                // 4/3 비율 높이에서 16:9 비율 높이 비율: (4/3) / (16/9) = 3/4
                let height: CGFloat = 3.0 / 4.0
                let yOffset: CGFloat = (1.0 - height) / 2.0
                return CGRect(x: 0, y: yOffset, width: 1, height: height)
            case .ratio1_1:
                // 4:3 → 1:1: 좌우를 균등하게 잘라낸다
                let width: CGFloat = 3.0 / 4.0
                let xOffset: CGFloat = (1.0 - width) / 2.0
                return CGRect(x: xOffset, y: 0, width: width, height: 1)
        }
    }

    var displayName: String {
        switch self {
            case .ratio4_3: "4:3"
            case .ratio16_9: "16:9"
            case .ratio1_1: "1:1"
        }
    }
}

enum TimerDuration: CaseIterable {
    case off
    case threeSeconds
    case tenSeconds

    var seconds: Int {
        switch self {
            case .off: 0
            case .threeSeconds: 3
            case .tenSeconds: 10
        }
    }

    var displayName: String {
        switch self {
            case .off: "OFF"
            case .threeSeconds: "3s"
            case .tenSeconds: "10s"
        }
    }
}

@Observable
@MainActor
final class CameraSettings {
    private(set) var currentAspectRatio: AspectRatio = .ratio4_3
    private(set) var currentZoomFactor: CGFloat = 1.0
    var flashMode: AVCaptureDevice.FlashMode = .auto
    var isGridEnabled: Bool = false
    private(set) var timerDuration: TimerDuration = .off
    private(set) var isUsingFrontCamera: Bool = false
    private(set) var availableZoomFactors: [CGFloat] = [1.0]

    func cycleAspectRatio() {
        let all = AspectRatio.allCases
        guard let current = all.firstIndex(of: currentAspectRatio) else { return }
        currentAspectRatio = all[(current + 1) % all.count]
    }

    func cycleFlashMode() {
        switch flashMode {
            case .auto: flashMode = .on
            case .on: flashMode = .off
            case .off: flashMode = .auto
            @unknown default: flashMode = .auto
        }
    }

    func toggleGrid() {
        isGridEnabled.toggle()
    }

    func cycleTimer() {
        let all = TimerDuration.allCases
        guard let current = all.firstIndex(of: timerDuration) else { return }
        timerDuration = all[(current + 1) % all.count]
    }

    func setFrontCamera(_ isFront: Bool) {
        isUsingFrontCamera = isFront
    }

    /// 줌 배율을 변경하고 디바이스에 즉시(또는 애니메이션으로) 적용한다.
    ///
    /// - Parameters:
    ///   - factor: 목표 줌 배율
    ///   - device: 현재 활성 `AVCaptureDevice` — **반드시 sessionQueue에서 호출할 것**
    ///   - animated: `true`이면 `rampToVideoZoomFactor`로 부드럽게 전환
    ///
    /// > Warning: 이 메서드는 `device.lockForConfiguration()` 을 내부에서 처리한다.
    ///   호출자가 이미 잠근 상태라면 `animated: false` 로 직접 `videoZoomFactor` 를 설정하고
    ///   이 메서드 대신 `clampedZoomFactor(_:for:)` 를 활용할 것.
    nonisolated func setZoom(factor: CGFloat, on device: AVCaptureDevice, animated: Bool) {
        let clamped = clampedZoomFactor(factor, for: device)

        do {
            try device.lockForConfiguration()
            if animated {
                device.ramp(toVideoZoomFactor: clamped, withRate: 8.0)
            } else {
                device.videoZoomFactor = clamped
            }
            device.unlockForConfiguration()
        } catch {}

        // MainActor 상태를 별도 Task로 업데이트 (nonisolated 컨텍스트에서 호출 가능)
        Task { @MainActor [weak self] in
            self?.currentZoomFactor = clamped
        }
    }

    nonisolated func getAvailableZoomFactors(from device: AVCaptureDevice) -> [CGFloat] {
        let switchPoints = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }

        var factors = Set<CGFloat>([1.0])
        switchPoints.forEach { factors.insert($0) }

        let min = device.minAvailableVideoZoomFactor
        let max = device.maxAvailableVideoZoomFactor

        let sorted = factors
            .filter { $0 >= min && $0 <= max }
            .sorted()

        return sorted.isEmpty ? [1.0] : sorted
    }

    nonisolated func updateAvailableZoomFactors(from device: AVCaptureDevice) {
        let factors = getAvailableZoomFactors(from: device)
        Task { @MainActor [weak self] in
            self?.availableZoomFactors = factors
        }
    }

    nonisolated func clampedZoomFactor(_ factor: CGFloat, for device: AVCaptureDevice) -> CGFloat {
        let minFactor = device.minAvailableVideoZoomFactor
        let maxFactor = device.maxAvailableVideoZoomFactor
        return min(max(factor, minFactor), maxFactor)
    }
}
