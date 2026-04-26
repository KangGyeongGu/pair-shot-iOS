import Foundation
import ImageIO
@testable import PairShot
import SwiftData
import UIKit
import XCTest

/// Audit-D — coverage for the CompositeRenderer changes that don't fit
/// the geometry-focused ``CompositeRendererTests``:
///
/// 1. Re-compositing a pair that already has a `combinedPath` deletes
///    the old file before writing the new one (no orphaning).
/// 2. The encoded JPEG carries an EXIF `DateTimeOriginal` matching the
///    `now` parameter the renderer was called with.
/// 3. When the parent project has GPS, the encoded JPEG carries a GPS
///    dictionary with the matching latitude / longitude.
/// 4. ``ExifEmbedder.makeMetadata`` is a pure function: GPS reference
///    glyphs reflect the sign convention regardless of latitude /
///    longitude order.
@MainActor
final class CompositeRendererPerformanceTests: XCTestCase {
    private var tempDir: URL!
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-composite-perf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Re-composite cleanup

    func testRecompositingDeletesPreviousCombinedFile() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)

        let firstRel = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let firstURL = try XCTUnwrap(storage.resolve(relativePath: firstRel))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        let secondRel = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .vertical, jpegQuality: 0.7, watermarkEnabled: false),
            storage: storage,
            in: context
        )

        XCTAssertNotEqual(firstRel, secondRel, "re-composite must produce a fresh filename")
        XCTAssertEqual(pair.combinedPath, secondRel, "combinedPath should point at the new file")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: firstURL.path),
            "previous combined file should be unlinked on re-composite (Audit-D)"
        )
        let secondURL = try XCTUnwrap(storage.resolve(relativePath: secondRel))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }

    // MARK: - EXIF / GPS round-trip

    func testCompositeJPEGContainsExifDateTimeOriginal() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)
        let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed for assertion

        let rel = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context,
            now: now
        )
        let url = try XCTUnwrap(storage.resolve(relativePath: rel))
        let data = try Data(contentsOf: url)
        let exif = try XCTUnwrap(extractExif(from: data))
        let stamp = try XCTUnwrap(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = ExifEmbedder.exifDateFormat
        XCTAssertEqual(
            stamp,
            formatter.string(from: now),
            "EXIF DateTimeOriginal must match the `now` parameter"
        )
    }

    func testCompositeJPEGContainsGPSWhenProjectHasCoordinates() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let project = Project(title: "GPS")
        project.latitude = 37.5665 // Seoul
        project.longitude = 126.9780
        context.insert(project)
        let pair = try makePair(storage: storage, project: project)

        let rel = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let url = try XCTUnwrap(storage.resolve(relativePath: rel))
        let data = try Data(contentsOf: url)
        let gps = try XCTUnwrap(extractGPS(from: data), "GPS dictionary must be present")
        let lat = try XCTUnwrap(gps[kCGImagePropertyGPSLatitude as String] as? Double)
        let lon = try XCTUnwrap(gps[kCGImagePropertyGPSLongitude as String] as? Double)
        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
        XCTAssertEqual(lat, 37.5665, accuracy: 1e-4)
        XCTAssertEqual(lon, 126.9780, accuracy: 1e-4)
        XCTAssertEqual(latRef, "N")
        XCTAssertEqual(lonRef, "E")
    }

    func testCompositeJPEGSkipsGPSWhenProjectHasNoCoordinates() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage) // no GPS

        let rel = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let url = try XCTUnwrap(storage.resolve(relativePath: rel))
        let data = try Data(contentsOf: url)
        XCTAssertNil(extractGPS(from: data), "GPS must not be embedded without project coordinates")
    }

    // MARK: - ExifEmbedder pure helpers

    func testExifEmbedderMakesNorthEastForPositiveCoordinates() {
        let metadata = ExifEmbedder.makeMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            latitude: 37.5,
            longitude: 127.0
        )
        let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        XCTAssertEqual(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String, "N")
        XCTAssertEqual(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String, "E")
    }

    func testExifEmbedderMakesSouthWestForNegativeCoordinates() {
        let metadata = ExifEmbedder.makeMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            latitude: -33.8688, // Sydney
            longitude: -70.6483 // Santiago longitude as negative
        )
        let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        XCTAssertEqual(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String, "S")
        XCTAssertEqual(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String, "W")
        // Magnitude survives the abs() unwrap.
        XCTAssertEqual(gps?[kCGImagePropertyGPSLatitude as String] as? Double, 33.8688)
        XCTAssertEqual(gps?[kCGImagePropertyGPSLongitude as String] as? Double, 70.6483)
    }

    func testExifEmbedderOmitsGPSWhenEitherCoordinateIsNil() {
        let onlyLat = ExifEmbedder.makeMetadata(
            capturedAt: .now, latitude: 1.0, longitude: nil
        )
        XCTAssertNil(onlyLat[kCGImagePropertyGPSDictionary as String])
        let onlyLon = ExifEmbedder.makeMetadata(
            capturedAt: .now, latitude: nil, longitude: 1.0
        )
        XCTAssertNil(onlyLon[kCGImagePropertyGPSDictionary as String])
        let neither = ExifEmbedder.makeMetadata(
            capturedAt: .now, latitude: nil, longitude: nil
        )
        XCTAssertNil(neither[kCGImagePropertyGPSDictionary as String])
    }

    // MARK: - helpers

    private func makePopulatedPair(storage: PhotoStorageService) throws -> PhotoPair {
        let project = Project(title: "noGPS")
        context.insert(project)
        return try makePair(storage: storage, project: project)
    }

    private func makePair(
        storage: PhotoStorageService,
        project: Project
    ) throws -> PhotoPair {
        let before = makeSolidImage(size: CGSize(width: 60, height: 40), color: .blue)
        let after = makeSolidImage(size: CGSize(width: 60, height: 40), color: .yellow)
        let beforeData = try XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        let afterData = try XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        let beforePath = try storage.saveBeforeJPEG(beforeData)
        let afterPath = try storage.saveAfterJPEG(afterData)
        let pair = PhotoPair(beforePath: beforePath, project: project)
        pair.afterPath = afterPath
        pair.status = .complete
        context.insert(pair)
        try context.save()
        return pair
    }

    private func extractExif(from data: Data) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [String: Any] else { return nil }
        return props[kCGImagePropertyExifDictionary as String] as? [String: Any]
    }

    private func extractGPS(from data: Data) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [String: Any] else { return nil }
        return props[kCGImagePropertyGPSDictionary as String] as? [String: Any]
    }

    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
