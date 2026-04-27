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
    var kindRawString: String = ""
    var payloadVersion: Int = 1
    var issuedAt = Date(timeIntervalSince1970: 0)

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
        status: Status = .active,
        kindRawString: String? = nil,
        payloadVersion: Int = 1,
        issuedAt: Date? = nil
    ) {
        id = UUID()
        self.code = code
        self.activatedAt = activatedAt
        self.durationDays = durationDays
        self.signatureBase64 = signatureBase64
        self.status = status
        self.kindRawString = kindRawString ?? "\(CouponKind.timedPrefix)\(durationDays)"
        self.payloadVersion = payloadVersion
        self.issuedAt = issuedAt ?? activatedAt
    }

    var kind: CouponKind {
        CouponKind(rawString: kindRawString) ?? .timed(days: durationDays)
    }

    var expirationDate: Date {
        switch kind {
            case let .timed(days):
                Calendar.current.date(byAdding: .day, value: days, to: activatedAt)
                    ?? activatedAt.addingTimeInterval(TimeInterval(days) * 86_400)

            case .unlimited:
                .distantFuture
        }
    }

    func isCurrentlyActive(now: Date = .now) -> Bool {
        guard status == .active else { return false }
        return now < expirationDate
    }
}
