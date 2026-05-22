import Foundation
@testable import PairShot
import Testing
import UniformTypeIdentifiers

struct ExportQualityTests {
    @Test
    func `low preset is jpeg at 0_6`() {
        #expect(ExportQuality.low.compressionQuality == 0.6)
        #expect(ExportQuality.low.utType == .jpeg)
        #expect(ExportQuality.low.fileExtension == "jpg")
    }

    @Test
    func `standard preset is jpeg at 0_8`() {
        #expect(ExportQuality.standard.compressionQuality == 0.8)
        #expect(ExportQuality.standard.utType == .jpeg)
        #expect(ExportQuality.standard.fileExtension == "jpg")
    }

    @Test
    func `high preset is jpeg at 0_95`() {
        #expect(ExportQuality.high.compressionQuality == 0.95)
        #expect(ExportQuality.high.utType == .jpeg)
        #expect(ExportQuality.high.fileExtension == "jpg")
    }

    @Test
    func `lossless preset is heic at 1_0`() {
        #expect(ExportQuality.lossless.compressionQuality == 1.0)
        #expect(ExportQuality.lossless.utType == .heic)
        #expect(ExportQuality.lossless.fileExtension == "heic")
    }

    @Test
    func `all preset rawValues round-trip`() {
        for preset in ExportQuality.allCases {
            #expect(ExportQuality(rawValue: preset.rawValue) == preset)
        }
    }

    @MainActor
    @Test
    func `AppSettings defaults to high preset`() {
        let suiteName = "ExportQualityTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.exportQuality == .high)
    }

    @MainActor
    @Test
    func `AppSettings persists explicit preset choice`() {
        let suiteName = "ExportQualityTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.exportQuality = .lossless
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.exportQuality == .lossless)
    }
}
