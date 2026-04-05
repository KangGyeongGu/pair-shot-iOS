import Foundation
import OSLog
import SwiftData

nonisolated enum AIAnalysisCoordinator {
    private static let logger = Logger(subsystem: "com.pairshot", category: "AIAnalysis")

    static func analyze(pairID: UUID, modelContainer: ModelContainer) {
        Task.detached(priority: .userInitiated) {
            await runAnalysis(pairID: pairID, modelContainer: modelContainer)
        }
    }

    private static func runAnalysis(pairID: UUID, modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PhotoPair>(predicate: #Predicate { $0.id == pairID })
        guard let pair = try? context.fetch(descriptor).first,
              let projectID = pair.project?.id,
              let urls = makeURLs(projectID: projectID, pairID: pairID)
        else { return }

        let needsAlign = pair.alignedBeforeImagePath == nil
        let needsScore = pair.matchingScore == nil
        let needsCorrected = pair.colorCorrectedBeforeImagePath == nil

        guard needsAlign || needsScore || needsCorrected else { return }

        async let aligned = runAlignment(urls: urls, needed: needsAlign)
        async let score = runMatchingScore(urls: urls, needed: needsScore)
        async let corrected = runColorCorrection(urls: urls, needed: needsCorrected)

        let (alignedResult, scoreResult, correctedResult) = await (aligned, score, corrected)

        let refetch = FetchDescriptor<PhotoPair>(predicate: #Predicate { $0.id == pairID })
        guard let fetched = try? context.fetch(refetch).first else { return }
        if let alignedResult { fetched.alignedBeforeImagePath = alignedResult.path }
        if let scoreResult { fetched.matchingScore = scoreResult }
        if let correctedResult { fetched.colorCorrectedBeforeImagePath = correctedResult.path }
        try? context.save()
    }

    private static func runAlignment(urls: PairURLs, needed: Bool) async -> URL? {
        guard needed else { return nil }
        do {
            return try await AlignmentService.align(
                beforeURL: urls.before,
                afterURL: urls.after,
                outputURL: urls.aligned
            )
        } catch {
            logger.error("AlignmentService failed: \(error)")
            return nil
        }
    }

    private static func runMatchingScore(urls: PairURLs, needed: Bool) async -> Float? {
        guard needed else { return nil }
        do {
            return try await MatchingScoreService.computeDistance(
                beforeURL: urls.before,
                afterURL: urls.after
            )
        } catch {
            logger.error("MatchingScoreService failed: \(error)")
            return nil
        }
    }

    private static func runColorCorrection(urls: PairURLs, needed: Bool) async -> URL? {
        guard needed else { return nil }
        do {
            return try await ColorCorrectionService.correct(
                beforeURL: urls.before,
                referenceAfterURL: urls.after,
                outputURL: urls.corrected
            )
        } catch {
            logger.error("ColorCorrectionService failed: \(error)")
            return nil
        }
    }

    private struct PairURLs {
        let before: URL
        let after: URL
        let aligned: URL
        let corrected: URL
    }

    private static func makeURLs(projectID: UUID, pairID: UUID) -> PairURLs? {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let pairDir = docsURL
            .appendingPathComponent("projects/\(projectID.uuidString)/pairs/\(pairID.uuidString)")
        return PairURLs(
            before: pairDir.appendingPathComponent("before.jpg"),
            after: pairDir.appendingPathComponent("after.jpg"),
            aligned: pairDir.appendingPathComponent("aligned_before.jpg"),
            corrected: pairDir.appendingPathComponent("corrected_before.jpg")
        )
    }
}
