import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    var aspectRatio: AspectRatio

    func makeUIView(context _: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer = previewLayer
        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context _: Context) {
        uiView.aspectRatio = aspectRatio
        uiView.setNeedsLayout()
    }
}

final class PreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var aspectRatio: AspectRatio = .ratio4_3

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layer = previewLayer else { return }
        layer.frame = bounds
        applyAspectMask()
    }

    private func applyAspectMask() {
        guard let previewLayer else { return }

        let maskRect: CGRect
        let bounds = bounds

        switch aspectRatio {
            case .ratio4_3:
                previewLayer.mask = nil
                return

            case .ratio16_9:
                // 상하 크롭: 뷰 너비 기준으로 16:9 높이를 계산
                let targetHeight = bounds.width * 9.0 / 16.0
                let yOffset = (bounds.height - targetHeight) / 2.0
                maskRect = CGRect(x: 0, y: yOffset, width: bounds.width, height: targetHeight)

            case .ratio1_1:
                // 좌우 크롭: 뷰 높이 기준으로 1:1 너비를 계산
                let side = min(bounds.width, bounds.height)
                let xOffset = (bounds.width - side) / 2.0
                let yOffset = (bounds.height - side) / 2.0
                maskRect = CGRect(x: xOffset, y: yOffset, width: side, height: side)
        }

        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = UIBezierPath(rect: maskRect).cgPath
        previewLayer.mask = maskLayer
    }
}
