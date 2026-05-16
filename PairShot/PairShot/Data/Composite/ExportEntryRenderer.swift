import Foundation
import UIKit
import UniformTypeIdentifiers

nonisolated struct RenderedExportEntry {
    let data: Data
    let utType: UTType
}

nonisolated enum ExportEntryRenderer {
    @MainActor
    static func render(
        entry: ExportSelection.Entry,
        pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        renderOptions: ExportRenderOptions,
        now: Date,
    ) async -> RenderedExportEntry? {
        switch entry.kind {
            case .combined:
                await renderCombined(
                    pair: pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now,
                )

            case .before, .after:
                await renderIndividual(
                    entry: entry,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                )
        }
    }

    @MainActor
    private static func renderCombined(
        pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        renderOptions: ExportRenderOptions,
        now: Date,
    ) async -> RenderedExportEntry? {
        let combineSettings: CombineSettings? =
            renderOptions.applyCombineSettings
                ? appSettings.combineSettings.effective(isPro: renderOptions.isPro)
                : nil
        let layout: CompositeLayout =
            combineSettings.map(CompositeLayoutResolver.layout(from:))
                ?? appSettings.defaultCompositeLayout
        let watermark = activeWatermark(appSettings: appSettings, renderOptions: renderOptions)
        let quality = appSettings.exportQuality
        let options = CompositeOptions(
            layout: layout,
            compressionQuality: quality.compressionQuality,
            utType: quality.utType,
            watermarkEnabled: watermark != nil,
            watermark: watermark,
            combineSettings: combineSettings,
            includeGPS: appSettings.embedGPSInPhoto,
        )
        guard let data = try? await CompositeRenderer.makeComposite(
            for: pair,
            photoLibrary: photoLibrary,
            options: options,
            now: now,
        ) else { return nil }
        return RenderedExportEntry(data: data, utType: quality.utType)
    }

    @MainActor
    private static func renderIndividual(
        entry: ExportSelection.Entry,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        renderOptions: ExportRenderOptions,
    ) async -> RenderedExportEntry? {
        guard let id = entry.localIdentifier,
              let raw = await photoLibrary.requestImageData(localIdentifier: id)
        else { return nil }
        let quality = appSettings.exportQuality
        guard let image = UIImage(data: raw) else {
            return RenderedExportEntry(data: raw, utType: quality.utType)
        }
        let watermark = activeWatermark(appSettings: appSettings, renderOptions: renderOptions)
        let combineSettings: CombineSettings? =
            renderOptions.applyCombineSettings
                ? appSettings.combineSettings.effective(isPro: renderOptions.isPro)
                : nil
        let isBefore = entry.kind == .before
        let rendered = CompositeRenderer.renderSingle(
            image: image,
            combineSettings: combineSettings,
            isBefore: isBefore,
            watermark: watermark,
            utType: quality.utType,
            compressionQuality: quality.compressionQuality,
        ) ?? raw
        return RenderedExportEntry(data: rendered, utType: quality.utType)
    }

    @MainActor
    private static func activeWatermark(
        appSettings: AppSettings,
        renderOptions: ExportRenderOptions,
    ) -> WatermarkSettings? {
        guard appSettings.watermarkEnabled else { return nil }
        return appSettings.watermarkSettings.effective(isPro: renderOptions.isPro)
    }
}

nonisolated enum CompositeLayoutResolver {
    static func layout(from settings: CombineSettings) -> CompositeLayout {
        switch settings.direction {
            case .horizontal: .horizontal
            case .vertical: .vertical
        }
    }
}
