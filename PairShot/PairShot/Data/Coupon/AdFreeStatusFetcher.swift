import Foundation

nonisolated struct AdFreeStatusFetcher {
    private let config: CouponApiConfig
    private let session: URLSession

    init(config: CouponApiConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func fetch(deviceHash: String) async -> Bool? {
        guard config.isEnabled else { return nil }
        guard var components = URLComponents(string: config.baseUrl + "/ad-free") else { return nil }
        components.queryItems = [URLQueryItem(name: "d", value: deviceHash)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = config.timeoutSeconds
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(AdFreeStatusDto.self, from: data)
            return decoded.active
        } catch {
            return nil
        }
    }
}

private nonisolated struct AdFreeStatusDto: Decodable {
    let active: Bool
}
