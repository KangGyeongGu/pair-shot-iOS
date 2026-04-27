import SwiftUI

struct CreateAlbumDialog: View {
    @Binding var isPresented: Bool
    let onCreate: (String, Bool) async -> Void

    @State private var name: String = ""
    @State private var includeLocation: Bool = true
    @State private var isCreating: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "album_dialog_rename_placeholder"),
                        text: $name
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                } header: {
                    Text(String(localized: "create_album_dialog_title_field"))
                }

                Section {
                    Toggle(String(localized: "create_album_dialog_include_location"), isOn: $includeLocation)
                } footer: {
                    Text(String(localized: "create_album_dialog_location_hint"))
                }
            }
            .navigationTitle(String(localized: "home_button_create_album"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_button_cancel")) { isPresented = false }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_button_create")) {
                        Task { await create() }
                    }
                    .disabled(trimmedName.isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() async {
        guard !trimmedName.isEmpty, !isCreating else { return }
        isCreating = true
        await onCreate(trimmedName, includeLocation)
        isCreating = false
        isPresented = false
    }
}
