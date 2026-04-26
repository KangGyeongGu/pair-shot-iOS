import CoreLocation
import Foundation
import ImageIO
import MobileCoreServices
import SwiftData
import UIKit
import UniformTypeIdentifiers

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
///
/// **Audit-D** changes:
/// - The decode → render → watermark → encode pipeline is now wrapped in
///   ``autoreleasepool`` and run on a `Task.detached(priority: .userInitiated)`
///   so two large UIImages don't pile autoreleased buffers onto the main
///   actor's pool.
/// - Re-compositing the same pair now unlinks the previous combined file
///   before writing the new one — without this, a re-render would orphan
///   the older JPEG (still referenced by `PhotoPair.combinedPath` for the
///   moment, but un-cleaned-up after the path overwrite).
/// - The encoded JPEG carries an EXIF `DateTimeOriginal` plus, when the
///   parent `Project` has GPS coordinates, a GPS dictionary so the file
///   round-trips through Photos.app and downstream tools that read EXIF.
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
    /// 1. Snapshot the inputs we need off the main actor (paths, project GPS).
    /// 2. Run decode → render → watermark → encode on a detached task
    ///    so the autoreleased UIImage buffers don't pile up on the main
    ///    actor's pool.
    /// 3. Audit-D — unlink any previous `combinedPath` before writing the
    ///    new file so re-composites don't orphan disk storage.
    /// 4. Persist via `PhotoStorageService`, write the relative path back
    ///    to `pair.combinedPath`, bump `project.updatedAt`, and save.
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
    ) async throws -> String {
        guard let afterPath = pair.afterPath, !afterPath.isEmpty else {
            throw RenderError.afterPathNotSet
        }
        let beforePath = pair.beforePath
        let previousCombined = pair.combinedPath
        let projectLatitude = pair.project?.latitude
        let projectLongitude = pair.project?.longitude

        // Audit-D — heavy work runs detached so the main actor's
        // autorelease pool doesn't accumulate two full-resolution
        // UIImages while waiting for the next runloop. The
        // autoreleasepool inside the closure releases the decoded
        // images as soon as the JPEG bytes are produced.
        let jpeg: Data = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let beforeImage = loadImage(relativePath: beforePath, storage: storage) else {
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
                guard let baseJPEG = composite.jpegData(
                    compressionQuality: options.jpegQuality
                ) else {
                    throw RenderError.encodeFailed
                }
                // EXIF / GPS embedding is best-effort: if it fails we
                // still ship the un-tagged JPEG rather than failing the
                // whole composite.
                return ExifEmbedder.embed(
                    into: baseJPEG,
                    capturedAt: now,
                    latitude: projectLatitude,
                    longitude: projectLongitude
                ) ?? baseJPEG
            }
        }.value

        // Audit-D — drop the previous combined file before writing the
        // new one. Best-effort: if the old file is already gone we
        // proceed silently.
        if let previousCombined, !previousCombined.isEmpty {
            try? storage.deletePhoto(at: previousCombined)
            ThumbnailCache.shared.evict(relativePath: previousCombined)
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

// MARK: - EXIF / GPS embedding (Audit-D)

/// Pure helper that re-encodes a JPEG `Data` buffer with an EXIF
/// `DateTimeOriginal` field plus an optional GPS dictionary.
///
/// Implementation uses `ImageIO`'s `CGImageDestination` because that's
/// the documented Apple recipe for "I have JPEG bytes and want to add
/// metadata without re-encoding the pixels through Core Graphics again".
/// The destination copies the original image data while writing a new
/// metadata block.
///
/// Embedding is best-effort: if the input JPEG is malformed or
/// `CGImageDestination` refuses to write, callers fall back to the
/// untagged JPEG (the user-visible composite still works).
enum ExifEmbedder {
    /// EXIF expects `yyyy:MM:dd HH:mm:ss` for `DateTimeOriginal`.
    static let exifDateFormat = "yyyy:MM:dd HH:mm:ss"

    /// Returns a copy of `jpeg` with EXIF + GPS metadata applied, or
    /// `nil` when the embed failed (caller falls back to `jpeg`
    /// unmodified).
    static func embed(
        into jpeg: Data,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetType(source) != nil else { return nil }
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let metadata = makeMetadata(
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude
        )
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            metadata as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    /// Build the metadata dictionary handed to `CGImageDestination`.
    /// Pure function so tests can verify the EXIF date string and GPS
    /// reference glyphs without touching ImageIO.
    static func makeMetadata(
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?
    ) -> [String: Any] {
        var top: [String: Any] = [:]

        var exif: [String: Any] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = exifDateFormat
        let stamp = formatter.string(from: capturedAt)
        exif[kCGImagePropertyExifDateTimeOriginal as String] = stamp
        exif[kCGImagePropertyExifDateTimeDigitized as String] = stamp
        top[kCGImagePropertyExifDictionary as String] = exif

        if let lat = latitude, let lon = longitude {
            var gps: [String: Any] = [:]
            gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
            gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
            gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
            top[kCGImagePropertyGPSDictionary as String] = gps
        }
        return top
    }
}
