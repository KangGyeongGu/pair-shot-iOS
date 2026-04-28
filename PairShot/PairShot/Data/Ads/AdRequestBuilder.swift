import AppTrackingTransparency
import Foundation
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum AdRequestBuilder {
    #if canImport(GoogleMobileAds)
        static func build(
            attStatus: ATTrackingManager.AuthorizationStatus
        ) -> GADRequest {
            let request = GADRequest()
            if shouldAttachNonPersonalised(attStatus: attStatus) {
                let extras = GADExtras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
            }
            return request
        }
    #endif

    static func shouldAttachNonPersonalised(
        attStatus: ATTrackingManager.AuthorizationStatus
    ) -> Bool {
        attStatus != .authorized
    }
}
