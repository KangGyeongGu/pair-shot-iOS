import Foundation
import OSLog
@preconcurrency import SwiftData

@MainActor
final class SwiftDataCouponRepository: CouponRepository {
    private static let isoFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let container: ModelContainer
    private let api: any CouponActivationApi
    private let deviceHashProvider: any DeviceHashProviding
    private let now: @Sendable () -> Date

    private var context: ModelContext {
        container.mainContext
    }

    init(
        container: ModelContainer,
        api: any CouponActivationApi,
        deviceHashProvider: any DeviceHashProviding,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.container = container
        self.api = api
        self.deviceHashProvider = deviceHashProvider
        self.now = now
    }

    func fetchAll() async throws -> [Coupon] {
        try fetchAllSync()
    }

    func fetchActive(now: Date) async throws -> [Coupon] {
        try fetchAllSync().filter { $0.isCurrentlyActive(now: now) }
    }

    func add(_ coupon: Coupon) async throws {
        context.insert(coupon)
        try context.save()
    }

    func updateStatus(id: UUID, status: Coupon.Status) async throws {
        let descriptor = FetchDescriptor<Coupon>(
            predicate: #Predicate { $0.id == id }
        )
        guard let coupon = try context.fetch(descriptor).first else { return }
        coupon.status = status
        try context.save()
    }

    func rolloverExpired(now: Date) async throws {
        let all = try fetchAllSync()
        var changed = false
        for coupon in all where coupon.status == .active && !coupon.isCurrentlyActive(now: now) {
            coupon.status = .expired
            changed = true
        }
        if changed {
            try context.save()
        }
    }

    func activate(code: String) async -> CouponActivationOutcome {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalidFormat }

        let deviceHash = deviceHashProvider.deviceHash()
        let request = ActivateRequestDto(code: trimmed, deviceHash: deviceHash)
        let apiResult = await api.activate(request)

        switch apiResult {
            case let .success(response):
                return await handleSuccess(code: trimmed, response: response)

            case .invalidCodeFormat:
                return .invalidFormat

            case .invalidSignature:
                return .invalidSignature

            case .notFound:
                return .notFound

            case .alreadyUsedOnAnotherDevice:
                return .alreadyUsedOnAnotherDevice

            case .revoked:
                return .revoked

            case .networkError:
                return .networkError

            case .serverError:
                return .serverError
        }
    }

    private func handleSuccess(code: String, response: ActivateResponseDto) async -> CouponActivationOutcome {
        let timestamp = now()
        let activatedAt = Self.parseIso8601(response.activatedAt) ?? timestamp
        let isUnlimited = response.durationDays == nil && response.expiresAt == nil
        let durationDays = response.durationDays ?? 0
        let resolvedKindRawString: String? = isUnlimited ? CouponKind.unlimited.rawString : nil
        let coupon = Coupon(
            code: code,
            activatedAt: activatedAt,
            durationDays: durationDays,
            signatureBase64: "",
            status: .active,
            kindRawString: resolvedKindRawString,
            payloadVersion: 1,
            issuedAt: activatedAt,
            serverCouponId: response.couponId
        )
        do {
            try await add(coupon)
        } catch {
            AppLogger.coupon.error(
                "Coupon persistence error: \(error.localizedDescription, privacy: .public)"
            )
            return .serverError
        }
        let expiresAt = Self.parseIso8601(response.expiresAt) ?? coupon.expirationDate
        return .success(coupon: coupon, expiresAt: expiresAt)
    }

    private func fetchAllSync() throws -> [Coupon] {
        let descriptor = FetchDescriptor<Coupon>(
            sortBy: [SortDescriptor(\.activatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private static func parseIso8601(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = isoFormatterFractional.date(from: raw) { return date }
        return isoFormatterBasic.date(from: raw)
    }
}
