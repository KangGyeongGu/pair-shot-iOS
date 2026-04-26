import Foundation
import SwiftData

@Model
final class PhotoPair {
    @Attribute(.unique) var id: UUID
    var beforePath: String
    var afterPath: String?
    var combinedPath: String?
    var beforeCapturedAt: Date
    var afterCapturedAt: Date?
    var status: Status
    var beforeZoomFactor: Double
    var beforeLensIdentifier: String?

    var project: Project?

    enum Status: String, Codable, CaseIterable {
        case pendingAfter
        case complete
    }

    init(
        beforePath: String,
        beforeZoomFactor: Double = 1.0,
        beforeLensIdentifier: String? = nil,
        capturedAt: Date = .now,
        project: Project? = nil
    ) {
        id = UUID()
        self.beforePath = beforePath
        beforeCapturedAt = capturedAt
        status = .pendingAfter
        self.beforeZoomFactor = beforeZoomFactor
        self.beforeLensIdentifier = beforeLensIdentifier
        self.project = project
    }
}
