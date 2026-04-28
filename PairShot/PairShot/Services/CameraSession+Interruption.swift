@preconcurrency import AVFoundation
import Foundation
import OSLog

final class InterruptionObserverBox: @unchecked Sendable {
    nonisolated(unsafe) var observers: [NSObjectProtocol] = []
    nonisolated init() {}

    nonisolated func cleanup() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
}

extension CameraSession {
    nonisolated func registerInterruptionObservers() {
        let session = box.session
        let observerBox = observerBox
        let center = NotificationCenter.default
        let interrupted = center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { notification in
            if let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
               let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue)
            {
                AppLogger.camera.info("Capture session interrupted: reason \(reason.rawValue, privacy: .public)")
            } else {
                AppLogger.camera.info("Capture session interrupted: reason unknown")
            }
        }
        let resumed = center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.resumeAfterInterruption() }
        }
        let runtimeError = center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            let description = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?
                .localizedDescription ?? "unknown"
            AppLogger.camera.error("Capture session runtime error: \(description, privacy: .public)")
            Task { await self.resumeAfterRuntimeError() }
        }
        observerBox.observers = [interrupted, resumed, runtimeError]
    }

    func resumeAfterInterruption() async {
        guard didConfigure, hasInputInternal else { return }
        let session = box.session
        await runOnSessionQueueVoid {
            guard !session.isRunning else { return }
            session.startRunning()
        }
        AppLogger.camera.info("Capture session resumed after interruption")
    }

    func resumeAfterRuntimeError() async {
        guard didConfigure, hasInputInternal else { return }
        let session = box.session
        await runOnSessionQueueVoid {
            if session.isRunning {
                session.stopRunning()
            }
            session.startRunning()
        }
        AppLogger.camera.info("Capture session resumed after runtime error")
    }
}
