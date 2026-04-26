import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Errors surfaced from the Before-capture flow.
enum CaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
}

/// Orchestrates one Before capture: actor → JPEG bytes → file system → SwiftData.
/// Pure logic so it's straightforward to unit-test against an in-memory
/// `ModelContext` plus a temp-folder `PhotoStorageService`.
struct BeforeCaptureCoordinator {
    let session: CameraSession
    let storage: PhotoStorageService
    /// P8.2 — optional `AppSettings` source. The capture pipeline still uses
    /// the system JPEG produced by AVFoundation (the camera respects its own
    /// internal quality knobs), but the *filename* prefix from settings is
    /// applied here. Re-encoding with `jpegQuality` would lose EXIF metadata
    /// the AVFoundation pipeline embeds, so the quality knob currently rides
    /// the composite renderer instead — see CompositeRenderer.makeComposite.
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

    /// Captures one Before photo and inserts a `PhotoPair(status: .pendingAfter)`
    /// linked to `project`. Returns the inserted `PhotoPair` for the caller to
    /// surface (e.g. flash thumbnail).
    ///
    /// Audit-C — haptic feedback is **not** emitted here. The view owns the
    /// shutter UX: `.heavy` impact when the user presses the shutter,
    /// `.success` notification once this coordinator returns. Emitting from
    /// inside the coordinator caused a double-fire (see
    /// `HapticDoubleFireTests`).
    @discardableResult
    func captureBefore(project: Project, into context: ModelContext) async throws -> PhotoPair {
        let captured: CapturedPhoto
        do {
            captured = try await session.capturePhoto()
        } catch let err as CameraSessionError {
            throw CaptureActionError.session(err)
        } catch {
            throw CaptureActionError.session(.captureFailed(error.localizedDescription))
        }

        let relativePath: String
        do {
            relativePath = try storage.saveBeforeJPEG(
                captured.jpegData,
                fileNamePrefix: fileNamePrefix
            )
        } catch {
            throw CaptureActionError.storage(error)
        }

        let pair = PhotoPair(
            beforePath: relativePath,
            beforeZoomFactor: captured.zoomFactor,
            beforeLensIdentifier: captured.lensIdentifier,
            capturedAt: captured.capturedAt,
            project: project
        )
        context.insert(pair)
        project.updatedAt = .now

        do {
            try context.save()
        } catch {
            throw CaptureActionError.persistence(error)
        }

        return pair
    }
}

/// Tiny haptics façade kept for source compatibility — call sites
/// that previously imported `CaptureHaptics` continue to work.
/// P9.1: routed through ``HapticService`` so the impact / notification
/// styles stay centralised. Direct `UIImpactFeedbackGenerator` and
/// `UINotificationFeedbackGenerator` calls were removed.
@MainActor
enum CaptureHaptics {
    static func shutter() async {
        HapticService.shared.impact(.heavy)
    }

    static func success() {
        HapticService.shared.notify(.success)
    }
}

/// SwiftUI shutter button. Round, white, 72pt — Android parity.
struct CaptureShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .opacity(isCapturing ? 0.4 : 1.0)
            }
            .accessibilityLabel(String(localized: "촬영"))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }
}
