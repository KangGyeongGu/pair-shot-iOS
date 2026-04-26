import Foundation
import ImageIO
@testable import PairShot
import SwiftData
import UIKit
import XCTest

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

        let schema = Schema(versionedSchema: SchemaV2.self)
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

    func testRecompositingDeletesPreviousCombinedFile() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)

        let firstName = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let firstURL = try XCTUnwrap(storage.resolve(kind: .combined, fileName: firstName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        let secondName = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .vertical, jpegQuality: 0.7, watermarkEnabled: false),
            storage: storage,
            in: context
        )

        XCTAssertNotEqual(firstName, secondName, "re-composite must produce a fresh filename")
        XCTAssertEqual(pair.combinedFileName, secondName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        let secondURL = try XCTUnwrap(storage.resolve(kind: .combined, fileName: secondName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }

    func testCompositeJPEGContainsExifDateTimeOriginal() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let name = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context,
            now: now
        )
        let url = try XCTUnwrap(storage.resolve(kind: .combined, fileName: name))
        let data = try Data(contentsOf: url)
        let exif = try XCTUnwrap(extractExif(from: data))
        let stamp = try XCTUnwrap(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = ExifEmbedder.exifDateFormat
        XCTAssertEqual(stamp, formatter.string(from: now))
    }

    func testCompositeJPEGContainsGPSWhenPairHasCoordinates() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)
        pair.latitude = 37.5665
        pair.longitude = 126.9780
        try context.save()

        let name = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let url = try XCTUnwrap(storage.resolve(kind: .combined, fileName: name))
        let data = try Data(contentsOf: url)
        let gps = try XCTUnwrap(extractGPS(from: data))
        let lat = try XCTUnwrap(gps[kCGImagePropertyGPSLatitude as String] as? Double)
        let lon = try XCTUnwrap(gps[kCGImagePropertyGPSLongitude as String] as? Double)
        XCTAssertEqual(lat, 37.5665, accuracy: 1e-4)
        XCTAssertEqual(lon, 126.9780, accuracy: 1e-4)
    }

    func testCompositeJPEGSkipsGPSWhenPairHasNoCoordinates() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)

        let name = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false),
            storage: storage,
            in: context
        )
        let url = try XCTUnwrap(storage.resolve(kind: .combined, fileName: name))
        let data = try Data(contentsOf: url)
        XCTAssertNil(extractGPS(from: data))
    }

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
            latitude: -33.8688,
            longitude: -70.6483
        )
        let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        XCTAssertEqual(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String, "S")
        XCTAssertEqual(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String, "W")
        XCTAssertEqual(gps?[kCGImagePropertyGPSLatitude as String] as? Double, 33.8688)
        XCTAssertEqual(gps?[kCGImagePropertyGPSLongitude as String] as? Double, 70.6483)
    }

    func testExifEmbedderOmitsGPSWhenEitherCoordinateIsNil() {
        let onlyLat = ExifEmbedder.makeMetadata(capturedAt: .now, latitude: 1.0, longitude: nil)
        XCTAssertNil(onlyLat[kCGImagePropertyGPSDictionary as String])
        let onlyLon = ExifEmbedder.makeMetadata(capturedAt: .now, latitude: nil, longitude: 1.0)
        XCTAssertNil(onlyLon[kCGImagePropertyGPSDictionary as String])
        let neither = ExifEmbedder.makeMetadata(capturedAt: .now, latitude: nil, longitude: nil)
        XCTAssertNil(neither[kCGImagePropertyGPSDictionary as String])
    }

    private func makePopulatedPair(storage: PhotoStorageService) throws -> PhotoPair {
        let before = makeSolidImage(size: CGSize(width: 60, height: 40), color: .blue)
        let after = makeSolidImage(size: CGSize(width: 60, height: 40), color: .yellow)
        let beforeData = try XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        let afterData = try XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(beforeData, fileName: beforeName)
        _ = try storage.saveAfterJPEG(afterData, fileName: afterName)
        let pair = PhotoPair(beforeFileName: beforeName)
        pair.afterFileName = afterName
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

    deinit {}
}
