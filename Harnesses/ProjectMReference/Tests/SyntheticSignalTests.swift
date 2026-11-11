// SyntheticSignalTests — feature 008 T-F703 (research R4; FR-F705 metric).
import XCTest
@testable import ProjectMReference

final class SyntheticSignalTests: XCTestCase {
    func testDeterministicAndBounded() {
        var a = SyntheticSignal(), b = SyntheticSignal()
        let x = a.next(frames: 2_000), y = b.next(frames: 2_000)
        XCTAssertEqual(x, y)
        XCTAssertEqual(x.count, 4_000)
        XCTAssertTrue(x.allSatisfy { abs($0) <= 1 })
        XCTAssertGreaterThan(x.map(abs).max() ?? 0, 0.2, "audible")
        XCTAssertNotEqual(a.next(frames: 10), Array(x.prefix(20)), "continues rather than restarting")
    }

    func testChunksRespectTheEngineMaximum() {
        var s = SyntheticSignal()
        let chunks = s.chunksForVideoFrame(maxFramesPerCall: 300)
        XCTAssertEqual(chunks.map { $0.count / 2 }, [300, 300, 135], "735 frames per 1/60 s in ≤ 300-frame calls")
        XCTAssertEqual(s.frame, 735)
        var empty = SyntheticSignal()
        XCTAssertEqual(empty.next(frames: 0), [])
    }

    func testImageDiff() {
        let a: [UInt8] = [10, 20, 30, 255,  100, 100, 100, 255]
        let b: [UInt8] = [12, 20, 30, 255,  100, 100, 120, 255]
        let r = try! XCTUnwrap(ImageDiff.compare(a, b))
        XCTAssertEqual(r.meanAbs, 22.0 / 6, accuracy: 1e-12)
        XCTAssertEqual(r.within8, 0.5)
        XCTAssertFalse(r.passes)
        XCTAssertTrue(ImageDiff.compare(a, a)!.passes)
        XCTAssertNil(ImageDiff.compare(a, [0, 0, 0, 0]))
        XCTAssertEqual(ImageDiff.litFraction(a), 1)
        XCTAssertEqual(ImageDiff.litFraction([0, 0, 0, 255]), 0)
    }
}
