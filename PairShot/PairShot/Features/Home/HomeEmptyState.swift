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
                .font(.system(size: 56, weight: .light))
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
            case .pairs: String(localized: "Before 카메라에서 첫 페어를 만드세요")
            case .albums: String(localized: "하단 + 버튼으로 새 앨범을 만드세요")
        }
    }
}
