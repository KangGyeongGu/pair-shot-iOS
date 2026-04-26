import Foundation
import SwiftUI

struct ExportPicker: View {
    let pairs: [PhotoPair]
    let storage: PhotoStorageService

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExportPickerViewModel?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            content
        }
        .task { ensureViewModel() }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            body(for: viewModel)
        } else {
            ProgressView()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeExportPickerViewModel(
                pairs: pairs,
                storage: storage
            )
        }
    }

    @ViewBuilder
    private func body(for viewModel: ExportPickerViewModel) -> some View {
        @Bindable var bindable = viewModel
        Form {
            modeSection(viewModel: viewModel, binding: $bindable.mode)
            actionsSection(viewModel: viewModel)
        }
        .navigationTitle(String(localized: "내보내기"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "닫기")) { dismiss() }
            }
        }
        .overlay { busyOverlay(phase: viewModel.phase) }
        .alert(item: $bindable.error) { err in
            Alert(
                title: Text(String(localized: "내보내기 실패")),
                message: Text(err.message),
                dismissButton: .default(Text(String(localized: "확인")))
            )
        }
        .sheet(item: $bindable.shareItems) { items in
            ShareSheet(activityItems: items.values) {
                viewModel.clearShareItems()
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .onDisappear { viewModel.cleanupPendingZip() }
        .task { await observeEvents(viewModel: viewModel) }
    }

    private func observeEvents(viewModel: ExportPickerViewModel) async {
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()

                case let .toast(message):
                    toast = message
            }
        }
    }

    private func modeSection(
        viewModel: ExportPickerViewModel,
        binding: Binding<ExportMode>
    ) -> some View {
        Section {
            Picker(String(localized: "범위"), selection: binding) {
                ForEach(ExportMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(String(format: String(localized: "%d개 페어"), viewModel.pairCount))
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            Text(String(localized: "포함할 사진"))
        }
    }

    private func actionsSection(viewModel: ExportPickerViewModel) -> some View {
        Section {
            Button { Task { await viewModel.shareAsZip() } } label: {
                Label(String(localized: "ZIP 으로 공유"), systemImage: "doc.zipper")
            }
            Button { Task { await viewModel.saveToPhotoLibrary() } } label: {
                Label(String(localized: "사진 앱에 저장"), systemImage: "photo.on.rectangle.angled")
            }
            Button { Task { await viewModel.shareAsImages() } } label: {
                Label(String(localized: "이미지로 공유"), systemImage: "square.and.arrow.up")
            }
        } header: {
            Text(String(localized: "작업"))
        }
        .disabled(viewModel.isBusy)
    }

    @ViewBuilder
    private func busyOverlay(phase: ExportPickerPhase) -> some View {
        if phase != .idle {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView(phase.label)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 24)
                .task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    self.toast = nil
                }
        }
    }
}
