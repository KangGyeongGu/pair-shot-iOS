import SwiftUI

struct ExportSettingsView: View {
    @Bindable var viewModel: ExportSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            includesSection
            formatSection
            watermarkSection
            combineSection
        }
        .listStyle(.insetGrouped)
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
        .onDisappear { viewModel.cleanupPendingZip() }
        .task { await observeEvents() }
    }

    private var includesSection: some View {
        Section {
            Toggle(String(localized: "export_settings_include_combined"), isOn: $viewModel.includeCombined)
            Toggle(String(localized: "Before"), isOn: $viewModel.includeBefore)
            Toggle(String(localized: "After"), isOn: $viewModel.includeAfter)
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
                NavigationLink(value: Route.watermarkSettings) {
                    Text(String(localized: "export_settings_button_detail"))
                }
            }
        } header: {
            Text(String(localized: "export_settings_section_watermark"))
        }
    }

    private var combineSection: some View {
        Section {
            Toggle(String(localized: "export_settings_apply_combine"), isOn: $viewModel.applyCombineSettings)
            if viewModel.applyCombineSettings {
                NavigationLink(value: Route.combineSettings) {
                    Text(String(localized: "export_settings_button_detail"))
                }
            }
        } header: {
            Text(String(localized: "export_settings_section_combine"))
        }
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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

    private func observeEvents() async {
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()
            }
        }
    }
}
