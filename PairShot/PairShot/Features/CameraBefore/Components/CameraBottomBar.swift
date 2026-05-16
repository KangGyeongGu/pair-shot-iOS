import SwiftUI
import UIKit

struct CameraBottomBar: View {
    let lastThumbnail: UIImage?
    let isCapturing: Bool
    let zoneHeight: CGFloat
    let onLeadingTap: () -> Void
    let onShutter: () -> Void
    let onSettingsTap: () -> Void
    let shutterAnchorID: String?
    let leadingAnchorID: String?

    private var sideButtonSize: CGFloat {
        max(0, zoneHeight * 0.483)
    }

    private var shutterOuterSize: CGFloat {
        max(0, zoneHeight * 0.483)
    }

    private var shutterInnerSize: CGFloat {
        max(0, zoneHeight * 0.414)
    }

    private var thumbnailCornerRadius: CGFloat {
        max(0, zoneHeight * 0.069)
    }

    private var settingsIconSize: CGFloat {
        max(0, zoneHeight * 0.241)
    }

    private var homeIconScale: CGFloat {
        max(0, zoneHeight / 116.0)
    }

    var body: some View {
        HStack {
            leadingButton
            Spacer()
            shutterButton
            Spacer()
            trailingButton
        }
        .frame(height: zoneHeight)
        .padding(.horizontal, AppSpacing.xxl)
        .background(Color.appCameraBackground)
    }

    @ViewBuilder
    private var leadingButton: some View {
        let button = Button(action: onLeadingTap) {
            ZStack {
                if let lastThumbnail {
                    Image(uiImage: lastThumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: sideButtonSize, height: sideButtonSize)
                        .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: thumbnailCornerRadius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1),
                        )
                        .accessibilityLabel(String(localized: "camera_desc_last_thumbnail"))
                } else {
                    Image(systemName: "house.fill")
                        .font(.system(size: 28 * homeIconScale))
                        .foregroundStyle(.white)
                        .frame(width: sideButtonSize, height: sideButtonSize)
                        .accessibilityLabel(String(localized: "camera_desc_home"))
                }
            }
        }
        .buttonStyle(.plain)
        if let leadingAnchorID {
            button.tutorialAnchor(leadingAnchorID)
        } else {
            button
        }
    }

    @ViewBuilder
    private var shutterButton: some View {
        let button = Button(action: onShutter) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: shutterOuterSize, height: shutterOuterSize)
                Circle()
                    .fill(Color.white)
                    .frame(width: shutterInnerSize, height: shutterInnerSize)
                    .opacity(isCapturing ? 0.4 : 1.0)
                if isCapturing {
                    ProgressView()
                        .tint(.gray)
                }
            }
            .accessibilityLabel(String(localized: "camera_desc_capture"))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
        if let shutterAnchorID {
            button.tutorialAnchor(shutterAnchorID)
        } else {
            button
        }
    }

    private var trailingButton: some View {
        Button(action: onSettingsTap) {
            Image(systemName: "gearshape")
                .font(.system(size: settingsIconSize, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: sideButtonSize, height: sideButtonSize)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "camera_settings_title"))
        }
        .buttonStyle(.plain)
    }

    init(
        lastThumbnail: UIImage?,
        isCapturing: Bool,
        zoneHeight: CGFloat,
        onLeadingTap: @escaping () -> Void,
        onShutter: @escaping () -> Void,
        onSettingsTap: @escaping () -> Void,
        shutterAnchorID: String? = nil,
        leadingAnchorID: String? = nil,
    ) {
        self.lastThumbnail = lastThumbnail
        self.isCapturing = isCapturing
        self.zoneHeight = zoneHeight
        self.onLeadingTap = onLeadingTap
        self.onShutter = onShutter
        self.onSettingsTap = onSettingsTap
        self.shutterAnchorID = shutterAnchorID
        self.leadingAnchorID = leadingAnchorID
    }
}
