import SwiftUI

struct SpotlightAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>],
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}
