import Foundation
import SwiftData

@MainActor
final class SwiftDataCouponRepository: CouponRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    nonisolated func observeAll() -> AsyncStream<[Coupon]> {
        AsyncStream { continuation in
            Task { @MainActor in
                let snapshot = (try? self.fetchAllSync()) ?? []
                continuation.yield(snapshot)
                continuation.finish()
            }
        }
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

    private func fetchAllSync() throws -> [Coupon] {
        let descriptor = FetchDescriptor<Coupon>(
            sortBy: [SortDescriptor(\.activatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    deinit {}
}
