import SwiftUI

struct CameraBottomBar: View {
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

    private var settingsIconSize: CGFloat {
        max(0, zoneHeight * 0.241)
    }

    private var homeIconSize: CGFloat {
        max(0, zoneHeight * 0.276)
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
            Image(systemName: "house.fill")
                .font(.system(size: homeIconSize, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: sideButtonSize, height: sideButtonSize)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "camera_desc_home"))
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
        isCapturing: Bool,
        zoneHeight: CGFloat,
        onLeadingTap: @escaping () -> Void,
        onShutter: @escaping () -> Void,
        onSettingsTap: @escaping () -> Void,
        shutterAnchorID: String? = nil,
        leadingAnchorID: String? = nil,
    ) {
        self.isCapturing = isCapturing
        self.zoneHeight = zoneHeight
        self.onLeadingTap = onLeadingTap
        self.onShutter = onShutter
        self.onSettingsTap = onSettingsTap
        self.shutterAnchorID = shutterAnchorID
        self.leadingAnchorID = leadingAnchorID
    }
}
