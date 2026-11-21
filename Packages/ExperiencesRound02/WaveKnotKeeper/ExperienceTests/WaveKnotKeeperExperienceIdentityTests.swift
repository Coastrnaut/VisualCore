// WaveKnotKeeperExperienceIdentityTests — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-004, 005). The
// experience's id is the catalog id, the factory builds a shell around the presenter (with the accessibility settings
// passed through), and the quality profile's levels are the catalog tiers level-0 … level-2. iOS only, as the target.
#if os(iOS)
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct WaveKnotKeeperExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(WaveKnotKeeperExperience.id?.rawValue == "r02-g03.wave-knot-keeper")
        #expect(WaveKnotKeeperExperienceCore.experienceID == "r02-g03.wave-knot-keeper")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(WaveKnotKeeperExperience.id)
        let shell: ExperienceShell<WaveKnotKeeperPresenter> =
            WaveKnotKeeperExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<WaveKnotKeeperPresenter> = WaveKnotKeeperExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() {
        var names: [String] = []
        for level in WaveKnotKeeperExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(WaveKnotKeeperExperienceCore.qualityTiers == 3)
    }
}
#endif
