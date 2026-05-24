import PhotosUI
import SwiftUI

struct WatermarkLogoPickerRow: View {
    @Binding var imageData: Data?
    @Binding var fileName: String?
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        let pickerTitle =
            imageData == nil
                ? String(localized: "watermark_logo_pick_action")
                : String(localized: "watermark_logo_replace_action")
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(.secondary)
            Text(logoStateText)
                .font(.body)
                .foregroundStyle(imageData == nil ? .secondary : .primary)
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
            if imageData != nil {
                Button(role: .destructive) {
                    imageData = nil
                    fileName = nil
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
        if imageData == nil {
            return String(localized: "watermark_logo_state_empty")
        }
        return fileName ?? String(localized: "watermark_logo_state_set")
    }
}
