import SwiftUI

struct ProLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(String(localized: "common_pro_locked"))
    }
}
