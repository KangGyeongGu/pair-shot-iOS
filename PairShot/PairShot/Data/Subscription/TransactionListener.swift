import Foundation
import Observation
import OSLog
import StoreKit

@MainActor
@Observable
final class TransactionListener {
    @ObservationIgnored private var task: Task<Void, Never>?

    func start(onUpdate: @escaping @Sendable (Transaction) async -> Void) {
        guard task == nil else { return }
        task = Task.detached(priority: .background) {
            await Self.drainUnfinished(onUpdate: onUpdate)
            for await result in Transaction.updates {
                switch result {
                    case let .verified(transaction):
                        await onUpdate(transaction)
                        await transaction.finish()

                    case let .unverified(transaction, error):
                        AppLogger.subscription
                            .error(
                                "Transaction.updates unverified product=\(transaction.productID, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                            )
                        await transaction.finish()
                }
            }
        }
    }

    private static func drainUnfinished(
        onUpdate: @escaping @Sendable (Transaction) async -> Void
    ) async {
        var verifiedCount = 0
        var unverifiedCount = 0
        for await result in Transaction.unfinished {
            switch result {
                case let .verified(transaction):
                    verifiedCount += 1
                    await onUpdate(transaction)
                    await transaction.finish()

                case let .unverified(transaction, error):
                    unverifiedCount += 1
                    AppLogger.subscription
                        .error(
                            "Transaction.unfinished unverified product=\(transaction.productID, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                        )
                    await transaction.finish()
            }
        }
        if verifiedCount > 0 || unverifiedCount > 0 {
            AppLogger.subscription
                .info(
                    "Drained unfinished transactions verified=\(verifiedCount, privacy: .public) unverified=\(unverifiedCount, privacy: .public)"
                )
        }
    }

    deinit {
        task?.cancel()
    }
}
