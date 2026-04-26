import Foundation
import SwiftData
import SwiftUI

/// P6.4 — Coupon registration sheet.
///
/// Two surfaces:
/// 1. Manual paste of the single-token `<code>.<signatureBase64>` string.
/// 2. QR scan via `QRScannerView` (AVCaptureMetadataOutput, separate
///    AVCaptureSession from the Before/After camera actor — see SCOPE
///    note in P6.4).
///
/// On success: insert a `Coupon` row, refresh `AdFreeStore`, show a
/// success toast with the expiration date, then dismiss.
///
/// P10b — view-model, parser, typed errors and the two `Form` sections
/// live in ``CouponRegistrationSections.swift`` so this view stays
/// under the 250-line cap.
struct CouponRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AdFreeStore.self) private var adFreeStore

    @State private var viewModel = CouponRegistrationViewModel()
    @State private var isShowingScanner = false
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                ManualEntrySection(viewModel: viewModel) {
                    Task { await handleManualSubmit() }
                }
                QRScanSection(isSubmitting: viewModel.isSubmitting) {
                    isShowingScanner = true
                }
                if let successMessage {
                    successBanner(message: successMessage)
                }
            }
            .navigationTitle(String(localized: "쿠폰 등록"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .fullScreenCover(isPresented: $isShowingScanner) {
                QRScannerView(
                    onScan: { token in
                        isShowingScanner = false
                        Task { await handleScannedToken(token) }
                    },
                    onCancel: { isShowingScanner = false }
                )
            }
            .alert(
                String(localized: "쿠폰 등록 실패"),
                isPresented: errorBinding,
                presenting: viewModel.lastError
            ) { _ in
                Button(String(localized: "확인"), role: .cancel) {
                    viewModel.lastError = nil
                }
            } message: { error in
                Text(message(for: error))
            }
        }
    }

    // MARK: - Subviews

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
            Button(String(localized: "닫기")) {
                dismiss()
            }
        }
    }

    // MARK: - Bindings / helpers

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )
    }

    private func handleScannedToken(_ token: String) async {
        await viewModel.acceptScannedToken(
            token,
            store: adFreeStore,
            context: modelContext
        )
        await handlePostSubmit()
    }

    private func handleManualSubmit() async {
        await viewModel.submit(store: adFreeStore, context: modelContext)
        await handlePostSubmit()
    }

    private func handlePostSubmit() async {
        guard let expiration = viewModel.lastSuccessExpiration else { return }
        // P9.1 — success haptic on registration. Mirrors the QR scan
        // success haptic so manual paste and QR paths both confirm
        // the same way before the toast fades.
        HapticService.shared.notify(.success)
        successMessage = successMessage(for: expiration)
        // Brief pause so the user sees the toast before dismissal.
        try? await Task.sleep(nanoseconds: 900_000_000)
        dismiss()
    }

    private func successMessage(for expiration: Date) -> String {
        // Audit-C — `en_US_POSIX` so the `yyyy-MM-dd` template stays
        // Gregorian regardless of the device calendar. Mirrors
        // `AdFreeStatusFormatter.formatDate`.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let formatted = formatter.string(from: expiration)
        let template = String(localized: "쿠폰이 등록되었습니다 · 만료일 %@")
        return String(format: template, formatted)
    }

    private func message(for error: CouponRegistrationError) -> String {
        switch error {
            case .invalidFormat:
                String(localized: "코드 형식이 올바르지 않습니다")

            case .registrationFailed:
                String(localized: "쿠폰 검증 실패")

            case .verificationThrew:
                String(localized: "쿠폰 데이터를 확인할 수 없습니다")

            case .duplicate:
                String(localized: "이미 등록된 쿠폰입니다")

            case .persistFailed:
                String(localized: "쿠폰 저장에 실패했습니다")
        }
    }
}
