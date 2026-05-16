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

    static func render(
        job: ExportJob,
        photoLibrary: PhotoLibraryService,
    ) async throws -> RenderedExportEntry? {
        try Task.checkCancellation()
        switch job.entry.kind {
            case .combined:
                return try await renderCombined(job: job, photoLibrary: photoLibrary)

            case .before, .after:
                return try await renderIndividual(job: job, photoLibrary: photoLibrary)
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

    private static func renderCombined(
        job: ExportJob,
        photoLibrary: PhotoLibraryService,
    ) async throws -> RenderedExportEntry? {
        guard let beforeId = job.beforeLocalIdentifier, !beforeId.isEmpty,
              let afterId = job.afterLocalIdentifier, !afterId.isEmpty
        else { return nil }
        async let beforeData = photoLibrary.requestImageData(localIdentifier: beforeId)
        async let afterData = photoLibrary.requestImageData(localIdentifier: afterId)
        guard let bData = await beforeData, let aData = await afterData else { return nil }
        try Task.checkCancellation()
        let options = CompositeOptions(
            layout: job.layout,
            compressionQuality: job.exportQuality.compressionQuality,
            utType: job.exportQuality.utType,
            watermarkEnabled: job.watermark != nil,
            watermark: job.watermark,
            combineSettings: job.combineSettings,
            includeGPS: job.includeGPS,
        )
        let latitude = job.includeGPS ? job.latitude : nil
        let longitude = job.includeGPS ? job.longitude : nil
        return autoreleasepool {
            guard let data = try? CompositeRenderer.composeImage(
                beforeData: bData,
                afterData: aData,
                options: options,
                capturedAt: job.now,
                latitude: latitude,
                longitude: longitude,
            ) else { return nil }
            return RenderedExportEntry(data: data, utType: job.exportQuality.utType)
        }
    }

    private static func renderIndividual(
        job: ExportJob,
        photoLibrary: PhotoLibraryService,
    ) async throws -> RenderedExportEntry? {
        guard let id = job.entry.localIdentifier, !id.isEmpty,
              let raw = await photoLibrary.requestImageData(localIdentifier: id)
        else { return nil }
        try Task.checkCancellation()
        guard let image = UIImage(data: raw) else {
            return RenderedExportEntry(data: raw, utType: job.exportQuality.utType)
        }
        let isBefore = job.entry.kind == .before
        return autoreleasepool {
            let composed = CompositeRenderer.renderSingleComposite(
                image: image,
                combineSettings: job.combineSettings,
                isBefore: isBefore,
                watermark: job.watermark,
            )
            guard let cgImage = composed.cgImage else {
                return RenderedExportEntry(data: raw, utType: job.exportQuality.utType)
            }
            guard let encoded = CompositeImageEncoder.encode(
                cgImage: cgImage,
                utType: job.exportQuality.utType,
                quality: job.exportQuality.compressionQuality,
                capturedAt: nil,
                latitude: nil,
                longitude: nil,
            ) else {
                return RenderedExportEntry(data: raw, utType: job.exportQuality.utType)
            }
            return RenderedExportEntry(data: encoded, utType: job.exportQuality.utType)
        }
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

private actor ExportPerfTracker {
    private(set) var inFlight = 0
    private(set) var maxConcurrent = 0
    private(set) var totalDurationMs = 0
    private(set) var completedCount = 0

    func enter() -> Int {
        inFlight += 1
        if inFlight > maxConcurrent {
            maxConcurrent = inFlight
        }
        return inFlight
    }

    func leave(durationMs: Int) -> Int {
        inFlight -= 1
        totalDurationMs += durationMs
        completedCount += 1
        return inFlight
    }

    func averageDurationMs() -> Int {
        guard completedCount > 0 else { return 0 }
        return totalDurationMs / completedCount
    }
}

nonisolated enum ExportSlidingWindow {
    static func map<Job: Sendable, Result: Sendable>(
        jobs: [Job],
        cap: Int,
        onItemComplete: (@Sendable () async -> Void)? = nil,
        transform: @escaping @Sendable (Int, Job) async throws -> Result,
    ) async throws -> [Result] {
        let total = jobs.count
        guard total > 0 else { return [] }
        try Task.checkCancellation()

        let safeCap = max(1, min(cap, total))
        var results: [Result?] = Array(repeating: nil, count: total)

        let tracker = ExportPerfTracker()
        let startedAt = Date()

        try await withThrowingTaskGroup(of: (Int, Result).self) { group in
            var nextIndex = 0
            let initial = min(safeCap, total)
            for _ in 0 ..< initial {
                let index = nextIndex
                let job = jobs[index]
                nextIndex += 1
                group.addTask {
                    try Task.checkCancellation()
                    let inFlight = await tracker.enter()
                    let elapsedMs = Self.elapsedMs(since: startedAt)
                    print("[ExportPerf] +job[\(index)] start in-flight=\(inFlight) elapsed=\(elapsedMs)ms")
                    let jobStart = Date()
                    let value = try await transform(index, job)
                    let durMs = Self.elapsedMs(since: jobStart)
                    let remaining = await tracker.leave(durationMs: durMs)
                    let doneElapsedMs = Self.elapsedMs(since: startedAt)
                    print(
                        "[ExportPerf] -job[\(index)] done dur=\(durMs)ms in-flight=\(remaining) elapsed=\(doneElapsedMs)ms",
                    )
                    return (index, value)
                }
            }
            while let (index, value) = try await group.next() {
                try Task.checkCancellation()
                results[index] = value
                if let onItemComplete {
                    await onItemComplete()
                }
                if nextIndex < total {
                    let nextSlot = nextIndex
                    let job = jobs[nextSlot]
                    nextIndex += 1
                    group.addTask {
                        try Task.checkCancellation()
                        let inFlight = await tracker.enter()
                        let elapsedMs = Self.elapsedMs(since: startedAt)
                        print("[ExportPerf] +job[\(nextSlot)] start in-flight=\(inFlight) elapsed=\(elapsedMs)ms")
                        let jobStart = Date()
                        let value = try await transform(nextSlot, job)
                        let durMs = Self.elapsedMs(since: jobStart)
                        let remaining = await tracker.leave(durationMs: durMs)
                        let doneElapsedMs = Self.elapsedMs(since: startedAt)
                        print(
                            "[ExportPerf] -job[\(nextSlot)] done dur=\(durMs)ms in-flight=\(remaining) elapsed=\(doneElapsedMs)ms",
                        )
                        return (nextSlot, value)
                    }
                }
            }
        }

        let totalElapsedMs = Self.elapsedMs(since: startedAt)
        let avgDur = await tracker.averageDurationMs()
        let maxConcurrent = await tracker.maxConcurrent
        print(
            "[ExportPerf] complete total=\(total) elapsed=\(totalElapsedMs)ms avgDur=\(avgDur)ms maxConcurrent=\(maxConcurrent)",
        )

        return results.compactMap(\.self)
    }

    private static func elapsedMs(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

nonisolated enum ExportEntryBatchRenderer {
    static func renderAll(
        jobs: [ExportJob],
        photoLibrary: PhotoLibraryService,
        counter: ExportProgressCounter?,
        cap: Int = ExportConcurrency.recommendedCap(),
    ) async throws -> [RenderedExportPayload] {
        let detail = ExportConcurrency.recommendedCapDetails()
        let availMemMB = detail.availableMemoryBytes / (1024 * 1024)
        print(
            "[ExportPerf] start total=\(jobs.count) cap=\(cap) cores=\(detail.cores) availMemMB=\(availMemMB) memCap=\(detail.memCap) coreCap=\(detail.coreCap) hardCap=\(detail.hardCap)",
        )
        let onItemComplete: (@Sendable () async -> Void)? = if let counter {
            { await counter.tick() }
        } else {
            nil
        }
        let rendered: [RenderedExportPayload?] = try await ExportSlidingWindow.map(
            jobs: jobs,
            cap: cap,
            onItemComplete: onItemComplete,
        ) { _, job in
            try await renderOne(job: job, photoLibrary: photoLibrary)
        }
        return rendered.compactMap(\.self)
    }

    private static func renderOne(
        job: ExportJob,
        photoLibrary: PhotoLibraryService,
    ) async throws -> RenderedExportPayload? {
        guard let rendered = try await ExportEntryRenderer.render(
            job: job,
            photoLibrary: photoLibrary,
        ) else { return nil }
        return RenderedExportPayload(
            pairId: job.pairId,
            entry: job.entry,
            data: rendered.data,
            utType: rendered.utType,
        )
    }
}
