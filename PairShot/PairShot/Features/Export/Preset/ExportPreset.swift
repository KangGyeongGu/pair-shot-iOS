import Foundation

struct ExportPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var includeCombined: Bool
    var includeBefore: Bool
    var includeAfter: Bool
    var format: ExportFormat
    var applyCombineSettings: Bool
    var combineSettings: CombineSettings
    var applyWatermark: Bool
    var watermarkSettings: WatermarkSettings

    init(
        name: String,
        includeCombined: Bool,
        includeBefore: Bool,
        includeAfter: Bool,
        format: ExportFormat,
        applyCombineSettings: Bool,
        combineSettings: CombineSettings,
        applyWatermark: Bool,
        watermarkSettings: WatermarkSettings,
        id: UUID = UUID(),
    ) {
        self.id = id
        self.name = name
        self.includeCombined = includeCombined
        self.includeBefore = includeBefore
        self.includeAfter = includeAfter
        self.format = format
        self.applyCombineSettings = applyCombineSettings
        self.combineSettings = combineSettings
        self.applyWatermark = applyWatermark
        self.watermarkSettings = watermarkSettings
    }
}
