// AmethystEscapeExperienceIdentityTests — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-004, 005, 008;
// clarifications Q2, Q3, Q5). The experience's id is the catalog id, the factory (with and without storage) builds a
// shell around the presenter (with the accessibility settings passed through), the controls are the five declared
// actions in order, the quality profile's levels are the catalog tiers level-0 … level-2 and equal the presenter's,
// the palette is the clarification's colours and the catalog's five hex strings, and the description names the level,
// the moves, the pearl, the exit gap and every shell, a won play's escape and a failure with its reason. iOS only, as
// the target.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct AmethystEscapeExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(AmethystEscapeExperience.id?.rawValue == "r02-g07.amethyst-escape")
        #expect(AmethystEscapeExperienceCore.experienceID == "r02-g07.amethyst-escape")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> =
            AmethystEscapeExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == AmethystEscapeShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == AmethystEscapeShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let name: String = "amethyst-escape-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = AmethystEscapeExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                       reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == AmethystEscapeExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<AmethystEscapePresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    @Test func theControlsAreTheFiveActions() {
        var ids: [String] = []
        for control in AmethystEscapeExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["shell.rotate", "pearl.advance", "play.undo", "play.redo", "level.next"])
        #expect(ids == AmethystEscapeExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in AmethystEscapeExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(AmethystEscapeExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(AmethystEscapePalette.backdrop == SIMD3<Double>(10.0 / 255, 6.0 / 255, 20.0 / 255))
        #expect(AmethystEscapePalette.amethyst == SIMD3<Double>(142.0 / 255, 79.0 / 255, 216.0 / 255))
        #expect(AmethystEscapePalette.platinum == SIMD3<Double>(214.0 / 255, 220.0 / 255, 230.0 / 255))
        #expect(AmethystEscapePalette.pearl == SIMD3<Double>(246.0 / 255, 242.0 / 255, 255.0 / 255))
        #expect(AmethystEscapePalette.exit == SIMD3<Double>(184.0 / 255, 240.0 / 255, 255.0 / 255))
        #expect(AmethystEscapePalette.hex == ["#0A0614", "#8E4FD8", "#D6DCE6", "#F6F2FF", "#B8F0FF"])
    }

    @Test func theDescriptionNamesTheLevelAndShells() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        let core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0)
        let level: AmethystEscapeLevel = core.play.level
        #expect(text.contains("Amethyst Escape level 21."), "\(text)")
        #expect(text.contains("0 of \(snapshot.budget) moves spent."), "\(text)")
        #expect(text.contains("The exit gap is at \(level.sectorName(snapshot.exitGap))."), "\(text)")
        #expect(text.contains("The pearl is in \(level.shellName(snapshot.pearl.shell))"), "\(text)")
        for index in level.shells.indices {
            #expect(text.lowercased().contains(level.shellName(index).lowercased() + ":"), "\(text)")
        }
        // The mirror follows the description.
        #expect(shell.presenter.mirror.levelNumber == 21)
        #expect(shell.presenter.mirror.shellNames.count == snapshot.shells.count)
        #expect(shell.presenter.mirror.budget == snapshot.budget)
        #expect(shell.presenter.mirror.status == "Ready")
    }

    @Test func theDescriptionNamesAWin() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty)
        for action in actions {
            let issued = AmethystEscapeTest.control(action)
            let result: ActionResult = core.apply(ExperienceAction(control: issued.control, values: issued.values,
                                                                   step: 0))
            #expect(result == .accepted, "\(issued.control) \(issued.values): \(result.code)")
        }
        #expect(core.play.stage == .won)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The pearl escaped through the exit gap."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.pearlLabel == "The pearl is outside the crystal")
    }

    @Test func theDescriptionNamesAFailure() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        // Turning the innermost shell + and − alternately never wins, so the last move of the budget fails the play.
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let budget: Int = core.snapshot(time: 0).budget
        for move in 0..<budget {
            let step: Double = move % 2 == 0 ? 1 : -1
            let result: ActionResult = core.apply(ExperienceAction(control: "shell.rotate", values: [0, step],
                                                                   step: 0))
            #expect(result == .accepted, "move \(move): \(result.code)")
        }
        #expect(core.play.stage == .failed)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The move budget ran out before the pearl escaped."), "\(text)")
        #expect(text.contains("Amethyst Escape level 1."), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        print("amethyst-escape failure description: \(text)")
    }
}
#endif
