import SwiftUI

extension ExportSettingsView {
    var applyWatermarkBinding: Binding<Bool> {
        Binding(
            get: { viewModel.applyWatermark },
            set: { viewModel.applyWatermark = $0 },
        )
    }

    var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } },
        )
    }

    var shareItemsBinding: Binding<ExportShareItems?> {
        Binding(
            get: { viewModel.shareItems },
            set: { viewModel.shareItems = $0 },
        )
    }

    var zipExportBinding: Binding<DocumentExporterItem?> {
        Binding(
            get: { viewModel.zipExportItem },
            set: { _ in },
        )
    }
}
