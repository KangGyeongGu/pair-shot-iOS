import Foundation
import SwiftData
import UIKit

/// P5.2 — combines the Before and After images of a `PhotoPair` into a single
/// composite JPEG and persists the result.
///
/// **Architecture invariant** (CLAUDE.md): no homography, no auto-alignment,
/// no auto color correction. Just paste pixels side-by-side (or stacked) on a
/// `UIGraphicsImageRenderer` canvas. Each side is scaled to a shared edge
/// length so the canvas isn't ragged; that's the only geometric operation.
///
/// Phase 7 (Export) and Phase 8.3 (Settings) will both read combined JPEGs
/// produced by this renderer, so the on-disk shape (`Application
/// Support/photos/<UUID>.jpg`) matches the Before/After convention.
enum CompositeRenderer {
    /// Errors surfaced to the caller (UI shows a toast). All file-IO errors
    /// from `PhotoStorageService` are propagated as `.persistFailed`.
    enum RenderError: Error, Equatable {
        /// Couldn't decode the Before file at the path stored in `PhotoPair.beforePath`.
        case beforeImageMissing
        /// Couldn't decode the After file at the path stored in `PhotoPair.afterPath`.
        case afterImageMissing
        /// `PhotoPair.afterPath` was nil (still pending).
        case afterPathNotSet
        /// JPEG encoding returned nil.
        case encodeFailed
        /// File or SwiftData write failure.
        case persistFailed
    }

    /// High-level entry point used by `ComparisonView`'s composite menu.
    ///
    /// 1. Decode Before/After UIImages from disk.
    /// 2. Render the composite via `renderComposite(...)`.
    /// 3. Optionally stamp a watermark.
    /// 4. Encode JPEG, persist via `PhotoStorageService`, and write the
    ///    relative path back to `pair.combinedPath` + bump `project.updatedAt`.
    ///
    /// - Returns: the relative path now stored on the pair (also retrievable
    ///   via `pair.combinedPath`).
    @MainActor
    @discardableResult
    static func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions = .default,
        storage: PhotoStorageService = PhotoStorageService(),
        fileNamePrefix: String = "",
        in context: ModelContext,
        now: Date = .now
    ) throws -> String {
        guard let afterPath = pair.afterPath, !afterPath.isEmpty else {
            throw RenderError.afterPathNotSet
        }
        guard let beforeImage = loadImage(relativePath: pair.beforePath, storage: storage) else {
            throw RenderError.beforeImageMissing
        }
        guard let afterImage = loadImage(relativePath: afterPath, storage: storage) else {
            throw RenderError.afterImageMissing
        }

        var composite = renderComposite(
            before: beforeImage,
            after: afterImage,
            layout: options.layout
        )
        if options.watermarkEnabled {
            composite = WatermarkOverlay.apply(to: composite, date: now)
        }
        guard let jpeg = composite.jpegData(compressionQuality: options.jpegQuality) else {
            throw RenderError.encodeFailed
        }
        let relative: String
        do {
            relative = try storage.saveCombinedJPEG(jpeg, fileNamePrefix: fileNamePrefix)
        } catch {
            throw RenderError.persistFailed
        }
        pair.combinedPath = relative
        pair.project?.updatedAt = now
        do {
            try context.save()
        } catch {
            throw RenderError.persistFailed
        }
        return relative
    }

    // MARK: - Pure renderer

    /// Pure (no IO, no SwiftData) helper exposed for unit tests. Concatenates
    /// `before` and `after` on a single `UIGraphicsImageRenderer` canvas.
    ///
    /// **Sizing rule**:
    /// - `.horizontal`: each side is scaled so its height equals
    ///   `min(beforeHeight, afterHeight)`. Final canvas =
    ///   `(scaledBeforeWidth + scaledAfterWidth) × commonHeight`.
    /// - `.vertical`: each side is scaled so its width equals
    ///   `min(beforeWidth, afterWidth)`. Final canvas =
    ///   `commonWidth × (scaledBeforeHeight + scaledAfterHeight)`.
    ///
    /// The shared-edge approach guarantees zero letterboxing without forcing
    /// either side to be cropped.
    static func renderComposite(
        before: UIImage,
        after: UIImage,
        layout: CompositeLayout
    ) -> UIImage {
        let frames = composeFrames(
            beforeSize: before.size,
            afterSize: after.size,
            layout: layout
        )
        let format = UIGraphicsImageRendererFormat()
        // Use point scale = 1 so the output's pixel dimensions exactly match
        // `frames.canvas`. This keeps the JPEG file deterministic and the
        // tests don't need to reason about retina scale factors.
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frames.canvas, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: frames.canvas))
            before.draw(in: frames.beforeRect)
            after.draw(in: frames.afterRect)
        }
    }

    /// Geometry helper. Pure function so the layout math is unit-testable
    /// without rendering an image. Returned coordinates are in canvas-points.
    static func composeFrames(
        beforeSize: CGSize,
        afterSize: CGSize,
        layout: CompositeLayout
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        // Defensive: a zero-sized image should not crash the renderer; we
        // collapse that side to width/height 1 so the canvas math stays well
        // defined. Real captures from AVFoundation are always >0.
        let beforeWidth = max(beforeSize.width, 1)
        let beforeHeight = max(beforeSize.height, 1)
        let afterWidth = max(afterSize.width, 1)
        let afterHeight = max(afterSize.height, 1)

        switch layout {
            case .horizontal:
                let commonHeight = min(beforeHeight, afterHeight)
                let scaledBeforeWidth = beforeWidth * (commonHeight / beforeHeight)
                let scaledAfterWidth = afterWidth * (commonHeight / afterHeight)
                let canvas = CGSize(
                    width: scaledBeforeWidth + scaledAfterWidth,
                    height: commonHeight
                )
                let beforeRect = CGRect(x: 0, y: 0, width: scaledBeforeWidth, height: commonHeight)
                let afterRect = CGRect(
                    x: scaledBeforeWidth, y: 0,
                    width: scaledAfterWidth, height: commonHeight
                )
                return (canvas, beforeRect, afterRect)
            case .vertical:
                let commonWidth = min(beforeWidth, afterWidth)
                let scaledBeforeHeight = beforeHeight * (commonWidth / beforeWidth)
                let scaledAfterHeight = afterHeight * (commonWidth / afterWidth)
                let canvas = CGSize(
                    width: commonWidth,
                    height: scaledBeforeHeight + scaledAfterHeight
                )
                let beforeRect = CGRect(x: 0, y: 0, width: commonWidth, height: scaledBeforeHeight)
                let afterRect = CGRect(
                    x: 0, y: scaledBeforeHeight,
                    width: commonWidth, height: scaledAfterHeight
                )
                return (canvas, beforeRect, afterRect)
        }
    }

    // MARK: - Internals

    /// Synchronous JPEG decode. Mirrors `GhostOverlayLoader.loadImage`'s
    /// "small file, do it inline" stance — composites are user-initiated so
    /// the brief stall is acceptable. The `ComparisonView` covers the action
    /// with a progress sheet anyway.
    private static func loadImage(relativePath: String, storage: PhotoStorageService) -> UIImage? {
        guard let url = storage.resolve(relativePath: relativePath) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
