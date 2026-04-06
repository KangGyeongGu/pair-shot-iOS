import Foundation
import SwiftData

@Model
final class PhotoPair {
    var id: UUID
    var createdAt: Date
    var status: PairStatus
    var captureModeRaw: String?
    var matchingScore: Float?
    var alignedAfterImagePath: String?
    var colorCorrectedAfterImagePath: String?

    @Relationship(deleteRule: .cascade)
    var beforePhoto: Photo?

    @Relationship(deleteRule: .cascade)
    var afterPhoto: Photo?

    var project: Project?

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: captureModeRaw ?? "") ?? .precision }
        set { captureModeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        status: PairStatus = .pendingAfter,
        captureMode: CaptureMode = .precision,
        project: Project? = nil,
        matchingScore: Float? = nil,
        alignedAfterImagePath: String? = nil,
        colorCorrectedAfterImagePath: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        captureModeRaw = captureMode.rawValue
        self.project = project
        self.matchingScore = matchingScore
        self.alignedAfterImagePath = alignedAfterImagePath
        self.colorCorrectedAfterImagePath = colorCorrectedAfterImagePath
    }
}
