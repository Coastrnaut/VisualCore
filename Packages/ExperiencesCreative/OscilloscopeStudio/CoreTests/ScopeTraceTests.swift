// ScopeTraceTests — feature 062 (A08-P02) T-A08-205 (FR-A08-210, FR-A08-211; SC-A08-203; data-model "ScopeTrace").
// The trace points, host-free and short: the waveform zig-zag has two points per column, centred in the column and
// spanning the column's min…max, clamped beyond ±1; the XY points equal the window's scaled (left, right) pairs mapped
// into the square, clamped at gain ×5, one per frame (at most 4,096) and without non-finite pairs.
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct ScopeTraceTests {
    private let rect = (x: 10.0, y: 20.0, width: 400.0, height: 200.0)
    private let square = (x: 50.0, y: 30.0, side: 300.0)

    private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }

    /// A stereo sine pair (left at `f` cycles, right at 1.5 `f`), amplitude 0.8, `count` frames.
    private func stereoSine(count: Int, cycles: Double = 2) -> (left: [Float], right: [Float]) {
        let left = (0..<count).map { Float(0.8 * sin(2 * Double.pi * cycles * Double($0) / Double(count))) }
        let right = (0..<count).map { Float(0.8 * sin(2 * Double.pi * cycles * 1.5 * Double($0) / Double(count))) }
        return (left, right)
    }

    @Test func theZigZagHasTwoPointsPerColumnCentredAndSpanningMinToMax() {
        let columns = [ColumnRange(min: -0.5, max: 0.5), ColumnRange(min: 0, max: 0),
                       ColumnRange(min: -1, max: 0.25), ColumnRange(min: 0.75, max: 1)]
        let points = ScopeTrace.waveformPoints(columns, in: rect)
        #expect(points.count == 2 * columns.count)
        for (c, range) in columns.enumerated() {
            let low = points[2 * c], high = points[2 * c + 1]
            let x = rect.x + (Double(c) + 0.5) / Double(columns.count) * rect.width
            #expect(near(low.x, x) && near(high.x, x))
            #expect(near(low.y, rect.y + (Double(range.min) + 1) / 2 * rect.height))
            #expect(near(high.y, rect.y + (Double(range.max) + 1) / 2 * rect.height))
            #expect(low.y <= high.y)
        }
        let xs = stride(from: 0, to: points.count, by: 2).map { points[$0].x }
        #expect(zip(xs, xs.dropFirst()).allSatisfy { $0 < $1 })
        #expect(near(points[0].x, 60) && near(points[6].x, 360))   // 400 / 4 = 100 per column, centred
        #expect(ScopeTrace.waveformPoints([], in: rect).isEmpty)
    }

    @Test func theZigZagClampsBeyondFullScale() {
        let points = ScopeTrace.waveformPoints([ColumnRange(min: -3, max: 2.5), ColumnRange(min: .nan, max: 0.5)],
                                               in: rect)
        #expect(points.count == 4)
        #expect(near(points[0].y, rect.y) && near(points[1].y, rect.y + rect.height))
        #expect(points.allSatisfy { $0.y >= rect.y && $0.y <= rect.y + rect.height && $0.y.isFinite })
        #expect(near(points[2].y, rect.y + rect.height / 2))   // a non-finite bound counts as 0
    }

    @Test func xyPointsEqualTheScaledPairsMappedIntoTheSquare() {
        let (left, right) = stereoSine(count: 1_000)
        let points = ScopeTrace.xyPoints(left: left, right: right, gain: 1, in: square)
        #expect(points.count == left.count)
        for i in left.indices {
            let x = square.x + (Double(left[i]) + 1) / 2 * square.side
            let y = square.y + (Double(right[i]) + 1) / 2 * square.side
            #expect(near(points[i].x, x) && near(points[i].y, y))
        }
    }

    @Test func xyPointsClampAtHighGain() {
        let (left, right) = stereoSine(count: 512)
        let points = ScopeTrace.xyPoints(left: left, right: right, gain: 5, in: square)
        #expect(points.count == 512)
        for i in left.indices {
            let l = min(max(Double(left[i]) * 5, -1), 1), r = min(max(Double(right[i]) * 5, -1), 1)
            #expect(near(points[i].x, square.x + (l + 1) / 2 * square.side))
            #expect(near(points[i].y, square.y + (r + 1) / 2 * square.side))
        }
        #expect(points.allSatisfy { $0.x >= square.x && $0.x <= square.x + square.side })
        #expect(points.allSatisfy { $0.y >= square.y && $0.y <= square.y + square.side })
        #expect(points.contains { near($0.x, square.x + square.side) })   // 0.8 × 5 = 4 reaches the edge
    }

    @Test func xyPointsSkipNonFinitePairsUseTheShorterChannelAndAreCapped() {
        let left: [Float] = [0.5, .nan, 0.25, .infinity, -0.5]
        let right: [Float] = [0.5, 0.1, -.infinity, 0.2, -0.5, 0.9]
        let points = ScopeTrace.xyPoints(left: left, right: right, gain: 1, in: square)
        #expect(points.count == 2)   // frames 0 and 4; frame 5 has no left sample
        #expect(near(points[0].x, square.x + 0.75 * square.side) && near(points[1].y, square.y + 0.25 * square.side))
        let (longLeft, longRight) = stereoSine(count: 5_000)
        #expect(ScopeTrace.xyPoints(left: longLeft, right: longRight, gain: 1, in: square).count
                    == ScopeTrace.maxXYPoints)
        #expect(ScopeTrace.maxXYPoints == 4_096)
        #expect(ScopeTrace.xyPoints(left: [], right: [0.5], gain: 1, in: square).isEmpty)
    }
}
