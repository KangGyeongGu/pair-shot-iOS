import Foundation
@testable import PairShot
import Photos
import XCTest

/// P7.2 — `PhotoLibraryExporting` protocol contract via in-memory fake.
///
/// We can't drive `PHPhotoLibrary` deterministically from XCTest (the
/// authorization prompt is OS-managed and writes hit the user's real
/// library). Instead we exercise the protocol surface: any caller that uses
/// `PhotoLibraryExporting` should behave correctly when authorize() returns
/// each of the relevant statuses and when saveImageData succeeds / throws.
@MainActor
final class PhotoLibraryExportTests: XCTestCase {
    func testFakeExporterAuthorizesAndStoresEachSavedImage() async throws {
        let fake = FakePhotoLibraryExporter(
            authStatus: .authorized
        )
        try await fake.saveImageData(Data([0x01, 0x02]), type: .photo)
        try await fake.saveImageData(Data([0x03]), type: .photo)

        XCTAssertEqual(fake.savedImages.count, 2)
        XCTAssertEqual(fake.savedImages[0].count, 2)
        XCTAssertEqual(fake.savedImages[1].count, 1)
        XCTAssertEqual(fake.authorizeCalls, 2)
    }

    func testFakeExporterPropagatesNotAuthorizedError() async {
        let fake = FakePhotoLibraryExporter(authStatus: .denied)
        do {
            try await fake.saveImageData(Data([0x01]), type: .photo)
            XCTFail("Expected notAuthorized")
        } catch PhotoLibraryExportError.notAuthorized {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(fake.savedImages.isEmpty)
    }

    func testFakeExporterPropagatesWriteFailedError() async {
        let fake = FakePhotoLibraryExporter(
            authStatus: .authorized,
            writeError: PhotoLibraryExportError.writeFailed("disk full")
        )
        do {
            try await fake.saveImageData(Data([0x01]), type: .photo)
            XCTFail("Expected writeFailed")
        } catch let PhotoLibraryExportError.writeFailed(detail) {
            XCTAssertEqual(detail, "disk full")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testFakeExporterRespectsLimitedAccess() async throws {
        // `.limited` is treated as success by the production wrapper —
        // PhotoKit allows add-only writes under either status.
        let fake = FakePhotoLibraryExporter(authStatus: .limited)
        try await fake.saveImageData(Data([0xFF]), type: .photo)
        XCTAssertEqual(fake.savedImages.count, 1)
    }

    func testProductionExportTypeConformsToPhotoLibraryExporting() {
        // Smoke: the production class instantiates and is usable as the
        // protocol type. We can't actually call its methods in a unit test
        // (would prompt the user / write to library), so this just guards
        // the compile-time conformance.
        let prod: any PhotoLibraryExporting = PhotoLibraryExport()
        _ = prod
    }
}

/// In-memory fake — the only collaborator the export picker needs to be
/// driven from a unit test. Mutations happen on `MainActor` for store-safety.
@MainActor
final class FakePhotoLibraryExporter: PhotoLibraryExporting {
    nonisolated let authStatus: PHAuthorizationStatus
    nonisolated let writeError: Error?

    private(set) var authorizeCalls = 0
    private(set) var savedImages: [Data] = []

    nonisolated init(
        authStatus: PHAuthorizationStatus,
        writeError: Error? = nil
    ) {
        self.authStatus = authStatus
        self.writeError = writeError
    }

    func authorize() async -> PHAuthorizationStatus {
        authorizeCalls += 1
        return authStatus
    }

    func saveImageData(_ data: Data, type: ImageMediaType) async throws {
        let status = await authorize()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryExportError.notAuthorized
        }
        if let writeError {
            throw writeError
        }
        _ = type
        savedImages.append(data)
    }
}
