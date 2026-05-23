import Foundation
@testable import PairShot
import Testing

@MainActor
struct SnackbarReasonResolverTests {
    @Test
    func `모든 SnackbarReason 의 title 과 body 키가 xcstrings 에 존재한다`() {
        for reason in SnackbarReason.allCases {
            let resolution = SnackbarReasonResolver.resolve(reason)
            Self.assertLocalizedKeyExists(resolution.title, label: "\(reason).title")
            Self.assertLocalizedKeyExists(resolution.body, label: "\(reason).body")
        }
    }

    @Test
    func `모든 SnackbarProgressReason 의 title 과 body 키가 xcstrings 에 존재한다`() {
        for reason in SnackbarProgressReason.allCases {
            let resolution = SnackbarReasonResolver.resolve(reason)
            Self.assertLocalizedKeyExists(resolution.title, label: "\(reason).title")
            Self.assertLocalizedKeyExists(resolution.body, label: "\(reason).body")
        }
    }

    @Test
    func `모든 SnackbarReason 의 iconSymbol 이 빈 문자열이 아니다`() {
        for reason in SnackbarReason.allCases {
            let resolution = SnackbarReasonResolver.resolve(reason)
            #expect(!resolution.iconSymbol.isEmpty, "Empty iconSymbol for \(reason)")
        }
    }

    @Test
    func `모든 SnackbarProgressReason 의 iconSymbol 이 빈 문자열이 아니다`() {
        for reason in SnackbarProgressReason.allCases {
            let resolution = SnackbarReasonResolver.resolve(reason)
            #expect(!resolution.iconSymbol.isEmpty, "Empty iconSymbol for \(reason)")
        }
    }

    @Test
    func `각 SnackbarReason 이 의도한 SnackbarVariantKind 로 매핑된다`() {
        let expected: [SnackbarReason: SnackbarVariantKind] = [
            .savedToPhotos: .success,
            .savedZip: .success,
            .allAfterCaptured: .success,
            .saveFailed: .error,
            .shareFailed: .error,
            .nothingToSave: .warning,
            .watermarkSetupRequired: .warning,
            .proFeatureGate: .info,
            .dailyLimitGate: .info,
            .labelPlacementRequiresBorder: .info,
        ]
        #expect(
            expected.count == SnackbarReason.allCases.count,
            "expected 매핑이 SnackbarReason.allCases 와 어긋남 — 신규 case 추가 시 기대값 동기화 필요",
        )
        for reason in SnackbarReason.allCases {
            let resolution = SnackbarReasonResolver.resolve(reason)
            #expect(
                resolution.variant == expected[reason],
                "\(reason) variant 불일치: actual=\(resolution.variant) expected=\(String(describing: expected[reason]))",
            )
        }
    }

    private static func assertLocalizedKeyExists(
        _ resource: LocalizedStringResource,
        label: String,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) {
        let key = String(describing: resource.key)
        let sentinel = "<<MISSING:\(key)>>"
        let localized = Bundle.main.localizedString(forKey: key, value: sentinel, table: nil)
        #expect(
            localized != sentinel,
            "Missing xcstrings key for \(label): \(key)",
            sourceLocation: sourceLocation,
        )
    }
}
