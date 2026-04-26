import Foundation
import SwiftUI

struct CouponPayload: Equatable {
    let code: String
    let signatureBase64: String
}

enum QRPayloadParseError: Error, Equatable {
    case empty
    case wrongSeparatorCount
    case emptyCode
    case emptySignature
}

enum CouponRegistrationError: Error, Equatable {
    case invalidFormat
    case registrationFailed
    case duplicate
    case persistFailed
}

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
