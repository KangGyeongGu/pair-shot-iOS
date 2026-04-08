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
            let tier1Fallback = {
                try performTier1(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    ciContext: ciCtx
                )
            }
            if let ctx = resolvedCtx, tier == "tier3" {
                return try performTier3(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    context: ctx,
                    ciContext: ciCtx
                )
            } else if let ctx = resolvedCtx, tier == "tier2" {
                return try (try? performTier2(
                    beforeURL: beforeURL,
                    afterURL: afterURL,
                    outputURL: outputURL,
                    context: ctx,
                    ciContext: ciCtx
                )) ?? tier1Fallback()
            } else {
                return try tier1Fallback()
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

    /// Tier 1: 모든 기기. Vision homography(전역) → optical flow(세부 보정).
    private static func performTier1(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        ciContext: CIContext
    ) throws -> URL? {
        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 2000, applyTransform: false),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 2000, applyTransform: false)
        else { throw AlignmentError.loadFailed }

        let outputOrientation: CGImagePropertyOrientation = beforeCG.width > beforeCG.height ? .right : .up
        let targetSize = CGSize(width: beforeCG.width, height: beforeCG.height)
        guard let afterResized = resize(image: afterCG, to: targetSize) else {
            throw AlignmentError.loadFailed
        }

        // Step 1: Vision homography — 전역 시점 차이 보정 (대규모 이동 처리)
        let homogRequest = VNHomographicImageRegistrationRequest(targetedCGImage: afterResized, options: [:])
        let homogHandler = VNImageRequestHandler(cgImage: beforeCG, options: [.ciContext: ciContext])
        let coarseAligned: CGImage = if (try? homogHandler.perform([homogRequest])) != nil,
                                        let obs = homogRequest.results?.first,
                                        let coarseWarped = applyWarp(
                                            cgImage: afterResized,
                                            warpTransform: obs.warpTransform,
                                            afterSize: targetSize,
                                            context: ciContext
                                        )
        {
            coarseWarped
        } else {
            afterResized
        }

        // Step 2: optical flow 세부 보정 (coarse 정렬 후 잔여 오차 제거)
        let result = refineWithOpticalFlow(
            before: beforeCG,
            coarseAligned: coarseAligned,
            targetSize: targetSize,
            ciContext: ciContext
        )

        guard let jpeg = makeJpegData(from: result, orientation: outputOrientation)
        else { throw AlignmentError.warpFailed }
        do { try jpeg.write(to: outputURL) } catch { throw AlignmentError.saveFailed }
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
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 3000, applyTransform: false),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 3000, applyTransform: false)
        else { throw AlignmentError.loadFailed }

        let outputOrientation: CGImagePropertyOrientation = beforeCG.width > beforeCG.height ? .right : .up
        let targetSize = CGSize(width: beforeCG.width, height: beforeCG.height)
        guard let afterResized = resize(image: afterCG, to: targetSize) else {
            throw AlignmentError.loadFailed
        }

        // intrinsics를 실제 로드된 이미지 크기로 스케일 (full-res로 저장된 intrinsics 보정)
        let intrinsicsScale = Float(targetSize.width) / (intrinsics.columns.2.x * 2)
        let scaledIntrinsics = matrix_float3x3(
            simd_float3(intrinsics.columns.0.x * intrinsicsScale, 0, 0),
            simd_float3(0, intrinsics.columns.1.y * intrinsicsScale, 0),
            simd_float3(
                intrinsics.columns.2.x * intrinsicsScale,
                intrinsics.columns.2.y * intrinsicsScale,
                1
            )
        )

        let homography = buildPoseHomography(
            beforeTransform: beforeTransform,
            afterTransform: afterTransform,
            intrinsics: scaledIntrinsics,
            depth: Float(context.depthAtCenter ?? 2.0)
        )

        guard let warped = applyWarp(
            cgImage: afterResized,
            warpTransform: homography,
            afterSize: targetSize,
            context: ciContext
        ) else { throw AlignmentError.warpFailed }

        let result = refineWithOpticalFlow(
            before: beforeCG,
            coarseAligned: warped,
            targetSize: targetSize,
            ciContext: ciContext
        )

        guard let jpeg = makeJpegData(from: result, orientation: outputOrientation)
        else { throw AlignmentError.saveFailed }
        do {
            try jpeg.write(to: outputURL)
        } catch {
            throw AlignmentError.saveFailed
        }
        return outputURL
    }

    /// Tier 3: LiDAR Pro 기기 전용.
    /// 1순위: depth + pose 3D reprojection(coarse) → optical flow 세부 보정
    /// 2순위: Tier 1 폴백 (Vision homography + optical flow)
    private static func performTier3(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: AlignmentContext,
        ciContext: CIContext
    ) throws -> URL? {
        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 2000, applyTransform: false),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 2000, applyTransform: false)
        else { throw AlignmentError.loadFailed }

        let outputOrientation: CGImagePropertyOrientation = beforeCG.width > beforeCG.height ? .right : .up
        let targetSize = CGSize(width: beforeCG.width, height: beforeCG.height)
        guard let afterResized = resize(image: afterCG, to: targetSize) else {
            throw AlignmentError.loadFailed
        }

        // 1순위: depth + pose 3D reprojection → optical flow 세부 보정
        if let depthURL = context.beforeDepthMapURL,
           let beforeTransform = context.beforeTransform,
           let afterTransform = context.afterTransform,
           let beforeIntrinsics = context.beforeIntrinsics
        {
            let effectiveAfterIntrinsics = context.afterIntrinsics ?? beforeIntrinsics
            if let depthBuffer = buildDepthDisplacementField(
                depthURL: depthURL,
                beforeIntrinsics: beforeIntrinsics,
                afterIntrinsics: effectiveAfterIntrinsics,
                beforeTransform: beforeTransform,
                afterTransform: afterTransform,
                imageSize: targetSize
            ), let coarseWarped = applyFullOpticalFlow(
                after: afterResized,
                flowBuffer: depthBuffer,
                imageSize: targetSize,
                context: ciContext
            ) {
                let result = refineWithOpticalFlow(
                    before: beforeCG,
                    coarseAligned: coarseWarped,
                    targetSize: targetSize,
                    ciContext: ciContext
                )
                guard let jpeg = makeJpegData(from: result, orientation: outputOrientation)
                else { throw AlignmentError.warpFailed }
                do { try jpeg.write(to: outputURL) } catch { throw AlignmentError.saveFailed }
                return outputURL
            }
        }

        // 2순위: Tier 1 폴백 (Vision homography + optical flow)
        return try performTier1(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            ciContext: ciContext
        )
    }
}

