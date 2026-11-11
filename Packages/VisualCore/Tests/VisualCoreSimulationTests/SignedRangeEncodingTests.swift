// SignedRangeEncodingTests — feature 019 T-A02-102 (G-CPUFIELD; spec clarification 4).
import XCTest
import VisualCoreSimulation

final class SignedRangeEncodingTests: XCTestCase {
    func testEncodeDecode() throws {
        let e = try XCTUnwrap(SignedRangeEncoding(range: 4))
        XCTAssertEqual(e.encode(0), 0.5)
        XCTAssertEqual(e.encode(4), 1)
        XCTAssertEqual(e.encode(-4), 0)
        XCTAssertEqual(e.encode(100), 1, "clamped")
        XCTAssertEqual(e.decode(0.5), 0)
        for v: Float in [-3.9, -1, 0.25, 2.5] {
            let u = StoragePrecision.unorm8.round(e.encode(v))
            XCTAssertEqual(e.decode(u), v, accuracy: 4.0 * 2 / 255, "8-bit round trip")
        }
    }

    func testInvalidRange() {
        XCTAssertNil(SignedRangeEncoding(range: 0))
        XCTAssertNil(SignedRangeEncoding(range: -1))
        XCTAssertNil(SignedRangeEncoding(range: .nan))
        XCTAssertNil(SignedRangeEncoding(range: .infinity))
    }

    // Feature 020: zero must survive 8-bit storage exactly.
    func testUnorm8ZeroIsExact() throws {
        let e = try XCTUnwrap(SignedRangeEncoding.unorm8(range: 240))
        XCTAssertEqual(e.center, 128.0 / 255)
        XCTAssertEqual(StoragePrecision.unorm8.round(e.encode(0)), e.encode(0))
        XCTAssertEqual(e.decode(StoragePrecision.unorm8.round(e.encode(0))), 0)
        let half = try XCTUnwrap(SignedRangeEncoding(range: 240))
        XCTAssertNotEqual(half.decode(StoragePrecision.unorm8.round(half.encode(0))), 0, "a 0.5 center is not storable")
        XCTAssertNil(SignedRangeEncoding(range: 1, center: 0))
        XCTAssertNil(SignedRangeEncoding(range: 1, center: 1))
    }
}
