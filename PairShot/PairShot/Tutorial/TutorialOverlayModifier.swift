import SwiftUI

struct TutorialOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
            TutorialOverlay(anchors: anchors)
        }
    }
}

extension View {
    func tutorialOverlay() -> some View {
        modifier(TutorialOverlayModifier())
    }
}
