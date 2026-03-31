import AVFoundation
import UIKit

/// CameraManager의 공개 인터페이스 — 테스트 가능성 및 의존성 주입을 위한 프로토콜
@MainActor
protocol CameraServiceProtocol: AnyObject {
    var isSessionRunning: Bool { get }
    var isCameraAuthorized: Bool { get }
    var capturedPhoto: UIImage? { get }

    func requestAuthorization() async -> Bool
    func startSession()
    func stopSession()
    func capturePhoto(projectId: UUID, pairId: UUID)
    func switchCamera()
}
