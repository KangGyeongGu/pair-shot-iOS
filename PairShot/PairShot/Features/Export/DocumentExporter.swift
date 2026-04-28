import SwiftUI
import UIKit

struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL
    var onComplete: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.delegate = context.coordinator
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: ((Bool) -> Void)?

        init(onComplete: ((Bool) -> Void)?) {
            self.onComplete = onComplete
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            onComplete?(true)
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onComplete?(false)
        }
    }
}

struct DocumentExporterItem: Identifiable {
    let url: URL
    var id: URL {
        url
    }
}
