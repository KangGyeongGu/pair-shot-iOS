enum CameraPermissionProbe {
    @Sendable
    static func resolve() async -> Bool {
        let service = await MainActor.run { PermissionStatusService() }
        return await service.requestCameraAccessIfNeeded()
    }
}
