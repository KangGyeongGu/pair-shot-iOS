import CoreLocation
import SwiftUI

struct CreateAlbumDialog: View {
    @Binding var isPresented: Bool
    let onCreate: (String, Double?, Double?, String?) async -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var name: String = ""
    @State private var isCreating: Bool = false
    @State private var resolvedLatitude: Double?
    @State private var resolvedLongitude: Double?
    @State private var resolvedLabel: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        placeholderText,
                        text: $name
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                } header: {
                    Text(String(localized: "create_album_dialog_title_field"))
                } footer: {
                    Text(String(localized: "home_dialog_album_create_hint"))
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
                    .disabled(submitName.isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView().controlSize(.large)
                }
            }
            .task { await resolveLocation() }
        }
    }

    private var placeholderText: String {
        let fallback = String(localized: "home_dialog_album_create_placeholder")
        guard let label = resolvedLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty
        else { return fallback }
        return label
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var submitName: String {
        if !trimmedName.isEmpty { return trimmedName }
        return resolvedLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func resolveLocation() async {
        guard resolvedLatitude == nil, resolvedLongitude == nil else { return }
        guard let coord = await env.location.fetchOnce() else { return }
        resolvedLatitude = coord.latitude
        resolvedLongitude = coord.longitude
        resolvedLabel = await Self.reverseGeocode(latitude: coord.latitude, longitude: coord.longitude)
    }

    private func create() async {
        guard !submitName.isEmpty, !isCreating else { return }
        isCreating = true
        await onCreate(submitName, resolvedLatitude, resolvedLongitude, resolvedLabel)
        isCreating = false
        isPresented = false
    }

    static func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: .current),
              let placemark = placemarks.first
        else { return nil }
        let parts = [
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.name,
        ].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let combined = parts.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }
}
