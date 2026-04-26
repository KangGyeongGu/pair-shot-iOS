import Foundation
import Observation
import SwiftData
import SwiftUI

// P10b — extracted from `CouponRegistrationView.swift` to keep the view
// under 250 lines. This file owns the view-model, the parser, the typed
// error enums, and the two `Form` sections (manual paste + QR scan).
// The top-level `CouponRegistrationView` only wires them together.

// MARK: - Pure value types

/// Decoded coupon payload — `code` and `signatureBase64` parsed out of the
/// single-token QR/text format `<code>.<signatureBase64>`.
///
/// Single-token format mirrors the issuer-side QR encoding so a scan and a
/// paste arrive at the same parse path. `CouponRegistrationViewModel`
/// owns the verify → persist transition.
struct CouponPayload: Equatable {
    let code: String
    let signatureBase64: String
}

/// Errors thrown by `QRPayloadParser`. The view maps each to a localised
/// alert message; the underlying enum stays UI-free.
enum QRPayloadParseError: Error, Equatable {
    /// The input was empty or whitespace-only.
    case empty
    /// The input did not contain exactly one `.` separator.
    case wrongSeparatorCount
    /// The `code` half was empty.
    case emptyCode
    /// The `signatureBase64` half was empty.
    case emptySignature
}

/// Errors surfaced from `CouponRegistrationViewModel.submit(...)`. The view
/// renders a localised alert per case.
enum CouponRegistrationError: Error, Equatable {
    /// The token didn't parse — wrong separator / empty halves.
    case invalidFormat
    /// The signature decoded but `CouponVerifier` returned `false`.
    case registrationFailed
    /// The token was structurally valid but the underlying verifier threw
    /// (malformed base64, malformed key). Mapped from
    /// `CouponVerificationError`.
    case verificationThrew
    /// A coupon with the same `code` is already registered and currently
    /// active. We don't double-insert.
    case duplicate
    /// SwiftData `context.save()` failed.
    case persistFailed
}

/// Parses the single-token `<code>.<signatureBase64>` format used by both
/// the QR encoding and the manual text-field input. `.` is a safe
/// separator because Base64 alphabet doesn't include it.
enum QRPayloadParser {
    static func parse(_ raw: String) throws -> CouponPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QRPayloadParseError.empty }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw QRPayloadParseError.wrongSeparatorCount }

        let code = String(parts[0])
        let signature = String(parts[1])
        guard !code.isEmpty else { throw QRPayloadParseError.emptyCode }
        guard !signature.isEmpty else { throw QRPayloadParseError.emptySignature }

        return CouponPayload(code: code, signatureBase64: signature)
    }
}

// MARK: - View model (testable)

/// View-side state for the registration sheet. Pulled out of the view so
/// the verify → insert → refresh pipeline is unit-testable without
/// driving SwiftUI.
@MainActor
@Observable
final class CouponRegistrationViewModel {
    /// Current text-field / QR-scanned token. Trimmed on submit.
    var inputToken: String = ""

    /// True while `submit(...)` is in flight. The view disables inputs.
    private(set) var isSubmitting: Bool = false

    /// Last error surfaced. The view binds this to an alert.
    var lastError: CouponRegistrationError?

    /// Set on the most recent successful registration. The view shows a
    /// toast with the expiration date and dismisses.
    private(set) var lastSuccessExpiration: Date?

    /// Default duration applied to coupons whose payload doesn't encode a
    /// per-coupon duration. Mirrors the Android default.
    static let defaultDurationDays: Int = 365

    typealias VerifyFn = (_ code: String, _ signatureBase64: String) throws -> Bool

    /// Apply a scanned token from the QR scanner and immediately submit.
    func acceptScannedToken(
        _ raw: String,
        verifier: VerifyFn? = nil,
        store: AdFreeStore,
        context: ModelContext,
        durationDays: Int = defaultDurationDays,
        now: Date = .now
    ) async {
        inputToken = raw
        await submit(
            verifier: verifier,
            store: store,
            context: context,
            durationDays: durationDays,
            now: now
        )
    }

    /// Verify + persist + refresh. Surfaces user-facing errors via
    /// `lastError`; on success populates `lastSuccessExpiration`.
    func submit(
        verifier: VerifyFn? = nil,
        store: AdFreeStore,
        context: ModelContext,
        durationDays: Int = defaultDurationDays,
        now: Date = .now
    ) async {
        guard !isSubmitting else { return }
        let trimmed = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = .invalidFormat
            return
        }

        let payload: CouponPayload
        do {
            payload = try QRPayloadParser.parse(trimmed)
        } catch {
            lastError = .invalidFormat
            return
        }

        if duplicateActiveCouponExists(code: payload.code, in: context, now: now) {
            lastError = .duplicate
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let verifyImpl: VerifyFn = verifier ?? { code, sig in
            try CouponVerifier.verify(code: code, signatureBase64: sig)
        }

        let verified: Bool
        do {
            verified = try verifyImpl(payload.code, payload.signatureBase64)
        } catch {
            lastError = .verificationThrew
            return
        }

        guard verified else {
            lastError = .registrationFailed
            return
        }

        let coupon = Coupon(
            code: payload.code,
            activatedAt: now,
            durationDays: durationDays,
            signatureBase64: payload.signatureBase64
        )
        context.insert(coupon)
        do {
            try context.save()
        } catch {
            context.delete(coupon)
            lastError = .persistFailed
            return
        }

        store.refresh(now: now)
        lastSuccessExpiration = coupon.expirationDate
    }

    /// Is the supplied code already present as an `.active` coupon that
    /// hasn't yet expired? Filters in-memory because SwiftData
    /// `#Predicate` on enum raw values is brittle (mirrors `AdFreeStore`).
    private func duplicateActiveCouponExists(
        code: String,
        in context: ModelContext,
        now: Date
    ) -> Bool {
        let descriptor = FetchDescriptor<Coupon>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.contains { existing in
            existing.code == code && existing.isCurrentlyActive(now: now)
        }
    }
}

// MARK: - Form sections

/// "수동 입력" section — text field + submit button. Disabled while the
/// view-model reports `isSubmitting`.
struct ManualEntrySection: View {
    @Bindable var viewModel: CouponRegistrationViewModel
    let onSubmit: () -> Void

    var body: some View {
        Section {
            TextField(
                String(localized: "쿠폰 토큰 (code.signature)"),
                text: $viewModel.inputToken,
                axis: .vertical
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .disabled(viewModel.isSubmitting)
            .lineLimit(2 ... 5)

            Button {
                onSubmit()
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text(String(localized: "등록"))
                }
            }
            .disabled(submitDisabled)
        } header: {
            Text(String(localized: "수동 입력"))
        } footer: {
            Text(String(localized: "발급받은 쿠폰 토큰을 그대로 붙여넣으세요"))
        }
    }

    private var submitDisabled: Bool {
        viewModel.isSubmitting
            || viewModel.inputToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// "QR 스캔" section — single button that opens the scanner sheet.
struct QRScanSection: View {
    let isSubmitting: Bool
    let onTap: () -> Void

    var body: some View {
        Section {
            Button {
                onTap()
            } label: {
                Label(String(localized: "QR 코드 스캔"), systemImage: "qrcode.viewfinder")
            }
            .disabled(isSubmitting)
        } header: {
            Text(String(localized: "QR 스캔"))
        }
    }
}
