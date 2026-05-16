import SwiftUI

struct PermissionGateView: View {
    @Bindable var viewModel: PermissionGateViewModel

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer(minLength: 16)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(String(localized: "permission_gate_title"))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "permission_gate_message"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                BlockingReasonsList(reasons: viewModel.blockingReasons)
                Spacer()
                Button {
                    viewModel.openSettings()
                } label: {
                    Text(String(localized: "permission_gate_open_settings"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
    }
}

private struct BlockingReasonsList: View {
    let reasons: [PermissionGateBlockingReason]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(reasons) { reason in
                BlockingReasonRow(reason: reason)
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct BlockingReasonRow: View {
    let reason: PermissionGateBlockingReason

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(label)
                .font(.body)
            Spacer()
            Text(String(localized: "permission_gate_status_denied"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground)),
        )
    }

    private var iconName: String {
        reason == .camera ? "camera.fill" : "photo.on.rectangle"
    }

    private var label: String {
        reason == .camera
            ? String(localized: "permission_gate_camera_label")
            : String(localized: "permission_gate_photos_label")
    }
}

#Preview {
    PermissionGateView(
        viewModel: PermissionGateViewModel(
            permissionStatusService: PermissionStatusService(),
        ),
    )
}
