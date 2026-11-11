// FluidDetailTests — feature 023 T-A02-503 (FR-A02-511, SC-A02-507; clarification 4; research R4).
import FluidArtPlaygroundCore
import XCTest

final class FluidDetailTests: XCTestCase {
    func testLevelsAndNames() {
        XCTAssertEqual(FluidDetail.allCases, [.low, .medium, .high])
        XCTAssertEqual(FluidDetail.allCases.map(\.edge), [64, 128, 256])
        XCTAssertEqual(FluidDetail.allCases.map(\.name), ["Low", "Medium", "High"])
        XCTAssertEqual(FluidDetail.medium.accessibilityValue, "Medium, 128 by 128 cells")
    }

    func testApplySetsASquareGridAndKeepsTuning() {
        var c = FluidConfiguration()
        c.viscosity = 0.3
        FluidDetail.high.apply(to: &c)
        XCTAssertEqual(c.gridWidth, 256)
        XCTAssertEqual(c.gridHeight, 256)
        XCTAssertEqual(c.viscosity, 0.3)
        XCTAssertTrue(c.validated(maxEdge: 512).issues.isEmpty)
    }

    func testDefaultIsMediumAndNearestLevel() {
        XCTAssertEqual(FluidDetail(grid: FluidConfiguration()), .medium)
        var c = FluidConfiguration()
        c.gridWidth = 60; c.gridHeight = 70
        XCTAssertEqual(FluidDetail(grid: c), .low)
        c.gridWidth = 200; c.gridHeight = 220   // a device-capped High stays High
        XCTAssertEqual(FluidDetail(grid: c), .high)
        c.gridWidth = 8; c.gridHeight = 8
        XCTAssertEqual(FluidDetail(grid: c), .low)
    }
}
