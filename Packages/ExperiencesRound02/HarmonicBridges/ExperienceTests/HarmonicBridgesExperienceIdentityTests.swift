// HarmonicBridgesExperienceIdentityTests — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-003, 004, 005, 007,
// 008, 009; clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without
// storage) builds a shell around the presenter (with the accessibility settings passed through), the controls are the
// five declared actions in order with their arities and ranges, the registration facts hold (100 certified levels,
// schema 1, the tiers level-0 … level-2, the palette's five hex strings), the quality profile's levels equal the Core's
// `qualityTiers` and the presenter's, the palette is clarification Q3's colours, the frame probes are none before a
// frame and the two dark ground corners after one, the description names the level and the actions left, and the
// mirror follows the description with the panel's choice opening on string 0 at its current peg, clamped to the
// strings and the pegs. iOS only, as the target.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct HarmonicBridgesExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(HarmonicBridgesExperience.id?.rawValue == "r02-g12.harmonic-bridges")
        #expect(HarmonicBridgesExperienceCore.experienceID == "r02-g12.harmonic-bridges")
        #expect(HarmonicBridgesTest.id.rawValue == HarmonicBridgesExperienceCore.experienceID)
    }

    /// The registration's content facts: 100 certified levels, schema 1, three tiers, five palette hex strings.
    @Test func theRegistrationFactsHold() {
        #expect(HarmonicBridgesExperienceCore.levelNumbers == 1...100)
        #expect(HarmonicBridgesExperienceCore.certifiedCandidates.count == 100)
        #expect(HarmonicBridgesExperienceCore.schemaVersion == 1)
        #expect(HarmonicBridgesExperienceCore.levelNumber(forSeed: 0) == 1)
        #expect(HarmonicBridgesExperienceCore.levelNumber(forSeed: 199) == 100)
        #expect(HarmonicBridgesPalette.hex == ["#07060C", "#E0A070", "#4FD8E8", "#7A6A9C", "#A894FF"])
        var names: [String] = []
        for level in HarmonicBridgesExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let shell: ExperienceShell<HarmonicBridgesPresenter> =
            HarmonicBridgesExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == HarmonicBridgesShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<HarmonicBridgesPresenter> = HarmonicBridgesExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == HarmonicBridgesShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let name: String = "harmonic-bridges-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = HarmonicBridgesExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                        reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == HarmonicBridgesExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<HarmonicBridgesPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The controls are the five declared actions in order: `string.tune` [string 0 … 11, peg 1 … 12], then four
    /// without values.
    @Test func theControlsAreTheFiveActions() {
        var ids: [String] = []
        var arities: [Int] = []
        for control in HarmonicBridgesExperienceCore.controls {
            ids.append(control.id)
            arities.append(control.ranges.count)
        }
        #expect(ids == ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next"])
        #expect(ids == HarmonicBridgesExperienceCore.actionIDs)
        #expect(arities == [2, 0, 0, 0, 0])
        let tune: ExperienceControl = HarmonicBridgesExperienceCore.controls[0]
        #expect(tune.ranges.count == 2)
        if tune.ranges.count == 2 {
            #expect(tune.ranges[0] == 0.0...11.0, "string range \(tune.ranges[0])")
            #expect(tune.ranges[1] == 1.0...12.0, "peg range \(tune.ranges[1])")
        }
    }

    /// The quality profile names level-0 … level-2 and equals the presenter's (the X follow-through declares the same
    /// count).
    @Test func theQualityLevelsEqualTheCoresTiers() throws {
        var names: [String] = []
        for level in HarmonicBridgesExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(HarmonicBridgesExperienceCore.qualityTiers == 3)
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let shell: ExperienceShell<HarmonicBridgesPresenter> = HarmonicBridgesExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == HarmonicBridgesExperienceCore.qualityTiers)
    }

    /// The palette is clarification Q3's colours.
    @Test func thePaletteIsTheClarificationsColours() {
        #expect(HarmonicBridgesPalette.ground == SIMD3<Double>(7.0 / 255, 6.0 / 255, 12.0 / 255))
        #expect(HarmonicBridgesPalette.islandFace == SIMD3<Double>(122.0 / 255, 74.0 / 255, 46.0 / 255))
        #expect(HarmonicBridgesPalette.islandEdge == SIMD3<Double>(224.0 / 255, 160.0 / 255, 112.0 / 255))
        #expect(HarmonicBridgesPalette.string == SIMD3<Double>(200.0 / 255, 138.0 / 255, 90.0 / 255))
        #expect(HarmonicBridgesPalette.membrane == SIMD3<Double>(79.0 / 255, 216.0 / 255, 232.0 / 255))
        #expect(HarmonicBridgesPalette.markFilled == SIMD3<Double>(184.0 / 255, 244.0 / 255, 255.0 / 255))
        #expect(HarmonicBridgesPalette.markHollow == SIMD3<Double>(122.0 / 255, 106.0 / 255, 156.0 / 255))
        #expect(HarmonicBridgesPalette.start == SIMD3<Double>(242.0 / 255, 210.0 / 255, 168.0 / 255))
        #expect(HarmonicBridgesPalette.goal == SIMD3<Double>(168.0 / 255, 148.0 / 255, 255.0 / 255))
        #expect(HarmonicBridgesPalette.glow == SIMD3<Double>(143.0 / 255, 244.0 / 255, 255.0 / 255))
        #expect(HarmonicBridgesPalette.shell == SIMD3<Double>(111.0 / 255, 224.0 / 255, 240.0 / 255))
        #expect(HarmonicBridgesPalette.pip == SIMD3<Double>(79.0 / 255, 216.0 / 255, 232.0 / 255))
        #expect(HarmonicBridgesPalette.pipUnlit == SIMD3<Double>(58.0 / 255, 51.0 / 255, 72.0 / 255))
        #expect(HarmonicBridgesPalette.gaugeLit == SIMD3<Double>(224.0 / 255, 160.0 / 255, 112.0 / 255))
        #expect(HarmonicBridgesPalette.gaugeUnlit == SIMD3<Double>(42.0 / 255, 36.0 / 255, 51.0 / 255))
        #expect(HarmonicBridgesPalette.brokenOutline == SIMD3<Double>(255.0 / 255, 107.0 / 255, 74.0 / 255))
    }

    /// No probes before a frame; the two dark ground corners after a real frame, and their pixels are the ground.
    @Test func theProbesAreTheGroundCornersAfterARealFrame() async throws {
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let bare: ExperienceShell<HarmonicBridgesPresenter> = HarmonicBridgesExperience.make(id: id)
        let opening: HarmonicBridgesExperienceCore = try HarmonicBridgesExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try HarmonicBridgesTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["ground-top-left", "ground-bottom-right"])
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
        #expect(shell.presenter.scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        for probe in probes {
            let got = HarmonicBridgesTest.pixelAtFraction(rgba, probe.x, probe.y, width: HarmonicBridgesTest.width,
                                                          height: HarmonicBridgesTest.height)
            let distance: Double = HarmonicBridgesTest.channelDistance(got.colour, HarmonicBridgesPalette.ground)
            #expect(distance <= HarmonicBridgesTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }

    /// The description names the level and the actions left; the mirror follows it.
    @Test func theDescriptionNamesTheLevelAndTheActionsLeft() throws {
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let shell: ExperienceShell<HarmonicBridgesPresenter> = HarmonicBridgesExperience.make(id: id)
        let core: HarmonicBridgesExperienceCore = try HarmonicBridgesExperienceCore.opening(number: 11)
        let level: HarmonicBridgesLevel = core.play.level
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("Harmonic Bridges level 11."), "\(text)")
        #expect(text.contains(core.play.progressDescription), "\(text)")
        let mirror: HarmonicBridgesMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 11)
        #expect(mirror.actionsLeft == level.budget)
        #expect(mirror.budget == level.budget)
        #expect(mirror.status == "Ready")
        #expect(mirror.failureText == nil)
        // After the certified tunings the description counts the actions spent.
        let tuned: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.tuned(11)
        let tunings: Int = try HarmonicBridgesTest.certifiedTunings(11).count
        let after: String = shell.presenter.describe(tuned)
        #expect(after.contains(tuned.play.progressDescription), "\(after)")
        #expect(shell.presenter.mirror.status == "Playing")
        #expect(shell.presenter.mirror.actionsLeft == level.budget - tunings)
    }

    /// The panel's choice opens on string 0 at its current peg, is clamped to the strings and the pegs, and returns to
    /// string 0 on a new level.
    @Test func theMirrorChoiceOpensOnStringZero() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 30)
        let core: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.core(shell)
        let mirror: HarmonicBridgesMirror = shell.presenter.mirror
        #expect(mirror.string == 0, "chosen string \(mirror.string)")
        #expect(mirror.peg == core.play.pegs[0], "chosen peg \(mirror.peg)")
        let strings: Int = core.play.level.strings.count
        mirror.stepString(-1)
        #expect(mirror.string == 0, "clamped at the first string")
        mirror.stepString(strings + 5)
        #expect(mirror.string == strings - 1, "clamped at the last string")
        #expect(mirror.peg == core.play.pegs[strings - 1], "the peg follows the chosen string's current peg")
        mirror.stepPeg(-20)
        #expect(mirror.peg == 1, "clamped at peg 1")
        mirror.stepPeg(20)
        #expect(mirror.peg == 12, "clamped at peg 12")
        // The choice is presentation state: moving it changed nothing in the kernel.
        let before: String = try HarmonicBridgesTest.digest(shell)
        try HarmonicBridgesTest.draw(session)
        #expect(try HarmonicBridgesTest.digest(shell) == before)
        #expect(mirror.string == strings - 1 && mirror.peg == 12, "a frame of the same level keeps the choice")
        // The next level chooses its string 0 at its current peg.
        #expect(shell.handle(control: "level.next") == .accepted)
        try HarmonicBridgesTest.draw(session)
        let next: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.core(shell)
        #expect(next.levelNumber == 32)
        #expect(mirror.string == 0)
        #expect(mirror.peg == next.play.pegs[0])
    }
}
#endif
