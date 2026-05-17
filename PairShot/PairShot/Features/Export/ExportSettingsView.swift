import SwiftUI

struct ExportSettingsView: View {
    @Bindable var viewModel: ExportSettingsViewModel
    let onPushWatermarkSettings: (() -> Void)?
    let onPushCombineSettings: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @Environment(RewardedAdManager.self) var rewardedManager
    @Environment(PromotionStore.self) var promotionStore
    @Environment(SubscriptionStore.self) var subscriptionStore
    @Environment(ExportCompletionCoordinator.self) var exportCompletionCoordinator
    @Environment(ExportTutorialCoordinator.self) private var exportTutorialCoordinator
    @Environment(\.fullscreenAdCoordinator) var coordinator
    @AppStorage("exportTutorial.completed") private var exportTutorialCompleted = false

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()
            ScrollView {
                LazyVStack(spacing: 16) {
                    includesCard
                    formatCard
                    watermarkCard
                    combineCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(String(localized: "export_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(String(localized: "common_button_close"))
            }
            ToolbarItemGroup(placement: .bottomBar) {
                shareButton
                Spacer()
                saveButton
            }
        }
        .alert(
            String(localized: "export_picker_dialog_failed_title"),
            isPresented: errorBinding,
            presenting: viewModel.errorMessage,
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
                },
        )
        .onDisappear {
            viewModel.cleanupPendingZip()
            exportCompletionCoordinator.cancelPending()
        }
        .task { await observeEvents() }
        .task {
            rewardedManager.loadIfNeeded(
                promotionStore: promotionStore,
                subscriptionStore: subscriptionStore,
            )
        }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showWatermarkGateDialog,
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
            isPresented: $viewModel.showCombineGateDialog,
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmCombineGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_combine_detail"))
        }
        .paywallSheet(isPresented: $viewModel.showPaywall)
        .exportTutorialOverlay()
        .task {
            if !exportTutorialCompleted, !exportTutorialCoordinator.isActive {
                exportTutorialCoordinator.start()
            }
        }
        .onChange(of: exportTutorialCoordinator.current) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                exportTutorialCompleted = true
            }
        }
    }

    private var includesCard: some View {
        ExportSettingsCard(header: "export_settings_section_include") {
            Toggle(String(localized: "export_settings_include_combined"), isOn: $viewModel.includeCombined)
            Divider()
            Toggle(String(localized: "Before"), isOn: $viewModel.includeBefore)
            Divider()
            Toggle(String(localized: "After"), isOn: $viewModel.includeAfter)
            PhotosLimitedAccessButton()
        }
        .tutorialAnchor(ExportTutorialAnchorID.includes)
    }

    private var formatCard: some View {
        ExportSettingsCard(header: "export_settings_section_format") {
            formatRow(format: .individualImages, systemImage: "photo", labelKey: "export_settings_format_image")
            Divider()
            formatRow(format: .zip, systemImage: "doc.zipper", labelKey: "ZIP", showsProBadge: !viewModel.isProUser)
        }
        .tutorialAnchor(ExportTutorialAnchorID.format)
    }

    private func formatRow(
        format: ExportFormat,
        systemImage: String,
        labelKey: String.LocalizationValue,
        showsProBadge: Bool = false,
    ) -> some View {
        Button {
            viewModel.selectFormat(format)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(String(localized: labelKey))
                    .foregroundStyle(.primary)
                if showsProBadge {
                    ProLockBadge()
                }
                Spacer()
                if viewModel.format == format {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var watermarkCard: some View {
        ExportSettingsCard(header: "export_settings_section_watermark") {
            Toggle(
                String(localized: "export_settings_apply_watermark"),
                isOn: applyWatermarkBinding,
            )
            if viewModel.applyWatermark {
                Divider()
                Button {
                    if viewModel.requestWatermarkGate(rewardedManager: rewardedManager) {
                        onPushWatermarkSettings?()
                    }
                } label: {
                    userSettingsRowLabel(showsSetupNeeded: viewModel.watermarkSettingsBlank)
                }
                .buttonStyle(.plain)
            }
        }
        .tutorialAnchor(ExportTutorialAnchorID.watermark)
    }

    private var combineCard: some View {
        ExportSettingsCard(header: "export_settings_section_combine") {
            Toggle(String(localized: "export_settings_apply_combine"), isOn: $viewModel.applyCombineSettings)
            if viewModel.applyCombineSettings {
                Divider()
                Button {
                    if viewModel.requestCombineGate(rewardedManager: rewardedManager) {
                        onPushCombineSettings?()
                    }
                } label: {
                    userSettingsRowLabel()
                }
                .buttonStyle(.plain)
            }
        }
        .tutorialAnchor(ExportTutorialAnchorID.combine)
    }

    private var shareButton: some View {
        Button {
            Task { await viewModel.share() }
        } label: {
            Label(
                String(localized: "common_button_share"),
                systemImage: "square.and.arrow.up",
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
                systemImage: "arrow.down.to.line",
            )
        }
        .disabled(!viewModel.canExecute)
    }

    init(
        viewModel: ExportSettingsViewModel,
        onPushWatermarkSettings: (() -> Void)? = nil,
        onPushCombineSettings: (() -> Void)? = nil,
    ) {
        self.viewModel = viewModel
        self.onPushWatermarkSettings = onPushWatermarkSettings
        self.onPushCombineSettings = onPushCombineSettings
    }

    private func userSettingsRowLabel(showsSetupNeeded: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
            Text(String(localized: "settings_item_user_settings"))
                .foregroundStyle(.primary)
            Spacer()
            if showsSetupNeeded {
                InlineWarningLabel(text: String(localized: "settings_warning_setup_needed"))
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct ExportSettingsCard<Content: View>: View {
    let header: String.LocalizationValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: header))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            VStack(spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
