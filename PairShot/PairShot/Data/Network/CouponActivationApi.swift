import Foundation

enum ActivationApiResult {
    case success(ActivateResponseDto)
    case invalidCodeFormat
    case invalidSignature
    case notFound
    case alreadyUsedOnAnotherDevice
    case revoked
    case serverError
    case networkError
}

enum StatusApiResult: Equatable {
    case activated
    case revoked
    case notFoundOrForeign
    case networkError
    case serverError
}

enum ListApiResult {
    case success([CouponListItemDto])
    case networkError
    case serverError
}

protocol CouponActivationApi: Sendable {
    func activate(_ request: ActivateRequestDto) async -> ActivationApiResult
    func fetchStatus(_ request: StatusRequestDto) async -> StatusApiResult
    func fetchMyCoupons(deviceHash: String) async -> ListApiResult
}
