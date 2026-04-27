import SwiftUI
import UIKit

struct CameraBottomBar: View {
    let lastThumbnail: UIImage?
    let isCapturing: Bool
    let canShowHomeIcon: Bool
    let onLeadingTap: () -> Void
    let onShutter: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack {
            leadingButton
            Spacer()
            shutterButton
            Spacer()
            settingsButton
        }
        .frame(height: 116)
        .padding(.horizontal, AppSpacing.xxl)
        .background(Color.appCameraBackground)
    }

    private var leadingButton: some View {
        Button(action: onLeadingTap) {
            if let lastThumbnail {
                Image(uiImage: lastThumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityLabel(String(localized: "camera_desc_last_thumbnail"))
            } else if canShowHomeIcon {
                Image(systemName: "house.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .accessibilityLabel(String(localized: "camera_desc_home"))
            } else {
                Color.clear.frame(width: 56, height: 56)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canShowHomeIcon && lastThumbnail == nil)
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
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

    private var settingsButton: some View {
        Button(action: onSettingsTap) {
            Image(systemName: "gearshape")
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .accessibilityLabel(String(localized: "camera_desc_settings"))
        }
        .buttonStyle(.plain)
    }
}
