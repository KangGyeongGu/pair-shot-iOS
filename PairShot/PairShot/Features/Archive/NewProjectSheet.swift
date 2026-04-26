import CoreLocation
import SwiftData
import SwiftUI

enum NewProjectFactory {
    static func make(
        title: String,
        includeGPS: Bool,
        locationService: any LocationProviding
    ) async -> Project? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var lat: Double?
        var lon: Double?
        if includeGPS, let location = await locationService.requestSingleLocation() {
            lat = location.coordinate.latitude
            lon = location.coordinate.longitude
        }
        return Project(title: trimmed, latitude: lat, longitude: lon)
    }
}

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let locationService: any LocationProviding

    @State private var title: String = ""
    @State private var includeGPS: Bool = true
    @State private var isLocating: Bool = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedTitle.isEmpty && !isLocating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "프로젝트 정보")) {
                    TextField(String(localized: "제목"), text: $title)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Toggle(String(localized: "위치 정보 포함"), isOn: $includeGPS)
                } footer: {
                    Text(String(localized: "프로젝트 생성 시 현재 위치를 1회 기록합니다. 권한이 없으면 위치 없이 생성됩니다."))
                        .font(.caption)
                }
            }
            .navigationTitle(String(localized: "새 프로젝트"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "취소")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLocating ? String(localized: "위치 확인…") : String(localized: "생성")) {
                        Task { await save() }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private func save() async {
        isLocating = includeGPS
        defer { isLocating = false }
        guard let project = await NewProjectFactory.make(
            title: trimmedTitle,
            includeGPS: includeGPS,
            locationService: locationService
        ) else { return }
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NewProjectSheet(locationService: PreviewLocationService())
        .modelContainer(for: [Project.self, PhotoPair.self], inMemory: true)
}

private struct PreviewLocationService: LocationProviding {
    func requestSingleLocation() async -> CLLocation? {
        CLLocation(latitude: 37.5665, longitude: 126.978)
    }
}
