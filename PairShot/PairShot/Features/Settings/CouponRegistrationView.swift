import Foundation
import SwiftData
import SwiftUI

struct CouponRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: CouponRegistrationViewModel?
    @State private var isShowingScanner = false
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if let viewModel {
                    content(for: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "coupon_dialog_register_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .task { ensureViewModel() }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeCouponRegistrationViewModel()
        }
    }

    private func content(for viewModel: CouponRegistrationViewModel) -> some View {
        Form {
            ManualEntrySection(viewModel: viewModel) {
                Task { await handleManualSubmit(viewModel: viewModel) }
            }
            QRScanSection(isSubmitting: viewModel.isSubmitting) {
                isShowingScanner = true
            }
            if let successMessage {
                successBanner(message: successMessage)
            }
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            QRScannerView(
                onScan: { token in
                    isShowingScanner = false
                    Task { await handleScannedToken(token, viewModel: viewModel) }
                },
                onCancel: { isShowingScanner = false }
            )
        }
        .alert(
            String(localized: "coupon_dialog_register_failed_title"),
            isPresented: errorBinding(for: viewModel),
            presenting: viewModel.lastError
        ) { _ in
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                viewModel.lastError = nil
            }
        } message: { error in
            Text(message(for: error))
        }
    }

    private func successBanner(message: String) -> some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(String(localized: "common_button_close")) {
                dismiss()
            }
        }
    }

    private func errorBinding(for viewModel: CouponRegistrationViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )
    }

    private func handleScannedToken(_ token: String, viewModel: CouponRegistrationViewModel) async {
        await viewModel.acceptScannedToken(token)
        await handlePostSubmit(viewModel: viewModel)
    }

    private func handleManualSubmit(viewModel: CouponRegistrationViewModel) async {
        await viewModel.submit()
        await handlePostSubmit(viewModel: viewModel)
    }

    private func handlePostSubmit(viewModel: CouponRegistrationViewModel) async {
        guard let expiration = viewModel.lastSuccessExpiration else { return }
        HapticService.shared.notify(.success)
        successMessage = successMessage(for: expiration)
        try? await Task.sleep(nanoseconds: 900_000_000)
        dismiss()
    }

    private func successMessage(for expiration: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let formatted = formatter.string(from: expiration)
        let template = String(localized: "coupon_register_success_template")
        return String(format: template, formatted)
    }

    private func message(for error: CouponRegistrationError) -> String {
        switch error {
            case .invalidFormat:
                String(localized: "coupon_error_invalid_code_format")

            case .registrationFailed:
                String(localized: "coupon_error_verify_failed")

            case .duplicate:
                String(localized: "coupon_error_already_registered")

            case .persistFailed:
                String(localized: "coupon_error_save_failed")
        }
    }
}
