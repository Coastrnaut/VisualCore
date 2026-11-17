// ResamplerTests — feature 145 (A20-P01) T-A20-107 (FR-A20-103; SC-A20-102; clarification Q2). A fast, sparse path
// resampled leaves neighbours at most 0.004 + 1e-9 tray widths apart and keeps its first and last points; a long path
// ends at the cap of 512, marked capped; points outside the tray are clamped; a non-finite point and an empty input
// refuse; one point is a dab; repeated points are dropped.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct ResamplerTests {
    /// The tolerance of the spacing (clarification Q2).
    private static let tolerance = 1e-9

    /// The resampled points and cap flag, or nil when the resampler refused.
    private static func success(_ result: Result<(points: [Vec2], capped: Bool), DocumentRefusal>)
        -> (points: [Vec2], capped: Bool)? {
        if case .success(let value) = result { return value }
        return nil
    }

    /// Whether the resampler refused with out-of-range.
    private static func refusedOutOfRange(_ result: Result<(points: [Vec2], capped: Bool), DocumentRefusal>) -> Bool {
        if case .failure(.outOfRange(_)) = result { return true }
        return false
    }

    /// The largest gap between neighbouring points, in tray widths.
    private static func largestGap(_ points: [Vec2]) -> Double {
        var largest = 0.0
        for index in 1..<points.count {
            largest = max(largest, StrokeResampler.trayDistance(points[index - 1], points[index]))
        }
        return largest
    }

    @Test func aSparsePathLeavesNoGapAboveTheSpacing() throws {
        let raw = [Vec2(0.05, 0.1), Vec2(0.6, 0.7), Vec2(0.3, 0.9)]
        let out = try #require(Self.success(StrokeResampler.resample(raw)))
        #expect(!out.capped)
        #expect(out.points.count > 200 && out.points.count <= RakeStroke.maxPoints)
        #expect(Self.largestGap(out.points) <= StrokeResampler.spacing + Self.tolerance)
        #expect(out.points.first == raw[0])
        #expect(out.points.last == raw[2])
    }

    @Test func aLongPathEndsAtTheCap() throws {
        let raw = [Vec2(0, 0.5), Vec2(1, 0.5), Vec2(0, 0.5), Vec2(1, 0.5)]
        let out = try #require(Self.success(StrokeResampler.resample(raw)))
        #expect(out.capped)
        #expect(out.points.count == RakeStroke.maxPoints)
        #expect(Self.largestGap(out.points) <= StrokeResampler.spacing + Self.tolerance)
        #expect(out.points.first == raw[0])
    }

    @Test func pointsOutsideTheTrayAreClamped() throws {
        let raw = [Vec2(-1, 0.5), Vec2(2, 0.5), Vec2(0.5, 3)]
        let out = try #require(Self.success(StrokeResampler.resample(raw)))
        #expect(out.points.first == Vec2(0, 0.5))
        #expect(out.points.last == Vec2(0.5, 1))
        for point in out.points {
            #expect(point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1)
        }
    }

    @Test func nonFiniteAndEmptyInputsRefuse() {
        #expect(Self.refusedOutOfRange(StrokeResampler.resample([Vec2(0.1, 0.1), Vec2(.nan, 0.2)])))
        #expect(Self.refusedOutOfRange(StrokeResampler.resample([Vec2(0.1, .infinity)])))
        #expect(Self.refusedOutOfRange(StrokeResampler.resample([])))
    }

    @Test func onePointIsADab() throws {
        let out = try #require(Self.success(StrokeResampler.resample([Vec2(0.4, 0.6)])))
        #expect(out.points == [Vec2(0.4, 0.6)])
        #expect(!out.capped)
    }

    @Test func repeatedPointsAreDropped() throws {
        let a = Vec2(0.2, 0.2)
        let dab = try #require(Self.success(StrokeResampler.resample([a, a, Vec2(0.2 + 1e-8, 0.2)])))
        #expect(dab.points == [a])
        let b = Vec2(0.3, 0.25)
        let plain = try #require(Self.success(StrokeResampler.resample([a, b])))
        let repeated = try #require(Self.success(StrokeResampler.resample([a, a, b, b])))
        #expect(plain.points == repeated.points)
    }
}
