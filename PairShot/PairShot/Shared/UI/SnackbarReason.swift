import Foundation

enum SnackbarVariantKind {
    case success
    case error
    case warning
    case info
}

enum SnackbarReason: String, CaseIterable {
    case savedToPhotos
    case savedZip
    case allAfterCaptured
    case saveFailed
    case shareFailed
    case nothingToSave
    case watermarkSetupRequired
    case proFeatureGate
    case dailyLimitGate
    case labelPlacementRequiresBorder
}

enum SnackbarProgressReason: String, CaseIterable {
    case saveToPhotos
    case prepareZipExport
    case share
}

struct SnackbarReasonResolution: Equatable {
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    let iconSymbol: String
    let variant: SnackbarVariantKind
}

struct SnackbarProgressReasonResolution: Equatable {
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    let iconSymbol: String
}

enum SnackbarReasonResolver {
    static func resolve(_ reason: SnackbarReason) -> SnackbarReasonResolution {
        switch reason {
            case .savedToPhotos:
                .init(
                    title: "snackbar_savedToPhotos_title",
                    body: "snackbar_savedToPhotos_body",
                    iconSymbol: "photo.badge.checkmark",
                    variant: .success,
                )

            case .savedZip:
                .init(
                    title: "snackbar_savedZip_title",
                    body: "snackbar_savedZip_body",
                    iconSymbol: "doc.zipper",
                    variant: .success,
                )

            case .allAfterCaptured:
                .init(
                    title: "snackbar_allAfterCaptured_title",
                    body: "snackbar_allAfterCaptured_body",
                    iconSymbol: "checkmark.seal.fill",
                    variant: .success,
                )

            case .saveFailed:
                .init(
                    title: "snackbar_saveFailed_title",
                    body: "snackbar_saveFailed_body",
                    iconSymbol: "externaldrive.badge.xmark",
                    variant: .error,
                )

            case .shareFailed:
                .init(
                    title: "snackbar_shareFailed_title",
                    body: "snackbar_shareFailed_body",
                    iconSymbol: "square.and.arrow.up.trianglebadge.exclamationmark",
                    variant: .error,
                )

            case .nothingToSave:
                .init(
                    title: "snackbar_nothingToSave_title",
                    body: "snackbar_nothingToSave_body",
                    iconSymbol: "tray.fill",
                    variant: .warning,
                )

            case .watermarkSetupRequired:
                .init(
                    title: "snackbar_watermarkSetupRequired_title",
                    body: "snackbar_watermarkSetupRequired_body",
                    iconSymbol: "signature",
                    variant: .warning,
                )

            case .proFeatureGate:
                .init(
                    title: "snackbar_proFeatureGate_title",
                    body: "snackbar_proFeatureGate_body",
                    iconSymbol: "lock.fill",
                    variant: .info,
                )

            case .dailyLimitGate:
                .init(
                    title: "snackbar_dailyLimitGate_title",
                    body: "snackbar_dailyLimitGate_body",
                    iconSymbol: "hourglass",
                    variant: .info,
                )

            case .labelPlacementRequiresBorder:
                .init(
                    title: "snackbar_labelPlacementRequiresBorder_title",
                    body: "snackbar_labelPlacementRequiresBorder_body",
                    iconSymbol: "square.dashed",
                    variant: .info,
                )
        }
    }

    static func resolve(_ reason: SnackbarProgressReason) -> SnackbarProgressReasonResolution {
        switch reason {
            case .saveToPhotos:
                .init(
                    title: "snackbar_progress_saveToPhotos_title",
                    body: "snackbar_progress_saveToPhotos_body",
                    iconSymbol: "square.and.arrow.down.fill",
                )

            case .prepareZipExport:
                .init(
                    title: "snackbar_progress_prepareZipExport_title",
                    body: "snackbar_progress_prepareZipExport_body",
                    iconSymbol: "archivebox.fill",
                )

            case .share:
                .init(
                    title: "snackbar_progress_share_title",
                    body: "snackbar_progress_share_body",
                    iconSymbol: "square.and.arrow.up.fill",
                )
        }
    }
}
