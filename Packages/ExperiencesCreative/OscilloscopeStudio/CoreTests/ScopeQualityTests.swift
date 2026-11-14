// ScopeQualityTests — feature 065 (A08-P05) T-A08-503 (FR-A08-521; SC-A08-504). The three levels are (1, 1), (½, 2),
// (¼, 4); `level(tier:forced:)` clamps to 0…2 and a forced level overrides the tier; levels 1 and 2 draw half and a
// quarter of the columns (±1) and analyse every second and fourth frame.
import Foundation
import Testing
import OscilloscopeStudioCore

@Suite struct ScopeQualityTests {
    @Test func theThreeLevels() {
        #expect(ScopeQuality.levels.count == 3)
        #expect(ScopeQuality.levels.map(\.columnShare) == [1, 0.5, 0.25])
        #expect(ScopeQuality.levels.map(\.analysisInterval) == [1, 2, 4])
        #expect(ScopeQuality.levelNames == ["level-0", "level-1", "level-2"])
    }

    @Test func levelClampsAndForcedOverrides() {
        #expect(ScopeQuality.level(tier: -3) == 0)
        #expect(ScopeQuality.level(tier: 0) == 0)
        #expect(ScopeQuality.level(tier: 1) == 1)
        #expect(ScopeQuality.level(tier: 2) == 2)
        #expect(ScopeQuality.level(tier: 7) == 2)
        #expect(ScopeQuality.level(tier: 0, forced: 2) == 2)
        #expect(ScopeQuality.level(tier: 2, forced: 0) == 0)
        #expect(ScopeQuality.level(tier: 1, forced: 9) == 2)
        #expect(ScopeQuality.level(tier: 1, forced: -1) == 0)
        #expect(ScopeQuality.level(5) == ScopeQuality.levels[2])
        #expect(ScopeQuality.level(-5) == ScopeQuality.levels[0])
    }

    @Test(arguments: [1, 2, 3, 97, 390, 1179, 2048, 2732])
    func columnsHalveAndQuarter(width: Int) {
        let full = ScopeQuality.level(0).columns(forPixelWidth: Double(width))
        let half = ScopeQuality.level(1).columns(forPixelWidth: Double(width))
        let quarter = ScopeQuality.level(2).columns(forPixelWidth: Double(width))
        #expect(full == width)
        #expect(abs(half - width / 2) <= 1)
        #expect(abs(quarter - width / 4) <= 1)
        #expect(half >= 1 && quarter >= 1)
    }

    @Test func columnsOfDegenerateWidthsAreOne() {
        let level = ScopeQuality.level(0)
        #expect(level.columns(forPixelWidth: 0) == 1)
        #expect(level.columns(forPixelWidth: -10) == 1)
        #expect(level.columns(forPixelWidth: .nan) == 1)
        #expect(level.columns(forPixelWidth: .infinity) == 1)
    }

    @Test func analysisEveryOneTwoAndFourFrames() {
        let frames = 0..<16
        let counts = ScopeQuality.levels.map { level in frames.filter { level.shouldAnalyse(frame: $0) }.count }
        #expect(counts == [16, 8, 4])
        #expect(ScopeQuality.level(1).shouldAnalyse(frame: 0))
        #expect(!ScopeQuality.level(1).shouldAnalyse(frame: 1))
        #expect(ScopeQuality.level(2).shouldAnalyse(frame: 8))
        #expect(!ScopeQuality.level(2).shouldAnalyse(frame: 6))
    }

    @Test func initClampsInvalidValues() {
        let level = ScopeQuality(columnShare: 3, analysisInterval: 0)
        #expect(level.columnShare == 1)
        #expect(level.analysisInterval == 1)
        #expect(ScopeQuality(columnShare: .nan, analysisInterval: -2).columnShare == 1)
        #expect(ScopeQuality(columnShare: -1, analysisInterval: 1).columns(forPixelWidth: 100) == 1)
    }
}
