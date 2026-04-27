import Foundation
import SwiftData
import SwiftUI

struct AdFreeStatusView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var statusViewModel: AdFreeStatusViewModel?
    @State private var registrationViewModel: CouponRegistrationViewModel?
    @State private var isShowingScanner = false
    @State private var isShowingManualEntry = false
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            if let statusViewModel, let registrationViewModel {
                content(statusViewModel: statusViewModel, registrationViewModel: registrationViewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "ad_free_status_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { ensureViewModels() }
    }

    private func ensureViewModels() {
        if statusViewModel == nil {
            statusViewModel = env.makeAdFreeStatusViewModel()
        }
        if registrationViewModel == nil {
            registrationViewModel = env.makeCouponRegistrationViewModel()
        }
    }

    private func content(
        statusViewModel: AdFreeStatusViewModel,
        registrationViewModel: CouponRegistrationViewModel
    ) -> some View {
        Form {
            bannerSection
            statusSection(viewModel: statusViewModel)
            registrationSection(
                statusViewModel: statusViewModel,
                registrationViewModel: registrationViewModel
            )
            myCouponsSection(viewModel: statusViewModel)
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            QRScannerView(
                onScan: { token in
                    isShowingScanner = false
                    Task { await handleScannedToken(
                        token,
                        statusViewModel: statusViewModel,
                        registrationViewModel: registrationViewModel
                    ) }
                },
                onCancel: { isShowingScanner = false }
            )
        }
        .alert(
            String(localized: "coupon_dialog_title"),
            isPresented: $isShowingManualEntry
        ) {
            TextField(
                String(localized: "coupon_dialog_input_hint"),
                text: Binding(
                    get: { registrationViewModel.inputCode },
                    set: { registrationViewModel.inputCode = $0 }
                )
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            Button(String(localized: "coupon_dialog_register")) {
                Task { await handleManualSubmit(
                    statusViewModel: statusViewModel,
                    registrationViewModel: registrationViewModel
                ) }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "coupon_dialog_input_message"))
        }
        .alert(
            String(localized: "coupon_dialog_register_failed_title"),
            isPresented: errorBinding(for: registrationViewModel),
            presenting: registrationViewModel.lastError
        ) { _ in
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                registrationViewModel.lastError = nil
            }
        } message: { error in
            Text(message(for: error))
        }
    }

    private var bannerSection: some View {
        Section {
            BannerAdSlot()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private func statusSection(viewModel: AdFreeStatusViewModel) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isAdFree ? "checkmark.seal.fill" : "lock.open.fill")
                    .foregroundStyle(viewModel.isAdFree ? .green : .secondary)
                    .frame(width: 24)
                Text(viewModel.headline())
                    .multilineTextAlignment(.leading)
            }
        } header: {
            Text(String(localized: "ad_free_status_section_status"))
        } footer: {
            Text(String(localized: "ad_free_status_hint"))
        }
    }

    private func registrationSection(
        statusViewModel: AdFreeStatusViewModel,
        registrationViewModel: CouponRegistrationViewModel
    ) -> some View {
        Section {
            Button {
                isShowingScanner = true
            } label: {
                Label(
                    String(localized: "coupon_button_scan_qr"),
                    systemImage: "qrcode.viewfinder"
                )
            }
            .disabled(registrationViewModel.isSubmitting)

            Button {
                registrationViewModel.inputCode = ""
                isShowingManualEntry = true
            } label: {
                Label(
                    String(localized: "coupon_button_enter_code"),
                    systemImage: "keyboard"
                )
            }
            .disabled(registrationViewModel.isSubmitting)

            if let successMessage {
                Label {
                    Text(successMessage)
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text(String(localized: "ad_free_register_section_title"))
        } footer: {
            Text(String(localized: "ad_free_register_intro"))
        }
    }

    @ViewBuilder
    private func myCouponsSection(viewModel: AdFreeStatusViewModel) -> some View {
        let active = viewModel.activeCoupons
        let past = viewModel.pastCoupons
        Section {
            if active.isEmpty, past.isEmpty {
                Text(String(localized: "coupon_my_coupons_empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(active) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: nil,
                        statusTint: .green,
                        viewModel: viewModel
                    )
                }
                ForEach(past) { coupon in
                    CouponLedgerRow(
                        coupon: coupon,
                        statusLabel: viewModel.pastStatusLabel(for: coupon),
                        statusTint: .secondary,
                        viewModel: viewModel
                    )
                }
            }
        } header: {
            HStack {
                Text(String(localized: "coupon_my_coupons_section"))
                Spacer()
                Button {
                    openURL(AdFreeExternalLinks.couponHelp)
                } label: {
                    HStack(spacing: 4) {
                        Text(String(localized: "coupon_dialog_need_coupon"))
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .textCase(nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func errorBinding(for viewModel: CouponRegistrationViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )
    }

    private func handleScannedToken(
        _ token: String,
        statusViewModel: AdFreeStatusViewModel,
        registrationViewModel: CouponRegistrationViewModel
    ) async {
        await registrationViewModel.acceptScannedToken(token)
        await handlePostSubmit(statusViewModel: statusViewModel, registrationViewModel: registrationViewModel)
    }

    private func handleManualSubmit(
        statusViewModel: AdFreeStatusViewModel,
        registrationViewModel: CouponRegistrationViewModel
    ) async {
        await registrationViewModel.submit()
        await handlePostSubmit(statusViewModel: statusViewModel, registrationViewModel: registrationViewModel)
    }

    private func handlePostSubmit(
        statusViewModel: AdFreeStatusViewModel,
        registrationViewModel: CouponRegistrationViewModel
    ) async {
        guard let expiration = registrationViewModel.lastSuccessExpiration else { return }
        HapticService.shared.notify(.success)
        successMessage = successMessage(for: expiration)
        registrationViewModel.inputCode = ""
        statusViewModel.refresh()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        successMessage = nil
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

            case .invalidSignature:
                String(localized: "coupon_error_invalid_signature")

            case .duplicate:
                String(localized: "coupon_error_already_registered")

            case .notFound:
                String(localized: "coupon_error_not_found")

            case .alreadyUsedOnAnotherDevice:
                String(localized: "coupon_error_already_used_other_device")

            case .revoked:
                String(localized: "coupon_error_revoked")

            case .networkError:
                String(localized: "coupon_error_network")

            case .serverError:
                String(localized: "coupon_error_server")
        }
    }
}

enum AdFreeExternalLinks {
    // swiftlint:disable:next force_unwrapping
    static let couponHelp: URL = .init(string: "https://pairshot.kangkyeonggu.com")!
}

enum AdFreeStatusFormatter {
    static let dateFormat = "yyyy-MM-dd"

    static func remainingDays(until expiration: Date, now: Date) -> Int {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfExpiration = calendar.startOfDay(for: expiration)
        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfExpiration)
        return max(0, components.day ?? 0)
    }

    static func headline(isAdFree: Bool, latestExpiration: Date?, now: Date) -> String {
        guard isAdFree, let latestExpiration else {
            return String(localized: "coupon_status_inactive")
        }
        let days = remainingDays(until: latestExpiration, now: now)
        let formatted = formatDate(latestExpiration)
        let template = String(localized: "coupon_status_active_remaining_template")
        return String(format: template, days, formatted)
    }

    static func maskCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "****" }
        let visibleCount = 4
        if trimmed.count <= visibleCount { return trimmed }
        return "****-\(trimmed.suffix(visibleCount))"
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    static func pastStatusLabel(for coupon: Coupon) -> String {
        switch coupon.status {
            case .revoked:
                String(localized: "coupon_status_canceled")

            case .expired, .active:
                String(localized: "coupon_status_expired")
        }
    }
}

private struct CouponLedgerRow: View {
    let coupon: Coupon
    let statusLabel: String?
    let statusTint: Color
    let viewModel: AdFreeStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.maskedCode(for: coupon))
                    .font(.body.monospaced())
                Spacer()
                if let statusLabel {
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusTint.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusTint)
                }
            }
            HStack(spacing: 12) {
                Label {
                    Text(viewModel.formattedDate(coupon.activatedAt))
                } icon: {
                    Image(systemName: "play.circle")
                }
                Label {
                    Text(viewModel.formattedDate(coupon.expirationDate))
                } icon: {
                    Image(systemName: "hourglass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
