import Foundation

enum CouponRegistrationError: Error, Equatable {
    case invalidFormat
    case invalidSignature
    case duplicate
    case notFound
    case alreadyUsedOnAnotherDevice
    case revoked
    case networkError
    case serverError
}
