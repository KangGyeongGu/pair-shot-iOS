import Foundation
@testable import PairShot
import SwiftData
import XCTest

final class PhotoStorageServiceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    func testSaveBeforeJPEGProducesFileNameAndPersistsBytes() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xAB, count: 1024)
        let id = UUID()
        let fileName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: id)
        let returned = try storage.saveBeforeJPEG(bytes, fileName: fileName)

        XCTAssertEqual(returned, fileName)
        XCTAssertTrue(returned.hasSuffix(".jpg"))

        let absolute = storage.resolve(kind: .before, fileName: returned)
        XCTAssertNotNil(absolute)
        let restored = try Data(contentsOf: XCTUnwrap(absolute))
        XCTAssertEqual(restored, bytes)
    }

    func testCapturedPhotoCarriesMetadata() {
        let captured = CapturedPhoto(
            jpegData: Data([0xFF]),
            zoomFactor: 2.0,
            lensIdentifier: "BuiltInWideAngleCamera.back",
            capturedAt: Date(timeIntervalSince1970: 1000)
        )
        XCTAssertEqual(captured.jpegData.count, 1)
        XCTAssertEqual(captured.zoomFactor, 2.0, accuracy: 1e-9)
        XCTAssertEqual(captured.lensIdentifier, "BuiltInWideAngleCamera.back")
        XCTAssertEqual(captured.capturedAt.timeIntervalSince1970, 1000, accuracy: 1e-9)
    }

    func testResolveBlankFileNameReturnsNil() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(storage.resolve(kind: .before, fileName: ""))
    }

    func testDeleteMissingPhotoIsNoOp() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        try storage.deletePhoto(kind: .before, fileName: "does-not-exist.jpg")
    }

    func testSaveTwiceProducesDistinctFiles() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let nameA = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let nameB = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let firstName = try storage.saveBeforeJPEG(Data([0x01]), fileName: nameA)
        let secondName = try storage.saveBeforeJPEG(Data([0x02]), fileName: nameB)
        XCTAssertNotEqual(firstName, secondName)
    }

    func testSeparateDirectoriesPerKind() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        let combinedName = FileNameBuilder.combined(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: beforeName)
        _ = try storage.saveAfterJPEG(Data([0x02]), fileName: afterName)
        _ = try storage.saveCombinedJPEG(Data([0x03]), fileName: combinedName)

        let beforeDir = storage.photosDirectory(for: .before)
        let afterDir = storage.photosDirectory(for: .after)
        let combinedDir = storage.photosDirectory(for: .combined)
        XCTAssertNotEqual(beforeDir.path, afterDir.path)
        XCTAssertNotEqual(beforeDir.path, combinedDir.path)
        XCTAssertNotEqual(afterDir.path, combinedDir.path)
    }

    deinit {}
}
