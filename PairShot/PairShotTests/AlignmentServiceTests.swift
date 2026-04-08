import CoreGraphics
import Foundation
import ImageIO
@testable import PairShot
import simd
import Testing

@Suite(.serialized)
struct AlignmentServiceTests {
    private func makeTempJpeg(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).jpg")
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: 64,
            height: 64,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let cgImage = ctx.makeImage() else {
            throw AlignmentService.AlignmentError.loadFailed
        }
        guard let data = CFDataCreateMutable(nil, 0),
              let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
        else { throw AlignmentService.AlignmentError.saveFailed }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw AlignmentService.AlignmentError.saveFailed
        }
        try (data as Data).write(to: url)
        return url
    }

    private func makeTempOutput() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("aligned_\(UUID().uuidString).jpg")
    }

    /// context가 nil이면 tier1을 반환한다.
    @Test func align_nilContext_returnsTier1() async throws {
        let beforeURL = try makeTempJpeg(named: "before_nil_\(UUID().uuidString)")
        let afterURL = try makeTempJpeg(named: "after_nil_\(UUID().uuidString)")
        let outputURL = makeTempOutput()
        defer {
            try? FileManager.default.removeItem(at: beforeURL)
            try? FileManager.default.removeItem(at: afterURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let (_, tier) = try await AlignmentService.align(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: nil
        )

        #expect(tier == "tier1")
    }

    /// worldMapRelocalized=false → tier1 폴백
    @Test func align_notRelocalized_returnsTier1() async throws {
        let beforeURL = try makeTempJpeg(named: "before_noloc_\(UUID().uuidString)")
        let afterURL = try makeTempJpeg(named: "after_noloc_\(UUID().uuidString)")
        let outputURL = makeTempOutput()
        defer {
            try? FileManager.default.removeItem(at: beforeURL)
            try? FileManager.default.removeItem(at: afterURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let ctx = AlignmentService.AlignmentContext(
            beforeTransform: matrix_identity_float4x4,
            afterTransform: matrix_identity_float4x4,
            beforeIntrinsics: matrix_identity_float3x3,
            afterIntrinsics: nil,
            beforeDepthMapURL: nil,
            depthAtCenter: nil,
            worldMapRelocalized: false
        )

        let (_, tier) = try await AlignmentService.align(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: ctx
        )

        #expect(tier == "tier1")
    }

    /// worldMapRelocalized=true, beforeTransform=nil → tier1 폴백
    @Test func align_relocalized_missingTransform_returnsTier1() async throws {
        let beforeURL = try makeTempJpeg(named: "before_notx_\(UUID().uuidString)")
        let afterURL = try makeTempJpeg(named: "after_notx_\(UUID().uuidString)")
        let outputURL = makeTempOutput()
        defer {
            try? FileManager.default.removeItem(at: beforeURL)
            try? FileManager.default.removeItem(at: afterURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let ctx = AlignmentService.AlignmentContext(
            beforeTransform: nil,
            afterTransform: matrix_identity_float4x4,
            beforeIntrinsics: matrix_identity_float3x3,
            afterIntrinsics: nil,
            beforeDepthMapURL: nil,
            depthAtCenter: nil,
            worldMapRelocalized: true
        )

        let (_, tier) = try await AlignmentService.align(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: ctx
        )

        #expect(tier == "tier1")
    }

    /// worldMapRelocalized=true, 모든 transform/intrinsics 존재, depthMapURL=nil → tier2
    @Test func align_fullContextNoDepth_returnsTier2() async throws {
        let beforeURL = try makeTempJpeg(named: "before_t2_\(UUID().uuidString)")
        let afterURL = try makeTempJpeg(named: "after_t2_\(UUID().uuidString)")
        let outputURL = makeTempOutput()
        defer {
            try? FileManager.default.removeItem(at: beforeURL)
            try? FileManager.default.removeItem(at: afterURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let intrinsics = matrix_float3x3(
            simd_float3(32, 0, 0),
            simd_float3(0, 32, 0),
            simd_float3(32, 32, 1)
        )
        let ctx = AlignmentService.AlignmentContext(
            beforeTransform: matrix_identity_float4x4,
            afterTransform: matrix_identity_float4x4,
            beforeIntrinsics: intrinsics,
            afterIntrinsics: nil,
            beforeDepthMapURL: nil,
            depthAtCenter: 2.0,
            worldMapRelocalized: true
        )

        let (_, tier) = try await AlignmentService.align(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: ctx
        )

        #expect(tier == "tier2")
    }

    /// worldMapRelocalized=true, depthMapURL 존재 → tier3
    @Test func align_fullContextWithDepth_returnsTier3() async throws {
        let beforeURL = try makeTempJpeg(named: "before_t3_\(UUID().uuidString)")
        let afterURL = try makeTempJpeg(named: "after_t3_\(UUID().uuidString)")
        let outputURL = makeTempOutput()

        let depthURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("before_depth_64x64.bin")
        let floatCount = 64 * 64
        var depthBytes = [Float32](repeating: 1.5, count: floatCount)
        let depthData = Data(bytes: &depthBytes, count: floatCount * MemoryLayout<Float32>.size)
        try depthData.write(to: depthURL)

        defer {
            try? FileManager.default.removeItem(at: beforeURL)
            try? FileManager.default.removeItem(at: afterURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: depthURL)
        }

        let intrinsics = matrix_float3x3(
            simd_float3(32, 0, 0),
            simd_float3(0, 32, 0),
            simd_float3(32, 32, 1)
        )
        let ctx = AlignmentService.AlignmentContext(
            beforeTransform: matrix_identity_float4x4,
            afterTransform: matrix_identity_float4x4,
            beforeIntrinsics: intrinsics,
            afterIntrinsics: nil,
            beforeDepthMapURL: depthURL,
            depthAtCenter: 1.5,
            worldMapRelocalized: true
        )

        let (_, tier) = try await AlignmentService.align(
            beforeURL: beforeURL,
            afterURL: afterURL,
            outputURL: outputURL,
            context: ctx
        )

        // depthURL이 존재하면 tier3를 시도하고, 실패 시 tier1로 폴백한다.
        // resolveTier는 tier3를 반환하므로 tier 문자열은 "tier3"이어야 한다.
        #expect(tier == "tier3")
    }

    /// AlignmentContext 초기화: worldMapRelocalized 필드가 올바르게 저장된다.
    @Test func alignmentContext_storedFieldsAreReadable() {
        let transform = matrix_identity_float4x4
        let intrinsics = matrix_identity_float3x3
        let depthURL = URL(fileURLWithPath: "/tmp/before_depth_10x10.bin")

        let ctx = AlignmentService.AlignmentContext(
            beforeTransform: transform,
            afterTransform: transform,
            beforeIntrinsics: intrinsics,
            afterIntrinsics: intrinsics,
            beforeDepthMapURL: depthURL,
            depthAtCenter: 3.0,
            worldMapRelocalized: true
        )

        #expect(ctx.worldMapRelocalized == true)
        #expect(ctx.depthAtCenter == 3.0)
        #expect(ctx.beforeDepthMapURL?.lastPathComponent == "before_depth_10x10.bin")
        #expect(ctx.beforeTransform != nil)
        #expect(ctx.afterTransform != nil)
        #expect(ctx.beforeIntrinsics != nil)
    }
}
