import Observation
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

                    case let .unverified(transaction, _):
                        await transaction.finish()
                }
            }
        }
    }

    private static func drainUnfinished(
        onUpdate: @escaping @Sendable (Transaction) async -> Void,
    ) async {
        for await result in Transaction.unfinished {
            switch result {
                case let .verified(transaction):
                    await onUpdate(transaction)
                    await transaction.finish()

                case let .unverified(transaction, _):
                    await transaction.finish()
            }
        }
    }

    deinit {
        task?.cancel()
    }
}
