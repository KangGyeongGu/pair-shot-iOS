import SwiftUI

struct ExportSettingsView: View {
    @Bindable var viewModel: ExportSettingsViewModel
    let onPushWatermarkSettings: (() -> Void)?
    let onPushCombineSettings: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(RewardedAdManager.self) private var rewardedManager
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(\.fullscreenAdCoordinator) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                includesSection
                formatSection
                watermarkSection
                combineSection
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(String(localized: "export_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(String(localized: "common_button_close"))
            }
            ToolbarItemGroup(placement: .bottomBar) {
                shareButton
                Spacer()
                saveButton
            }
        }
        .overlay { busyOverlay }
        .alert(
            String(localized: "export_picker_dialog_failed_title"),
            isPresented: errorBinding,
            presenting: viewModel.errorMessage
        ) { _ in
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .sheet(item: shareItemsBinding) { items in
            ShareSheet(activityItems: items.values) {
                viewModel.clearShareItems()
            }
        }
        .background(
            Color.clear
                .sheet(item: zipExportBinding) { item in
                    DocumentExporter(url: item.url) { saved in
                        viewModel.handleZipExportCompleted(saved)
                    }
                }
        )
        .onDisappear { viewModel.cleanupPendingZip() }
        .task { await observeEvents() }
        .task { rewardedManager.loadIfNeeded(adFreeStore: adFreeStore) }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showWatermarkGateDialog
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmWatermarkGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_watermark_detail"))
        }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showCombineGateDialog
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmCombineGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_combine_detail"))
        }
    }

    private var includesSection: some View {
        Section {
            Toggle(String(localized: "export_settings_include_combined"), isOn: $viewModel.includeCombined)
            Toggle(String(localized: "Before"), isOn: $viewModel.includeBefore)
            Toggle(String(localized: "After"), isOn: $viewModel.includeAfter)
            PhotosLimitedAccessButton()
        } header: {
            Text(String(localized: "export_settings_section_include"))
        }
    }

    private var formatSection: some View {
        Section {
            Picker(String(localized: "export_settings_field_format"), selection: $viewModel.format) {
                Label(
                    String(localized: "export_settings_format_image"),
                    systemImage: "photo"
                )
                .tag(ExportFormat.individualImages)
                Label(
                    String(localized: "ZIP"),
                    systemImage: "doc.zipper"
                )
                .tag(ExportFormat.zip)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text(String(localized: "export_settings_section_format"))
        }
    }

    private var watermarkSection: some View {
        Section {
            Toggle(String(localized: "export_settings_apply_watermark"), isOn: $viewModel.applyWatermark)
            if viewModel.applyWatermark {
                Button {
                    if viewModel.requestWatermarkGate(rewardedManager: rewardedManager) {
                        onPushWatermarkSettings?()
                    }
                } label: {
                    userSettingsRowLabel
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "export_settings_section_watermark"))
        }
    }

    private var combineSection: some View {
        Section {
            Toggle(String(localized: "export_settings_apply_combine"), isOn: $viewModel.applyCombineSettings)
            if viewModel.applyCombineSettings {
                Button {
                    if viewModel.requestCombineGate(rewardedManager: rewardedManager) {
                        onPushCombineSettings?()
                    }
                } label: {
                    userSettingsRowLabel
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "export_settings_section_combine"))
        }
    }

    private var userSettingsRowLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
            Text(String(localized: "settings_item_user_settings"))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var shareButton: some View {
        Button {
            Task { await viewModel.share() }
        } label: {
            Label(
                String(localized: "common_button_share"),
                systemImage: "square.and.arrow.up"
            )
        }
        .disabled(!viewModel.canExecute)
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveToDevice() }
        } label: {
            Label(
                String(localized: "common_button_save_to_device"),
                systemImage: "arrow.down.to.line"
            )
        }
        .disabled(!viewModel.canExecute)
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if viewModel.isExporting {
            ZStack {
                Color.appLetterbox.opacity(0.35).ignoresSafeArea()
                ProgressView(String(localized: "export_progress_exporting"))
                    .padding()
                    .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14), kind: .thin)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var shareItemsBinding: Binding<ExportShareItems?> {
        Binding(
            get: { viewModel.shareItems },
            set: { viewModel.shareItems = $0 }
        )
    }

    private var zipExportBinding: Binding<DocumentExporterItem?> {
        Binding(
            get: { viewModel.zipExportItem },
            set: { newValue in
                if newValue == nil, viewModel.zipExportItem != nil {
                    viewModel.handleZipExportCompleted(false)
                }
            }
        )
    }

    init(
        viewModel: ExportSettingsViewModel,
        onPushWatermarkSettings: (() -> Void)? = nil,
        onPushCombineSettings: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onPushWatermarkSettings = onPushWatermarkSettings
        self.onPushCombineSettings = onPushCombineSettings
    }

    @MainActor
    private func confirmWatermarkGate() async {
        let result = await viewModel.confirmWatermarkGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController()
        )
        if case .proceed = result {
            onPushWatermarkSettings?()
        }
    }

    @MainActor
    private func confirmCombineGate() async {
        let result = await viewModel.confirmCombineGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController()
        )
        if case .proceed = result {
            onPushCombineSettings?()
        }
    }

    private func observeEvents() async {
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()
            }
        }
    }
}