private extension AlignmentService {
    /// 이미 coarse 정렬된 이미지 위에 optical flow로 세부 보정. 실패 시 coarseAligned 반환.
    nonisolated static func refineWithOpticalFlow(
        before: CGImage,
        coarseAligned: CGImage,
        targetSize: CGSize,
        ciContext: CIContext
    ) -> CGImage {
        guard let flowBuffer = computeOpticalFlowBuffer(before: before, after: coarseAligned, ciContext: ciContext),
              let refined = applyFullOpticalFlow(
                  after: coarseAligned,
                  flowBuffer: flowBuffer,
                  imageSize: targetSize,
                  context: ciContext
              )
        else { return coarseAligned }
        return refined
    }

    nonisolated static func computeOpticalFlowBuffer(
        before: CGImage,
        after: CGImage,
        ciContext: CIContext
    ) -> CVPixelBuffer? {
        let request = VNGenerateOpticalFlowRequest(targetedCGImage: after, options: [:])
        request.revision = VNGenerateOpticalFlowRequestRevision2
        request.computationAccuracy = .high

        let handler = VNImageRequestHandler(cgImage: before, options: [.ciContext: ciContext])
        guard (try? handler.perform([request])) != nil,
              let flow = request.results?.first
        else { return nil }
        return flow.pixelBuffer
    }

