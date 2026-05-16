import CoreLocation
import Foundation

extension HomeViewModel {
    func openCreateAlbum() {
        albumNameInput = ""
        resolvedAlbumLatitude = nil
        resolvedAlbumLongitude = nil
        resolvedAlbumLabel = nil
        showCreateAlbum = true
    }

    func preloadAlbumLocation() async {
        guard resolvedAlbumLatitude == nil, resolvedAlbumLongitude == nil else { return }
        guard let coord = await location.fetchOnce() else { return }
        resolvedAlbumLatitude = coord.latitude
        resolvedAlbumLongitude = coord.longitude
        resolvedAlbumLabel = await HomeReverseGeocoder.label(latitude: coord.latitude, longitude: coord.longitude)
    }

    func confirmCreateAlbum() async {
        let trimmed = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = resolvedAlbumLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? fallback : trimmed
        guard !finalName.isEmpty else {
            resetCreateAlbumState()
            return
        }
        await createAlbum(
            name: finalName,
            latitude: resolvedAlbumLatitude,
            longitude: resolvedAlbumLongitude,
            locationLabel: resolvedAlbumLabel,
        )
        resetCreateAlbumState()
    }

    func cancelCreateAlbum() {
        resetCreateAlbumState()
    }

    func createAlbum(
        name: String,
        latitude: Double?,
        longitude: Double?,
        locationLabel: String?,
    ) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let album = Album(
            name: trimmed,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
        )
        try? await albumRepo.add(album)
    }

    private func resetCreateAlbumState() {
        albumNameInput = ""
        resolvedAlbumLatitude = nil
        resolvedAlbumLongitude = nil
        resolvedAlbumLabel = nil
    }
}
