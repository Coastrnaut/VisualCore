// EchoCartographerExperienceIdentityTests — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-003, 004, 005, 007,
// 008; clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without storage)
// builds a shell around the presenter (with the accessibility settings passed through), the controls are the six
// declared actions in order with their arities, the quality profile's levels are the catalog tiers level-0 … level-2
// and equal the presenter's, the palette is the clarification's colours and the catalog's five hex strings, the frame
// probes are none before a frame and the two dark ground corners after one, the description names the level and the
// energy left, and the mirror follows the description with the panel's cursor opening on the entry and clamped to the
// chamber. Level 1 is a 6 × 6 chamber entered at (0, 3) with one beacon at (1, 2) and 9 energy. iOS only, as the
// target.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct EchoCartographerExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(EchoCartographerExperience.id?.rawValue == "r02-g11.echo-cartographer")
        #expect(EchoCartographerExperienceCore.experienceID == "r02-g11.echo-cartographer")
        #expect(EchoCartographerTest.id.rawValue == EchoCartographerExperienceCore.experienceID)
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(EchoCartographerExperience.id)
        let shell: ExperienceShell<EchoCartographerPresenter> =
            EchoCartographerExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == EchoCartographerShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<EchoCartographerPresenter> = EchoCartographerExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == EchoCartographerShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(EchoCartographerExperience.id)
        let name: String = "echo-cartographer-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = EchoCartographerExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                         reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == EchoCartographerExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<EchoCartographerPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The controls are the declared actions in order: the six of feature 403 with arities 2, 2, 2, 0, 0, 0 and ranges
    /// 0 … 15, then (feature 405) `level.select` [1 … 100], `mode.daily` [year, month, day], `mode.practice`,
    /// `mode.campaign` and `tutorial.dismiss`, then (feature 407) `replay.start` [1 … 100], `replay.step`, `replay.stop`
    /// and `settings.sound` [0 … 1].
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        var arities: [Int] = []
        for control in EchoCartographerExperienceCore.controls {
            ids.append(control.id)
            arities.append(control.ranges.count)
        }
        #expect(ids == ["cell.pulse", "cell.claim", "cell.mark", "play.undo", "play.redo", "level.next",
                        "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss",
                        "replay.start", "replay.step", "replay.stop", "settings.sound"])
        #expect(ids == EchoCartographerExperienceCore.actionIDs)
        #expect(arities == [2, 2, 2, 0, 0, 0, 1, 3, 0, 0, 0, 1, 0, 0, 1])
        for index in 0..<3 {
            let control: ExperienceControl = EchoCartographerExperienceCore.controls[index]
            for range in control.ranges {
                #expect(range == 0.0...15.0, "\(control.id): \(range)")
            }
        }
    }

    /// The quality profile names level-0 … level-2 and equals the presenter's.
    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in EchoCartographerExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(EchoCartographerExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(EchoCartographerExperience.id)
        let shell: ExperienceShell<EchoCartographerPresenter> = EchoCartographerExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == EchoCartographerExperienceCore.qualityTiers)
    }

    /// The palette is clarification Q3's colours and the catalog's five hex strings.
    @Test func thePaletteIsTheClarificationsColours() {
        #expect(EchoCartographerPalette.ground == SIMD3<Double>(5.0 / 255, 7.0 / 255, 10.0 / 255))
        #expect(EchoCartographerPalette.floor == SIMD3<Double>(58.0 / 255, 74.0 / 255, 70.0 / 255))
        #expect(EchoCartographerPalette.wallFace == SIMD3<Double>(18.0 / 255, 48.0 / 255, 42.0 / 255))
        #expect(EchoCartographerPalette.wallEdge == SIMD3<Double>(61.0 / 255, 245.0 / 255, 196.0 / 255))
        #expect(EchoCartographerPalette.flare == SIMD3<Double>(184.0 / 255, 255.0 / 255, 240.0 / 255))
        #expect(EchoCartographerPalette.pulse == SIMD3<Double>(95.0 / 255, 247.0 / 255, 255.0 / 255))
        #expect(EchoCartographerPalette.entry == SIMD3<Double>(207.0 / 255, 227.0 / 255, 221.0 / 255))
        #expect(EchoCartographerPalette.marker == SIMD3<Double>(232.0 / 255, 241.0 / 255, 238.0 / 255))
        #expect(EchoCartographerPalette.pillar == SIMD3<Double>(95.0 / 255, 247.0 / 255, 255.0 / 255))
        #expect(EchoCartographerPalette.glow == SIMD3<Double>(159.0 / 255, 255.0 / 255, 247.0 / 255))
        #expect(EchoCartographerPalette.gaugeLit == SIMD3<Double>(61.0 / 255, 245.0 / 255, 196.0 / 255))
        #expect(EchoCartographerPalette.gaugeUnlit == SIMD3<Double>(30.0 / 255, 42.0 / 255, 42.0 / 255))
        #expect(EchoCartographerPalette.hex == ["#05070A", "#3DF5C4", "#3A4A46", "#CFE3DD", "#5FF7FF"])
    }

    /// No probes before a frame; the two dark ground corners after a real frame, and their pixels are the ground.
    @Test func theProbesAreTheGroundCornersAfterARealFrame() async throws {
        let id: ExperienceID = try #require(EchoCartographerExperience.id)
        let bare: ExperienceShell<EchoCartographerPresenter> = EchoCartographerExperience.make(id: id)
        let opening: EchoCartographerExperienceCore = try EchoCartographerExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try EchoCartographerTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["ground-top-left", "ground-bottom-right"])
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
        #expect(shell.presenter.scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        for probe in probes {
            let got = EchoCartographerTest.pixelAtFraction(rgba, probe.x, probe.y, width: EchoCartographerTest.width,
                                                           height: EchoCartographerTest.height)
            let distance: Double = EchoCartographerTest.channelDistance(got.colour, EchoCartographerPalette.ground)
            #expect(distance <= EchoCartographerTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }

    /// The description names the level and the energy left; the mirror follows it.
    @Test func theDescriptionNamesTheLevelAndTheEnergy() throws {
        let id: ExperienceID = try #require(EchoCartographerExperience.id)
        let shell: ExperienceShell<EchoCartographerPresenter> = EchoCartographerExperience.make(id: id)
        let core: EchoCartographerExperienceCore = try EchoCartographerExperienceCore.opening(number: 1)
        let level: EchoCartographerLevel = core.play.level
        // Level 1's facts.
        #expect(level.chamber.width == 6 && level.chamber.height == 6)
        #expect(level.entry == EchoCartographerCell(x: 0, y: 3))
        #expect(level.beacons == [EchoCartographerCell(x: 1, y: 2)])
        #expect(level.energy == 9)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("Echo Cartographer level 1."), "\(text)")
        #expect(text.contains("0 of 1 beacon located, 9 energy left"), "\(text)")
        let mirror: EchoCartographerMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 1)
        #expect(mirror.energy == 9)
        #expect(mirror.budget == 9)
        let target: String = "Level: " + level.levelDescription()
        #expect(mirror.targetLabel == target)
        #expect(mirror.status == "Ready")
        // After one pulse from the entry the description counts the energy and names the echo.
        let advanced: EchoCartographerExperienceCore = try EchoCartographerTest.advanced(1)
        let after: String = shell.presenter.describe(advanced)
        #expect(after.contains("8 energy left"), "\(after)")
        #expect(after.contains("pulse from column 0, row 3"), "\(after)")
        #expect(shell.presenter.mirror.status == "Playing")
        #expect(shell.presenter.mirror.energy == 8)
    }

    /// The panel's cursor opens on the entry, is clamped to the chamber, and returns to the new entry on a new level.
    @Test func theMirrorCursorOpensOnTheEntry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        let mirror: EchoCartographerMirror = shell.presenter.mirror
        #expect(mirror.column == 0 && mirror.row == 3, "cursor at \(mirror.column), \(mirror.row)")
        #expect(mirror.cursor == EchoCartographerCell(x: 0, y: 3))
        #expect(mirror.width == 6 && mirror.height == 6)
        #expect(mirror.cursorLabel == "column 0, row 3: open")
        mirror.stepColumn(-1)
        #expect(mirror.column == 0, "clamped at the left edge")
        mirror.stepRow(10)
        #expect(mirror.row == 5, "clamped at the bottom edge")
        mirror.stepColumn(20)
        #expect(mirror.column == 5, "clamped at the right edge")
        // The cursor is presentation state: moving it changed nothing in the kernel.
        let before: String = try EchoCartographerTest.digest(shell)
        try EchoCartographerTest.draw(session)
        #expect(try EchoCartographerTest.digest(shell) == before)
        #expect(mirror.column == 5 && mirror.row == 5, "a frame of the same level keeps the cursor")
        // The next level puts the cursor on its entry (since feature 405 level 2 opens with level 1's win).
        for action in try EchoCartographerTest.certifiedActions(1) {
            let step: (control: String, values: [Double]) = EchoCartographerTest.control(action)
            #expect(shell.handle(control: step.control, values: step.values) == .accepted)
        }
        #expect(shell.handle(control: "level.next") == .accepted)
        try EchoCartographerTest.draw(session)
        let entry: EchoCartographerCell = try EchoCartographerExperienceCore.level(number: 2).entry
        #expect(mirror.cursor == entry, "cursor at \(mirror.column), \(mirror.row)")
    }
}
#endif
