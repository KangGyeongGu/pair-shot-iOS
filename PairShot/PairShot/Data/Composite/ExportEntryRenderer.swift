import Foundation
import UIKit

nonisolated enum ExportEntryRenderer {
    @MainActor
    static func render(
        entry: ExportSelection.Entry,
        pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings?,
        renderOptions: ExportRenderOptions,
        now: Date
    ) async -> Data? {
        switch entry.kind {
            case .combined:
                await renderCombined(
                    pair: pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now
                )

            case .before, .after:
                await renderIndividual(
                    entry: entry,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions
                )
        }
    }

    @MainActor
    private static func renderCombined(
        pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings?,
        renderOptions: ExportRenderOptions,
        now: Date
    ) async -> Data? {
        let combineSettings: CombineSettings? = if renderOptions.applyCombineSettings,
                                                   let appSettings
        {
            appSettings.combineSettings
        } else {
            nil
        }
        let layout: CompositeLayout = combineSettings.map(CompositeLayoutResolver.layout(from:))
            ?? appSettings?.defaultCompositeLayout
            ?? .horizontal
        let watermark = activeWatermark(appSettings: appSettings, renderOptions: renderOptions)
        let options = CompositeOptions(
            layout: layout,
            jpegQuality: 0.95,
            watermarkEnabled: watermark != nil,
            watermark: watermark,
            combineSettings: combineSettings
        )
        return try? await CompositeRenderer.makeComposite(
            for: pair,
            options: options,
            photoLibrary: photoLibrary,
            now: now
        )
    }

    @MainActor
    private static func renderIndividual(
        entry: ExportSelection.Entry,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings?,
        renderOptions: ExportRenderOptions
    ) async -> Data? {
        guard let id = entry.localIdentifier,
              let raw = await photoLibrary.requestImageData(localIdentifier: id)
        else { return nil }
        guard let watermark = activeWatermark(appSettings: appSettings, renderOptions: renderOptions),
              let image = UIImage(data: raw)
        else { return raw }
        let stamped = WatermarkOverlay.apply(to: image, settings: watermark)
        return stamped.jpegData(compressionQuality: 0.95) ?? raw
    }

    @MainActor
    private static func activeWatermark(
        appSettings: AppSettings?,
        renderOptions: ExportRenderOptions
    ) -> WatermarkSettings? {
        guard let appSettings,
              renderOptions.applyWatermark,
              appSettings.watermarkEnabled
        else { return nil }
        return appSettings.watermarkSettings
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
