// NightPolicyTests — feature 134 (A18-P04) T-A18-403 (FR-A18-401, FR-A18-405; SC-A18-401; clarification Q2). The
// boundary table of contracts/power.md "Night" (a wrapping window, a same-day window, an empty window, on and off);
// clamping and validation; the local minute in a fixed zone; the amber night text reaching 4.5 : 1 against every
// dimmed and tinted palette colour; a night colour darker than its day colour.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct NightPolicyTests {
    private static func minute(_ hour: Int, _ minute: Int) -> Int { hour * 60 + minute }

    @Test func theDefaultsAreOffTwentyTwoToSevenAndHalfDim() {
        let policy = NightPolicy()
        #expect(policy.mode == .off)
        #expect(policy.start == 1320)
        #expect(policy.end == 420)
        #expect(policy.dim == 0.5)
        #expect(NightPolicy.Mode.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test func aWindowAcrossMidnightIncludesItsStartAndExcludesItsEnd() {
        let policy = NightPolicy(mode: .scheduled, start: 1320, end: 420)
        let table: [(Int, Bool)] = [
            (Self.minute(21, 59), false), (Self.minute(22, 0), true), (Self.minute(6, 59), true),
            (Self.minute(7, 0), false), (0, true), (Self.minute(12, 0), false),
        ]
        for (minute, night) in table { #expect(policy.isNight(localMinute: minute) == night, "\(minute)") }
    }

    @Test func aSameDayWindowIsHalfOpen() {
        let policy = NightPolicy(mode: .scheduled, start: Self.minute(13, 0), end: Self.minute(14, 0))
        #expect(!policy.isNight(localMinute: Self.minute(12, 59)))
        #expect(policy.isNight(localMinute: Self.minute(13, 0)))
        #expect(policy.isNight(localMinute: Self.minute(13, 59)))
        #expect(!policy.isNight(localMinute: Self.minute(14, 0)))
    }

    @Test func anEmptyWindowIsNeverNightAndOnAndOffIgnoreTheWindow() {
        let empty = NightPolicy(mode: .scheduled, start: 600, end: 600)
        let on = NightPolicy(mode: .on, start: 600, end: 600)
        let off = NightPolicy(mode: .off, start: 0, end: 1439)
        for minute in 0..<1440 {
            #expect(!empty.isNight(localMinute: minute))
            #expect(on.isNight(localMinute: minute))
            #expect(!off.isNight(localMinute: minute))
        }
    }

    @Test func theInitClampsAndTheValidatingInitRefuses() {
        let clamped = NightPolicy(mode: .scheduled, start: -5, end: 5000, dim: 0.1)
        #expect(clamped.start == 0)
        #expect(clamped.end == 1439)
        #expect(clamped.dim == 0.3)
        #expect(NightPolicy(dim: 2).dim == 1)
        #expect(NightPolicy(dim: .nan).dim == 0.5)
        #expect(NightPolicy(validatingMode: 2, start: 1320, end: 420, dim: 0.5)
            == NightPolicy(mode: .scheduled, start: 1320, end: 420, dim: 0.5))
        #expect(NightPolicy(validatingMode: 3, start: 0, end: 0, dim: 0.5) == nil)
        #expect(NightPolicy(validatingMode: 0, start: 1440, end: 0, dim: 0.5) == nil)
        #expect(NightPolicy(validatingMode: 0, start: 0, end: -1, dim: 0.5) == nil)
        #expect(NightPolicy(validatingMode: 0, start: 0, end: 0, dim: 0.29) == nil)
        #expect(NightPolicy(validatingMode: 0, start: 0, end: 0, dim: .infinity) == nil)
    }

    @Test func theLocalMinuteFollowsTheCalendarZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        // 2026-01-01T16:35:00Z is 22:05 in Kolkata (UTC+5:30).
        let date = Date(timeIntervalSince1970: 1_767_285_300)
        #expect(NightPolicy.localMinute(of: date, calendar: calendar) == 22 * 60 + 5)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(NightPolicy.localMinute(of: date, calendar: calendar) == 16 * 60 + 35)
    }

    @Test func theTintAndTextColourAreTheDocumentedValues() {
        #expect(NightPolicy.tint == SIMD3(1, 0.75, 0.55))
        #expect(NightPolicy.textColor == SIMD3(1, 178.0 / 255, 122.0 / 255))
    }

    @Test func theNightTextReachesTheContrastAgainstEveryDimmedPaletteColour() {
        #expect(NightPolicy.contrastProblems().isEmpty)
        #expect(ThemeCatalog.themes.flatMap { $0.palettes.flatMap(\.colors) }.count == 48)
        // The check bites: white is reported at dim 1 (tinted white is lighter than the amber text); at dim 0.3 it is
        // dark enough to pass.
        let light = ThemePalette(name: "Light", colors: [SIMD3(1, 1, 1)])
        let problems = NightPolicy.contrastProblems(palettes: [light])
        #expect(problems.count == 1)
        #expect(problems.first?.contains("dim 1.0") == true)
    }

    @Test func aNightColourIsDarkerThanItsDayColour() {
        for color in ThemeCatalog.themes.flatMap({ $0.palettes.flatMap(\.colors) }) {
            let day = ThemeCatalog.relativeLuminance(color)
            for dim in [0.3, 0.5, 0.99] {
                #expect(ThemeCatalog.relativeLuminance(NightPolicy.nightColor(color, dim: dim)) < day)
            }
        }
        #expect(NightPolicy.nightColor(SIMD3(1, 1, 1), dim: 0.5) == SIMD3(0.5, 0.375, 0.275))
        #expect(NightPolicy.nightColor(SIMD3(1, 1, 1), dim: 0) == NightPolicy.nightColor(SIMD3(1, 1, 1), dim: 0.3))
    }
}
