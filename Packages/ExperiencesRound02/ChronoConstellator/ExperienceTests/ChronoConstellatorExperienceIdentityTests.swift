// ChronoConstellatorExperienceIdentityTests — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-004, 005, 008;
// clarifications Q2, Q3, Q5). The experience's id is the catalog id, the factory builds a shell around the presenter
// (with the accessibility settings passed through), the controls are the eight declared actions in order, the quality
// profile's levels are the catalog tiers level-0 … level-2, the palette is the clarification's six colours and the
// catalog's five hex strings, and the description names the level, the tick, every star with its shape and phase, and a
// failure with its reason. iOS only, as the target.
#if os(iOS)
import ChronoConstellatorCore
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct ChronoConstellatorExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(ChronoConstellatorExperience.id?.rawValue == "r02-g06.chrono-constellator")
        #expect(ChronoConstellatorExperienceCore.experienceID == "r02-g06.chrono-constellator")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(ChronoConstellatorExperience.id)
        let shell: ExperienceShell<ChronoConstellatorPresenter> =
            ChronoConstellatorExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == ChronoConstellatorShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<ChronoConstellatorPresenter> = ChronoConstellatorExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == ChronoConstellatorShaders.standardGlowLimit)
    }

    @Test func theControlsAreTheEightActions() {
        var ids: [String] = []
        for control in ChronoConstellatorExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["star.phase", "star.hold", "star.release", "time.step", "time.rewind", "play.undo",
                        "play.redo", "level.next"])
        #expect(ids == ChronoConstellatorExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() {
        var names: [String] = []
        for level in ChronoConstellatorExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(ChronoConstellatorExperienceCore.qualityTiers == 3)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(ChronoConstellatorPalette.field == SIMD3<Double>(11.0 / 255, 10.0 / 255, 36.0 / 255))
        #expect(ChronoConstellatorPalette.grid == SIMD3<Double>(28.0 / 255, 26.0 / 255, 68.0 / 255))
        #expect(ChronoConstellatorPalette.silver == SIMD3<Double>(201.0 / 255, 206.0 / 255, 216.0 / 255))
        #expect(ChronoConstellatorPalette.star == SIMD3<Double>(242.0 / 255, 244.0 / 255, 255.0 / 255))
        #expect(ChronoConstellatorPalette.rose == SIMD3<Double>(255.0 / 255, 92.0 / 255, 138.0 / 255))
        #expect(ChronoConstellatorPalette.amber == SIMD3<Double>(255.0 / 255, 176.0 / 255, 32.0 / 255))
        #expect(ChronoConstellatorPalette.hex == ["#0B0A24", "#C9CED8", "#F2F4FF", "#FF5C8A", "#FFB020"])
    }

    @Test func theDescriptionNamesTheLevelAndStars() throws {
        let id: ExperienceID = try #require(ChronoConstellatorExperience.id)
        let shell: ExperienceShell<ChronoConstellatorPresenter> = ChronoConstellatorExperience.make(id: id)
        let core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
        #expect(text.contains("Chrono Constellator level 21."), "\(text)")
        #expect(text.contains("Tick 0 of \(snapshot.tickLimit)"), "\(text)")
        #expect(text.contains("\(snapshot.remaining) edits left"), "\(text)")
        for index in 0..<snapshot.stars.count {
            let shape: String = ChronoConstellatorLevel.shape(of: index).name
            #expect(text.contains("Star \(index + 1) (\(shape))"), "\(text)")
            #expect(text.contains("start phase \(snapshot.phases[index])"), "\(text)")
        }
        // The mirror follows the description.
        #expect(shell.presenter.mirror.levelNumber == 21)
        #expect(shell.presenter.mirror.starNames.count == snapshot.stars.count)
        #expect(shell.presenter.mirror.tickLimit == snapshot.tickLimit)
        #expect(shell.presenter.mirror.status == "Editing the timeline")
    }

    @Test func theDescriptionNamesAFailure() throws {
        let id: ExperienceID = try #require(ChronoConstellatorExperience.id)
        let shell: ExperienceShell<ChronoConstellatorPresenter> = ChronoConstellatorExperience.make(id: id)
        // Unedited, level 1 fails when replayed to its tick limit (a collision or the time running out).
        var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: 1)
        let limit: Int = core.snapshot(time: 0).tickLimit
        let result: ActionResult = core.apply(ExperienceAction(control: "time.step", values: [Double(limit)], step: 0))
        #expect(result == .accepted, "\(result.code)")
        #expect(core.play.stage == .failed)
        let text: String = shell.presenter.describe(core)
        let named: Bool = text.contains("collided at row") || text.contains("Time ran out")
        #expect(named, "\(text)")
        #expect(text.contains("Chrono Constellator level 1."), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        print("chrono-constellator failure description: \(text)")
    }
}
#endif
