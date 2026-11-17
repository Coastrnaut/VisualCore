// NightRenderTests — feature 134 (A18-P04) T-A18-405 (FR-A18-401, FR-A18-402, FR-A18-403; SC-A18-401; G-NIGHT;
// clarification Q2; contracts/power.md "Night"). Night mode of Ambient Clock drawn inside the one app's session host on
// the simulator, short runs only (no wall-clock assertion):
//   - `night.mode [1]` shows night: the frame at the same frame time has a lower mean luma than the day frame and is
//     not blank (not black, more than one colour), and the scene's uniforms are the night dim and the warm tint;
//   - scheduled 22:00–07:00 with a fixed clock at 23:00 in New York (the display environment's zone) is night, at 12:00
//     it is day (no frame drawn);
//   - the overlay's text is warm amber (#FFB27A) at night and white by day;
//   - the amber reaches 4.5 : 1 against every dimmed and tinted palette colour (`NightPolicy.contrastProblems()`).
import Foundation
import SwiftUI
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct NightRenderTests {
    /// The mean Rec. 709 luma of a picture, 0…255.
    private func meanLuma(_ rgba: [UInt8]) -> Double {
        var sum = 0.0
        var count = 0
        var i = 0
        while i + 3 < rgba.count {
            sum += FrameChecks.luma(r: rgba[i], g: rgba[i + 1], b: rgba[i + 2])
            count += 1
            i += 4
        }
        return count > 0 ? sum / Double(count) : 0
    }

    /// The luma spread (maximum − minimum) of a picture, 0…255.
    private func lumaSpread(_ rgba: [UInt8]) -> Double {
        var low = Double.greatestFiniteMagnitude
        var high = -Double.greatestFiniteMagnitude
        var i = 0
        while i + 3 < rgba.count {
            let value = FrameChecks.luma(r: rgba[i], g: rgba[i + 1], b: rgba[i + 2])
            low = min(low, value)
            high = max(high, value)
            i += 4
        }
        return high - low
    }

    @Test func nightModeOnDrawsADarkerFrameThatIsNotBlank() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        let day = try AmbientTest.still(session, time: 3)
        #expect(!shell.presenter.isNightShown)
        #expect(shell.presenter.lastScreenUniforms.tint == SIMD3(1, 1, 1))
        #expect(shell.presenter.lastScreenUniforms.dim == 1)
        let on = shell.handle(control: "night.mode", values: [1])
        #expect(on == .accepted)
        let night = try AmbientTest.still(session, time: 3)
        #expect(shell.presenter.isNightShown)
        #expect(shell.presenter.mirror.isNight)
        let uniforms = shell.presenter.lastScreenUniforms
        #expect(uniforms.tint == NightPolicy.tint)
        #expect(abs(uniforms.dim - NightPolicy.defaultDim) < 1e-12, "night dim 0.5 × idle dim 1")
        let dayLuma = meanLuma(day.rgba)
        let nightLuma = meanLuma(night.rgba)
        #expect(nightLuma < dayLuma, "night \(nightLuma) below day \(dayLuma)")
        #expect(FrameChecks.isNonBlank(day.rgba, width: day.width, height: day.height))
        #expect(!FrameChecks.isBlack(night.rgba, width: night.width, height: night.height), "the night frame is not black")
        #expect(lumaSpread(night.rgba) > 0, "the night frame still shows the picture")
        #expect(AmbientTest.differingPixels(day.rgba, night.rgba) > 0)
        // Back to day: the same frame as before.
        let dayAgain = shell.handle(control: "night.mode", values: [0])
        #expect(dayAgain == .accepted)
        let after = try AmbientTest.still(session, time: 3)
        #expect(!shell.presenter.isNightShown)
        #expect(after == day)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aScheduledWindowIsNightAtElevenPMAndDayAtNoonInTheDisplayZone() async throws {
        // 23:00 and 12:00 in New York (UTC−4 in June).
        let cases: [(String, Bool)] = [("2026-06-16T03:00:00Z", true), ("2026-06-15T16:00:00Z", false),
                                       ("2026-06-16T01:59:00Z", false), ("2026-06-16T02:00:00Z", true),
                                       ("2026-06-16T10:59:00Z", true), ("2026-06-16T11:00:00Z", false)]
        for (iso, night) in cases {
            let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.date(iso)))
            let scheduled = shell.handle(control: "night.mode", values: [2])
            #expect(scheduled == .accepted, "\(iso)")
            let window = shell.handle(control: "night.window", values: [1320, 420])
            #expect(window == .accepted, "\(iso)")
            let core = try AmbientTest.core(shell)
            #expect(core.nightMode == 2 && core.nightStart == 1320 && core.nightEnd == 420, "\(iso)")
            shell.presenter.follow(core)
            #expect(shell.presenter.isNightShown == night, "\(iso)")
            #expect(shell.presenter.mirror.isNight == night, "\(iso)")
            #expect(shell.presenter.screenUniforms.tint == (night ? NightPolicy.tint : SIMD3(1, 1, 1)), "\(iso)")
        }
    }

    @Test func theOverlayTextIsAmberAtNightAndWhiteByDay() {
        let environment = EnvironmentValues()
        let night = ClockOverlay.textColor(night: true).resolve(in: environment)
        let day = ClockOverlay.textColor(night: false).resolve(in: environment)
        let amber: [Double] = [1, Double(0xB2) / 255, Double(0x7A) / 255]
        let shown = [Double(night.red), Double(night.green), Double(night.blue)]
        for index in 0..<3 {
            #expect(abs(shown[index] - amber[index]) < 0.01, "channel \(index): \(shown[index])")
        }
        #expect(NightPolicy.textColor == SIMD3(1, Double(0xB2) / 255, Double(0x7A) / 255))
        let white = [Double(day.red), Double(day.green), Double(day.blue)]
        for index in 0..<3 {
            #expect(abs(white[index] - 1) < 0.01, "day channel \(index): \(white[index])")
        }
    }

    @Test func theNightTextReachesTheRequiredContrastAgainstEveryDimmedColour() {
        #expect(NightPolicy.contrastProblems() == [])
        let colours = ThemeCatalog.themes.flatMap(\.palettes).reduce(0) { $0 + $1.colors.count }
        #expect(colours == 48)
    }
}
