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
}
