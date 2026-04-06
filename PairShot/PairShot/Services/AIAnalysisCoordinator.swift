import Foundation
import OSLog
import SwiftData

@MainActor
enum AIAnalysisCoordinator {
    private nonisolated static let logger = Logger(subsystem: "com.pairshot", category: "AIAnalysis")
    private static var inFlight: Set<UUID> = []

    static func analyze(pairID: UUID, in modelContext: ModelContext) async {
        guard !inFlight.contains(pairID) else {
            logger.info("already in flight: \(pairID)")
            return
        }
        inFlight.insert(pairID)
        defer { inFlight.remove(pairID) }

        let descriptor = FetchDescriptor<PhotoPair>(predicate: #Predicate { $0.id == pairID })
        guard let pair = try? modelContext.fetch(descriptor).first,
              let projectID = pair.project?.id
        else { return }

        let needsAlign = pair.alignedAfterImagePath == nil
        let needsScore = pair.matchingScore == nil
        let needsCorrected = pair.colorCorrectedAfterImagePath == nil
        guard needsAlign || needsScore || needsCorrected else { return }

        let storage = PhotoStorageService()
        guard
            let beforeURL = try? storage.photoURL(projectId: projectID, pairId: pairID, isBefore: true),
            let afterURL = try? storage.photoURL(projectId: projectID, pairId: pairID, isBefore: false),
            let alignedURL = try? storage.alignedPhotoURL(projectId: projectID, pairId: pairID),
            let correctedURL = try? storage.colorCorrectedPhotoURL(projectId: projectID, pairId: pairID)
        else {
            logger.error("URL 생성 실패")
            return
        }

        async let alignedResult: URL? = needsAlign
            ? Self.runAlign(beforeURL: beforeURL, afterURL: afterURL, outputURL: alignedURL)
            : nil
        async let distanceResult: Float? = needsScore
            ? Self.runScore(beforeURL: beforeURL, afterURL: afterURL)
            : nil
        async let correctedResult: URL? = needsCorrected
            ? Self.runCorrect(beforeURL: beforeURL, afterURL: afterURL, outputURL: correctedURL)
            : nil

        let (aligned, distance, corrected) = await (alignedResult, distanceResult, correctedResult)

        if needsAlign, aligned != nil {
            pair.alignedAfterImagePath = storage.alignedPhotoRelativePath(projectId: projectID, pairId: pairID)
        }
        if needsScore, let distance {
            pair.matchingScore = distance
        }
        if needsCorrected, corrected != nil {
            pair.colorCorrectedAfterImagePath = storage.colorCorrectedPhotoRelativePath(
                projectId: projectID,
                pairId: pairID
            )
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("save failed: \(error)")
        }
    }

    private nonisolated static func runAlign(beforeURL: URL, afterURL: URL, outputURL: URL) async -> URL? {
        do {
            return try await AlignmentService.align(beforeURL: beforeURL, afterURL: afterURL, outputURL: outputURL)
        } catch {
            logger.error("align failed: \(error)")
            return nil
        }
    }

    private nonisolated static func runScore(beforeURL: URL, afterURL: URL) async -> Float? {
        do {
            return try await MatchingScoreService.computeDistance(beforeURL: beforeURL, afterURL: afterURL)
        } catch {
            logger.error("score failed: \(error)")
            return nil
        }
    }

    private nonisolated static func runCorrect(beforeURL: URL, afterURL: URL, outputURL: URL) async -> URL? {
        do {
            return try await ColorCorrectionService.correct(
                afterURL: afterURL,
                referenceBeforeURL: beforeURL,
                outputURL: outputURL
            )
        } catch {
            logger.error("correct failed: \(error)")
            return nil
        }
    }
}
