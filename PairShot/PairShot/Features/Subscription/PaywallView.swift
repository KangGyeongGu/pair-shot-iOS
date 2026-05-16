import OSLog
import StoreKit
import SwiftUI
import UIKit

enum PaywallPresentationMode {
    case firstRun
    case upgrade
}

struct PaywallView: View {
    let mode: PaywallPresentationMode
    let onCompletion: () -> Void

    @Environment(SubscriptionStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @State private var didCaptureInitial: Bool = false
    @State private var wasInitiallyPro: Bool = false

    var body: some View {
        SubscriptionStoreView(groupID: ProductIDs.groupID) {
            PaywallHeader()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .storeButton(.hidden, for: .cancellation)
        .subscriptionStorePolicyDestination(url: PaywallURLs.privacy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: PaywallURLs.terms, for: .termsOfService)
        .overlay(alignment: .topTrailing) {
            if mode == .upgrade {
                Button {
                    onCompletion()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "paywall_close"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text(String(localized: "paywall_korea_refund_notice"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                if mode == .firstRun {
                    Button {
                        onCompletion()
                    } label: {
                        Text(String(localized: "paywall_continue_free"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .interactiveDismissDisabled(mode == .firstRun)
        .onAppear {
            AppLogger.ads
                .debug(
                    "PAYWALL onAppear mode=\(String(describing: mode), privacy: .public) isPro=\(store.isPro, privacy: .public)"
                )
            if !didCaptureInitial {
                wasInitiallyPro = store.isPro
                didCaptureInitial = true
            }
        }
        .onDisappear {
            AppLogger.ads
                .debug(
                    "PAYWALL onDisappear mode=\(String(describing: mode), privacy: .public) isPro=\(store.isPro, privacy: .public)"
                )
        }
        .onChange(of: store.isPro) { oldValue, newValue in
            AppLogger.ads
                .debug(
                    "PAYWALL isPro change \(oldValue, privacy: .public) -> \(newValue, privacy: .public) wasInitially=\(wasInitiallyPro, privacy: .public)"
                )
            guard didCaptureInitial, !wasInitiallyPro, newValue else { return }
            AppLogger.ads.debug("PAYWALL onCompletion via isPro change")
            onCompletion()
        }
        .snackbarOverlay(env.snackbarQueue)
    }
}

private struct PaywallHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            AppIconBadge()
            Text(String(localized: "paywall_title"))
                .font(.title.weight(.bold))
            Text(String(localized: "paywall_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                PaywallFeatureRow(text: String(localized: "paywall_feature_unlimited_pairs"))
                PaywallFeatureRow(text: String(localized: "paywall_feature_no_ads"))
                PaywallFeatureRow(text: String(localized: "paywall_feature_all_access"))
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }
}

private struct PaywallFeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.green)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

private struct AppIconBadge: View {
    var body: some View {
        if let icon = Bundle.main.appIconImage {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .frame(width: 72, height: 72)
        }
    }
}

private extension Bundle {
    var appIconImage: UIImage? {
        guard let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let lastFile = files.last
        else { return nil }
        return UIImage(named: lastFile)
    }
}
