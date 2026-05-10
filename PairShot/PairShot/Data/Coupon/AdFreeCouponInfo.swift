import Foundation

nonisolated struct AdFreeCouponInfo: Equatable, Identifiable {
    let shortCode: String
    let durationDays: Int?
    let activatedAt: Date
    let expiresAt: Date?

    var id: String { shortCode }
}
