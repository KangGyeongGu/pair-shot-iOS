import CoreImage
import Foundation

nonisolated enum ImageProcessingContext {
    static let shared = CIContext(options: [.useSoftwareRenderer: false])
}
