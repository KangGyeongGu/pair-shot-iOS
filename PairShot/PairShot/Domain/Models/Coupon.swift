import Foundation
import SwiftData

@Model
final class Coupon {
    @Attribute(.unique) var id: UUID
    var code: String
    var activatedAt: Date
    var durationDays: Int
    var signatureBase64: String
    var status: Status

    enum Status: String, Codable, CaseIterable {
        case active
        case expired
        case revoked
    }

    init(
        code: String,
        activatedAt: Date = .now,
        durationDays: Int,
        signatureBase64: String,
        status: Status = .active
    ) {
        id = UUID()
        self.code = code
        self.activatedAt = activatedAt
        self.durationDays = durationDays
        self.signatureBase64 = signatureBase64
        self.status = status
    }

    var expirationDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: activatedAt)
            ?? activatedAt.addingTimeInterval(TimeInterval(durationDays) * 86_400)
    }

    func isCurrentlyActive(now: Date = .now) -> Bool {
        guard status == .active else { return false }
        return now < expirationDate
    }
}
