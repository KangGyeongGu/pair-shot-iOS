import Foundation

nonisolated struct ExportContents: Equatable {
    let includeCombined: Bool
    let includeBefore: Bool
    let includeAfter: Bool

    var isEmpty: Bool {
        !includeCombined && !includeBefore && !includeAfter
    }
}

nonisolated enum ExportFormat: String, Equatable, CaseIterable {
    case zip = "ZIP"
    case individualImages = "INDIVIDUAL"
}

nonisolated struct ExportRenderOptions: Equatable {
    let applyCombineSettings: Bool
    let applyWatermark: Bool

    static let disabled = Self(applyCombineSettings: false, applyWatermark: false)
}
