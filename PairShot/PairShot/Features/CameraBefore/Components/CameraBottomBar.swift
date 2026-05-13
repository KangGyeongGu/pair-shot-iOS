import SwiftUI
import UIKit

struct CameraBottomBar: View {
    let lastThumbnail: UIImage?
    let isCapturing: Bool
    let zoneHeight: CGFloat
    let onLeadingTap: () -> Void
    let onShutter: () -> Void
    let onSettingsTap: () -> Void

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

    private var leadingButton: some View {
        Button(action: onLeadingTap) {
            ZStack {
                if let lastThumbnail {
                    Image(uiImage: lastThumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: sideButtonSize, height: sideButtonSize)
                        .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: thumbnailCornerRadius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
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
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
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
}
