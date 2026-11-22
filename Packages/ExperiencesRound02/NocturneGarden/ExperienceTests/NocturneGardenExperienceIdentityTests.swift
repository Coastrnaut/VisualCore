// NocturneGardenExperienceIdentityTests — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-003, 004, 005, 007, 008;
// clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without storage) builds a
// shell around the presenter (with the accessibility settings passed through), the controls are the eight declared
// actions in order, the quality profile's levels are the catalog tiers level-0 … level-2 and equal the presenter's, the
// palette is the clarification's colours and the catalog's five hex strings, the frame probes are declared after a frame
// and not before, and the description names the level, the moves spent and the budget, the level in words, the planted
// blooms, a won play and a leak failure with the kernel's reason; the mirror follows the description and the panel's
// picks start at the level's first supplied kind, column 0, row 0 and its smallest size. iOS only, as the target.
#if os(iOS)
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct NocturneGardenExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(NocturneGardenExperience.id?.rawValue == "r02-g09.nocturne-garden")
        #expect(NocturneGardenExperienceCore.experienceID == "r02-g09.nocturne-garden")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> =
            NocturneGardenExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == NocturneGardenShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == NocturneGardenShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let name: String = "nocturne-garden-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = NocturneGardenExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                       reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == NocturneGardenExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<NocturneGardenPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The eight play actions and, since feature 385 (R02-G09-05), the five teaching and progression actions.
    @Test func theControlsAreTheThirteenActions() {
        var ids: [String] = []
        for control in NocturneGardenExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set", "play.undo",
                        "play.redo", "level.next", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss"])
        #expect(ids == NocturneGardenExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in NocturneGardenExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(NocturneGardenExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == NocturneGardenExperienceCore.qualityTiers)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(NocturneGardenPalette.ground == SIMD3<Double>(10.0 / 255, 18.0 / 255, 48.0 / 255))
        #expect(NocturneGardenPalette.mist == SIMD3<Double>(184.0 / 255, 196.0 / 255, 224.0 / 255))
        #expect(NocturneGardenPalette.mistHighlight == SIMD3<Double>(230.0 / 255, 236.0 / 255, 247.0 / 255))
        #expect(NocturneGardenPalette.shadow == SIMD3<Double>(5.0 / 255, 6.0 / 255, 10.0 / 255))
        #expect(NocturneGardenPalette.gold == SIMD3<Double>(232.0 / 255, 200.0 / 255, 114.0 / 255))
        #expect(NocturneGardenPalette.coral == SIMD3<Double>(255.0 / 255, 122.0 / 255, 92.0 / 255))
        #expect(NocturneGardenPalette.leak == SIMD3<Double>(255.0 / 255, 59.0 / 255, 48.0 / 255))
        #expect(NocturneGardenPalette.body == SIMD3<Double>(16.0 / 255, 19.0 / 255, 28.0 / 255))
        #expect(NocturneGardenPalette.glow == SIMD3<Double>(255.0 / 255, 184.0 / 255, 138.0 / 255))
        #expect(NocturneGardenPalette.lantern == SIMD3<Double>(255.0 / 255, 217.0 / 255, 160.0 / 255))
        #expect(NocturneGardenPalette.spent == SIMD3<Double>(255.0 / 255, 122.0 / 255, 92.0 / 255))
        #expect(NocturneGardenPalette.unspent == SIMD3<Double>(58.0 / 255, 69.0 / 255, 88.0 / 255))
        #expect(NocturneGardenPalette.hex == ["#0A1230", "#B8C4E0", "#E8C872", "#FF7A5C", "#05060A"])
    }

    /// The frame probes are declared once a real frame was drawn.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try NocturneGardenTest.core(shell))
        #expect(probes.count == 2)
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
        #expect(shell.presenter.scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
    }

    @Test func theDescriptionNamesTheLevelAndMoves() throws {
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        let core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let level: NocturneGardenLevel = core.play.level
        #expect(text.contains("Nocturne Garden level 21."), "\(text)")
        #expect(text.contains("0 of \(level.budget) moves spent."), "\(text)")
        #expect(text.contains("No bloom planted."), "\(text)")
        // The mirror follows the description; the picks start at the level's defaults.
        let mirror: NocturneGardenMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 21)
        #expect(mirror.budget == level.budget)
        #expect(mirror.moves == 0)
        #expect(mirror.bloomNames.isEmpty)
        #expect(mirror.targetLabel == "Level: " + level.targetDescription())
        #expect(mirror.status == "Ready")
        #expect(mirror.kind == NocturneGardenMirror.suppliedKinds(level).first)
        #expect(mirror.column == 0 && mirror.row == 0)
        #expect(mirror.size == level.sizes.min())
        #expect(mirror.bloom == 0)
        #expect(mirror.sun == core.play.elevation)
    }

    @Test func theDescriptionNamesAPlantedBloom() throws {
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        let core: NocturneGardenExperienceCore = try NocturneGardenTest.advanced(21)
        let play: NocturneGardenPlay = core.play
        #expect(play.blooms.count == 1)
        let text: String = shell.presenter.describe(core)
        let bloom: NocturneGardenBloom = try #require(play.blooms.first)
        #expect(text.contains("\(play.moves) of \(play.level.budget) moves spent."), "\(text)")
        #expect(text.contains(play.level.bloomName(0, bloom: bloom)), "\(text)")
        #expect(shell.presenter.mirror.bloomNames == [play.level.bloomName(0, bloom: bloom)])
        if play.stage == .playing {
            #expect(shell.presenter.mirror.status == "Playing")
        }
    }

    @Test func theDescriptionNamesAWin() throws {
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: 1)
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        #expect(!actions.isEmpty)
        for action in actions {
            let result: ActionResult = core.apply(NocturneGardenTest.experienceAction(action))
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(core.play.stage == .won)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The shadow matches the target."), "\(text)")
        #expect(text.contains("\(actions.count) of \(core.play.level.budget) moves spent."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
    }

    /// A leak failure (found by `NocturneGardenTest.leakFailure`) names the kernel's reason in the description.
    @Test func theDescriptionNamesALeakFailure() throws {
        let found = try #require(try NocturneGardenTest.leakFailure(), "a plant of some level leaks visibly")
        let id: ExperienceID = try #require(NocturneGardenExperience.id)
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: found.level)
        for action in found.actions {
            let result: ActionResult = core.apply(NocturneGardenTest.experienceAction(action))
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(core.play.stage == .failed)
        #expect(core.play.failure == .leak(found.actions.count - 1))
        #expect(core.outcome?.code == NocturneGardenExperienceCore.failedCode)
        // Since feature 385 (R02-G09-05) the description gives the failure explanation: the kernel's reason
        // sentence-cased, then "Undo the last move or retry the level."
        let reason: String = try #require(NocturneGardenFailureExplanation(play: core.play)?.text)
        let kernelReason: String = try #require(core.play.failureReason)
        #expect(reason.lowercased().contains(kernelReason.lowercased()), "\(reason)")
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(reason), "\(text)")
        #expect(text.contains("Nocturne Garden level \(found.level)."), "\(text)")
        #expect(shell.presenter.mirror.status == "Failed: " + reason)
        let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.leakFailure)
        #expect(!snapshot.leaking.isEmpty)
        print("nocturne-garden leak failure description: \(text)")
    }
}
#endif
