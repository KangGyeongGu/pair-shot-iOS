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
                        String(localized: "앨범 이름 입력"),
                        text: $name
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                } header: {
                    Text(String(localized: "제목"))
                }

                Section {
                    Toggle(String(localized: "위치 정보 포함"), isOn: $includeLocation)
                } footer: {
                    Text(String(
                        localized: "프로젝트 생성 시 현재 위치를 1회 기록합니다. 권한이 없으면 위치 없이 생성됩니다."
                    ))
                }
            }
            .navigationTitle(String(localized: "앨범 생성"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "취소")) { isPresented = false }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "생성")) {
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
