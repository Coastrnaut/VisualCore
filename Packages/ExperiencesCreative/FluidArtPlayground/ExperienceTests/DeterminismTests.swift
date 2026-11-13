// DeterminismTests — feature 023 T-A02-506 (FR-A02-504, SC-A02-502; US2 AC1–AC3; research R5).
import FluidArtPlaygroundCore
import VisualCoreRendering
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class DeterminismTests: XCTestCase {
    private func run(seed: UInt64, frames: Int = 120) throws -> (digest: String, pixels: [UInt8], applied: Int) {
        let model = TestMode.makeModel(seed: seed, viewSize: CGSize(width: 100, height: 200))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        for _ in 0..<frames { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(model.scene.stepCount, frames)
        XCTAssertEqual(model.scene.lastStep, 1.0 / 60, accuracy: 1e-12, "fixed 1/60 s step")
        XCTAssertEqual(model.tier, 0, "tier pinned to Full")
        let pixels = host.readPixels()
        return (try XCTUnwrap(TestMode.digest(host)), pixels, model.scene.appliedSplats)
    }

    /// US2 AC1: the same seed and frame count give a byte-identical picture.
    func testSameSeedIsByteIdentical() throws {
        let a = try run(seed: 7), b = try run(seed: 7)
        print("determinism seed 7: \(a.digest) applied \(a.applied)")
        XCTAssertGreaterThan(a.applied, 0, "the script painted")
        XCTAssertEqual(a.applied, b.applied)
        XCTAssertEqual(a.digest, b.digest)
        XCTAssertEqual(a.pixels, b.pixels)
    }

    /// US2 AC2 / SC-A02-502: different seeds differ in at least 1% of pixels (a pixel differs if any channel does).
    func testDifferentSeedsDiffer() throws {
        let a = try run(seed: 7), b = try run(seed: 8)
        XCTAssertNotEqual(a.digest, b.digest)
        let count = a.pixels.count / 4
        let differing = (0..<count).filter { i in (0..<3).contains { a.pixels[i * 4 + $0] != b.pixels[i * 4 + $0] } }.count
        let share = Double(differing) / Double(count)
        print("determinism seeds 7/8: \(share * 100)% of pixels differ")
        XCTAssertGreaterThanOrEqual(share, 0.01)
    }

    /// US2 AC3: the scripted touches come from the seeded script (several pointers paint, none pinch).
    func testScriptPaintsWithSeveralPointersWithoutPinching() throws {
        let model = TestMode.makeModel(seed: 3, viewSize: CGSize(width: 100, height: 200))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertFalse(model.pinching)
        XCTAssertEqual(model.drainedFrames, 10)
        XCTAssertGreaterThan(model.scene.appliedSplats, 10)
        XCTAssertEqual(model.scene.configuration.forceScale, FluidConfiguration.forceScaleRange.upperBound)
        XCTAssertEqual(model.scene.configuration.seed, 3)
    }
}
