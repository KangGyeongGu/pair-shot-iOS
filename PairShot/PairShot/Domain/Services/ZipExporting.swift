import Foundation

nonisolated struct ExportContents: Equatable {
    let includeCombined: Bool
    let includeBefore: Bool
    let includeAfter: Bool
}

nonisolated enum ExportFormat: String, Equatable, CaseIterable {
    case zip = "ZIP"
    case individualImages = "INDIVIDUAL"
}

nonisolated struct ExportRenderOptions: Equatable {
    let applyCombineSettings: Bool
    let applyWatermark: Bool
}
