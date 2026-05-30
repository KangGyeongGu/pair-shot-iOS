import PhotosUI
import SwiftUI

struct WatermarkLogoPickerRow: View {
    let hasLogo: Bool
    @Binding var fileName: String?
    @Binding var pickerItem: PhotosPickerItem?
    let onClear: () -> Void

    var body: some View {
        let pickerTitle =
            hasLogo
                ? String(localized: "watermark_logo_replace_action")
                : String(localized: "watermark_logo_pick_action")
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(.secondary)
            Text(logoStateText)
                .font(.body)
                .foregroundStyle(hasLogo ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared(),
            ) {
                Text(pickerTitle)
                    .font(.footnote)
            }
            .buttonStyle(.borderless)
            if hasLogo {
                Button(role: .destructive) {
                    onClear()
                    pickerItem = nil
                } label: {
                    Text(String(localized: "watermark_logo_clear_action"))
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var logoStateText: String {
        if !hasLogo {
            return String(localized: "watermark_logo_state_empty")
        }
        return fileName ?? String(localized: "watermark_logo_state_set")
    }
}
