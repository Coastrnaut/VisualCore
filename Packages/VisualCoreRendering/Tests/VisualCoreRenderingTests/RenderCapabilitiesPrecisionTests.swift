// RenderCapabilitiesPrecisionTests — feature 027 T-A03-202 (G-PRECISION; FR-A03-204; clarification 1; analyze C1).
// The simulator's reported precision is recorded as context only (constitution V); device values come in campaign II.
import Foundation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class RenderCapabilitiesPrecisionTests: XCTestCase {
    func testFragmentPrecisionIsReported() throws {
        let host = try RenderHost(scene: ClearColorScene(red: 0, green: 0, blue: 0))
        defer { host.destroy() }
        let caps = host.capabilities
        let high = try XCTUnwrap(caps.fragmentHighp)
        let medium = try XCTUnwrap(caps.fragmentMediump)
        print("fragment precision (simulator context only): highp \(high), mediump \(medium)")
        XCTAssertTrue(high.isSupported, "GLES 3.0 requires highp in fragment shaders")
        XCTAssertGreaterThanOrEqual(high.precisionBits, medium.precisionBits)
        XCTAssertGreaterThanOrEqual(high.precisionBits, 16)
        XCTAssertGreaterThanOrEqual(medium.precisionBits, 10, "GLSL ES minimum for mediump")
        XCTAssertGreaterThanOrEqual(high.rangeMax, 62)
        XCTAssertEqual(caps.fragmentMantissaBits(), high.precisionBits)
    }

    func testMantissaFallbacks() {
        var caps = RenderCapabilities()
        XCTAssertEqual(caps.fragmentMantissaBits(), 10, "nothing queried: the mediump minimum")
        caps.fragmentMediump = .init(rangeMin: 14, rangeMax: 14, precisionBits: 10)
        caps.fragmentHighp = .init(rangeMin: 0, rangeMax: 0, precisionBits: 0)
        XCTAssertEqual(caps.fragmentMantissaBits(), 10, "unsupported highp falls back to mediump")
        caps.fragmentHighp = .init(rangeMin: 127, rangeMax: 127, precisionBits: 23)
        XCTAssertEqual(caps.fragmentMantissaBits(), 23)
    }

    func testEarlierReportsWithoutPrecisionStillDecode() throws {
        let old = #"{"glVersion":"OpenGL ES 3.0","glslVersion":"","renderer":"","vendor":"","eglVendor":"","extensions":[],"maxTextureSize":4096,"maxViewport":{"width":4096,"height":4096},"maxRenderbufferSize":4096}"#
        let caps = try JSONDecoder().decode(RenderCapabilities.self, from: Data(old.utf8))
        XCTAssertEqual(caps.maxTextureSize, 4096)
        XCTAssertNil(caps.fragmentHighp)
        var withPrecision = caps
        withPrecision.fragmentHighp = .init(rangeMin: 127, rangeMax: 127, precisionBits: 23)
        let round = try JSONDecoder().decode(RenderCapabilities.self, from: JSONEncoder().encode(withPrecision))
        XCTAssertEqual(round, withPrecision)
    }
}
