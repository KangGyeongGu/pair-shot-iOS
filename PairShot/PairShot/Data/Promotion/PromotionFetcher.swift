import Foundation

nonisolated struct MembershipSnapshot: Equatable, Codable {
    struct EntitlementState: Equatable, Codable {
        let active: Bool
        let expiresAt: Date?
    }

    static let empty = Self(
        pro: EntitlementState(active: false, expiresAt: nil),
        adFree: EntitlementState(active: false, expiresAt: nil)
    )

    let pro: EntitlementState
    let adFree: EntitlementState
}

nonisolated protocol PromotionFetching: Sendable {
    func fetch(deviceHash: String) async -> MembershipSnapshot?
}

nonisolated struct PromotionFetcher: PromotionFetching {
    private let config: CouponApiConfig
    private let session: URLSession

    init(config: CouponApiConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func fetch(deviceHash: String) async -> MembershipSnapshot? {
        guard config.isEnabled else { return nil }
        guard
            var components = URLComponents(string: config.baseUrl + "/api/v1/pairshot/promotion")
        else { return nil }
        components.queryItems = [URLQueryItem(name: "device", value: deviceHash)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = config.timeoutSeconds
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let dto = try decoder.decode(PromotionResponseDto.self, from: data)
            return dto.toSnapshot()
        } catch {
            return nil
        }
    }
}

private nonisolated struct PromotionResponseDto: Decodable {
    struct EntitlementStateDto: Decodable {
        let active: Bool
        let expiresAt: Date?
    }

    let pro: EntitlementStateDto
    let adFree: EntitlementStateDto

    func toSnapshot() -> MembershipSnapshot {
        MembershipSnapshot(
            pro: MembershipSnapshot.EntitlementState(
                active: pro.active,
                expiresAt: pro.expiresAt
            ),
            adFree: MembershipSnapshot.EntitlementState(
                active: adFree.active,
                expiresAt: adFree.expiresAt
            )
        )
    }
}
