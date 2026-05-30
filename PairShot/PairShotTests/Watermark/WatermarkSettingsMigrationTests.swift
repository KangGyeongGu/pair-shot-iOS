import Foundation
@testable import PairShot
import Testing

@MainActor
struct WatermarkSettingsMigrationTests {
    private let bytes = Data([0x10, 0x20, 0x30, 0x40])

    @Test
    func `legacy logoImageData migrates to logoImageRef via userInfo store`() throws {
        let store = makeStore()
        let legacyJSON = legacyLogoJSON()

        let decoder = JSONDecoder()
        decoder.userInfo[.watermarkLogoStore] = store
        let decoded = try decoder.decode(WatermarkSettings.self, from: Data(legacyJSON.utf8))

        let ref = try #require(decoded.logoImageRef)
        let storedBytes = try #require(store.load(ref: ref))
        #expect(storedBytes == bytes)
    }

    @Test
    func `re-encoding drops legacy logoImageData key`() throws {
        let store = makeStore()
        let legacyJSON = legacyLogoJSON()

        let decoder = JSONDecoder()
        decoder.userInfo[.watermarkLogoStore] = store
        let decoded = try decoder.decode(WatermarkSettings.self, from: Data(legacyJSON.utf8))
        let reEncoded = try JSONEncoder().encode(decoded)
        let dict = try JSONSerialization.jsonObject(with: reEncoded) as? [String: Any]

        #expect(dict?["logoImageData"] == nil)
        #expect(dict?["logoImageRef"] != nil)
    }

    @Test
    func `decoder without userInfo store preserves legacy data in pending`() throws {
        let legacyJSON = legacyLogoJSON()
        let decoded = try JSONDecoder().decode(WatermarkSettings.self, from: Data(legacyJSON.utf8))
        #expect(decoded.logoImageRef == nil)
        #expect(decoded.pendingLegacyLogoData == bytes)
    }

    @Test
    func `pending legacy data is re-encoded as logoImageData for retry`() throws {
        let legacyJSON = legacyLogoJSON()
        let decoded = try JSONDecoder().decode(WatermarkSettings.self, from: Data(legacyJSON.utf8))
        let reEncoded = try JSONEncoder().encode(decoded)
        let dict = try JSONSerialization.jsonObject(with: reEncoded) as? [String: Any]

        #expect(dict?["logoImageData"] != nil)
        #expect(dict?["logoImageRef"] == nil)
    }

    @Test
    func `migration failure preserves legacy data for next launch retry`() throws {
        let failingStore = WatermarkLogoStore(
            baseDirectory: URL(fileURLWithPath: "/dev/null/forbidden-\(UUID().uuidString)"),
        )
        let legacyJSON = legacyLogoJSON()

        let decoder = JSONDecoder()
        decoder.userInfo[.watermarkLogoStore] = failingStore
        let decoded = try decoder.decode(WatermarkSettings.self, from: Data(legacyJSON.utf8))

        #expect(decoded.logoImageRef == nil)
        #expect(decoded.pendingLegacyLogoData == bytes)
    }

    @Test
    func `decoder already-migrated payload preserves ref unchanged`() throws {
        let store = makeStore()
        let payload = """
        {
            "type": "logo",
            "text": "",
            "opacity": 0.5,
            "lineCount": 10,
            "repeatCount": 1.5,
            "textSizeRatio": 0.03,
            "logoImageRef": "existing-ref",
            "logoPosition": "center",
            "logoWidthRatio": 0.5,
            "logoAlpha": 0.5
        }
        """

        let decoder = JSONDecoder()
        decoder.userInfo[.watermarkLogoStore] = store
        let decoded = try decoder.decode(WatermarkSettings.self, from: Data(payload.utf8))

        #expect(decoded.logoImageRef == "existing-ref")
    }

    private func legacyLogoJSON() -> String {
        """
        {
            "type": "logo",
            "text": "",
            "opacity": 0.5,
            "lineCount": 10,
            "repeatCount": 1.5,
            "textSizeRatio": 0.03,
            "logoImageData": "\(bytes.base64EncodedString())",
            "logoFileName": "legacy.png",
            "logoPosition": "center",
            "logoWidthRatio": 0.5,
            "logoAlpha": 0.5
        }
        """
    }

    private func makeStore() -> WatermarkLogoStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatermarkMigrationTest-\(UUID().uuidString)", isDirectory: true)
        return WatermarkLogoStore(baseDirectory: dir)
    }
}
