import Foundation
import Observation
import SwiftUI

enum SnackbarVariant: Equatable {
    case success
    case error
    case warning
    case info
    case progress(value: Double)
    case indeterminateProgress
}

struct SnackbarItem: Identifiable, Equatable {
    let id: UUID
    let token: String?
    let message: LocalizedStringResource
    let variant: SnackbarVariant
    let isActionable: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        token: String? = nil,
        message: LocalizedStringResource,
        variant: SnackbarVariant,
        isActionable: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.token = token
        self.message = message
        self.variant = variant
        self.isActionable = isActionable
        self.createdAt = createdAt
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.variant == rhs.variant && lhs.message == rhs.message
    }

    var isProgress: Bool {
        switch variant {
            case .progress, .indeterminateProgress:
                true

            default:
                false
        }
    }
}

struct SnackbarProgressHandle: Equatable {
    let token: String
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

    @discardableResult
    func enqueueProgress(
        _ message: LocalizedStringResource,
        token: String,
        initialValue: Double? = nil
    ) -> SnackbarProgressHandle {
        let now = clock()
        let variant: SnackbarVariant = initialValue
            .map { .progress(value: max(0, min(1, $0))) } ?? .indeterminateProgress
        let item = SnackbarItem(
            token: token,
            message: message,
            variant: variant,
            isActionable: false,
            createdAt: now
        )
        if current?.token == token {
            current = item
        } else if let pendingIndex = pending.firstIndex(where: { $0.token == token }) {
            pending[pendingIndex] = item
        } else {
            dismissTask?.cancel()
            dismissTask = nil
            pending.insert(item, at: 0)
            current = nil
            advance(startTimer: false)
        }
        return SnackbarProgressHandle(token: token)
    }

    func updateProgress(_ handle: SnackbarProgressHandle, value: Double, message: LocalizedStringResource? = nil) {
        let clamped = max(0, min(1, value))
        let now = clock()
        if let active = current, active.token == handle.token {
            current = SnackbarItem(
                id: active.id,
                token: active.token,
                message: message ?? active.message,
                variant: .progress(value: clamped),
                isActionable: false,
                createdAt: active.createdAt
            )
        } else if let index = pending.firstIndex(where: { $0.token == handle.token }) {
            let existing = pending[index]
            pending[index] = SnackbarItem(
                id: existing.id,
                token: existing.token,
                message: message ?? existing.message,
                variant: .progress(value: clamped),
                isActionable: false,
                createdAt: now
            )
        }
    }

    func completeProgress(
        _ handle: SnackbarProgressHandle,
        finalMessage: LocalizedStringResource? = nil,
        finalVariant: SnackbarVariant = .success
    ) {
        if let active = current, active.token == handle.token {
            dismissTask?.cancel()
            dismissTask = nil
            if let message = finalMessage {
                let now = clock()
                current = SnackbarItem(
                    token: nil,
                    message: message,
                    variant: finalVariant,
                    isActionable: false,
                    createdAt: now
                )
                scheduleDismiss(for: current!)
            } else {
                current = nil
                advance()
            }
        } else {
            pending.removeAll { $0.token == handle.token }
        }
    }

    func cancelProgress(_ handle: SnackbarProgressHandle) {
        completeProgress(handle, finalMessage: nil, finalVariant: .info)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
        advance()
    }

    private func advance(startTimer: Bool = true) {
        guard current == nil, !pending.isEmpty else { return }
        let next = pending.removeFirst()
        current = next
        if startTimer, !next.isProgress {
            scheduleDismiss(for: next)
        }
    }

    private func scheduleDismiss(for item: SnackbarItem) {
        guard !item.isProgress else { return }
        let duration = item.isActionable ? Self.actionableDuration : Self.nonActionableDuration
        let scheduledId = item.id
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
