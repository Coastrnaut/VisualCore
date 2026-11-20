// LissajousLabyrinthExperienceIdentityTests — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-004, 005, 008). The
// experience's id is the catalog id, the factory builds a shell around the presenter (with the accessibility settings
// passed through), and the quality profile's levels are the catalog tiers level-0 … level-2. iOS only, as the target.
#if os(iOS)
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct LissajousLabyrinthExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(LissajousLabyrinthExperience.id?.rawValue == "r02-g02.lissajous-labyrinth")
        #expect(LissajousLabyrinthExperienceCore.experienceID == "r02-g02.lissajous-labyrinth")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id = try #require(LissajousLabyrinthExperience.id)
        let shell: ExperienceShell<LissajousLabyrinthPresenter> =
            LissajousLabyrinthExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<LissajousLabyrinthPresenter> = LissajousLabyrinthExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() {
        var names: [String] = []
        for level in LissajousLabyrinthExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(LissajousLabyrinthExperienceCore.qualityTiers == 3)
    }
}
#endif
