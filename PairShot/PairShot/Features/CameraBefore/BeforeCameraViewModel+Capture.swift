@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UIKit

extension BeforeCameraViewModel {
    func shutter() async {
        guard !isCapturing, session.captureReadiness == .ready else { return }
        if await shouldGateForPaywall() {
            snackbarQueue.enqueue(
                "settings_promotion_guide_daily_limit",
                variant: .info,
                debounceKey: "pro_gate_daily_limit",
            )
            showPaywall = true
            return
        }
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
        updateLastThumbnail(from: captured.data)
        eventsContinuation.yield(.snackbarSuccess)
        isCapturing = false
        await persistCapturedPhoto(captured)
    }

    func updateLastThumbnail(from data: Data) {
        guard let image = UIImage(data: data) else { return }
        lastThumbnail = image
    }

    private func shouldGateForPaywall() async -> Bool {
        guard refillPairId == nil else { return false }
        let isPro = membership.proIsActive
        let dayStart = PairLimitGate.startOfToday()
        let createdToday = await (try? pairRepo.countCreated(since: dayStart)) ?? 0
        return PairLimitGate.shouldGatePairCreation(isPro: isPro, todayCreatedCount: createdToday)
    }

    private func persistCapturedPhoto(_ captured: CapturedPhoto) async {
        let lensPosition = LensPosition.resolve(identifier: captured.lensIdentifier)
        let aspect = currentAspect
        let cameraSettings = CameraSettings(
            zoomFactor: captured.zoomFactor,
            lensPosition: lensPosition,
            aspectRatio: aspect,
        )
        do {
            if let refillPairId {
                _ = try await createPair.refillBefore(
                    pairId: refillPairId,
                    beforeData: captured.data,
                    beforeUTType: captured.utType,
                    cameraSettings: cameraSettings,
                    aspectRatio: aspect,
                    isDeferredProxy: captured.isDeferredProxy,
                )
                eventsContinuation.yield(.dismiss)
                return
            }
            let pair = try await createPair(
                beforeData: captured.data,
                beforeUTType: captured.utType,
                cameraSettings: cameraSettings,
                aspectRatio: aspect,
                isDeferredProxy: captured.isDeferredProxy,
            )
            if let albumId {
                try? await albumRepo.addPair(pairId: pair.id, toAlbum: albumId)
            }
            let nextPairs = await fetchSortedPendingPairs()
            withAnimation(.smooth) {
                pendingPairs = nextPairs
                selectedPairId = pair.id
            }
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
        }
    }

    private func fetchSortedPendingPairs() async -> [PhotoPair] {
        let all = await (try? pairRepo.fetchAll()) ?? []
        let scoped: [PhotoPair] = if let albumId {
            all.filter { $0.albumIds.contains(albumId) }
        } else { all }
        let filtered = scoped
            .filter { $0.afterPhotoLocalIdentifier == nil }
            .filter { $0.createdAt >= sessionStartedAt }
        return filtered.sorted { lhs, rhs in
            sortOrder == .newest ? lhs.createdAt > rhs.createdAt : lhs.createdAt < rhs.createdAt
        }
    }
}
