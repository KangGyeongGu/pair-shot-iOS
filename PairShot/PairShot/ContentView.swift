import SwiftData
import SwiftUI

struct ContentView: View {
    @Binding var showFallbackAlert: Bool

    init(showFallbackAlert: Binding<Bool> = .constant(false)) {
        _showFallbackAlert = showFallbackAlert
    }

    var body: some View {
        NavigationStack {
            PairGalleryView()
        }
        .alert(
            String(localized: "저장소 초기화 실패"),
            isPresented: $showFallbackAlert
        ) {
            Button(String(localized: "확인"), role: .cancel) {
                showFallbackAlert = false
            }
        } message: {
            Text(String(
                localized: "일시 모드로 동작합니다. 데이터가 보존되지 않습니다. 앱 재시작 후에도 문제가 지속되면 재설치가 필요합니다."
            ))
        }
    }
}

private struct ContentViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Schema(versionedSchema: SchemaV2.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        ContentView()
            .modelContainer(container)
            .environment(AdFreeStore(context: container.mainContext))
            .environment(\.fullscreenAdCoordinator, FullscreenAdCoordinator())
            .environment(InterstitialAdManager())
            .environment(AppOpenAdManager())
            .environment(RewardedAdManager())
            .environment(NativeAdLoader())
            .environment(TrackingAuthorizationService())
            .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-content") ?? .standard))
    }
}

#Preview {
    ContentViewPreviewWrapper()
}
