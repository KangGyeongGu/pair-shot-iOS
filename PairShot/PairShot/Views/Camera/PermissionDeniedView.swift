import SwiftUI

/// 권한 거부 상태를 표시하는 재사용 가능한 컴포넌트.
///
/// - `isBlocking = true` (카메라): 앱 사용 자체가 불가 → 설정 버튼 강조
/// - `isBlocking = false` (위치 등): 선택적 권한 → 안내 후 계속 진행 가능
struct PermissionDeniedView: View {
    let icon: String
    let title: String
    let message: String
    let showSettingsButton: Bool
    let isBlocking: Bool

    var body: some View {
        ZStack {
            if isBlocking {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            } else {
                Color(uiColor: .systemBackground)
                    .opacity(0.95)
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Spacer()
                iconView
                textSection
                if showSettingsButton {
                    settingsButton
                }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(
                isBlocking
                    ? Color(uiColor: .tertiaryLabel)
                    : Color(uiColor: .secondaryLabel)
            )
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }

    private var textSection: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var settingsButton: some View {
        Button(action: openSettings) {
            Text("설정 열기")
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isBlocking ? Color.accentColor : Color(uiColor: .secondaryLabel))
        )
        .padding(.top, 8)
        .accessibilityLabel("설정 앱 열기")
        .accessibilityHint("PairShot의 권한 설정 화면으로 이동합니다")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension PermissionDeniedView {
    static var camera: PermissionDeniedView {
        PermissionDeniedView(
            icon: "camera.fill",
            title: "카메라 접근 권한이 필요합니다",
            message: "설정에서 PairShot의 카메라 접근을 허용해주세요",
            showSettingsButton: true,
            isBlocking: true
        )
    }

    static var location: PermissionDeniedView {
        PermissionDeniedView(
            icon: "location.slash.fill",
            title: "위치 권한이 필요합니다",
            message: "위치 정보 없이도 촬영은 가능합니다",
            showSettingsButton: true,
            isBlocking: false
        )
    }
}

#Preview("카메라 권한 거부 (블로킹)") {
    PermissionDeniedView.camera
}

#Preview("위치 권한 거부 (비블로킹)") {
    PermissionDeniedView.location
}

#Preview("커스텀 권한") {
    PermissionDeniedView(
        icon: "mic.slash.fill",
        title: "마이크 접근 권한이 필요합니다",
        message: "설정에서 마이크 접근을 허용해주세요",
        showSettingsButton: true,
        isBlocking: false
    )
}
