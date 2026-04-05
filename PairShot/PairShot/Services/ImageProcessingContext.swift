import CoreImage
import Foundation

nonisolated enum ImageProcessingContext {
    static let shared = CIContext(options: [.cacheIntermediates: false])
}
