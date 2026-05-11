import Foundation

nonisolated struct AdFreeStatusFetcher {
    private let config: CouponApiConfig
    private let session: URLSession

    init(config: CouponApiConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func fetch(deviceHash: String) async -> AdFreeStatusResult? {
        guard config.isEnabled else { return nil }
        guard var components = URLComponents(string: config.baseUrl + "/api/pairshot/ad-free") else { return nil }
        components.queryItems = [URLQueryItem(name: "d", value: deviceHash)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = config.timeoutSeconds
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(AdFreeStatusDto.self, from: data)
            return decoded.toResult()
        } catch {
            return nil
        }
    }
}

nonisolated struct AdFreeStatusResult: Equatable, Codable {
    let active: Bool
    let expiresAt: Date?
    let remainingDays: Int?
    let couponCount: Int
    let activeCoupons: [AdFreeCouponInfo]
}

nonisolated private struct AdFreeStatusDto: Decodable {
    let active: Bool
    let expiresAt: Date?
    let remainingDays: Int?
    let couponCount: Int
    let activeCoupons: [AdFreeCouponItemDto]

    enum CodingKeys: String, CodingKey {
        case active
        case expiresAt = "expires_at"
        case remainingDays = "remaining_days"
        case couponCount = "coupon_count"
        case activeCoupons = "active_coupons"
    }

    func toResult() -> AdFreeStatusResult {
        AdFreeStatusResult(
            active: active,
            expiresAt: expiresAt,
            remainingDays: remainingDays,
            couponCount: couponCount,
            activeCoupons: activeCoupons.map { $0.toInfo() }
        )
    }
}

nonisolated private struct AdFreeCouponItemDto: Decodable {
    let shortCode: String
    let durationDays: Int?
    let activatedAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case shortCode = "short_code"
        case durationDays = "duration_days"
        case activatedAt = "activated_at"
        case expiresAt = "expires_at"
    }

    func toInfo() -> AdFreeCouponInfo {
        AdFreeCouponInfo(
            shortCode: shortCode,
            durationDays: durationDays,
            activatedAt: activatedAt,
            expiresAt: expiresAt
        )
    }
}
