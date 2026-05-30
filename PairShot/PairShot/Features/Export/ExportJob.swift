import Foundation
import UniformTypeIdentifiers

nonisolated struct ExportJob {
    let pairId: UUID
    let entry: ExportSelection.Entry
    let beforeLocalIdentifier: String?
    let afterLocalIdentifier: String?
    let latitude: Double?
    let longitude: Double?
    let layout: CompositeLayout
    let combineSettings: CombineSettings?
    let watermark: WatermarkSettings?
    let watermarkLogoData: Data?
    let exportQuality: ExportQuality
    let includeGPS: Bool
    let now: Date
}

nonisolated struct RenderedExportPayload {
    let pairId: UUID
    let entry: ExportSelection.Entry
    let data: Data
    let utType: UTType
}

enum ExportJobBuilder {
    @MainActor
    static func makeJobs(
        pairs: [PhotoPair],
        selection: ExportContents,
        appSettings: AppSettings,
        renderOptions: ExportRenderOptions,
        logoStore: WatermarkLogoStore,
        now: Date,
    ) -> [ExportJob] {
        let prefix = appSettings.fileNamePrefix
        let quality = appSettings.exportQuality
        let combineSettings: CombineSettings? =
            renderOptions.applyCombineSettings
                ? appSettings.combineSettings.effective(isPro: renderOptions.isPro)
                : nil
        let layout: CompositeLayout =
            combineSettings.map(CompositeLayoutResolver.layout(from:))
                ?? appSettings.defaultCompositeLayout
        let watermark: WatermarkSettings? =
            appSettings.watermarkEnabled
                ? appSettings.watermarkSettings.effective(isPro: renderOptions.isPro)
                : nil
        let watermarkLogoData: Data? = watermark?.loadLogoData(using: logoStore)
        let includeGPS = appSettings.embedGPSInPhoto

        return pairs.enumerated().flatMap { offset, pair in
            let entries = ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                sequenceNumber: offset + 1,
                prefix: prefix,
                fileExtension: quality.fileExtension,
            )
            return entries.map { entry in
                ExportJob(
                    pairId: pair.id,
                    entry: entry,
                    beforeLocalIdentifier: pair.beforePhotoLocalIdentifier,
                    afterLocalIdentifier: pair.afterPhotoLocalIdentifier,
                    latitude: pair.latitude,
                    longitude: pair.longitude,
                    layout: layout,
                    combineSettings: combineSettings,
                    watermark: watermark,
                    watermarkLogoData: watermarkLogoData,
                    exportQuality: quality,
                    includeGPS: includeGPS,
                    now: now,
                )
            }
        }
    }
}
