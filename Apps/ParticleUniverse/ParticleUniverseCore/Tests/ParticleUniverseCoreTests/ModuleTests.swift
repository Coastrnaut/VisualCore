// ModuleTests.swift — package smoke test (feature 033 T-A04-101).
import XCTest
@testable import ParticleUniverseCore

final class ModuleTests: XCTestCase {
    func testSchemaVersionIsOne() { XCTAssertEqual(ParticleUniverseCore.schemaVersion, 1) }
}
