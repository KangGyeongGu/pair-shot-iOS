import Foundation
import SwiftData
import SwiftUI
import UIKit

struct ComparisonView: View {
    let pairs: [PhotoPair]
    let startIndex: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env

    @State private var viewModel: ComparisonViewModel?

    init(pairs: [PhotoPair], startIndex: Int) {
        self.pairs = pairs
        self.startIndex = startIndex
    }

    enum ViewMode: String, Hashable, CaseIterable {
        case split
        case beforeOnly
        case afterOnly
    }

    var index: Int {
        if pairs.isEmpty { return 0 }
        return max(0, min(startIndex, pairs.count - 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let viewModel {
                    content(for: viewModel)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle(viewModel?.pagerLabel ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .alert(
                String(localized: "합성 실패"),
                isPresented: errorBinding,
                presenting: viewModel?.compositeError
            ) { _ in
                Button(String(localized: "확인"), role: .cancel) { viewModel?.clearError() }
            } message: { message in
                Text(message)
            }
        }
        .task { ensureViewModel() }
        .task { await observeEvents() }
        .preferredColorScheme(.dark)
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeComparisonViewModel(pairs: pairs, startIndex: startIndex)
        }
    }

    private func observeEvents() async {
        while viewModel == nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let viewModel else { return }
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()

                case .compositeCompleted:
                    HapticService.shared.notify(.success)
                    await env.interstitialAdManager.presentIfReady(
                        from: BannerAdView.resolveRootViewController(),
                        coordinator: env.fullscreenAdCoordinator,
                        adFreeStore: env.adFreeStore
                    )
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: ComparisonViewModel) -> some View {
        if let pair = viewModel.currentPair {
            ComparisonImagePane(pair: pair, mode: viewModel.mode, storage: viewModel.storage)
                .id(pair.id)
                .offset(viewModel.dragOffset)
                .gesture(swipeGesture(for: viewModel))
                .onTapGesture { viewModel.advanceMode() }
        } else {
            emptyState
        }

        if viewModel.isCompositing {
            ProgressView(String(localized: "합성 중..."))
                .controlSize(.large)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel?.dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "닫기"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            modePicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            CompositeMenu(
                defaultLayout: viewModel?.defaultLayout ?? .horizontal,
                isDisabled: viewModel?.canComposite != true,
                onSelect: { layout in handleComposite(layout: layout) }
            )
        }
    }

    private var modePicker: some View {
        let binding = Binding<ViewMode>(
            get: { viewModel?.mode ?? .split },
            set: { viewModel?.mode = $0 }
        )
        return Picker(String(localized: "보기"), selection: binding) {
            Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
            Image(systemName: "1.square").tag(ViewMode.beforeOnly)
            Image(systemName: "2.square").tag(ViewMode.afterOnly)
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white.opacity(0.6))
            Text(String(localized: "비교할 사진이 없습니다"))
                .foregroundStyle(.white)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.compositeError != nil },
            set: { if !$0 { viewModel?.clearError() } }
        )
    }

    private func swipeGesture(for viewModel: ComparisonViewModel) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                viewModel.onDragChanged(value.translation)
            }
            .onEnded { value in
                viewModel.onDragEnded(value.translation)
            }
    }

    private func handleComposite(layout: CompositeLayout) {
        guard let viewModel else { return }
        Task { @MainActor in
            await viewModel.runComposite(layout: layout, in: modelContext)
        }
    }
}
