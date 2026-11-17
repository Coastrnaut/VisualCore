// ThemeRenderTests — feature 133 (A18-P03) T-A18-305 (FR-A18-301, FR-A18-302, FR-A18-306; SC-A18-301, SC-A18-302;
// G-THEMES/G-BUDGETS; clarification Q2; contracts/themes.md "Contrast", "Render"). The four themes drawn inside the
// one app's session host on the simulator, short runs only (no wall-clock assertion): each theme at level-0 and
// level-1 draws a non-blank frame with a dark centre probe and one full-screen draw whose element count (`u_count`) is
// `ThemeCatalog.budget(theme:tier:)`; the three new themes differ from the noise gradient; palette 0 of theme 0 is the
// A18-P02 noise palette; and `ThemeCatalog.contrastRatio` agrees with VisualCoreUI's `AccessibleColors.contrastRatio`
// for every palette colour against white.
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreUI

@MainActor
@Suite(.serialized) struct ThemeRenderTests {
    /// Opens Ambient Clock pinned to `level`, chooses `theme` (motion on) and lets the fade finish through two
    /// offscreen frames (the fade starts at frame time 0 and is done at 5).
    private func openShowing(theme: Int, level: Int) async throws
        -> (ExperienceSession, ExperienceShell<AmbientPresenter>) {
        let session = ExperienceSession()
        session.qualityPin = level
        let shell = try await AmbientTest.open(session)
        if theme != 0 {
            let chosen = shell.handle(control: "theme.select", values: [Double(theme)])
            #expect(chosen == .accepted, "theme \(theme)")
        }
        _ = try AmbientTest.still(session, time: 0)
        _ = try AmbientTest.still(session, time: 5)
        #expect(shell.presenter.shownTheme == theme)
        #expect(shell.presenter.fadeStart == nil, "theme \(theme): the fade is over")
        return (session, shell)
    }

    @Test func everyThemeAtBothLevelsIsNotBlankWithADarkCentreAndItsBudget() async throws {
        for level in 0..<2 {
            for theme in 0..<ThemeCatalog.themes.count {
                let label = "theme \(theme) level-\(level)"
                let (session, shell) = try await openShowing(theme: theme, level: level)
                let frame = try AmbientTest.picture(session)
                #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(label)")
                for probe in shell.frameProbes {
                    let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
                    #expect(found?.rawValue == probe.expected, "\(label) \(probe.name)")
                }
                #expect(shell.engine.qualityTier == level, "\(label)")
                #expect(shell.presenter.drawCount == 1, "\(label): one full-screen draw")
                let budget = ThemeCatalog.budget(theme: theme, tier: level)
                #expect(shell.presenter.lastCount == budget, "\(label)")
                let scene = shell.presenter.scene?.to as? FullScreenShaderScene
                #expect(scene?.parameters["count"] == Double(budget), "\(label): u_count")
                #expect(scene?.parameters["block"] == Double(AmbientCore.pixelBlock(forTier: level)), "\(label)")
                let still = try AmbientTest.still(session, time: 3)
                #expect(FrameChecks.isNonBlank(still.rgba, width: still.width, height: still.height), "\(label) still")
                session.close()
                let counts = try #require(session.diagnostics.lastCloseCounts)
                #expect(counts.objects == 0 && counts.leaked == 0, "\(label)")
            }
        }
    }

    @Test func theThreeNewThemesDifferFromTheNoiseGradient() async throws {
        var stills: [StillImage] = []
        for theme in 0..<ThemeCatalog.themes.count {
            let (session, _) = try await openShowing(theme: theme, level: 0)
            stills.append(try AmbientTest.still(session, time: 3))
            session.close()
        }
        for theme in 1..<stills.count {
            #expect(AmbientTest.differingPixels(stills[0].rgba, stills[theme].rgba) > 0, "theme \(theme)")
        }
    }

    @Test func theBudgetsPerTierAreTheCatalogCounts() {
        let expected = [[5, 3], [48, 24], [6, 3], [8, 4]]
        for theme in 0..<expected.count {
            for tier in 0..<2 {
                let budget = ThemeCatalog.budget(theme: theme, tier: tier)
                #expect(budget == expected[theme][tier], "theme \(theme) tier \(tier)")
                let parameters = ThemeShaders.parameters(theme: theme, tier: tier)
                #expect(parameters["count"] == Double(budget), "theme \(theme) tier \(tier)")
            }
        }
        // The noise gradient's count is the A18-P02 octave count.
        for tier in 0..<2 {
            #expect(ThemeCatalog.budget(theme: 0, tier: tier) == AmbientCore.octaves(forTier: tier))
        }
    }

    @Test func theFirstPaletteOfTheNoiseGradientIsTheAmbientPaletteOfPhaseTwo() {
        let first = ThemeCatalog.themes[0].palettes[0].colors
        #expect(first == NoiseGradientTheme.encodedPalette)
        #expect(first.count == 4)
        #expect(ThemeCatalog.themes[0].id == NoiseGradientTheme.id)
    }

    @Test func theCatalogContrastAgreesWithAccessibleColorsForEveryPaletteColour() {
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        var checked = 0
        for info in ThemeCatalog.themes {
            for palette in info.palettes {
                for color in palette.colors {
                    let ui = UIColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
                    let reference = AccessibleColors.contrastRatio(white, ui)
                    let catalog = ThemeCatalog.contrastRatio(ThemeCatalog.white, color)
                    #expect(abs(reference - catalog) < 1e-9, "\(info.id) \(palette.name)")
                    #expect(catalog >= ThemeCatalog.requiredContrast, "\(info.id) \(palette.name)")
                    checked += 1
                }
            }
        }
        #expect(checked == 48)
        #expect(ThemeCatalog.contrastProblems().isEmpty)
    }
}
