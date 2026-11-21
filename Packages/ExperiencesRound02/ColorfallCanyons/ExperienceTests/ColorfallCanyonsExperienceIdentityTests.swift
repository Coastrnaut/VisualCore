// ColorfallCanyonsExperienceIdentityTests — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-004, 005, 008;
// clarifications Q2, Q3, Q5). The experience's id is the catalog id, the factory builds a shell around the presenter
// (with the accessibility settings passed through), the controls are the six declared actions, the quality profile's
// levels are the catalog tiers level-0 … level-2, the palette is the clarification's seven colours, and the description
// names the level, the springs and the basins. iOS only, as the target.
#if os(iOS)
import ColorfallCanyonsCore
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct ColorfallCanyonsExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(ColorfallCanyonsExperience.id?.rawValue == "r02-g05.colorfall-canyons")
        #expect(ColorfallCanyonsExperienceCore.experienceID == "r02-g05.colorfall-canyons")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(ColorfallCanyonsExperience.id)
        let shell: ExperienceShell<ColorfallCanyonsPresenter> =
            ColorfallCanyonsExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == ColorfallCanyonsShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<ColorfallCanyonsPresenter> = ColorfallCanyonsExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == ColorfallCanyonsShaders.standardGlowLimit)
    }

    @Test func theControlsAreTheSixActions() {
        var ids: [String] = []
        for control in ColorfallCanyonsExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["canyon.carve", "canyon.valve", "time.step", "play.undo", "play.redo", "level.next"])
        #expect(ids == ColorfallCanyonsExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() {
        var names: [String] = []
        for level in ColorfallCanyonsExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(ColorfallCanyonsExperienceCore.qualityTiers == 3)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(ColorfallCanyonsPalette.night == SIMD3<Double>(5.0 / 255, 7.0 / 255, 15.0 / 255))
        #expect(ColorfallCanyonsPalette.sandstone == SIMD3<Double>(140.0 / 255, 90.0 / 255, 60.0 / 255))
        #expect(ColorfallCanyonsPalette.rock == SIMD3<Double>(59.0 / 255, 48.0 / 255, 44.0 / 255))
        #expect(ColorfallCanyonsPalette.pearl == SIMD3<Double>(232.0 / 255, 228.0 / 255, 218.0 / 255))
        #expect(ColorfallCanyonsPalette.cyan == SIMD3<Double>(25.0 / 255, 227.0 / 255, 240.0 / 255))
        #expect(ColorfallCanyonsPalette.coral == SIMD3<Double>(255.0 / 255, 111.0 / 255, 89.0 / 255))
        #expect(ColorfallCanyonsPalette.yellow == SIMD3<Double>(255.0 / 255, 210.0 / 255, 63.0 / 255))
    }

    @Test func theDescriptionNamesTheLevelSpringsAndBasins() throws {
        let id: ExperienceID = try #require(ColorfallCanyonsExperience.id)
        let shell: ExperienceShell<ColorfallCanyonsPresenter> = ColorfallCanyonsExperience.make(id: id)
        let core: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: 0)
        #expect(text.contains("level 21"), "\(text)")
        #expect(text.contains("Tick 0 of \(snapshot.tickLimit)"), "\(text)")
        for index in 0..<snapshot.springs.count {
            #expect(text.contains("Spring \(index + 1), \(snapshot.springs[index].color.name)"), "\(text)")
        }
        for index in 0..<snapshot.basins.count {
            #expect(text.contains("Basin \(index + 1) holds"), "\(text)")
        }
        // The mirror follows the description.
        #expect(shell.presenter.mirror.levelNumber == 21)
        #expect(shell.presenter.mirror.springNames.count == snapshot.springs.count)
        #expect(shell.presenter.mirror.status == "Playing")
    }
}
#endif
