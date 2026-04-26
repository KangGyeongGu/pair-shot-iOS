import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        ArchiveView()
    }
}

private struct ContentViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        ContentView()
            .modelContainer(container)
            .environment(AdFreeStore(context: container.mainContext))
            .environment(\.fullscreenAdCoordinator, FullscreenAdCoordinator())
            .environment(InterstitialAdManager())
            .environment(AppOpenAdManager())
    }
}

#Preview {
    ContentViewPreviewWrapper()
}
