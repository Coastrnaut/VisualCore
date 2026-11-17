// CrossfadeUseTests — feature 133 (A18-P03) T-A18-305 (FR-A18-303, FR-A18-306; SC-A18-303; G-TRANSITION;
// clarifications Q1, Q5; contracts/themes.md "Crossfade use"; spec edge case "a theme whose shader fails"). Ambient
// Clock's theme change through VisualCore's `CrossfadeScene`, drawn offscreen at chosen frame times (no wall-clock
// assertion). The pictures are compared with motion off (uniform time 0), so a theme's frame does not depend on the
// frame time and a fresh render of a theme is a reference for any frame:
//   - under Reduce Motion a `theme.select` shows the new theme on the next frame (a cut);
//   - otherwise the fade starts at the frame that sees the change (T): at T + 0.6 the frame differs from both themes
//     and three draws are made; at T + 1.2 it is the new theme exactly with one draw;
//   - a second change at T + 0.4 restarts the fade from the picture shown (the start moves, the progress is 0 and the
//     frame looks like the last one);
//   - a theme whose fragment fails to compile (the seam `failNextThemeCompile`) leaves the previous theme drawn and
//     records `lastThemeError`; the time text is unchanged.
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct CrossfadeUseTests {
    /// The frame time at which the tests change the theme.
    private static let changeTime = 2.0

    /// A fresh render of `theme` with `palette` alone at uniform time 0 (motion off), at the still size: a session in
    /// which the theme was chosen and its fade has finished. With `reduceMotion` the session is made under Reduce
    /// Motion, so the screen-care drift is zero as in a Reduce Motion session (A18-P04: the scene moves by the drift
    /// of the clock's instant otherwise).
    private func reference(theme: Int, palette: Int = 0, reduceMotion: Bool = false) async throws -> StillImage {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, reduceMotion: reduceMotion)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        if theme != 0 {
            let chosen = shell.handle(control: "theme.select", values: [Double(theme)])
            #expect(chosen == .accepted)
        }
        if palette != 0 {
            let chosen = shell.handle(control: "theme.palette", values: [Double(palette)])
            #expect(chosen == .accepted)
        }
        _ = try AmbientTest.still(session, time: 0)
        let still = try AmbientTest.still(session, time: 10)
        #expect(shell.presenter.shownTheme == theme && shell.presenter.fadeStart == nil)
        session.close()
        return still
    }

    /// The largest difference of one RGB channel between two pictures of the same size (255 when the sizes differ).
    private func largestChannelDifference(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return 255 }
        var largest = 0
        var i = 0
        while i + 3 < a.count {
            for c in 0..<3 { largest = max(largest, abs(Int(a[i + c]) - Int(b[i + c]))) }
            i += 4
        }
        return largest
    }

    @Test func underReduceMotionAThemeChangeShowsTheNewThemeOnTheNextFrame() async throws {
        let wave = try await reference(theme: 2, reduceMotion: true)
        let noise = try await reference(theme: 0, reduceMotion: true)
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, reduceMotion: true)
        let before = try AmbientTest.still(session, time: 1)
        #expect(before == noise, "Reduce Motion: uniform time 0, the noise gradient")
        let chosen = shell.handle(control: "theme.select", values: [2])
        #expect(chosen == .accepted)
        let next = try AmbientTest.still(session, time: 1 + 1.0 / 60)
        #expect(shell.presenter.shownTheme == 2)
        #expect(shell.presenter.fadeStart == nil, "a cut: no fade runs")
        #expect(shell.presenter.fadeProgress == 1)
        #expect(shell.presenter.drawCount == 1)
        #expect(AmbientTest.differingPixels(next.rgba, wave.rgba) == 0)
        #expect(next == wave)
        session.close()
    }

    @Test func withoutReduceMotionTheFadeMixesAndEndsOnTheNewTheme() async throws {
        let wave = try await reference(theme: 2)
        let noise = try await reference(theme: 0)
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        let before = try AmbientTest.still(session, time: 1)
        #expect(before == noise)
        let chosen = shell.handle(control: "theme.select", values: [2])
        #expect(chosen == .accepted)
        let t = Self.changeTime
        let start = try AmbientTest.still(session, time: t)
        #expect(shell.presenter.fadeStart == t)
        #expect(shell.presenter.fadeProgress == 0)
        #expect(shell.presenter.drawCount == 1, "progress 0: the outgoing picture alone")
        #expect(largestChannelDifference(start.rgba, noise.rgba) <= 1, "the fade starts from the picture shown")
        let middle = try AmbientTest.still(session, time: t + 0.6)
        let progress = shell.presenter.fadeProgress
        #expect(abs(progress - 0.5) < 1e-9, "smoothstep(0.5)")
        #expect(shell.presenter.drawCount == 3, "the outgoing still, the incoming theme and the mix")
        #expect(AmbientTest.differingPixels(middle.rgba, noise.rgba) > 0, "differs from the old theme")
        #expect(AmbientTest.differingPixels(middle.rgba, wave.rgba) > 0, "differs from the new theme")
        let end = try AmbientTest.still(session, time: t + 1.2)
        #expect(shell.presenter.fadeProgress == 1)
        #expect(shell.presenter.fadeStart == nil)
        #expect(shell.presenter.drawCount == 1)
        #expect(AmbientTest.differingPixels(end.rgba, wave.rgba) == 0)
        #expect(end == wave)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func theProgressFollowsSmoothstepOverOnePointTwoSeconds() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let chosen = shell.handle(control: "theme.select", values: [1])
        #expect(chosen == .accepted)
        let t = Self.changeTime
        _ = try AmbientTest.still(session, time: t)
        #expect(AmbientPresenter.fadeDuration == 1.2)
        for fraction in [0.25, 0.5, 0.75] {
            _ = try AmbientTest.still(session, time: t + 1.2 * fraction)
            let expected = fraction * fraction * (3 - 2 * fraction)
            #expect(abs(shell.presenter.fadeProgress - expected) < 1e-9, "at \(fraction)")
            #expect(shell.presenter.drawCount == 3, "at \(fraction)")
        }
        _ = try AmbientTest.still(session, time: t + 2)
        #expect(shell.presenter.fadeProgress == 1 && shell.presenter.drawCount == 1)
        session.close()
    }

    @Test func aChangeDuringAFadeRestartsItFromThePictureShown() async throws {
        let shapes = try await reference(theme: 3)
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        _ = try AmbientTest.still(session, time: 1)
        let first = shell.handle(control: "theme.select", values: [2])
        #expect(first == .accepted)
        let t = Self.changeTime
        _ = try AmbientTest.still(session, time: t)
        #expect(shell.presenter.fadeStart == t)
        let mixed = try AmbientTest.still(session, time: t + 0.4)
        let midway = shell.presenter.fadeProgress
        #expect(midway > 0 && midway < 1)
        #expect(shell.presenter.drawCount == 3)
        let second = shell.handle(control: "theme.select", values: [3])
        #expect(second == .accepted)
        let restarted = try AmbientTest.still(session, time: t + 0.4)
        #expect(shell.presenter.fadeStart == t + 0.4, "the start moves to the frame that saw the change")
        #expect(shell.presenter.fadeProgress == 0, "the progress starts again")
        #expect(shell.presenter.shownTheme == 3)
        #expect(largestChannelDifference(restarted.rgba, mixed.rgba) <= 1, "the next frame looks like the last one")
        _ = try AmbientTest.still(session, time: t + 0.4 + 0.6)
        #expect(shell.presenter.drawCount == 3)
        let end = try AmbientTest.still(session, time: t + 0.4 + 1.5)
        #expect(shell.presenter.fadeStart == nil && shell.presenter.drawCount == 1)
        #expect(end == shapes)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aPaletteChangeFadesAndEndsOnThePalette() async throws {
        let lagoon = try await reference(theme: 2, palette: 1, reduceMotion: true)
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, reduceMotion: true)
        let chosen = shell.handle(control: "theme.select", values: [2])
        let palette = shell.handle(control: "theme.palette", values: [1])
        #expect(chosen == .accepted && palette == .accepted)
        let next = try AmbientTest.still(session, time: 1)
        #expect(shell.presenter.shownTheme == 2 && shell.presenter.shownPalette == 1)
        #expect(next == lagoon)
        session.close()
    }

    @Test func aThemeThatFailsToCompileKeepsThePreviousThemeAndTheTime() async throws {
        let noise = try await reference(theme: 0)
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        shell.presenter.tick(port: shell.port)
        let core = try AmbientTest.core(shell)
        let label = shell.presenter.describe(core)
        let text = shell.presenter.display.display
        #expect(text != nil)
        _ = try AmbientTest.still(session, time: 1)
        #expect(shell.presenter.lastThemeError == nil)
        shell.presenter.failNextThemeCompile = true
        let chosen = shell.handle(control: "theme.select", values: [2])
        #expect(chosen == .accepted, "the core takes the choice; the presenter refuses to draw it")
        let frame = try AmbientTest.still(session, time: Self.changeTime)
        #expect(shell.presenter.shownTheme == 0, "the previous theme stays drawn")
        #expect(shell.presenter.fadeStart == nil && shell.presenter.drawCount == 1)
        #expect(!shell.presenter.failNextThemeCompile, "the seam is used once")
        let error = try #require(shell.presenter.lastThemeError)
        #expect(error.contains(ThemeCatalog.themes[2].name))
        #expect(frame == noise)
        // The refused choice is not tried again on later frames.
        let later = try AmbientTest.still(session, time: Self.changeTime + 2)
        #expect(shell.presenter.shownTheme == 0 && later == noise)
        #expect(shell.presenter.lastThemeError == error)
        // The time and its text are untouched.
        let after = try AmbientTest.core(shell)
        #expect(after.theme == 2)
        #expect(shell.presenter.display.display == text)
        #expect(shell.presenter.describe(after) == label)
        // Another choice is drawn again and clears the error.
        let other = shell.handle(control: "theme.select", values: [3])
        #expect(other == .accepted)
        _ = try AmbientTest.still(session, time: 10)
        _ = try AmbientTest.still(session, time: 12)
        #expect(shell.presenter.shownTheme == 3)
        #expect(shell.presenter.lastThemeError == nil)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }
}
