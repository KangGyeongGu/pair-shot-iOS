import SwiftUI
import UIKit

/// P7.3 — SwiftUI bridge for `UIActivityViewController`. Handed an array of
/// activity items (a ZIP `URL`, an array of `UIImage`s, etc.) and a single
/// completion callback; the view controller's chrome handles everything else.
///
/// Audit-D — ``ExportPicker`` (the Form/picker UI that drives the share
/// sheet) lives in ``ExportPicker.swift`` so this file stays well under
/// the 250-line cap.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        // Audit-A — `completionWithItemsHandler`'s second parameter is
        // `completed: Bool` (false when the user dismisses without
        // picking a destination). Firing `onComplete` regardless caused
        // `ExportPicker` to dismiss on cancel, denying the user a
        // chance to pick a different export destination. Honour the
        // flag so cancels keep the picker on screen.
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {
        // Activity items are immutable for the lifetime of one share sheet —
        // recreating the controller would dismiss it mid-flight.
    }
}
