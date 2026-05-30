@MainActor
enum MembershipDowngradeReconciler {
    static func reconcile(
        isPro: Bool,
        presetStore: ExportPresetStore,
        preferences: ExportPreferences,
    ) {
        guard !isPro else { return }
        if presetStore.activeIndex >= ExportPresetStore.freeAccessibleSlotCount {
            presetStore.switchActive(to: 0)
        }
        if preferences.format == .zip {
            preferences.format = .individualImages
        }
    }
}
