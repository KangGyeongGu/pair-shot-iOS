import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Errors surfaced from the After-capture flow. Mirrors `CaptureActionError`
/// (Before) so callers can branch on the same shape.
enum AfterCaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
    /// The pair is already complete — caller asked to capture after for a pair
    /// that already has an `afterPath`. Caller should advance instead of retry.
    case alreadyComplete
}

/// Result of one After capture: the updated `PhotoPair` plus the next pair the
/// caller should jump to (or `nil` when no more `pendingAfter` pairs remain).
struct AfterCaptureOutcome {
    let completedPair: PhotoPair
    let nextPendingPair: PhotoPair?
}

/// Orchestrates one After capture: actor → JPEG bytes → file system →
/// SwiftData transition (`status = .complete`, `afterPath`, `afterCapturedAt`).
/// Pure logic so it's straightforward to unit-test against an in-memory
/// `ModelContext` plus a temp-folder `PhotoStorageService`.
struct AfterCaptureCoordinator {
    let session: CameraSession
    let storage: PhotoStorageService
    /// P8.2 — filename prefix forwarded to ``PhotoStorageService.saveAfterJPEG``.
    /// See ``BeforeCaptureCoordinator`` for the rationale on why the JPEG
    /// quality knob lives on the composite path rather than the capture path.
    let fileNamePrefix: String

    init(
        session: CameraSession,
        storage: PhotoStorageService,
        fileNamePrefix: String = ""
    ) {
        self.session = session
        self.storage = storage
        self.fileNamePrefix = fileNamePrefix
    }

    /// Captures one After photo for `pair`, persists it, and computes the next
    /// `pendingAfter` pair from the same project (oldest `beforeCapturedAt`
    /// first — same order `AfterCameraPairLoader` uses).
    @discardableResult
    func captureAfter(
        for pair: PhotoPair,
        into context: ModelContext
    ) async throws -> AfterCaptureOutcome {
        guard pair.status == .pendingAfter, pair.afterPath == nil else {
            throw AfterCaptureActionError.alreadyComplete
        }

        let captured: CapturedPhoto
        do {
            captured = try await session.capturePhoto()
        } catch let err as CameraSessionError {
            throw AfterCaptureActionError.session(err)
        } catch {
            throw AfterCaptureActionError.session(.captureFailed(error.localizedDescription))
        }

        let relativePath: String
        do {
            relativePath = try storage.saveAfterJPEG(
                captured.jpegData,
                fileNamePrefix: fileNamePrefix
            )
        } catch {
            throw AfterCaptureActionError.storage(error)
        }

        pair.afterPath = relativePath
        pair.afterCapturedAt = captured.capturedAt
        pair.status = .complete
        pair.project?.updatedAt = .now

        do {
            try context.save()
        } catch {
            throw AfterCaptureActionError.persistence(error)
        }

        await CaptureHaptics.shutter()

        let next = AfterCameraPairLoader.nextPendingPair(after: pair)
        return AfterCaptureOutcome(completedPair: pair, nextPendingPair: next)
    }
}

/// Pure helpers for picking the next `pendingAfter` pair. Static so they're
/// trivially unit-testable without spinning up a SwiftData stack — they only
/// touch in-memory `[PhotoPair]`.
enum AfterCameraPairLoader {
    /// Pending pairs from `project`, ordered oldest-Before-first so the user
    /// completes them in the order they were captured.
    static func pendingPairs(in project: Project) -> [PhotoPair] {
        project.pairs
            .filter { $0.status == .pendingAfter && $0.afterPath == nil }
            .sorted { $0.beforeCapturedAt < $1.beforeCapturedAt }
    }

    /// First pending pair to show on entry. Returns `nil` when the project is
    /// fully completed — caller should auto-dismiss.
    static func firstPendingPair(in project: Project) -> PhotoPair? {
        pendingPairs(in: project).first
    }

    /// Next pending pair after `current` was just completed. Skips `current`
    /// itself in case it hasn't been re-fetched yet. Returns `nil` when no
    /// more remain.
    static func nextPendingPair(after current: PhotoPair) -> PhotoPair? {
        guard let project = current.project else { return nil }
        return project.pairs
            .filter { $0.id != current.id && $0.status == .pendingAfter && $0.afterPath == nil }
            .min { $0.beforeCapturedAt < $1.beforeCapturedAt }
    }
}
