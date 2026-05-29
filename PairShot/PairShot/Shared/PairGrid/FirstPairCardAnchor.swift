import SwiftUI

struct FirstPairCardAnchor: ViewModifier {
    let isFirst: Bool

    func body(content: Content) -> some View {
        if isFirst {
            content.tutorialAnchor(TutorialAnchorID.homeFirstPairCard)
        } else {
            content
        }
    }
}
