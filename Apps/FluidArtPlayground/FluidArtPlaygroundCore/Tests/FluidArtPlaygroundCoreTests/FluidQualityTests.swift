// FluidQualityTests — feature 021 T-A02-308 (FR-A02-308; clarification 4; manual §12 "reduce pressure iterations
// before reducing touch responsiveness").
import FluidArtPlaygroundCore
import XCTest

final class FluidQualityTests: XCTestCase {
    func testTiersLowerIterationsBeforeSplats() {
        let c = FluidConfiguration()   // 20 iterations, 16 splats
        XCTAssertEqual(FluidQuality.tierCount, 3)
        XCTAssertEqual(FluidQuality.parameters(tier: 0, configuration: c).iterations, 20)
        XCTAssertEqual(FluidQuality.parameters(tier: 0, configuration: c).splatCap, 16)
        XCTAssertEqual(FluidQuality.parameters(tier: 1, configuration: c).iterations, 10)
        XCTAssertEqual(FluidQuality.parameters(tier: 1, configuration: c).splatCap, 16, "touch kept at Reduced")
        XCTAssertEqual(FluidQuality.parameters(tier: 2, configuration: c).iterations, 5)
        XCTAssertEqual(FluidQuality.parameters(tier: 2, configuration: c).splatCap, 8)
        XCTAssertEqual([0, 1, 2].map(FluidQuality.name), ["Full", "Reduced", "Minimal"])
    }

    func testFloorsAndOutOfRangeTiers() {
        var c = FluidConfiguration()
        c.pressureIterations = 1
        c.maxSplatsPerFrame = 1
        let minimal = FluidQuality.parameters(tier: 2, configuration: c)
        XCTAssertEqual(minimal.iterations, 1)
        XCTAssertEqual(minimal.splatCap, 1)
        XCTAssertEqual(FluidQuality.parameters(tier: 9, configuration: FluidConfiguration()).iterations, 5, "clamped to Minimal")
        XCTAssertEqual(FluidQuality.parameters(tier: -3, configuration: FluidConfiguration()).iterations, 20, "clamped to Full")
        XCTAssertEqual(FluidQuality.name(7), "Minimal")
    }
}
