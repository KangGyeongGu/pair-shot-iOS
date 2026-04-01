import CoreLocation
import SwiftData
import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Project) -> Void

    @State private var nameText: String = ""
    @State private var locationManager = CLLocationManager()
    @State private var currentLocation: CLLocation?
    @State private var authStatus: CLAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("현장 이름") {
                    TextField(defaultName, text: $nameText)
                        .submitLabel(.done)
                }

                Section {
                    locationRow
                }
            }
            .navigationTitle("새 현장 촬영")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("시작") { createProject() }
                }
            }
        }
        .onAppear { requestLocationIfNeeded() }
    }

    private var defaultName: String {
        Self.makeDefaultName(from: Date())
    }

    static func makeDefaultName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(formatter.string(from: date)) 현장"
    }

    @ViewBuilder
    private var locationRow: some View {
        switch authStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if let loc = currentLocation {
                    Label(
                        String(format: "%.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude),
                        systemImage: "location.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Label("위치 확인 중…", systemImage: "location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

            case .denied, .restricted:
                Label("위치 정보 없이 생성됩니다", systemImage: "location.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            default:
                Label("위치 권한 요청 중…", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
        }
    }

    private func requestLocationIfNeeded() {
        authStatus = locationManager.authorizationStatus
        switch authStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                startLocationUpdate()

            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdate()

            default:
                break
        }
    }

    private func startLocationUpdate() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        // 최초 위치 수신 후 즉시 사용
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                currentLocation = locationManager.location
                authStatus = locationManager.authorizationStatus
                locationManager.stopUpdatingLocation()
            }
        }
    }

    private func createProject() {
        let title = nameText.trimmingCharacters(in: .whitespaces).isEmpty ? defaultName : nameText
        let project = Project(
            title: title,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude
        )
        modelContext.insert(project)
        dismiss()
        onCreated(project)
    }
}
