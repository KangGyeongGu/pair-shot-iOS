import Foundation

nonisolated struct CouponApiConfig {
    static let defaultTimeoutSeconds: TimeInterval = 10
    static let baseUrlInfoKey: String = "CouponApiBaseUrl"

    let baseUrl: String
    let timeoutSeconds: TimeInterval

    var isEnabled: Bool {
        !baseUrl.isEmpty
    }

    static func resolve(bundle: Bundle = .main) -> Self {
        let raw = bundle.object(forInfoDictionaryKey: baseUrlInfoKey) as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(baseUrl: trimmed, timeoutSeconds: defaultTimeoutSeconds)
    }
}
