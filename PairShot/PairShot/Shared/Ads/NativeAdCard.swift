import SwiftUI
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

struct NativeAdCard: View {
    let slotIndex: Int

    @Environment(NativeAdLoader.self) private var loader
    @Environment(AdFreeStore.self) private var adFreeStore
    @State private var ad: Any?

    var body: some View {
        Group {
            if adFreeStore.isAdFree {
                EmptyView()
            } else {
                cardBody
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
                    )
                    .onAppear { ensureAdLoaded() }
                    .id("native-ad-slot-\(slotIndex)")
            }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        #if canImport(GoogleMobileAds)
            if let nativeAd = ad as? GADNativeAd {
                NativeAdMediumRepresentable(nativeAd: nativeAd)
                    .background(Color.appOnSurfaceVariant.opacity(0.05))
            } else {
                placeholder
            }
        #else
            placeholder
        #endif
    }

    private var placeholder: some View {
        ZStack {
            Color.appOnSurfaceVariant.opacity(0.1)
            Text(String(localized: "ads_native_label"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private func ensureAdLoaded() {
        guard ad == nil else { return }
        ad = loader.dequeue(adFreeStore: adFreeStore)
    }
}

#if canImport(GoogleMobileAds)
    private struct NativeAdMediumRepresentable: UIViewRepresentable {
        let nativeAd: GADNativeAd

        func makeUIView(context _: Context) -> GADNativeAdView {
            let adView = GADNativeAdView()
            let icon = Self.makeIconView()
            let headline = Self.makeHeadlineLabel()
            let body = Self.makeBodyLabel()
            let cta = Self.makeCTAButton()
            let adLabel = Self.makeAdMarkLabel()

            adView.addSubview(adLabel)
            adView.addSubview(icon)
            adView.addSubview(headline)
            adView.addSubview(body)
            adView.addSubview(cta)

            adView.iconView = icon
            adView.headlineView = headline
            adView.bodyView = body
            adView.callToActionView = cta

            Self.activateConstraints(
                adView: adView,
                adLabel: adLabel,
                icon: icon,
                headline: headline,
                body: body,
                cta: cta
            )

            adView.nativeAd = nativeAd
            return adView
        }

        func updateUIView(_ adView: GADNativeAdView, context _: Context) {
            adView.nativeAd = nativeAd
            (adView.headlineView as? UILabel)?.text = nativeAd.headline
            (adView.bodyView as? UILabel)?.text = nativeAd.body
            if let cta = adView.callToActionView as? UIButton {
                var config = cta.configuration ?? UIButton.Configuration.filled()
                config.title = nativeAd.callToAction
                cta.configuration = config
            }
            if let iconView = adView.iconView as? UIImageView {
                iconView.image = nativeAd.icon?.image
            }
        }

        private static func makeIconView() -> UIImageView {
            let icon = UIImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.contentMode = .scaleAspectFit
            icon.layer.cornerRadius = 8
            icon.clipsToBounds = true
            return icon
        }

        private static func makeHeadlineLabel() -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 2
            return label
        }

        private static func makeBodyLabel() -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 2
            label.textColor = .secondaryLabel
            return label
        }

        private static func makeCTAButton() -> UIButton {
            var ctaConfig = UIButton.Configuration.filled()
            ctaConfig.baseBackgroundColor = .systemBlue
            ctaConfig.baseForegroundColor = .white
            ctaConfig.cornerStyle = .small
            ctaConfig.contentInsets = NSDirectionalEdgeInsets(
                top: 6, leading: 12, bottom: 6, trailing: 12
            )
            let cta = UIButton(configuration: ctaConfig)
            cta.translatesAutoresizingMaskIntoConstraints = false
            cta.isUserInteractionEnabled = false
            return cta
        }

        private static func makeAdMarkLabel() -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = String(localized: "ads_native_label")
            label.font = .systemFont(ofSize: 9, weight: .semibold)
            label.textColor = .white
            label.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.95)
            label.textAlignment = .center
            label.layer.cornerRadius = 3
            label.layer.masksToBounds = true
            return label
        }

        private static func activateConstraints(
            adView: UIView,
            adLabel: UILabel,
            icon: UIImageView,
            headline: UILabel,
            body: UILabel,
            cta: UIButton
        ) {
            NSLayoutConstraint.activate([
                adLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 6),
                adLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 6),
                adLabel.widthAnchor.constraint(equalToConstant: 22),
                adLabel.heightAnchor.constraint(equalToConstant: 12),

                icon.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
                icon.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
                icon.widthAnchor.constraint(equalToConstant: 48),
                icon.heightAnchor.constraint(equalToConstant: 48),

                headline.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
                headline.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                headline.trailingAnchor.constraint(equalTo: cta.leadingAnchor, constant: -8),

                body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 2),
                body.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                body.trailingAnchor.constraint(equalTo: cta.leadingAnchor, constant: -8),

                cta.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
                cta.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
            ])
        }
    }
#endif
