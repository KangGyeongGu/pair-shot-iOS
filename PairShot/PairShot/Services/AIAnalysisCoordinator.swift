import Foundation
import OSLog
import simd
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

        let alignContext = needsAlign ? extractContext(from: pair) : nil

        async let alignedResult: (URL?, String) = needsAlign
            ? Self.runAlign(beforeURL: beforeURL, afterURL: afterURL, outputURL: alignedURL, context: alignContext)
            : (nil, "none")
        async let distanceResult: Float? = needsScore
            ? Self.runScore(beforeURL: beforeURL, afterURL: afterURL)
            : nil
        async let correctedResult: URL? = needsCorrected
            ? Self.runCorrect(beforeURL: beforeURL, afterURL: afterURL, outputURL: correctedURL)
            : nil

        let (alignTuple, distance, corrected) = await (alignedResult, distanceResult, correctedResult)
        let (aligned, alignTier) = alignTuple
        logger.debug("needsAlign=\(needsAlign), aligned=\(aligned?.lastPathComponent ?? "nil"), tier=\(alignTier)")

        if needsAlign, aligned != nil {
            pair.alignedAfterImagePath = storage.alignedPhotoRelativePath(projectId: projectID, pairId: pairID)
            pair.alignmentTierRaw = alignTier
            logger.debug("saved tierRaw=\(pair.alignmentTierRaw ?? "nil")")
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

    private static func extractContext(from pair: PhotoPair) -> AlignmentService.AlignmentContext? {
        guard let before = pair.beforePhoto, let after = pair.afterPhoto else { return nil }

        let beforeTransform: simd_float4x4? = before.arTransformData.flatMap { data in
            guard data.count == MemoryLayout<simd_float4x4>.size else { return nil }
            return data.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
        }
        let afterTransform: simd_float4x4? = after.arTransformData.flatMap { data in
            guard data.count == MemoryLayout<simd_float4x4>.size else { return nil }
            return data.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
        }
        let beforeIntrinsics: matrix_float3x3? = before.arIntrinsicsData.flatMap { data in
            guard data.count == MemoryLayout<matrix_float3x3>.size else { return nil }
            return data.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
        }
        let afterIntrinsics: matrix_float3x3? = after.arIntrinsicsData.flatMap { data in
            guard data.count == MemoryLayout<matrix_float3x3>.size else { return nil }
            return data.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
        }

        var depthMapURL: URL?
        if let depthPath = before.depthMapPath, !depthPath.isEmpty,
           let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            depthMapURL = docsURL.appendingPathComponent(depthPath)
        }

        return AlignmentService.AlignmentContext(
            beforeTransform: beforeTransform,
            afterTransform: afterTransform,
            beforeIntrinsics: beforeIntrinsics,
            afterIntrinsics: afterIntrinsics,
            beforeDepthMapURL: depthMapURL,
            depthAtCenter: before.depthAtCenter,
            worldMapRelocalized: after.arRelocalized
        )
    }

    private nonisolated static func runAlign(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: AlignmentService.AlignmentContext?
    ) async -> (URL?, String) {
        do {
            let result = try await AlignmentService.align(
                beforeURL: beforeURL,
                afterURL: afterURL,
                outputURL: outputURL,
                context: context
            )
            return (result.url, result.tier)
        } catch {
            logger.error("align failed: \(error)")
            return (nil, "failed")
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
