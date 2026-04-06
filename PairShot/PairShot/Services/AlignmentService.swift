import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import simd
import Vision

nonisolated enum AlignmentService {
    private static let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

    enum AlignmentError: Error {
        case loadFailed
        case visionFailed
        case warpFailed
        case saveFailed
    }

    struct AlignmentContext {
        let beforeTransform: simd_float4x4?
        let afterTransform: simd_float4x4?
        let beforeIntrinsics: matrix_float3x3?
        let afterIntrinsics: matrix_float3x3?
        let beforeDepthMapURL: URL?
        let depthAtCenter: Double?
        let worldMapRelocalized: Bool
    }

    static func align(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: AlignmentContext? = nil
    ) async throws -> (url: URL?, tier: String) {
        let ciCtx = ImageProcessingContext.shared
        let (tier, resolvedCtx) = resolveTier(context: context)

        let resultURL: URL? = try await Task.detached(priority: .userInitiated) {
            if let ctx = resolvedCtx, tier == "tier3" {
                try performTier3(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    context: ctx,
                    ciContext: ciCtx
                )
            } else if let ctx = resolvedCtx, tier == "tier2" {
                try performTier2(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    context: ctx,
                    ciContext: ciCtx
                )
            } else {
                try performTier1(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    ciContext: ciCtx
                )
            }
        }.value

        return (resultURL, tier)
    }

    private static func resolveTier(context: AlignmentContext?) -> (String, AlignmentContext?) {
        guard let ctx = context else { return ("tier1", nil) }
        guard ctx.worldMapRelocalized,
              ctx.beforeTransform != nil,
              ctx.afterTransform != nil,
              ctx.beforeIntrinsics != nil
        else { return ("tier1", nil) }
        let tier = ctx.beforeDepthMapURL != nil ? "tier3" : "tier2"
        return (tier, ctx)
    }

    private static func performTier1(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        ciContext: CIContext
    ) throws -> URL? {
        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 3000),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 3000)
        else {
            throw AlignmentError.loadFailed
        }

        guard let afterResized = resize(
            image: afterCG,
            to: CGSize(width: beforeCG.width, height: beforeCG.height)
        ) else { throw AlignmentError.loadFailed }

        let request = VNHomographicImageRegistrationRequest(
            targetedCGImage: afterResized,
            options: [:]
        )

        let handler = VNImageRequestHandler(
            cgImage: beforeCG,
            options: [.ciContext: ciContext]
        )

        do {
            try handler.perform([request])
        } catch {
            throw AlignmentError.visionFailed
        }

        guard let observation = request.results?.first else {
            return nil
        }

        guard let warped = applyWarp(
            cgImage: afterResized,
            warpTransform: observation.warpTransform,
            afterSize: CGSize(width: beforeCG.width, height: beforeCG.height),
            context: ciContext
        ) else {
            throw AlignmentError.warpFailed
        }

        guard let jpeg = makeJpegData(from: warped) else {
            throw AlignmentError.warpFailed
        }

        do {
            try jpeg.write(to: outputURL)
        } catch {
            throw AlignmentError.saveFailed
        }

        return outputURL
    }

    /// Tier 2: 카메라 포즈(6DOF) 기반 평면 근사 Homography
    /// homography = intrinsics * (rotation - translationOuterNormal / depth) * intrinsics_inv
    /// tRelative = tBefore * tAfter.inverse → before→after 방향 (applyWarp 내부에서 inverse 취해 after→before)
    private static func performTier2(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: AlignmentContext,
        ciContext: CIContext
    ) throws -> URL? {
        guard let beforeTransform = context.beforeTransform,
              let afterTransform = context.afterTransform,
              let intrinsics = context.beforeIntrinsics
        else { throw AlignmentError.loadFailed }

        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 3000),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 3000)
        else { throw AlignmentError.loadFailed }

        let targetSize = CGSize(width: beforeCG.width, height: beforeCG.height)
        guard let afterResized = resize(image: afterCG, to: targetSize) else {
            throw AlignmentError.loadFailed
        }

        let homography = buildPoseHomography(
            beforeTransform: beforeTransform,
            afterTransform: afterTransform,
            intrinsics: intrinsics,
            depth: Float(context.depthAtCenter ?? 2.0)
        )

        guard let warped = applyWarp(
            cgImage: afterResized,
            warpTransform: homography,
            afterSize: targetSize,
            context: ciContext
        ) else { throw AlignmentError.warpFailed }

        guard let jpeg = makeJpegData(from: warped) else { throw AlignmentError.saveFailed }
        do {
            try jpeg.write(to: outputURL)
        } catch {
            throw AlignmentError.saveFailed
        }
        return outputURL
    }

    /// Tier 3: VNGenerateOpticalFlowRequest 기반 per-pixel displacement Warp.
    /// 4코너 optical flow displacement로 homography를 계산하여 적용.
    /// 실패 시 Tier 2로 자동 폴백.
    private static func performTier3(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: AlignmentContext,
        ciContext: CIContext
    ) throws -> URL? {
        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 2000),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 2000)
        else { throw AlignmentError.loadFailed }

        let targetSize = CGSize(width: beforeCG.width, height: beforeCG.height)
        guard let afterResized = resize(image: afterCG, to: targetSize) else {
            throw AlignmentError.loadFailed
        }

        if let warpMatrix = computeOpticalFlowWarp(before: beforeCG, after: afterResized, size: targetSize) {
            guard let warped = applyWarp(
                cgImage: afterResized,
                warpTransform: warpMatrix,
                afterSize: targetSize,
                context: ciContext
            ) else { throw AlignmentError.warpFailed }

            guard let jpeg = makeJpegData(from: warped) else { throw AlignmentError.saveFailed }
            do {
                try jpeg.write(to: outputURL)
            } catch {
                throw AlignmentError.saveFailed
            }
            return outputURL
        }

        return try performTier2(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: context,
            ciContext: ciContext
        )
    }

    /// VNGenerateOpticalFlowRequest로 4코너 displacement를 계산해 homography 반환.
    /// 실패 시 nil 반환하여 폴백 유도.
    /// applyWarp는 warpTransform.inverse를 취하므로, after→before 방향 행렬의 inverse를 전달.
    private static func computeOpticalFlowWarp(
        before: CGImage,
        after: CGImage,
        size: CGSize
    ) -> matrix_float3x3? {
        let request = VNGenerateOpticalFlowRequest(targetedCGImage: after, options: [:])
        if #available(iOS 16.0, *) {
            request.revision = VNGenerateOpticalFlowRequestRevision2
        }
        request.computationAccuracy = .medium

        let handler = VNImageRequestHandler(cgImage: before, options: [:])
        guard (try? handler.perform([request])) != nil,
              let flow = request.results?.first
        else { return nil }

        let buffer = flow.pixelBuffer
        let bufW = CVPixelBufferGetWidth(buffer)
        let bufH = CVPixelBufferGetHeight(buffer)
        guard bufW > 0, bufH > 0 else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let floats = base.assumingMemoryBound(to: Float.self)
        let scaleX = Float(bufW) / Float(size.width)
        let scaleY = Float(bufH) / Float(size.height)
        let imgW = Float(size.width)
        let imgH = Float(size.height)

        func sample(col: Int, row: Int) -> (Float, Float) {
            let cl = max(0, min(col, bufW - 1))
            let rw = max(0, min(row, bufH - 1))
            let offset = rw * (bytesPerRow / MemoryLayout<Float>.size) + cl * 2
            return (floats[offset], floats[offset + 1])
        }

        let (dx0, dy0) = sample(col: 0, row: 0)
        let (dx1, dy1) = sample(col: Int(imgW * scaleX), row: 0)
        let (dx2, dy2) = sample(col: Int(imgW * scaleX), row: Int(imgH * scaleY))
        let (dx3, dy3) = sample(col: 0, row: Int(imgH * scaleY))

        // after 코너 → before 코너: before_pos = after_pos + displacement
        let srcPts: [(Float, Float)] = [(0, 0), (imgW, 0), (imgW, imgH), (0, imgH)]
        let dstPts: [(Float, Float)] = [
            (dx0, dy0),
            (imgW + dx1, dy1),
            (imgW + dx2, imgH + dy2),
            (dx3, imgH + dy3),
        ]

        // afterToBeforeH: after → before 방향 homography
        guard let afterToBeforeH = computeHomography(src: srcPts, dst: dstPts) else { return nil }
        // applyWarp는 내부에서 inverse를 취하므로 beforeToAfterH를 전달해야 afterToBeforeH가 적용됨
        return safeInverse(afterToBeforeH)
    }

    /// 4점 대응으로 homography 행렬 계산 (DLT, src → dst 방향)
    private static func computeHomography(
        src: [(Float, Float)],
        dst: [(Float, Float)]
    ) -> matrix_float3x3? {
        guard src.count == 4, dst.count == 4 else { return nil }

        var equations = [[Float]](repeating: [Float](repeating: 0, count: 9), count: 8)
        for idx in 0 ..< 4 {
            let (sx, sy) = src[idx]
            let (dx, dy) = dst[idx]
            equations[2 * idx] = [-sx, -sy, -1, 0, 0, 0, dx * sx, dx * sy, dx]
            equations[2 * idx + 1] = [0, 0, 0, -sx, -sy, -1, dy * sx, dy * sy, dy]
        }

        guard var coefficients = solveHomographySystem(equations: equations) else { return nil }
        guard abs(coefficients[8]) > 1e-10 else { return nil }
        let normalizer = coefficients[8]
        coefficients = coefficients.map { $0 / normalizer }

        return matrix_float3x3(
            simd_float3(coefficients[0], coefficients[3], coefficients[6]),
            simd_float3(coefficients[1], coefficients[4], coefficients[7]),
            simd_float3(coefficients[2], coefficients[5], coefficients[8])
        )
    }

    /// 8x9 시스템의 최소자승해 (h[8]=1 고정하고 8x8 Gaussian elimination)
    private static func solveHomographySystem(equations: [[Float]]) -> [Float]? {
        let size = 9
        let rowCount = equations.count
        var normal = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)
        for kk in 0 ..< rowCount {
            for ii in 0 ..< size {
                for jj in 0 ..< size {
                    normal[ii][jj] += equations[kk][ii] * equations[kk][jj]
                }
            }
        }

        var system = [[Float]](repeating: [Float](repeating: 0, count: 9), count: 8)
        var rhs = [Float](repeating: 0, count: 8)
        for ii in 0 ..< 8 {
            for jj in 0 ..< 8 {
                system[ii][jj] = normal[ii][jj]
            }
            rhs[ii] = -normal[ii][8]
        }

        guard var solution = gaussianElimination(system: system, rhs: rhs) else { return nil }
        solution.append(1.0)
        return solution
    }

    /// 8x8 선형 시스템 Gauss-Jordan elimination
    private static func gaussianElimination(system: [[Float]], rhs: [Float]) -> [Float]? {
        let size = 8
        var aug = system
        for ii in 0 ..< size {
            aug[ii].append(rhs[ii])
        }

        for col in 0 ..< size {
            var pivotRow = col
            var pivotVal = abs(aug[col][col])
            for row in (col + 1) ..< size where abs(aug[row][col]) > pivotVal {
                pivotVal = abs(aug[row][col])
                pivotRow = row
            }
            guard pivotVal > 1e-10 else { return nil }
            aug.swapAt(col, pivotRow)

            let pivot = aug[col][col]
            for jj in col ..< (size + 1) {
                aug[col][jj] /= pivot
            }

            for row in 0 ..< size where row != col {
                let factor = aug[row][col]
                for jj in col ..< (size + 1) {
                    aug[row][jj] -= factor * aug[col][jj]
                }
            }
        }

        return (0 ..< size).map { aug[$0][size] }
    }

    private static func buildPoseHomography(
        beforeTransform: simd_float4x4,
        afterTransform: simd_float4x4,
        intrinsics: matrix_float3x3,
        depth: Float
    ) -> matrix_float3x3 {
        let tRelative = simd_mul(beforeTransform, afterTransform.inverse)
        let rotation = simd_float3x3(
            simd_float3(tRelative.columns.0.x, tRelative.columns.0.y, tRelative.columns.0.z),
            simd_float3(tRelative.columns.1.x, tRelative.columns.1.y, tRelative.columns.1.z),
            simd_float3(tRelative.columns.2.x, tRelative.columns.2.y, tRelative.columns.2.z)
        )
        let translation = simd_float3(
            tRelative.columns.3.x,
            tRelative.columns.3.y,
            tRelative.columns.3.z
        )

        // n = [0,0,1] → t ⊗ n^T: column-major, columns[2] = translation
        let outerProduct = simd_float3x3(
            simd_float3(0, 0, 0),
            simd_float3(0, 0, 0),
            translation
        )
        let scaled = simd_float3x3(
            outerProduct.columns.0 / depth,
            outerProduct.columns.1 / depth,
            outerProduct.columns.2 / depth
        )
        let compensated = simd_float3x3(
            rotation.columns.0 - scaled.columns.0,
            rotation.columns.1 - scaled.columns.1,
            rotation.columns.2 - scaled.columns.2
        )
        return simd_mul(simd_mul(intrinsics, compensated), intrinsics.inverse)
    }

    private static func safeInverse(_ mat: matrix_float3x3) -> matrix_float3x3? {
        let det = mat.columns.0.x * (mat.columns.1.y * mat.columns.2.z - mat.columns.2.y * mat.columns.1.z)
            - mat.columns.1.x * (mat.columns.0.y * mat.columns.2.z - mat.columns.2.y * mat.columns.0.z)
            + mat.columns.2.x * (mat.columns.0.y * mat.columns.1.z - mat.columns.1.y * mat.columns.0.z)
        guard abs(det) > 1e-10 else { return nil }
        return mat.inverse
    }

    private static func resize(image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: deviceRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    private static func applyWarp(
        cgImage: CGImage,
        warpTransform: matrix_float3x3,
        afterSize: CGSize,
        context: CIContext
    ) -> CGImage? {
        let inverseWarp = warpTransform.inverse
        let width = Float(cgImage.width)
        let height = Float(cgImage.height)
        let heightCG = CGFloat(height)

        func warpedCornerInCI(_ px: Float, _ py: Float) -> CGPoint {
            let vec = inverseWarp * simd_float3(px, py, 1)
            let (wx, wy): (CGFloat, CGFloat) = vec.z != 0
                ? (CGFloat(vec.x / vec.z), CGFloat(vec.y / vec.z))
                : (CGFloat(px), CGFloat(py))
            return CGPoint(x: wx, y: heightCG - wy)
        }

        let tl = warpedCornerInCI(0, 0)
        let tr = warpedCornerInCI(width, 0)
        let br = warpedCornerInCI(width, height)
        let bl = warpedCornerInCI(0, height)

        let filter = CIFilter.perspectiveTransform()
        filter.inputImage = CIImage(cgImage: cgImage)
        filter.topLeft = tl
        filter.topRight = tr
        filter.bottomRight = br
        filter.bottomLeft = bl

        guard let outputImage = filter.outputImage else { return nil }
        let outputRect = CGRect(x: 0, y: 0, width: afterSize.width, height: afterSize.height)
        return context.createCGImage(outputImage, from: outputRect)
    }

    static func makeJpegData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
