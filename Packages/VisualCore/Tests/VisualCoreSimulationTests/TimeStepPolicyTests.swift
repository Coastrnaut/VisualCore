// TimeStepPolicyTests — feature 019 T-A02-102 (G-CPUFIELD; FR-A02-108).
import XCTest
import VisualCoreSimulation

final class TimeStepPolicyTests: XCTestCase {
    func testClampRange() {
        var p = TimeStepPolicy()
        XCTAssertEqual(p.minStep, 1.0 / 240)
        XCTAssertEqual(p.maxStep, 1.0 / 30)
        XCTAssertEqual(p.clamp(1.0 / 60), 1.0 / 60)
        XCTAssertEqual(p.clamp(10), 1.0 / 30, "a long pause gives exactly one clamped step")
        XCTAssertEqual(p.clamp(0.0001), 1.0 / 240)
        XCTAssertEqual(p.clampedCount, 1)
        XCTAssertEqual(p.invalidCount, 0)
    }

    func testInvalidDeltas() {
        var p = TimeStepPolicy()
        for d in [Double.nan, .infinity, -.infinity, -1, 0] { XCTAssertEqual(p.clamp(d), 1.0 / 240) }
        XCTAssertEqual(p.invalidCount, 5)
    }

    func testInvalidConfigurationFallsBackToDefaults() {
        XCTAssertEqual(TimeStepPolicy(minStep: 0.1, maxStep: 0.01), TimeStepPolicy())
        XCTAssertEqual(TimeStepPolicy(minStep: -1, maxStep: 1), TimeStepPolicy())
        let custom = TimeStepPolicy(minStep: 0.01, maxStep: 0.02)
        XCTAssertEqual(custom.maxStep, 0.02)
    }
}
