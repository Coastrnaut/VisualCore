// BackwardsAuroraExperienceIdentityTests — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-003, 004, 005, 007, 008;
// clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without storage) builds a
// shell around the presenter (with the accessibility settings passed through), the controls are the four declared
// actions in order, the quality profile's levels are the catalog tiers level-0 … level-2 and equal the presenter's, the
// palette is the clarification's colours and the catalog's five hex strings, the frame probes are none before a frame
// and the two dark ground corners after one, and the description names the level, the reversals spent and the budget;
// the mirror follows the description and the panel's section starts at 0 … 1. iOS only, as the target.
#if os(iOS)
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct BackwardsAuroraExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(BackwardsAuroraExperience.id?.rawValue == "r02-g10.backwards-aurora")
        #expect(BackwardsAuroraExperienceCore.experienceID == "r02-g10.backwards-aurora")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(BackwardsAuroraExperience.id)
        let shell: ExperienceShell<BackwardsAuroraPresenter> =
            BackwardsAuroraExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == BackwardsAuroraShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<BackwardsAuroraPresenter> = BackwardsAuroraExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == BackwardsAuroraShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(BackwardsAuroraExperience.id)
        let name: String = "backwards-aurora-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = BackwardsAuroraExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                        reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == BackwardsAuroraExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<BackwardsAuroraPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The four play actions, since feature 395 (R02-G10-05) the five teaching and progression actions, and since
    /// feature 397 (R02-G10-07) the three replay controls and the sound setting.
    @Test func theControlsAreTheThirteenActions() {
        var ids: [String] = []
        var arities: [Int] = []
        for control in BackwardsAuroraExperienceCore.controls {
            ids.append(control.id)
            arities.append(control.ranges.count)
        }
        #expect(ids == ["wave.reverse", "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                        "mode.practice", "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step",
                        "replay.stop", "settings.sound"])
        #expect(ids == BackwardsAuroraExperienceCore.actionIDs)
        #expect(arities == [2, 0, 0, 0, 1, 3, 0, 0, 0, 1, 0, 0, 1])
        let reverse: ExperienceControl = BackwardsAuroraExperienceCore.controls[0]
        for range in reverse.ranges {
            #expect(range == 0.0...31.0, "\(range)")
        }
    }

    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in BackwardsAuroraExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(BackwardsAuroraExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(BackwardsAuroraExperience.id)
        let shell: ExperienceShell<BackwardsAuroraPresenter> = BackwardsAuroraExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == BackwardsAuroraExperienceCore.qualityTiers)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(BackwardsAuroraPalette.ground == SIMD3<Double>(7.0 / 255, 11.0 / 255, 31.0 / 255))
        #expect(BackwardsAuroraPalette.ribbon == SIMD3<Double>(31.0 / 255, 200.0 / 255, 214.0 / 255))
        #expect(BackwardsAuroraPalette.ribbonHighlight == SIMD3<Double>(159.0 / 255, 244.0 / 255, 250.0 / 255))
        #expect(BackwardsAuroraPalette.glow == SIMD3<Double>(111.0 / 255, 232.0 / 255, 240.0 / 255))
        #expect(BackwardsAuroraPalette.ghost == SIMD3<Double>(201.0 / 255, 184.0 / 255, 240.0 / 255))
        #expect(BackwardsAuroraPalette.ring == SIMD3<Double>(220.0 / 255, 211.0 / 255, 250.0 / 255))
        #expect(BackwardsAuroraPalette.matched == SIMD3<Double>(244.0 / 255, 240.0 / 255, 255.0 / 255))
        #expect(BackwardsAuroraPalette.kink == SIMD3<Double>(255.0 / 255, 138.0 / 255, 122.0 / 255))
        #expect(BackwardsAuroraPalette.tear == SIMD3<Double>(255.0 / 255, 59.0 / 255, 48.0 / 255))
        #expect(BackwardsAuroraPalette.band == SIMD3<Double>(42.0 / 255, 53.0 / 255, 112.0 / 255))
        #expect(BackwardsAuroraPalette.spent == SIMD3<Double>(31.0 / 255, 200.0 / 255, 214.0 / 255))
        #expect(BackwardsAuroraPalette.unspent == SIMD3<Double>(43.0 / 255, 51.0 / 255, 82.0 / 255))
        #expect(BackwardsAuroraPalette.hex == ["#070B1F", "#1FC8D6", "#C9B8F0", "#DCD3FA", "#FF8A7A"])
    }

    /// No probes before a frame; the two dark ground corners after a real frame, and their pixels are the ground.
    @Test func theProbesAreTheGroundCornersAfterARealFrame() async throws {
        let id: ExperienceID = try #require(BackwardsAuroraExperience.id)
        let bare: ExperienceShell<BackwardsAuroraPresenter> = BackwardsAuroraExperience.make(id: id)
        let opening: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try BackwardsAuroraTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["ground-top-left", "ground-bottom-right"])
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
        #expect(shell.presenter.scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        for probe in probes {
            let got = BackwardsAuroraTest.pixelAtFraction(rgba, probe.x, probe.y, width: BackwardsAuroraTest.width,
                                                          height: BackwardsAuroraTest.height)
            #expect(BackwardsAuroraTest.channelDistance(got.colour, BackwardsAuroraPalette.ground)
                        <= BackwardsAuroraTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }

    @Test func theDescriptionNamesTheLevelAndReversals() throws {
        let id: ExperienceID = try #require(BackwardsAuroraExperience.id)
        let shell: ExperienceShell<BackwardsAuroraPresenter> = BackwardsAuroraExperience.make(id: id)
        let core: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let level: BackwardsAuroraLevel = core.play.level
        #expect(text.contains("Backwards Aurora level 21."), "\(text)")
        #expect(text.contains("0 of \(level.budget) reversals spent."), "\(text)")
        let mirror: BackwardsAuroraMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 21)
        #expect(mirror.budget == level.budget)
        #expect(mirror.spent == 0)
        #expect(mirror.targetLabel == "Level: " + level.targetDescription())
        #expect(mirror.status == "Ready")
        #expect(mirror.start == 0 && mirror.end == 1)
        // After the first reversal the description counts it.
        let advanced: BackwardsAuroraExperienceCore = try BackwardsAuroraTest.advanced(21)
        let after: String = shell.presenter.describe(advanced)
        #expect(after.contains("1 of \(level.budget) reversals spent."), "\(after)")
        if advanced.play.stage == .playing {
            #expect(shell.presenter.mirror.status == "Playing")
        }
    }
}
#endif
