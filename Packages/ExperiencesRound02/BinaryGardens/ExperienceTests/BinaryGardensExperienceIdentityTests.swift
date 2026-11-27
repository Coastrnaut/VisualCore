// BinaryGardensExperienceIdentityTests — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-005, 007, 008). The
// experience's id is the catalog id; the registry's factory (`make(id:storage:reduceMotion:reduceFlashing:)`, which
// does not depend on the registration) builds a shell around the presenter with the accessibility settings passed
// through, as does the tests' factory; the controls are the nine declared actions in order; the registration facts
// hold (100 certified levels, schema 1, the tiers level-0 … level-2, the palette #070815, #FF5A36, #A6DDFF, #7BE8BE,
// #151B3D); the presenter's quality levels equal the names of the Core's `qualityProfile`; the presenter holds no GPU
// object and no snapshot before setup; Reduce Motion stops the coronas and motes (`motion` 0) and Reduce Flashing caps
// the glow; the presenter declares its two frame probes (the backdrop corners) once a frame was drawn; the feature's
// seed 2_503 opens level 4 at tick 48; and a refused action is named in words with or without the engine's
// `action.rule.` prefix. iOS only, as the target.
#if os(iOS)
import BinaryGardensCore
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct BinaryGardensExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(BinaryGardensExperience.id?.rawValue == "r02-g21.binary-gardens")
        #expect(BinaryGardensExperienceCore.experienceID == "r02-g21.binary-gardens")
    }

    /// The registration's content facts: 100 certified levels, schema 3 (since feature 507), three tiers, the
    /// five-colour palette.
    @Test func theRegistrationFactsHold() {
        #expect(BinaryGardensExperienceCore.levelNumbers == 1...100)
        #expect(BinaryGardensExperienceCore.certifiedCandidates.count == 100)
        #expect(BinaryGardensExperienceCore.schemaVersion == 3)
        var names: [String] = []
        for level in BinaryGardensExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(BinaryGardensExperienceCore.qualityTiers == 3)
        #expect(BinaryGardensPalette.hex == ["#070815", "#FF5A36", "#A6DDFF", "#7BE8BE", "#151B3D"])
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in BinaryGardensExperienceCore.controls { ids.append(control.id) }
        #expect(ids == BinaryGardensExperienceCore.actionIDs)
        #expect(ids == ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run", "play.undo",
                        "play.redo", "level.next", "clock.show", "level.select", "mode.daily", "mode.practice",
                        "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                        "settings.sound"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers` and equal the names of its
    /// `qualityProfile`.
    @Test func thePresentersQualityLevelsEqualTheCoresProfile() throws {
        let id: ExperienceID = try #require(BinaryGardensExperience.id)
        let shell: ExperienceShell<BinaryGardensPresenter> = BinaryGardensExperience.make(id: id)
        #expect(shell.qualityProfile.count == BinaryGardensExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == BinaryGardensExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var coreNames: [String] = []
        for level in BinaryGardensExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        var tierNames: [String] = []
        for tier in BinaryGardensTier.all { tierNames.append(tier.name) }
        #expect(names == coreNames)
        #expect(shell.presenter.qualityLevels == coreNames)
        #expect(coreNames == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(BinaryGardensExperience.id)
        let name: String = "binary-gardens-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = BinaryGardensExperience.make(id: id, storage: storage,
                                                                      reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == BinaryGardensExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<BinaryGardensPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through to the
    /// scene (`motion` 0, the glow capped); nothing is built or drawn before setup.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(BinaryGardensExperience.id)
        let shell: ExperienceShell<BinaryGardensPresenter> =
            BinaryGardensExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.motion == 0)
        #expect(shell.presenter.scene.glowLimit == BinaryGardensShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.systemBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        let plain: ExperienceShell<BinaryGardensPresenter> = BinaryGardensExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedMotion && !plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.motion == 1)
        #expect(plain.presenter.scene.glowLimit == BinaryGardensShaders.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(BinaryGardensExperience.id)
        let fresh: ExperienceShell<BinaryGardensPresenter> = BinaryGardensExperience.make(id: id)
        let opening: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BinaryGardensTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try BinaryGardensTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue, "\(probe.name)")
        }
        #expect(names == ["backdrop-top-left", "backdrop-bottom-right"])
        #expect(shell.frameProbes == probes, "the shell hands out the presenter's probes")
    }

    /// The feature's seed 2_503 opens certified level 4 at tick 48 (the starting configuration), and the mirror
    /// follows it: the level, the budget, the shown tick and the status "Ready".
    @Test func theFeatureSeedOpensLevelFour() async throws {
        #expect(BinaryGardensExperienceCore.levelNumber(forSeed: BinaryGardensTest.featureSeed) == 4)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BinaryGardensTest.open(session, seed: BinaryGardensTest.featureSeed,
                                                     atCheckTick: false)
        let core: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        #expect(core.levelNumber == 4)
        #expect(core.shownTick == BinaryGardensExperienceCore.openingTick)
        let text: String = shell.presenter.describe(core)
        #expect(text.hasPrefix("Binary Gardens level 4. "), "\(text)")
        let mirror: BinaryGardensMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 4)
        #expect(mirror.budget == core.play.level.budget)
        #expect(mirror.actionsLeft == core.play.actionsLeft)
        #expect(mirror.shownTick == BinaryGardensExperienceCore.openingTick)
        #expect(mirror.status == "Ready")
        #expect(mirror.tutorialText == (core.play.level.tutorial ? BinaryGardensPresenter.tutorial : nil))
        #expect(shell.presenter.lastSnapshot?.shownTick == BinaryGardensExperienceCore.openingTick)
    }

    /// The panel's selection arithmetic: rings, luminosities and the tilt are clamped to the level's ranges, phases
    /// step by the phase step cyclically over 0 … 47 and ticks wrap over 1 … 48.
    @Test func thePanelStaysInsideTheLevelsRanges() throws {
        let core: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: 1)
        let mirror = BinaryGardensMirror()
        mirror.follow(core.play, shownTick: core.shownTick)
        let level: BinaryGardensLevel = core.play.level
        for star in 0..<2 {
            mirror.star = star
            for step in [-9, -1, 1, 9] {
                #expect((0..<level.ringRadii.count).contains(mirror.ring(moved: step)))
                #expect((0..<level.luminosityLevels.count).contains(mirror.luminosity(moved: step)))
                #expect((0...level.maxTilt).contains(mirror.tilt(moved: step)))
                let phase: Int = mirror.phase(moved: step)
                #expect(BinaryGardensLevel.phases.contains(phase))
                #expect(phase % level.phaseStep == 0, "phase \(phase) on the grid of \(level.phaseStep)")
            }
        }
        #expect(BinaryGardensMirror.wrappedTick(49) == 1)
        #expect(BinaryGardensMirror.wrappedTick(0) == 48)
        #expect(BinaryGardensMirror.wrappedTick(24) == 24)
        #expect(mirror.tickLabel == "tick 48 of 48")
        #expect(!mirror.worldsLabel.isEmpty)
    }

    /// A refused action's code is named in words with or without the engine's `action.rule.` prefix.
    @Test func refusalsAreNamedInWords() {
        let codes: [String] = ["r02-g21.stage", "r02-g21.action", "r02-g21.budget", BinaryGardensExperienceRule.tick,
                               BinaryGardensExperienceRule.notWhole]
        let fallback: String = BinaryGardensMirror.refusalText(code: "unknown")
        for code in codes {
            let bare: String = BinaryGardensMirror.refusalText(code: code)
            #expect(bare != fallback, "\(code) has its own words")
            #expect(BinaryGardensMirror.refusalText(code: "action.rule." + code) == bare, "\(code) with the prefix")
        }
    }
}
#endif
