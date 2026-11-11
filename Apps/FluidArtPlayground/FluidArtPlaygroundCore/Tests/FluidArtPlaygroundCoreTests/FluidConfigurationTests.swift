// FluidConfigurationTests — feature 019 T-A02-108 (FR-A02-101, SC-A02-103; data-model FluidConfiguration).
import FluidArtPlaygroundCore
import Foundation
import XCTest

final class FluidConfigurationTests: XCTestCase {
    func testDefaultsAreValid() {
        let (c, issues) = FluidConfiguration().validated()
        XCTAssertEqual(issues, [])
        XCTAssertEqual(c, FluidConfiguration())
        XCTAssertEqual([c.gridWidth, c.gridHeight], [128, 128])
        XCTAssertEqual(c.dyeDissipation, 1.0)
        XCTAssertEqual(c.velocityDissipation, 0.2)
        XCTAssertEqual(c.pressureIterations, 20)
        XCTAssertEqual(c.velocityRange, 4.0)
    }

    /// At least 8 out-of-range cases are clamped (or reset) and reported (SC-A02-103).
    func testOutOfRangeValuesAreClampedAndReported() {
        let cases: [(String, (inout FluidConfiguration) -> Void, (FluidConfiguration) -> Bool)] = [
            ("gridWidth", { $0.gridWidth = 4096 }, { $0.gridWidth == 512 }),
            ("gridWidth", { $0.gridWidth = 2 }, { $0.gridWidth == 16 }),
            ("gridHeight", { $0.gridHeight = -5 }, { $0.gridHeight == 16 }),
            ("gridHeight", { $0.gridHeight = 9999 }, { $0.gridHeight == 512 }),
            ("dyeDissipation", { $0.dyeDissipation = 50 }, { $0.dyeDissipation == 10 }),
            ("dyeDissipation", { $0.dyeDissipation = -1 }, { $0.dyeDissipation == 0 }),
            ("dyeDissipation", { $0.dyeDissipation = .nan }, { $0.dyeDissipation == 1.0 }),
            ("velocityDissipation", { $0.velocityDissipation = .infinity }, { $0.velocityDissipation == 0.2 }),
            ("viscosity", { $0.viscosity = 3 }, { $0.viscosity == 1 }),
            ("pressureIterations", { $0.pressureIterations = 0 }, { $0.pressureIterations == 1 }),
            ("pressureIterations", { $0.pressureIterations = 500 }, { $0.pressureIterations == 80 }),
            ("velocityRange", { $0.velocityRange = 0.01 }, { $0.velocityRange == 0.5 }),
            ("velocityRange", { $0.velocityRange = -.infinity }, { $0.velocityRange == 4.0 }),
            ("version", { $0.version = 7 }, { $0.version == 1 }),
        ]
        XCTAssertGreaterThanOrEqual(cases.count, 8)
        for (field, mutate, check) in cases {
            var raw = FluidConfiguration()
            mutate(&raw)
            let (c, issues) = raw.validated()
            XCTAssertTrue(check(c), "\(field) not corrected")
            XCTAssertEqual(issues.map(\.field), [field], "\(field) not reported")
            XCTAssertEqual(c.validated().issues, [], "validation is idempotent for \(field)")
        }
    }

    func testDeviceMaxEdgeCapsTheGrid() {
        var raw = FluidConfiguration()
        raw.gridWidth = 512
        raw.gridHeight = 300
        let (c, issues) = raw.validated(maxEdge: 256)
        XCTAssertEqual([c.gridWidth, c.gridHeight], [256, 256])
        XCTAssertEqual(Set(issues.map(\.field)), ["gridWidth", "gridHeight"])
        XCTAssertEqual(raw.validated(maxEdge: 8).0.gridWidth, 16, "the minimum edge wins over a tiny device cap")
    }

    func testIssueDescribesRequestedAndApplied() {
        var raw = FluidConfiguration()
        raw.dyeDissipation = 50
        let issue = raw.validated().issues.first
        XCTAssertEqual(issue?.requested, "50.0")
        XCTAssertEqual(issue?.applied, "10.0")
    }

    func testCodableRoundTrip() throws {
        var c = FluidConfiguration()
        c.seed = 0xDEAD_BEEF
        c.gridWidth = 64
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(FluidConfiguration.self, from: data), c)
    }
}
