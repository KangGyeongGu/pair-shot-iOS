import Foundation

struct ActivateRequestDto: Encodable {
    let code: String
    let deviceHash: String

    enum CodingKeys: String, CodingKey {
        case code
        case deviceHash = "device_hash"
    }
}

struct ActivateResponseDto: Decodable {
    let couponId: String
    let durationDays: Int?
    let activatedAt: String
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case couponId = "coupon_id"
        case durationDays = "duration_days"
        case activatedAt = "activated_at"
        case expiresAt = "expires_at"
    }
}

struct StatusRequestDto: Encodable {
    let couponId: String
    let deviceHash: String

    enum CodingKeys: String, CodingKey {
        case couponId = "coupon_id"
        case deviceHash = "device_hash"
    }
}

struct StatusResponseDto: Decodable {
    let status: String
    let durationDays: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case durationDays = "duration_days"
    }
}

struct CouponListRequestDto: Encodable {
    let deviceHash: String

    enum CodingKeys: String, CodingKey {
        case deviceHash = "device_hash"
    }
}

struct CouponListItemDto: Decodable {
    let couponId: String
    let shortCode: String?
    let durationDays: Int?
    let status: String
    let activatedAt: String
    let batchLabel: String?

    enum CodingKeys: String, CodingKey {
        case couponId = "coupon_id"
        case shortCode = "short_code"
        case durationDays = "duration_days"
        case status
        case activatedAt = "activated_at"
        case batchLabel = "batch_label"
    }
}

struct CouponListResponseDto: Decodable {
    let coupons: [CouponListItemDto]
}

struct ErrorResponseDto: Decodable {
    let error: String?
    let message: String?
}
