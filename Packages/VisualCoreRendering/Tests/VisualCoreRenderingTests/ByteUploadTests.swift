// ByteUploadTests — feature 183 (A25-P04) T-A25-402 (gap U-RGBAUPLOAD; FR-A25-401; contracts/visualcore.md): RGBA
// bytes uploaded into an `.rgba8` target read back equal; into `.rgba16f` they read back as n/255 within half-float
// precision; `.r8`, a wrong count and a stale target are refused.
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ByteUploadTests: XCTestCase {
    /// A deterministic byte pattern of `w` × `h` pixels covering 0…255.
    private func bytes(_ w: Int, _ h: Int) -> [UInt8] {
        (0..<(w * h * 4)).map { UInt8(($0 * 37 + 11) % 256) }
    }

    func testRGBA8BytesReadBackEqual() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let target = try context.resources.makeRenderTarget(width: 8, height: 4, format: .rgba8, label: "bytes")
            defer { context.resources.release(target) }
            let pixels = self.bytes(8, 4)
            XCTAssertTrue(target.upload(rgba: pixels))
            XCTAssertEqual(target.readPixels(), pixels)
        }
    }

    func testHalfFloatTargetStoresBytesOver255() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let support = FloatRenderSupport.detect(in: context.resources)
            try XCTSkipUnless(support.supported, "half-float render targets unsupported on this runtime")
            let target = try context.resources.makeRenderTarget(width: 8, height: 4, format: .rgba16f, label: "half")
            defer { context.resources.release(target) }
            let pixels = self.bytes(8, 4)
            XCTAssertTrue(target.upload(rgba: pixels))
            let back = target.readFloatPixels()
            XCTAssertEqual(back.count, pixels.count)
            for (value, byte) in zip(back, pixels) {
                XCTAssertEqual(value, StoragePrecision.float16.round(Float(byte) / 255), accuracy: 1e-6)
            }
        }
    }

    func testRejectedByteUploads() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var kept: RenderTarget?
        try withContext(host, scene) { context in
            let target = try context.resources.makeRenderTarget(width: 2, height: 2, format: .rgba8, label: "t")
            XCTAssertFalse(target.upload(rgba: [0, 1, 2]), "count mismatch")
            let r8 = try context.resources.makeRenderTarget(width: 2, height: 2, format: .r8, label: "r8")
            XCTAssertFalse(r8.upload(rgba: Array(repeating: 0, count: 16)), "r8 refused")
            context.resources.release(r8)
            kept = target
        }
        host.recreateContext()
        let stale = try XCTUnwrap(kept)
        try withContext(host, scene) { _ in
            XCTAssertFalse(stale.upload(rgba: Array(repeating: 0, count: 16)), "stale target")
        }
    }
}
