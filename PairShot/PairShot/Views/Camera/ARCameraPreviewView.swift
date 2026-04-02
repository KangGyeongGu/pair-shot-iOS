import ARKit
import SwiftUI

struct ARCameraPreviewView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context _: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = session
        arView.automaticallyUpdatesLighting = false
        arView.rendersCameraGrain = false
        arView.rendersMotionBlur = false
        arView.scene = SCNScene()
        arView.backgroundColor = .black
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context _: Context) {
        if uiView.session !== session {
            uiView.session = session
        }
    }
}
