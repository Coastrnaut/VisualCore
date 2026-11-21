// HueCompassExperienceIdentityTests — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-004, 005; clarifications
// Q2, Q3). The experience's id is the catalog id, the factory builds a shell around the presenter (with the accessibility
// settings passed through), the quality profile's levels are the catalog tiers level-0 … level-2 and the palette is the
// clarification's four colours. iOS only, as the target.
#if os(iOS)
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct HueCompassExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(HueCompassExperience.id?.rawValue == "r02-g04.hue-compass")
        #expect(HueCompassExperienceCore.experienceID == "r02-g04.hue-compass")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(HueCompassExperience.id)
        let shell: ExperienceShell<HueCompassPresenter> =
            HueCompassExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.gainLimit == HueCompassShaders.reducedFlashingGainLimit)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<HueCompassPresenter> = HueCompassExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.gainLimit == HueCompassShaders.standardGainLimit)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() {
        var names: [String] = []
        for level in HueCompassExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(HueCompassExperienceCore.qualityTiers == 3)
    }

    @Test func thePaletteIsTheClarificationsFourColours() {
        #expect(HueCompassPalette.hex == ["#05070F", "#E8E4DA", "#2F6FD8", "#E0703A"])
        #expect(HueCompassPalette.night == SIMD3<Double>(5.0 / 255, 7.0 / 255, 15.0 / 255))
        #expect(HueCompassPalette.pearl == SIMD3<Double>(232.0 / 255, 228.0 / 255, 218.0 / 255))
        #expect(HueCompassPalette.sapphire == SIMD3<Double>(47.0 / 255, 111.0 / 255, 216.0 / 255))
        #expect(HueCompassPalette.ember == SIMD3<Double>(224.0 / 255, 112.0 / 255, 58.0 / 255))
        // The 24 band colours are distinct, and every band has its own glyph.
        var colours: [SIMD3<Double>] = []
        var glyphs: Set<HueCompassGlyph> = []
        for band in 0..<24 {
            let c: SIMD3<Double> = HueCompassPalette.band(band)
            #expect(!colours.contains(c), "band \(band) repeats a colour")
            colours.append(c)
            glyphs.insert(HueCompassGlyph.of(band: band))
        }
        #expect(glyphs.count == 24)
    }
}
#endif
