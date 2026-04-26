import CoreGraphics
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ComparisonViewModel {
    enum Event {
        case dismiss
        case compositeCompleted
    }

    let pairs: [PhotoPair]
    let storage: PhotoStorageService

    var index: Int
    var mode: ComparisonView.ViewMode = .split
    var dragOffset: CGSize = .zero
    var isCompositing: Bool = false
    var compositeError: String?

    let events: AsyncStream<Event>

    private let pairRepo: PhotoPairRepository
    private let appSettings: AppSettings
    private let composer: ComparisonCompositing
    private let eventsContinuation: AsyncStream<Event>.Continuation

    init(
        pairs: [PhotoPair],
        startIndex: Int,
        pairRepo: PhotoPairRepository,
        appSettings: AppSettings,
        storage: PhotoStorageService,
        composer: ComparisonCompositing? = nil
    ) {
        self.pairs = pairs
        self.pairRepo = pairRepo
        self.appSettings = appSettings
        self.storage = storage
        self.composer = composer ?? CompositeRendererComposing(storage: storage)
        if pairs.isEmpty {
            index = 0
        } else {
            index = max(0, min(startIndex, pairs.count - 1))
        }
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    var currentPair: PhotoPair? {
        guard pairs.indices.contains(index) else { return nil }
        return pairs[index]
    }

    var pagerLabel: String {
        ComparisonPager.label(index: index, count: pairs.count)
    }

    var canComposite: Bool {
        currentPair?.afterFileName != nil && !isCompositing
    }

    var defaultLayout: CompositeLayout {
        appSettings.defaultCompositeLayout
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func onSwipeNext() {
        index = ComparisonPager.next(index: index, count: pairs.count)
    }

    func onSwipePrevious() {
        index = ComparisonPager.previous(index: index, count: pairs.count)
    }

    func onDragChanged(_ translation: CGSize) {
        dragOffset = translation
    }

    func onDragEnded(_ translation: CGSize) {
        let horizontal = translation.width
        let vertical = translation.height
        defer { dragOffset = .zero }
        if vertical > 120, abs(vertical) > abs(horizontal) {
            dismiss()
            return
        }
        guard abs(horizontal) > 80, abs(horizontal) > abs(vertical) else { return }
        if horizontal < 0 {
            onSwipeNext()
        } else {
            onSwipePrevious()
        }
    }

    func advanceMode() {
        let cases = ComparisonView.ViewMode.allCases
        let currentIdx = cases.firstIndex(of: mode) ?? 0
        mode = cases[(currentIdx + 1) % cases.count]
    }

    func clearError() {
        compositeError = nil
    }

    func runComposite(layout: CompositeLayout, in context: ModelContext) async {
        guard let pair = currentPair, !isCompositing else { return }
        isCompositing = true
        defer { isCompositing = false }
        let options = CompositeOptions(
            layout: layout,
            jpegQuality: CGFloat(appSettings.jpegQuality),
            watermarkEnabled: WatermarkOverlay.isEnabled
        )
        let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        do {
            try await composer.makeComposite(
                for: pair,
                options: options,
                fileNamePrefix: prefix,
                in: context
            )
            eventsContinuation.yield(.compositeCompleted)
        } catch {
            compositeError = Self.errorMessage(for: error)
        }
    }

    static func errorMessage(for error: Error) -> String {
        guard let renderError = error as? CompositeRenderer.RenderError else {
            return error.localizedDescription
        }
        switch renderError {
            case .beforeImageMissing:
                return String(localized: "Before 사진을 찾을 수 없습니다")

            case .afterImageMissing:
                return String(localized: "After 사진을 찾을 수 없습니다")

            case .afterPathNotSet:
                return String(localized: "After 촬영이 아직 완료되지 않았습니다")

            case .encodeFailed:
                return String(localized: "JPEG 인코딩 실패")

            case .persistFailed:
                return String(localized: "저장 실패")
        }
    }

    deinit {}
}

protocol ComparisonCompositing: Sendable {
    @MainActor
    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        fileNamePrefix: String,
        in context: ModelContext
    ) async throws
}

struct CompositeRendererComposing: ComparisonCompositing {
    let storage: PhotoStorageService

    @MainActor
    func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions,
        fileNamePrefix: String,
        in context: ModelContext
    ) async throws {
        _ = try await CompositeRenderer.makeComposite(
            for: pair,
            options: options,
            storage: storage,
            fileNamePrefix: fileNamePrefix,
            in: context
        )
    }
}
