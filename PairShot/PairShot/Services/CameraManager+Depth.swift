@preconcurrency import AVFoundation

extension CameraManager {
    func addOutput(_ output: AVCaptureOutput, on queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            captureSession.commitConfiguration()
        }
    }

    func removeOutput(_ output: AVCaptureOutput, on queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            captureSession.removeOutput(output)
            captureSession.commitConfiguration()
        }
    }

    func addVideoDataOutput(_ output: AVCaptureVideoDataOutput, on queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            captureSession.commitConfiguration()
        }
    }
}
