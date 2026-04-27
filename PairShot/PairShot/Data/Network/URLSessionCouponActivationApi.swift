import Foundation
import OSLog

struct URLSessionCouponActivationApi: CouponActivationApi {
    private static let badRequestErrorInvalidCodeFormat: String = "INVALID_CODE_FORMAT"
    private static let badRequestErrorInvalidSignature: String = "INVALID_SIGNATURE"
    private static let revokedStatusValue: String = "revoked"

    private let config: CouponApiConfig
    private let session: URLSession

    init(config: CouponApiConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func activate(_ request: ActivateRequestDto) async -> ActivationApiResult {
        guard config.isEnabled else {
            AppLogger.coupon.warning("Coupon API base URL is empty — activation disabled")
            return .networkError
        }
        guard let urlRequest = makeRequest(path: CouponApiConfig.activatePath, body: request) else {
            return .networkError
        }
        return await performActivate(urlRequest)
    }

    func fetchStatus(_ request: StatusRequestDto) async -> StatusApiResult {
        guard config.isEnabled else { return .networkError }
        guard let urlRequest = makeRequest(path: CouponApiConfig.statusPath, body: request) else {
            return .networkError
        }
        return await performStatus(urlRequest)
    }

    func fetchMyCoupons(deviceHash: String) async -> ListApiResult {
        guard config.isEnabled else { return .networkError }
        let body = CouponListRequestDto(deviceHash: deviceHash)
        guard let urlRequest = makeRequest(path: CouponApiConfig.byDevicePath, body: body) else {
            return .networkError
        }
        return await performList(urlRequest)
    }

    private func performActivate(_ request: URLRequest) async -> ActivationApiResult {
        let response: (Data, HTTPURLResponse)
        do {
            response = try await sendJSON(request)
        } catch {
            AppLogger.coupon.warning("Coupon activate network error: \(error.localizedDescription, privacy: .public)")
            return .networkError
        }
        let (data, http) = response
        switch http.statusCode {
            case 200:
                return decodeActivateSuccess(data)

            case 400:
                return decodeBadRequest(data)

            case 404:
                return .notFound

            case 409:
                return .alreadyUsedOnAnotherDevice

            case 410:
                return .revoked

            case 429:
                return .serverError

            default:
                AppLogger.coupon.warning("Coupon activate unexpected status=\(http.statusCode, privacy: .public)")
                return .serverError
        }
    }

    private func performStatus(_ request: URLRequest) async -> StatusApiResult {
        let response: (Data, HTTPURLResponse)
        do {
            response = try await sendJSON(request)
        } catch {
            return .networkError
        }
        let (data, http) = response
        switch http.statusCode {
            case 200:
                return decodeStatusSuccess(data)

            case 404:
                return .notFoundOrForeign

            case 429:
                return .serverError

            default:
                return .serverError
        }
    }

    private func performList(_ request: URLRequest) async -> ListApiResult {
        let response: (Data, HTTPURLResponse)
        do {
            response = try await sendJSON(request)
        } catch {
            return .networkError
        }
        let (data, http) = response
        switch http.statusCode {
            case 200:
                return decodeListSuccess(data)

            case 429:
                return .serverError

            default:
                return .serverError
        }
    }

    private func decodeActivateSuccess(_ data: Data) -> ActivationApiResult {
        do {
            let dto = try JSONDecoder().decode(ActivateResponseDto.self, from: data)
            return .success(dto)
        } catch {
            AppLogger.coupon
                .warning("Coupon activate 200 decode failed: \(error.localizedDescription, privacy: .public)")
            return .serverError
        }
    }

    private func decodeBadRequest(_ data: Data) -> ActivationApiResult {
        let body = try? JSONDecoder().decode(ErrorResponseDto.self, from: data)
        switch body?.error {
            case Self.badRequestErrorInvalidCodeFormat:
                return .invalidCodeFormat

            case Self.badRequestErrorInvalidSignature:
                return .invalidSignature

            default:
                AppLogger.coupon
                    .warning("Coupon activate 400 unrecognized error=\(body?.error ?? "nil", privacy: .public)")
                return .invalidCodeFormat
        }
    }

    private func decodeStatusSuccess(_ data: Data) -> StatusApiResult {
        do {
            let dto = try JSONDecoder().decode(StatusResponseDto.self, from: data)
            return dto.status == Self.revokedStatusValue ? .revoked : .activated
        } catch {
            return .serverError
        }
    }

    private func decodeListSuccess(_ data: Data) -> ListApiResult {
        do {
            let dto = try JSONDecoder().decode(CouponListResponseDto.self, from: data)
            return .success(dto.coupons)
        } catch {
            return .serverError
        }
    }

    private func makeRequest(path: String, body: some Encodable) -> URLRequest? {
        let trimmedBase = config.baseUrl.hasSuffix("/")
            ? String(config.baseUrl.dropLast())
            : config.baseUrl
        guard let url = URL(string: trimmedBase + path) else { return nil }
        let payload: Data
        do {
            payload = try JSONEncoder().encode(body)
        } catch {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let auth = config.authHeaderValue {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = payload
        return request
    }

    private func sendJSON(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
