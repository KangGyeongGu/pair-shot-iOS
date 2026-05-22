import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        func viewForZooming(in _: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > ZoomableImageView.minZoom {
                scrollView.setZoomScale(ZoomableImageView.minZoom, animated: true)
            } else {
                let point = recognizer.location(in: imageView)
                let zoomRect = makeZoomRect(
                    scale: ZoomableImageView.doubleTapZoom,
                    center: point,
                    in: scrollView,
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        func layoutForImage(in scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else {
                imageView?.frame = .zero
                scrollView.contentSize = .zero
                return
            }
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds.height > 0 else { return }
            let imageSize = image.size
            let widthRatio = bounds.width / imageSize.width
            let heightRatio = bounds.height / imageSize.height
            let fitScale = min(widthRatio, heightRatio)
            let fitted = CGSize(
                width: imageSize.width * fitScale,
                height: imageSize.height * fitScale,
            )
            imageView.frame = CGRect(origin: .zero, size: fitted)
            scrollView.contentSize = fitted
            centerContent(in: scrollView)
        }

        private func centerContent(in scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            let horizontalInset = max(0, (bounds.width - contentSize.width) / 2)
            let verticalInset = max(0, (bounds.height - contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset,
            )
        }

        private func makeZoomRect(
            scale: CGFloat,
            center: CGPoint,
            in scrollView: UIScrollView,
        ) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale,
            )
            let origin = CGPoint(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
            )
            return CGRect(origin: origin, size: size)
        }
    }

    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 4.0
    static let doubleTapZoom: CGFloat = 2.5

    let image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = Self.minZoom
        scrollView.maximumZoomScale = Self.maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:)),
        )
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        if imageView.image !== image {
            imageView.image = image
            scrollView.setZoomScale(Self.minZoom, animated: false)
            context.coordinator.layoutForImage(in: scrollView)
        } else {
            context.coordinator.layoutForImage(in: scrollView)
        }
    }
}
