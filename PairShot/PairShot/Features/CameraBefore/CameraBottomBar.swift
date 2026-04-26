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
        .padding(.horizontal, 32)
        .background(Color.black)
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
                    .accessibilityLabel(String(localized: "마지막 촬영 — 홈으로 이동"))
            } else if canShowHomeIcon {
                Image(systemName: "house.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .accessibilityLabel(String(localized: "홈으로 이동"))
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
            .accessibilityLabel(String(localized: "촬영"))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }

    private var settingsButton: some View {
        Button(action: onSettingsTap) {
            Image(systemName: "gearshape")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .accessibilityLabel(String(localized: "카메라 설정"))
        }
        .buttonStyle(.plain)
    }
}
