// DyeSeedTests — feature 019 T-A02-109 (FR-A02-110).
import FluidArtPlaygroundCore
import VisualCoreSimulation
import XCTest

final class DyeSeedTests: XCTestCase {
    func testPatternIsDeterministicAndBounded() {
        let a = DyeSeed.pattern(width: 32, height: 24, seed: 42)
        XCTAssertEqual(a, DyeSeed.pattern(width: 32, height: 24, seed: 42))
        XCTAssertNotEqual(a, DyeSeed.pattern(width: 32, height: 24, seed: 43))
        XCTAssertEqual([a.width, a.height, a.channels], [32, 24, 4])
        XCTAssertTrue(a.values.allSatisfy { (0...1).contains($0) })
        let lit = (0..<(32 * 24)).filter { a.values[$0 * 4] + a.values[$0 * 4 + 1] + a.values[$0 * 4 + 2] > 0.05 }.count
        XCTAssertGreaterThan(Double(lit) / Double(32 * 24), 0.1, "visible dye on at least 10% of cells")
        for cell in 0..<(32 * 24) { XCTAssertEqual(a.values[cell * 4 + 3], 1) }
    }

    func testUniformAndZeroVelocity() {
        let u = DyeSeed.uniform(width: 3, height: 2, rgba: SIMD4(0.8, 0.7, 0.6, 1))
        XCTAssertEqual(Array(u.values.prefix(4)), [0.8, 0.7, 0.6, 1])
        XCTAssertEqual(u.values.count, 24)
        let v = DyeSeed.zeroVelocity(width: 3, height: 2)
        XCTAssertEqual(v.channels, 2)
        XCTAssertTrue(v.values.allSatisfy { $0 == 0 })
    }
}
