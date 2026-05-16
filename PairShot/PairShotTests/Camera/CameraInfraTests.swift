@preconcurrency import AVFoundation
@testable import PairShot
import Testing

struct CameraInfraTests {
    @Test
    func `ResponsiveCaptureOptions.apply is a no-op on a fresh, unconfigured output`() {
        let output = AVCapturePhotoOutput()
        ResponsiveCaptureOptions.apply(to: output)
        #expect(output.isZeroShutterLagEnabled == output.isZeroShutterLagSupported)
        #expect(output.isResponsiveCaptureEnabled == output.isResponsiveCaptureSupported)
    }

    @MainActor
    @Test
    func `CameraReadinessAdapter forwards captureReadiness changes`() async {
        let output = AVCapturePhotoOutput()
        let coordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: output)
        let collector = ReadinessCollector()
        let adapter = CameraReadinessAdapter { readiness in
            collector.append(readiness)
        }
        coordinator.delegate = adapter
        adapter.readinessCoordinator(coordinator, captureReadinessDidChange: .ready)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(collector.values.contains(.ready))
        _ = coordinator
    }

    @MainActor
    @Test
    func `CameraSession exposes its underlying AVCaptureSession synchronously`() {
        let session = CameraSession()
        let captureSession: AVCaptureSession = session.captureSession
        #expect(captureSession === session.captureSession)
    }
}

@MainActor
private final class ReadinessCollector {
    var values: [AVCapturePhotoOutput.CaptureReadiness] = []

    func append(_ value: AVCapturePhotoOutput.CaptureReadiness) {
        values.append(value)
    }
}
