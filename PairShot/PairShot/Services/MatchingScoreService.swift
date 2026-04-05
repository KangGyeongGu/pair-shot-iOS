import CoreGraphics
import Foundation
import Vision

nonisolated enum MatchingScoreService {
    enum MatchingGrade { case excellent, good, retake }
    enum ScoreError: Error { case loadFailed, visionFailed, noFeaturePrint }

    static func computeDistance(beforeURL: URL, afterURL: URL) async throws -> Float {
        try await Task.detached(priority: .userInitiated) {
            guard
                let beforeImage = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 1200),
                let afterImage = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 1200)
            else { throw ScoreError.loadFailed }

            let beforePrint = try Self.makeFeaturePrint(cgImage: beforeImage)
            let afterPrint = try Self.makeFeaturePrint(cgImage: afterImage)

            var distance: Float = 0
            try beforePrint.computeDistance(&distance, to: afterPrint)
            return distance
        }.value
    }

    static func grade(for distance: Float) -> MatchingGrade {
        if distance < 5 { return .excellent }
        if distance < 15 { return .good }
        return .retake
    }

    static func percentMatch(for distance: Float) -> Int {
        max(0, Int((1 - min(distance / 20, 1)) * 100))
    }

    private static func makeFeaturePrint(cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [.ciContext: ImageProcessingContext.shared]
        )
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw ScoreError.noFeaturePrint
        }
        return observation
    }
}
