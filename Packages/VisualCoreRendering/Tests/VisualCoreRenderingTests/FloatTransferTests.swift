// FloatTransferTests — feature 019 T-A02-103 (G-FLOATRT; FR-A02-105; research R4): exact float upload and readback.
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class FloatTransferTests: XCTestCase {
    private func ramp(_ w: Int, _ h: Int) -> [Float] {
        (0..<(w * h * 4)).map { Float($0 % 97) / 96 }
    }

    func testHalfFloatRoundTripWhenSupported() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let support = FloatRenderSupport.detect(in: context.resources)
            try XCTSkipUnless(support.supported, "half-float render targets unsupported on this runtime")
            let target = try context.resources.makeRenderTarget(width: 8, height: 4, format: .rgba16f, label: "t")
            defer { context.resources.release(target) }
            let values = self.ramp(8, 4).map { $0 * 3 - 1 }   // signed values outside 0…1 survive
            XCTAssertTrue(target.upload(rgbaFloats: values))
            let back = target.readFloatPixels()
            XCTAssertEqual(back.count, values.count)
            for (a, b) in zip(back, values) { XCTAssertEqual(a, StoragePrecision.float16.round(b), accuracy: 1e-6) }
        }
    }

    func testRGBA8RoundTripIsQuantized() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let target = try context.resources.makeRenderTarget(width: 8, height: 4, format: .rgba8, label: "t")
            defer { context.resources.release(target) }
            let values = self.ramp(8, 4).map { $0 * 1.2 - 0.1 }
            XCTAssertTrue(target.upload(rgbaFloats: values))
            let back = target.readFloatPixels()
            XCTAssertEqual(back.count, values.count)
            for (a, b) in zip(back, values) { XCTAssertEqual(a, StoragePrecision.unorm8.round(b), accuracy: 1e-6) }
        }
    }

    func testRejectedTransfers() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var kept: RenderTarget?
        try withContext(host, scene) { context in
            let target = try context.resources.makeRenderTarget(width: 2, height: 2, format: .rgba8, label: "t")
            XCTAssertFalse(target.upload(rgbaFloats: [0, 1]), "count mismatch")
            let r8 = try context.resources.makeRenderTarget(width: 2, height: 2, format: .r8, label: "r8")
            XCTAssertFalse(r8.upload(rgbaFloats: Array(repeating: 0, count: 16)))
            XCTAssertEqual(r8.readFloatPixels(), [])
            context.resources.release(r8)
            kept = target
        }
        host.recreateContext()
        let stale = try XCTUnwrap(kept)
        try withContext(host, scene) { _ in
            XCTAssertFalse(stale.upload(rgbaFloats: Array(repeating: 0, count: 16)), "stale target")
            XCTAssertEqual(stale.readFloatPixels(), [])
        }
    }
}
