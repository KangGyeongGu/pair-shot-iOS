import Foundation
@testable import PairShot
import Testing
import ZIPFoundation

struct ZipExporterTests {
    private static let frozenNow = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test
    func `makeZip writes provided data bytes for each entry`() async throws {
        let exporter = ZipExporter()
        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let payloads = [
            ZipEntryPayload(
                relativeName: "AlbumA/BEFORE/before.jpg",
                data: Data([0x01, 0x02, 0x03, 0x04]),
            ),
            ZipEntryPayload(
                relativeName: "AlbumA/AFTER/after.jpg",
                data: Data(repeating: 0xAB, count: 1024),
            ),
            ZipEntryPayload(
                relativeName: "AlbumB/COMBINED/combo.jpg",
                data: Data((0 ..< 256).map { UInt8($0) }),
            ),
        ]

        let zipURL = try await exporter.makeZip(for: payloads, in: tempDir, now: Self.frozenNow)

        let archive = try Archive(url: zipURL, accessMode: .read)
        let names = archive.map(\.path)
        #expect(names == payloads.map(\.relativeName))
        for payload in payloads {
            let entry = try #require(archive[payload.relativeName])
            var collected = Data()
            _ = try archive.extract(entry) { chunk in
                collected.append(chunk)
            }
            #expect(collected == payload.data)
        }
    }

    @Test
    func `makeZip throws noPairs when entries empty`() async {
        let exporter = ZipExporter()
        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await #expect(throws: ZipExporter.ExportError.noPairs) {
            _ = try await exporter.makeZip(for: [], in: tempDir, now: Self.frozenNow)
        }
    }

    @Test
    func `makeZip does not create staging directory in tempDirectory`() async throws {
        let exporter = ZipExporter()
        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let payloads = [
            ZipEntryPayload(relativeName: "x.bin", data: Data([0xFF])),
        ]
        let zipURL = try await exporter.makeZip(for: payloads, in: tempDir, now: Self.frozenNow)

        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        let stagingCandidates = contents.filter { $0.hasPrefix("pairshot-zip-") }
        #expect(stagingCandidates.isEmpty)
        #expect(contents.contains(zipURL.lastPathComponent))
    }

    @Test
    func `makeZip overwrites existing zip at target path`() async throws {
        let exporter = ZipExporter()
        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstPayload = [
            ZipEntryPayload(relativeName: "first.bin", data: Data([0x10, 0x20])),
        ]
        let firstURL = try await exporter.makeZip(for: firstPayload, in: tempDir, now: Self.frozenNow)

        let secondPayload = [
            ZipEntryPayload(relativeName: "second.bin", data: Data([0x30, 0x40, 0x50])),
        ]
        let secondURL = try await exporter.makeZip(for: secondPayload, in: tempDir, now: Self.frozenNow)

        #expect(firstURL.path == secondURL.path)
        let archive = try Archive(url: secondURL, accessMode: .read)
        let names = archive.map(\.path)
        #expect(names == ["second.bin"])
    }

    private static func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZipExporterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
