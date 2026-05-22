import Foundation
import Observation
import SwiftUI

enum SnackbarVariant: Equatable {
    case success
    case error
    case warning
    case info
    case progress(value: Double, processed: Int?, total: Int?)
    case indeterminateProgress
}

struct SnackbarItem: Identifiable, Equatable {
    let id: UUID
    let token: String?
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    let iconSymbol: String
    let variant: SnackbarVariant
    let isActionable: Bool
    let createdAt: Date

    var isProgress: Bool {
        switch variant {
            case .progress, .indeterminateProgress:
                true

            default:
                false
        }
    }

    init(
        title: LocalizedStringResource,
        body: LocalizedStringResource,
        iconSymbol: String,
        variant: SnackbarVariant,
        isActionable: Bool,
        createdAt: Date,
        id: UUID = UUID(),
        token: String? = nil,
    ) {
        self.id = id
        self.token = token
        self.title = title
        self.body = body
        self.iconSymbol = iconSymbol
        self.variant = variant
        self.isActionable = isActionable
        self.createdAt = createdAt
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.variant == rhs.variant
            && lhs.title == rhs.title
            && lhs.body == rhs.body
            && lhs.iconSymbol == rhs.iconSymbol
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
    static let actionableDuration: TimeInterval = 6.0

    var current: SnackbarItem?
    weak var tutorialCoordinator: TutorialCoordinator?

    var hasPendingAutoDismiss: Bool {
        dismissTask != nil
    }

    private var pending: [SnackbarItem] = []
    private var lastEnqueueTimes: [String: Date] = [:]
    private var dismissTask: Task<Void, Never>?
    private let clock: @MainActor () -> Date
    private let hapticService: HapticService

    init(
        hapticService: HapticService = HapticService(),
        tutorialCoordinator: TutorialCoordinator? = nil,
        clock: @escaping @MainActor () -> Date = { Date() },
    ) {
        self.hapticService = hapticService
        self.tutorialCoordinator = tutorialCoordinator
        self.clock = clock
    }

    func enqueue(
        _ reason: SnackbarReason,
        isActionable: Bool = false,
        debounceKey: String? = nil,
    ) {
        if tutorialCoordinator?.isActive == true { return }
        let now = clock()
        let key = debounceKey ?? reason.rawValue
        if let last = lastEnqueueTimes[key],
           now.timeIntervalSince(last) < Self.debounceWindow
        {
            return
        }
        lastEnqueueTimes[key] = now
        let resolution = SnackbarReasonResolver.resolve(reason)
        let variant = mapVariant(resolution.variant)
        let item = SnackbarItem(
            title: resolution.title,
            body: resolution.body,
            iconSymbol: resolution.iconSymbol,
            variant: variant,
            isActionable: isActionable,
            createdAt: now,
        )
        pending.append(item)
        if let kind = hapticKind(for: variant) {
            hapticService.notify(kind)
        }
        if current == nil {
            advance()
        }
    }

    private func mapVariant(_ kind: SnackbarVariantKind) -> SnackbarVariant {
        switch kind {
            case .success: .success
            case .error: .error
            case .warning: .warning
            case .info: .info
        }
    }

    private func hapticKind(for variant: SnackbarVariant) -> HapticNotificationKind? {
        switch variant {
            case .error: .error
            case .warning: .warning
            case .success: .success
            case .info, .progress, .indeterminateProgress: nil
        }
    }

    @discardableResult
    func enqueueProgress(
        _ reason: SnackbarProgressReason,
        token: String,
        initialValue: Double? = nil,
    ) -> SnackbarProgressHandle {
        if tutorialCoordinator?.isActive == true {
            return SnackbarProgressHandle(token: token)
        }
        let now = clock()
        let resolution = SnackbarReasonResolver.resolve(reason)
        let variant: SnackbarVariant =
            initialValue
                .map { .progress(value: max(0, min(1, $0)), processed: nil, total: nil) }
                ?? .indeterminateProgress
        let item = SnackbarItem(
            title: resolution.title,
            body: resolution.body,
            iconSymbol: resolution.iconSymbol,
            variant: variant,
            isActionable: false,
            createdAt: now,
            token: token,
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

    func updateProgress(
        _ handle: SnackbarProgressHandle,
        value: Double,
        processed: Int? = nil,
        total: Int? = nil,
    ) {
        let clamped = max(0, min(1, value))
        let now = clock()
        let variant: SnackbarVariant = .progress(value: clamped, processed: processed, total: total)
        if let active = current, active.token == handle.token {
            current = SnackbarItem(
                title: active.title,
                body: active.body,
                iconSymbol: active.iconSymbol,
                variant: variant,
                isActionable: false,
                createdAt: active.createdAt,
                id: active.id,
                token: active.token,
            )
        } else if let index = pending.firstIndex(where: { $0.token == handle.token }) {
            let existing = pending[index]
            pending[index] = SnackbarItem(
                title: existing.title,
                body: existing.body,
                iconSymbol: existing.iconSymbol,
                variant: variant,
                isActionable: false,
                createdAt: now,
                id: existing.id,
                token: existing.token,
            )
        }
    }

    func completeProgress(
        _ handle: SnackbarProgressHandle,
        finalReason: SnackbarReason? = nil,
    ) {
        if let active = current, active.token == handle.token {
            dismissTask?.cancel()
            dismissTask = nil
            if let finalReason {
                let now = clock()
                let resolution = SnackbarReasonResolver.resolve(finalReason)
                let replacement = SnackbarItem(
                    title: resolution.title,
                    body: resolution.body,
                    iconSymbol: resolution.iconSymbol,
                    variant: mapVariant(resolution.variant),
                    isActionable: false,
                    createdAt: now,
                    token: nil,
                )
                current = replacement
                scheduleDismiss(for: replacement)
            } else {
                current = nil
                advance()
            }
        } else {
            pending.removeAll { $0.token == handle.token }
        }
    }

    func cancelProgress(_ handle: SnackbarProgressHandle) {
        completeProgress(handle, finalReason: nil)
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
}
