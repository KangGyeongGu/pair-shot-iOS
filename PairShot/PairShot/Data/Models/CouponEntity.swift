import Foundation
import SwiftData

@Model
final class CouponEntity {
    @Attribute(.unique) var id: UUID
    var serverCouponId: String = ""
    var code: String
    var activatedAt: Date
    var durationDays: Int
    var signatureBase64: String
    var status: Coupon.Status
    var kindRawString: String = ""
    var payloadVersion: Int = 1
    var issuedAt = Date(timeIntervalSince1970: 0)

    init(
        id: UUID = UUID(),
        code: String,
        activatedAt: Date = .now,
        durationDays: Int,
        signatureBase64: String,
        status: Coupon.Status = .active,
        kindRawString: String? = nil,
        payloadVersion: Int = 1,
        issuedAt: Date? = nil,
        serverCouponId: String = ""
    ) {
        self.id = id
        self.serverCouponId = serverCouponId
        self.code = code
        self.activatedAt = activatedAt
        self.durationDays = durationDays
        self.signatureBase64 = signatureBase64
        self.status = status
        self.kindRawString = kindRawString ?? "\(CouponKind.timedPrefix)\(durationDays)"
        self.payloadVersion = payloadVersion
        self.issuedAt = issuedAt ?? activatedAt
    }
}
