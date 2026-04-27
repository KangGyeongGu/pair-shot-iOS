import Foundation

struct CouponApiConfig {
    static let activatePath: String = "/coupons/activate"
    static let statusPath: String = "/coupons/status"
    static let byDevicePath: String = "/coupons/by-device"
    static let defaultTimeoutSeconds: TimeInterval = 10
    static let defaultDeviceHashSalt: String = "pairshot-coupon-v1-device-salt"

    static let baseUrlInfoKey: String = "CouponApiBaseUrl"
    static let authKeyInfoKey: String = "CouponApiAuthKey"
    static let deviceHashSaltInfoKey: String = "CouponDeviceHashSalt"

    let baseUrl: String
    let authKey: String
    let deviceHashSalt: String
    let timeoutSeconds: TimeInterval

    var isEnabled: Bool {
        !baseUrl.isEmpty
    }

    var authHeaderValue: String? {
        authKey.isEmpty ? nil : "Bearer \(authKey)"
    }

    static func resolve(bundle: Bundle = .main) -> Self {
        let base = trimmedString(bundle.object(forInfoDictionaryKey: baseUrlInfoKey))
        let auth = trimmedString(bundle.object(forInfoDictionaryKey: authKeyInfoKey))
        let saltRaw = trimmedString(bundle.object(forInfoDictionaryKey: deviceHashSaltInfoKey))
        let salt = saltRaw.isEmpty ? defaultDeviceHashSalt : saltRaw
        return Self(
            baseUrl: base,
            authKey: auth,
            deviceHashSalt: salt,
            timeoutSeconds: defaultTimeoutSeconds
        )
    }

    private static func trimmedString(_ value: Any?) -> String {
        guard let raw = value as? String else { return "" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
