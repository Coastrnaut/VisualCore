// MyceliumArchitectExperienceIdentityTests — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-005, 007, 008, 010;
// clarification Q5). The experience's id is the catalog id; the registry's factory
// (`make(id:storage:reduceMotion:reduceFlashing:)`, which does not depend on the registration) builds a shell around
// the presenter with the accessibility settings passed through, as does the tests' factory; the controls are the ten
// declared actions in order; the registration facts hold (100 certified levels, schema 1, the tiers level-0 …
// level-2, the palette #06070A, #2FE08A, #E08A3C, #7B3FB8, #12161C); the presenter's quality levels equal the names of
// the Core's `qualityProfile`; the presenter holds no GPU object and no snapshot before setup; Reduce Motion stills
// the scene (`motion` 0) and Reduce Flashing caps the glow; the presenter declares its two frame probes (the backdrop
// corners) once a frame was drawn; the feature's seed 2_513 opens level 14 with the full growth shown; the panel's
// cursor, direction and pulse stay inside the level's ranges; and a refused action is named in words with or without
// the engine's `action.rule.` prefix. iOS only, as the target.
#if os(iOS)
import Foundation
import MyceliumArchitectCore
import Testing
@testable import MyceliumArchitectExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct MyceliumArchitectExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(MyceliumArchitectExperience.id?.rawValue == "r02-g22.mycelium-architect")
        #expect(MyceliumArchitectExperienceCore.experienceID == "r02-g22.mycelium-architect")
    }

    /// The registration's content facts: 100 certified levels, schema 1, three tiers, the five-colour palette.
    @Test func theRegistrationFactsHold() {
        #expect(MyceliumArchitectExperienceCore.levelNumbers == 1...100)
        #expect(MyceliumArchitectExperienceCore.certifiedCandidates.count == 100)
        #expect(MyceliumArchitectExperienceCore.schemaVersion == 1)
        var names: [String] = []
        for level in MyceliumArchitectExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(MyceliumArchitectExperienceCore.qualityTiers == 3)
        #expect(MyceliumArchitectPalette.hex == ["#06070A", "#2FE08A", "#E08A3C", "#7B3FB8", "#12161C"])
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in MyceliumArchitectExperienceCore.controls { ids.append(control.id) }
        #expect(ids == MyceliumArchitectExperienceCore.actionIDs)
        #expect(ids == ["cell.nutrient", "cell.blocker", "cell.clear", "root.seed", "root.unseed", "growth.run",
                        "play.undo", "play.redo", "level.next", "growth.show"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers` and equal the names of its
    /// `qualityProfile`.
    @Test func thePresentersQualityLevelsEqualTheCoresProfile() throws {
        let id: ExperienceID = try #require(MyceliumArchitectExperience.id)
        let shell: ExperienceShell<MyceliumArchitectPresenter> = MyceliumArchitectExperience.make(id: id)
        #expect(shell.qualityProfile.count == MyceliumArchitectExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == MyceliumArchitectExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var coreNames: [String] = []
        for level in MyceliumArchitectExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        var tierNames: [String] = []
        for tier in MyceliumArchitectTier.all { tierNames.append(tier.name) }
        #expect(names == coreNames)
        #expect(shell.presenter.qualityLevels == coreNames)
        #expect(coreNames == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(MyceliumArchitectExperience.id)
        let name: String = "mycelium-architect-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = MyceliumArchitectExperience.make(id: id, storage: storage,
                                                                          reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == MyceliumArchitectExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<MyceliumArchitectPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through to the
    /// scene (`motion` 0, the glow capped); nothing is built or drawn before setup.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(MyceliumArchitectExperience.id)
        let shell: ExperienceShell<MyceliumArchitectPresenter> =
            MyceliumArchitectExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.motion == 0)
        #expect(shell.presenter.scene.glowLimit == MyceliumArchitectBoardScene.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.boardBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        let plain: ExperienceShell<MyceliumArchitectPresenter> = MyceliumArchitectExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedMotion && !plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.motion == 1)
        #expect(plain.presenter.scene.glowLimit == MyceliumArchitectBoardScene.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(MyceliumArchitectExperience.id)
        let fresh: ExperienceShell<MyceliumArchitectPresenter> = MyceliumArchitectExperience.make(id: id)
        let opening: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MyceliumArchitectTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try MyceliumArchitectTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue, "\(probe.name)")
        }
        #expect(names == ["backdrop-top-left", "backdrop-bottom-right"])
        #expect(shell.frameProbes == probes, "the shell hands out the presenter's probes")
    }

    /// The feature's seed 2_513 opens certified level 14 with the full growth shown, and the mirror follows it: the
    /// level, the budget, the shown pulse and the status "Ready".
    @Test func theFeatureSeedOpensLevelFourteen() async throws {
        #expect(MyceliumArchitectExperienceCore.levelNumber(forSeed: MyceliumArchitectTest.featureSeed) == 14)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MyceliumArchitectTest.open(session, seed: MyceliumArchitectTest.featureSeed)
        let core: MyceliumArchitectExperienceCore = try MyceliumArchitectTest.core(shell)
        #expect(core.levelNumber == 14)
        #expect(core.shownPulse == core.play.report.pulsesRun)
        let text: String = shell.presenter.describe(core)
        #expect(text.hasPrefix("Mycelium Architect level 14. "), "\(text)")
        let mirror: MyceliumArchitectMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 14)
        #expect(mirror.budget == core.play.level.budget)
        #expect(mirror.actionsLeft == core.play.actionsLeft)
        #expect(mirror.shownPulse == core.shownPulse)
        #expect(mirror.status == "Ready")
        #expect(mirror.tutorialText == (core.play.level.tutorial ? MyceliumArchitectPresenter.tutorial : nil))
        #expect(shell.presenter.lastSnapshot?.shownPulse == core.shownPulse)
    }

    /// The panel's selection arithmetic: the cursor is clamped to the board, the direction to 0 … 7 and the pulse to
    /// 0 … the pulses run; the labels name the cell, the direction, the pulse and every terminal in words.
    @Test func thePanelStaysInsideTheLevelsRanges() throws {
        let core: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: 1)
        let mirror = MyceliumArchitectMirror()
        mirror.follow(core.play, shownPulse: core.shownPulse)
        let level: MyceliumArchitectLevel = core.play.level
        let steps: [Int] = [-40, -1, 1, 40]
        for step in steps {
            mirror.moveColumn(step)
            mirror.moveRow(step)
            #expect((0..<level.width).contains(mirror.cursorColumn))
            #expect((0..<level.height).contains(mirror.cursorRow))
            #expect(level.contains(mirror.cursor))
            let pulse: Int = mirror.pulse(moved: step)
            #expect((0...core.play.report.pulsesRun).contains(pulse))
        }
        mirror.column = 99
        mirror.row = -5
        #expect(mirror.cursorColumn == level.width - 1)
        #expect(mirror.cursorRow == 0)
        mirror.direction = 12
        #expect(mirror.selectedDirection == .northWest)
        mirror.direction = -3
        #expect(mirror.selectedDirection == .north)
        #expect(mirror.pulseLabel == "pulse \(core.shownPulse) of \(core.play.report.pulsesRun)")
        #expect(!mirror.cellLabel.isEmpty && mirror.cellLabel != "no cell")
        #expect(mirror.directionLabel.hasPrefix("north"))
        #expect(!mirror.terminalsLabel.isEmpty && mirror.terminalsLabel != "no terminals")
    }

    /// A refused action's code is named in words with or without the engine's `action.rule.` prefix.
    @Test func refusalsAreNamedInWords() {
        let codes: [String] = ["r02-g22.stage", "r02-g22.action", "r02-g22.budget", MyceliumArchitectExperienceRule.pulse,
                               MyceliumArchitectExperienceRule.notWhole]
        let fallback: String = MyceliumArchitectMirror.refusalText(code: "unknown")
        for code in codes {
            let bare: String = MyceliumArchitectMirror.refusalText(code: code)
            #expect(bare != fallback, "\(code) has its own words")
            #expect(MyceliumArchitectMirror.refusalText(code: "action.rule." + code) == bare, "\(code) with the prefix")
        }
    }
}
#endif
