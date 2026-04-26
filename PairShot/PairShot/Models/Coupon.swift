import Foundation
import SwiftData

/// SwiftData entity representing a redeemed AdFree coupon.
///
/// A coupon's `code` is signed off-line by the issuer (apricity) using
/// Ed25519 (`CryptoKit.Curve25519.Signing.PrivateKey`). On registration we
/// verify the signature with the embedded public key — see
/// `CouponVerifier`. Persisted state mirrors what the user redeemed; the
/// app derives ad-free status from it via `AdFreeStore`.
///
/// Lifetime model: a coupon is valid from `activatedAt` until
/// `activatedAt + durationDays`. There is no manual revocation in MVP — a
/// `revoked` status is reserved for future server-side push.
@Model
final class Coupon {
    @Attribute(.unique) var id: UUID

    /// Issuer-supplied opaque code (the signed payload).
    var code: String

    /// When the user redeemed this coupon on this device.
    var activatedAt: Date

    /// Duration in days from `activatedAt` after which the coupon expires.
    var durationDays: Int

    /// Base64-encoded Ed25519 signature over the UTF-8 bytes of `code`,
    /// produced by the issuer's private key.
    var signatureBase64: String

    /// Lifecycle state. Computed expiration is read from `expirationDate`.
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
        self.id = UUID()
        self.code = code
        self.activatedAt = activatedAt
        self.durationDays = durationDays
        self.signatureBase64 = signatureBase64
        self.status = status
    }

    /// Computed expiration timestamp = `activatedAt + durationDays`.
    var expirationDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: activatedAt)
            ?? activatedAt.addingTimeInterval(TimeInterval(durationDays) * 86_400)
    }

    /// `true` when the coupon is `.active` and not yet past `expirationDate`.
    /// `revoked`/`expired` always return `false`.
    func isCurrentlyActive(now: Date = .now) -> Bool {
        guard status == .active else { return false }
        return now < expirationDate
    }
}
