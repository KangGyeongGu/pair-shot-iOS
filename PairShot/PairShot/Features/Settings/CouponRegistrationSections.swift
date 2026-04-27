import Foundation
import SwiftUI

enum CouponRegistrationError: Error, Equatable {
    case invalidFormat
    case registrationFailed
    case duplicate
    case persistFailed
}

struct CouponSignedToken: Equatable {
    let payloadJSON: Data
    let signatureBase64: String
}

enum CouponSignedTokenParseError: Error, Equatable {
    case empty
    case wrongSeparatorCount
    case malformedPayloadBase64
    case emptyPayload
    case emptySignature
}

enum CouponSignedTokenParser {
    static func parse(_ raw: String) throws -> CouponSignedToken {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CouponSignedTokenParseError.empty }

        let parts = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw CouponSignedTokenParseError.wrongSeparatorCount }

        let payloadBase64 = String(parts[0])
        let signatureBase64 = String(parts[1])
        guard !payloadBase64.isEmpty else { throw CouponSignedTokenParseError.emptyPayload }
        guard !signatureBase64.isEmpty else { throw CouponSignedTokenParseError.emptySignature }

        guard let payloadData = Data(base64Encoded: payloadBase64) else {
            throw CouponSignedTokenParseError.malformedPayloadBase64
        }
        guard !payloadData.isEmpty else { throw CouponSignedTokenParseError.emptyPayload }

        return CouponSignedToken(payloadJSON: payloadData, signatureBase64: signatureBase64)
    }
}

struct ManualEntrySection: View {
    @Bindable var viewModel: CouponRegistrationViewModel
    let onSubmit: () -> Void

    var body: some View {
        Section {
            TextField(
                String(localized: "coupon_dialog_token_field"),
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
                    Text(String(localized: "coupon_dialog_register"))
                }
            }
            .disabled(submitDisabled)
        } header: {
            Text(String(localized: "coupon_section_manual_input"))
        } footer: {
            Text(String(localized: "coupon_section_manual_hint"))
        }
    }

    private var submitDisabled: Bool {
        viewModel.isSubmitting
            || viewModel.inputToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct QRScanSection: View {
    let isSubmitting: Bool
    let onTap: () -> Void

    var body: some View {
        Section {
            Button {
                onTap()
            } label: {
                Label(String(localized: "coupon_button_scan_qr"), systemImage: "qrcode.viewfinder")
            }
            .disabled(isSubmitting)
        } header: {
            Text(String(localized: "coupon_section_qr"))
        }
    }
}
