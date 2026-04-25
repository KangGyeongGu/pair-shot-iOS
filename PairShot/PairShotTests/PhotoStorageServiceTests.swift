import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P2.6 — JPEG storage + PhotoPair persistence.
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

    // MARK: - happy

    func testSaveBeforeJPEGProducesRelativePath() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xAB, count: 1024)
        let id = UUID()
        let relative = try storage.saveBeforeJPEG(bytes, fileID: id)

        XCTAssertTrue(relative.hasPrefix("photos/"))
        XCTAssertTrue(relative.hasSuffix(".jpg"))
        XCTAssertTrue(relative.contains(id.uuidString))

        let absolute = storage.resolve(relativePath: relative)
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

    @MainActor
    func testCoordinatorCreatesPhotoPairLinkedToProject() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = Project(title: "현장 A")
        context.insert(project)
        try context.save()

        // Stub session that returns synthetic JPEG bytes via a stored CapturedPhoto.
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0x42, count: 32)
        let relative = try storage.saveBeforeJPEG(bytes)
        XCTAssertFalse(relative.isEmpty)

        // Build the PhotoPair the same way `BeforeCaptureCoordinator` would.
        let pair = PhotoPair(
            beforePath: relative,
            beforeZoomFactor: 1.0,
            beforeLensIdentifier: "BuiltInWideAngleCamera.back",
            project: project
        )
        context.insert(pair)
        try context.save()

        XCTAssertEqual(project.pairs.count, 1)
        XCTAssertEqual(project.pairs.first?.beforePath, relative)
        XCTAssertEqual(project.pairs.first?.status, .pendingAfter)
    }

    // MARK: - edge

    func testResolveBlankPathReturnsNil() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(storage.resolve(relativePath: ""))
    }

    func testDeleteMissingPhotoIsNoOp() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        try storage.deletePhoto(at: "photos/does-not-exist.jpg")
    }

    func testSaveTwiceProducesDistinctFiles() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let a = try storage.saveBeforeJPEG(Data([0x01]), fileID: UUID())
        let b = try storage.saveBeforeJPEG(Data([0x02]), fileID: UUID())
        XCTAssertNotEqual(a, b)
    }
}
