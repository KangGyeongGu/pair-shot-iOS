import AppTrackingTransparency
import Foundation
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

/// Audit-B — central builder for `GADRequest` instances.
///
/// Why this exists:
/// - **AdFree guard** (CLAUDE.md core principle 7): when the user is
///   ad-free we must never even construct a request. ``build(...)``
///   returns `nil` in that case so the calling manager early-returns
///   without touching the SDK.
/// - **ATT deny / restricted → npa signal**: when the user has
///   explicitly denied tracking (or is in an environment that
///   restricts it), Google requires the request to carry the
///   `["npa": "1"]` extra so the served ad falls back to the
///   non-personalised inventory. Forgetting this on a single surface
///   is a privacy compliance hole, so all ad managers must funnel
///   through this helper instead of constructing `GADRequest()`
///   themselves.
///
/// Production flow:
/// ```swift
/// guard let request = AdRequestBuilder.build(
///     isAdFree: adFreeStore.isAdFree,
///     attStatus: ATTrackingManager.trackingAuthorizationStatus
/// ) else { return }   // ad-free → skip entirely
/// GADInterstitialAd.load(withAdUnitID: id, request: request) { ... }
/// ```
///
/// The helper is a pure value transformation — it does not call
/// `ATTrackingManager.requestTrackingAuthorization`. Prompting is
/// owned by ``TrackingAuthorizationService`` and happens once during
/// the app's bootstrap.
enum AdRequestBuilder {
    #if canImport(GoogleMobileAds)
        /// Builds a request honouring the supplied AdFree + ATT state.
        /// - Parameters:
        ///   - isAdFree: Current AdFree entitlement. `true` short-circuits
        ///     to `nil` so no SDK object is allocated.
        ///   - attStatus: Latest tracking authorization status. Anything
        ///     other than `.authorized` results in the npa extra being
        ///     attached.
        /// - Returns: A configured `GADRequest`, or `nil` when AdFree.
        ///   When the SDK isn't linked (CI sandbox without
        ///   GoogleMobileAds) this overload is unavailable — callers
        ///   must short-circuit through ``shouldAttachNonPersonalised(attStatus:)``.
        static func build(
            isAdFree: Bool,
            attStatus: ATTrackingManager.AuthorizationStatus
        ) -> GADRequest? {
            guard !isAdFree else { return nil }
            let request = GADRequest()
            if shouldAttachNonPersonalised(attStatus: attStatus) {
                let extras = GADExtras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
            }
            return request
        }
    #endif

    /// Pure-decision overload — usable from environments that don't
    /// link the Google Mobile Ads SDK (CI, unit tests). Returns
    /// `true` when a request should be built and the npa extra
    /// attached.
    static func shouldAttachNonPersonalised(
        attStatus: ATTrackingManager.AuthorizationStatus
    ) -> Bool {
        // `.authorized` is the only state that permits IDFA-based
        // personalisation. Everything else (denied / restricted /
        // notDetermined) must fall back to non-personalised serving.
        attStatus != .authorized
    }
}
