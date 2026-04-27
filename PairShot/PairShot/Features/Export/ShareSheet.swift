import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
