import Foundation
import Observation
import SwiftUI

enum SnackbarVariant: Equatable {
    case success
    case error
    case warning
    case info
}

struct SnackbarItem: Identifiable, Equatable {
    let id = UUID()
    let message: LocalizedStringResource
    let variant: SnackbarVariant
    let isActionable: Bool
    let createdAt: Date

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class SnackbarQueue {
    static let debounceWindow: TimeInterval = 1.0
    static let nonActionableDuration: TimeInterval = 3.0
    static let actionableDuration: TimeInterval = 5.0

    var current: SnackbarItem?

    private var pending: [SnackbarItem] = []
    private var lastEnqueueTimes: [String: Date] = [:]
    private var dismissTask: Task<Void, Never>?
    private let clock: @MainActor () -> Date

    init(clock: @escaping @MainActor () -> Date = { Date() }) {
        self.clock = clock
    }

    func enqueue(
        _ message: LocalizedStringResource,
        variant: SnackbarVariant = .info,
        isActionable: Bool = false,
        debounceKey: String? = nil
    ) {
        let now = clock()
        if let key = debounceKey,
           let last = lastEnqueueTimes[key],
           now.timeIntervalSince(last) < Self.debounceWindow
        {
            return
        }
        if let key = debounceKey {
            lastEnqueueTimes[key] = now
        }
        let item = SnackbarItem(
            message: message,
            variant: variant,
            isActionable: isActionable,
            createdAt: now
        )
        pending.append(item)
        if current == nil {
            advance()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
        advance()
    }

    private func advance() {
        guard current == nil, !pending.isEmpty else { return }
        let next = pending.removeFirst()
        current = next
        let duration = next.isActionable ? Self.actionableDuration : Self.nonActionableDuration
        let scheduledId = next.id
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if current?.id == scheduledId {
                dismiss()
            }
        }
    }

    deinit {}
}
