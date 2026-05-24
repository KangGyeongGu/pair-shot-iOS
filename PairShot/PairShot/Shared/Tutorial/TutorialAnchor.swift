import SwiftUI

extension View {
    func tutorialAnchor(_ id: String) -> some View {
        anchorPreference(key: SpotlightAnchorKey.self, value: .bounds) { [id: $0] }
    }
}
