import SwiftUI

struct HomeEmptyState: View {
    enum Variant {
        case pairs
        case albums
    }

    let variant: Variant

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.secondary)

            Text(headline)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var systemImage: String {
        switch variant {
            case .pairs: "camera.viewfinder"
            case .albums: "rectangle.stack"
        }
    }

    private var headline: String {
        switch variant {
            case .pairs: String(localized: "home_empty_pairs")
            case .albums: String(localized: "home_empty_albums")
        }
    }
}
