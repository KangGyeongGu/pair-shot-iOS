@preconcurrency import AVFoundation
import Observation

@Observable
@MainActor
final class DepthCaptureService: NSObject {
    private(set) var centerDepth: Double = 0.0
    private(set) var isLiDARAvailable: Bool = false
    private(set) var isStreaming: Bool = false

    @ObservationIgnored
    private nonisolated(unsafe) var depthOutput: AVCaptureDepthDataOutput?
    @ObservationIgnored
    private nonisolated(unsafe) var calibrationData: AVCameraCalibrationData?
    private let processingQueue = DispatchQueue(label: "com.pairshot.depth", qos: .userInitiated)

    override init() {
        super.init()
        checkLiDARAvailability()
    }

    private func checkLiDARAvailability() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInLiDARDepthCamera],
            mediaType: .video,
            position: .back
        )
        isLiDARAvailable = !discovery.devices.isEmpty
    }

    var focalLengthPixels: Double? {
        guard let cal = calibrationData else { return nil }
        return Double(cal.intrinsicMatrix.columns.0.x)
    }

    func configure(session: AVCaptureSession, queue: DispatchQueue) {
        guard isLiDARAvailable else { return }

        queue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            let output = AVCaptureDepthDataOutput()
            output.isFilteringEnabled = false
            output.setDelegate(self, callbackQueue: processingQueue)

            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            if let connection = output.connection(with: .depthData) {
                connection.isEnabled = true
            }

            Task { @MainActor in
                self.depthOutput = output
                self.isStreaming = true
            }
        }
    }

    func stopStreaming() {
        isStreaming = false
    }
}

extension DepthCaptureService: AVCaptureDepthDataOutputDelegate {
    nonisolated func depthDataOutput(
        _: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp _: CMTime,
        connection _: AVCaptureConnection
    ) {
        let converted = depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData
            : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)

        let depthMap = converted.depthDataMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size

        let centerX = width / 2
        let centerY = height / 2
        let centerValue = Double(floatBuffer[centerY * floatsPerRow + centerX])

        let cal = converted.cameraCalibrationData

        Task { @MainActor [weak self] in
            guard let self, centerValue.isFinite, centerValue > 0 else { return }
            let alpha = 0.15
            centerDepth = centerDepth == 0 ? centerValue : alpha * centerValue + (1 - alpha) * centerDepth
            if let cal { calibrationData = cal }
        }
    }
}