    /// flow buffer(kCVPixelFormatType_TwoComponent32Float)를 CIDisplacementDistortion으로 per-pixel 적용.
    /// R=x displacement, G=y displacement (Y축은 CIImage bottom-left origin 맞게 반전).
    nonisolated static func applyFullOpticalFlow(
        after: CGImage,
        flowBuffer: CVPixelBuffer,
        imageSize: CGSize,
        context: CIContext
    ) -> CGImage? {
        let bufW = CVPixelBufferGetWidth(flowBuffer)
        let bufH = CVPixelBufferGetHeight(flowBuffer)
        guard bufW > 0, bufH > 0 else { return nil }

        // flow 버퍼를 CIImage로 변환 후 입력 이미지 크기로 스케일
        var flowCI = CIImage(cvPixelBuffer: flowBuffer, options: [.colorSpace: NSNull()])
        flowCI = flowCI.transformed(by: CGAffineTransform(
            scaleX: imageSize.width / CGFloat(bufW),
            y: imageSize.height / CGFloat(bufH)
        ))

        // flow 값을 [0,1]로 정규화 (CIDisplacementDistortion: 0.5 = 무변위, scale=최대변위*2)
        // Y축 반전: flow 버퍼는 top-left origin, CIImage는 bottom-left origin
        let maxDisp: CGFloat = 300
        let nScale = 1.0 / (2.0 * maxDisp)
        let normalizedFlow = flowCI.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: nScale, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: -nScale, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0, w: 1),
        ])

        let warped = CIImage(cgImage: after).clampedToExtent().applyingFilter("CIDisplacementDistortion", parameters: [
            "inputDisplacementImage": normalizedFlow,
            "inputScale": 2.0 * maxDisp,
        ])

        return context.createCGImage(warped, from: CGRect(origin: .zero, size: imageSize))
    }

    /// depth map URL 파일명에서 해상도 파싱. 형식: before_depth_{W}x{H}.bin
    nonisolated static func parseDimensions(from url: URL) -> (Int, Int)? {
        let name = url.deletingPathExtension().lastPathComponent
        let parts = name.components(separatedBy: "_")
        guard let dimStr = parts.last,
              let xIdx = dimStr.firstIndex(of: "x")
        else { return nil }
        let width = Int(String(dimStr[dimStr.startIndex ..< xIdx]))
        let height = Int(String(dimStr[dimStr.index(after: xIdx)...]))
        guard let width, let height, width > 0, height > 0 else { return nil }
        return (width, height)
    }

    /// LiDAR depth map + ARKit pose를 이용해 per-pixel displacement buffer 생성.
    /// before 각 픽셀을 3D로 unproject → after 카메라로 reproject → 픽셀 변위 계산.
    /// 출력: kCVPixelFormatType_TwoComponent32Float (applyFullOpticalFlow와 동일 포맷)
    nonisolated static func buildDepthDisplacementField(
        depthURL: URL,
        beforeIntrinsics: matrix_float3x3,
        afterIntrinsics: matrix_float3x3,
        beforeTransform: simd_float4x4,
        afterTransform: simd_float4x4,
        imageSize: CGSize
    ) -> CVPixelBuffer? {
        guard let (depthW, depthH) = parseDimensions(from: depthURL),
              let depthData = try? Data(contentsOf: depthURL),
              depthData.count >= depthW * depthH * MemoryLayout<Float32>.size
        else { return nil }

        // before-cam → after-cam 변환 (T_after^{-1} * T_before)
        let beforeToAfter = afterTransform.inverse * beforeTransform

        // intrinsics를 depth map 해상도로 스케일 (cx*2 ≈ 원본 width 추정)
        let approxFullW = beforeIntrinsics.columns.2.x * 2
        let approxFullH = beforeIntrinsics.columns.2.y * 2
        let fx = beforeIntrinsics.columns.0.x * (Float(depthW) / approxFullW)
        let fy = beforeIntrinsics.columns.1.y * (Float(depthH) / approxFullH)
        let cx = beforeIntrinsics.columns.2.x * (Float(depthW) / approxFullW)
        let cy = beforeIntrinsics.columns.2.y * (Float(depthH) / approxFullH)

        // after intrinsics를 alignment image 해상도로 스케일
        let approxAfterW = afterIntrinsics.columns.2.x * 2
        let approxAfterH = afterIntrinsics.columns.2.y * 2
        let afx = afterIntrinsics.columns.0.x * (Float(imageSize.width) / approxAfterW)
        let afy = afterIntrinsics.columns.1.y * (Float(imageSize.height) / approxAfterH)
        let acx = afterIntrinsics.columns.2.x * (Float(imageSize.width) / approxAfterW)
        let acy = afterIntrinsics.columns.2.y * (Float(imageSize.height) / approxAfterH)

        // depth map → alignment image 좌표 스케일
        let pixScaleX = Float(imageSize.width) / Float(depthW)
        let pixScaleY = Float(imageSize.height) / Float(depthH)

        var pixelBuffer: CVPixelBuffer?
        let bufferAttrs = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            depthW,
            depthH,
            kCVPixelFormatType_TwoComponent32Float,
            bufferAttrs,
            &pixelBuffer
        ) == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let outBase = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let outFloats = outBase.assumingMemoryBound(to: Float32.self)
        let outFloatsPerRow = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float32>.size

        depthData.withUnsafeBytes { rawPtr in
            guard let depthFloats = rawPtr.baseAddress?.assumingMemoryBound(to: Float32.self) else { return }
            for row in 0 ..< depthH {
                for col in 0 ..< depthW {
                    let depth = depthFloats[row * depthW + col]
                    let idx = row * outFloatsPerRow + col * 2
                    guard depth > 0.05, depth < 20.0, depth.isFinite else {
                        outFloats[idx] = 0; outFloats[idx + 1] = 0
                        continue
                    }

                    // depth map pixel → before camera space
                    let xCam = (Float(col) - cx) * depth / fx
                    let yCam = (Float(row) - cy) * depth / fy

                    // before-cam → after-cam
                    let pAfter = beforeToAfter * simd_float4(xCam, yCam, depth, 1)
                    guard pAfter.z > 0.01 else {
                        outFloats[idx] = 0; outFloats[idx + 1] = 0
                        continue
                    }

                    // after-cam → after image (alignment size)
                    let uAfter = afx * (pAfter.x / pAfter.z) + acx
                    let vAfter = afy * (pAfter.y / pAfter.z) + acy

                    // before pixel position in alignment image
                    outFloats[idx] = Float(col) * pixScaleX - uAfter
                    outFloats[idx + 1] = Float(row) * pixScaleY - vAfter
                }
            }
        }

        return buffer
    }

    nonisolated static func buildPoseHomography(
        beforeTransform: simd_float4x4,
        afterTransform: simd_float4x4,
        intrinsics: matrix_float3x3,
        depth: Float
    ) -> matrix_float3x3 {
        let tRelative = simd_mul(afterTransform.inverse, beforeTransform)
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

    nonisolated static func resize(image: CGImage, to size: CGSize) -> CGImage? {
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

    nonisolated static func applyWarp(
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
        filter.inputImage = CIImage(cgImage: cgImage).clampedToExtent()
        filter.topLeft = tl
        filter.topRight = tr
        filter.bottomRight = br
        filter.bottomLeft = bl

        guard let outputImage = filter.outputImage else { return nil }
        let outputRect = CGRect(x: 0, y: 0, width: afterSize.width, height: afterSize.height)
        return context.createCGImage(outputImage, from: outputRect)
    }
}

extension AlignmentService {
    nonisolated static func makeJpegData(
        from cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) -> Data? {
        let mutableData = CFDataCreateMutable(nil, 0)
        guard let mutableData,
              let destination = CGImageDestinationCreateWithData(
                  mutableData,
                  "public.jpeg" as CFString,
                  1,
                  nil
              ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [
                kCGImageDestinationLossyCompressionQuality: 0.85,
                kCGImagePropertyOrientation: orientation.rawValue,
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
