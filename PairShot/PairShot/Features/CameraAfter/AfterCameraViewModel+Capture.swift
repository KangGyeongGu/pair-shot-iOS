@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension AfterCameraViewModel {
    func shutter() async {
        guard !isCapturing, session.captureReadiness == .ready, let pair = currentPair else { return }
        isCapturing = true
        let captured: CapturedPhoto
        do {
            let metadata = ExifGPSBuilder.metadata(from: location.currentLocation)
            captured = try await session.capturePhoto(metadata: metadata)
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
            isCapturing = false
            return
        }
        let capturedPairId = pair.id
        do {
            _ = try await persistAfter(
                pairId: capturedPairId,
                afterData: captured.data,
                afterUTType: captured.utType,
                aspectRatio: currentAspect,
                isDeferredProxy: captured.isDeferredProxy,
            )
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
            isCapturing = false
            return
        }
        if tutorialCoordinator?.isAtStep(.afterCameraGuide) == true {
            tutorialCoordinator?.advance()
        }
        eventsContinuation.yield(.snackbarSuccess)
        contractPairsAndAdvance(removing: capturedPairId)
        isCapturing = false
    }

    func contractPairsAndAdvance(removing capturedPairId: UUID) {
        let capturedIndex = pairs.firstIndex(where: { $0.id == capturedPairId }) ?? 0
        withAnimation(.smooth) {
            pairs.removeAll { $0.id == capturedPairId }
            pendingPairCount = max(0, pendingPairCount - 1)
            completedPairCount += 1
            if pairs.isEmpty {
                currentPair = nil
                ghostImageData = nil
                allCompleted = true
            } else {
                let targetIndex = min(capturedIndex, pairs.count - 1)
                adopt(pair: pairs[targetIndex])
            }
        }
        if allCompleted {
            advanceTutorialOnAllCompleted()
            eventsContinuation.yield(.snackbarAllCompleted)
            scheduleAllCompletedDismiss()
        }
    }

    func advanceTutorialOnAllCompleted() {
        guard let tutorialCoordinator else { return }
        if tutorialCoordinator.isAtStep(.afterCameraGuide)
            || tutorialCoordinator.isAtStep(.afterCameraInProgress)
        {
            tutorialCoordinator.advance()
            if tutorialCoordinator.isAtStep(.afterCameraInProgress) {
                tutorialCoordinator.advance()
            }
        }
    }

    func persistAfter(
        pairId: UUID,
        afterData: Data,
        afterUTType: UTType,
        aspectRatio: AspectRatio,
        isDeferredProxy: Bool,
    ) async throws -> PhotoPair {
        try await captureAfter(
            pairId: pairId,
            afterData: afterData,
            afterUTType: afterUTType,
            aspectRatio: aspectRatio,
            isDeferredProxy: isDeferredProxy,
        )
    }

    static func captureErrorText(for error: Error) -> String {
        AfterCameraCaptureErrorMessages.text(for: error)
    }
}
