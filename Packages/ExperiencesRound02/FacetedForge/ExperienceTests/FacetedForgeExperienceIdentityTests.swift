// FacetedForgeExperienceIdentityTests — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-003, 004, 005, 007, 008;
// clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without storage) builds
// a shell around the presenter (with the accessibility settings passed through), the controls are the four declared
// actions in order, the quality profile's levels are the catalog tiers level-0 … level-2 and equal the presenter's,
// the palette is the clarification's colours and the catalog's five hex strings, the frame probes are declared after a
// frame, and the description names the level, the cuts, the target, every piece and the next cut, a won play and a
// failure with its reason. A sliver failure, found by a deterministic search over the certified levels, names its piece
// and cut in the description and is marked by the sliver-cross colour near the failed piece's centre. iOS only, as the
// target.
#if os(iOS)
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct FacetedForgeExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(FacetedForgeExperience.id?.rawValue == "r02-g08.faceted-forge")
        #expect(FacetedForgeExperienceCore.experienceID == "r02-g08.faceted-forge")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let shell: ExperienceShell<FacetedForgePresenter> =
            FacetedForgeExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == FacetedForgeShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == FacetedForgeShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let name: String = "faceted-forge-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = FacetedForgeExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                     reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == FacetedForgeExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<FacetedForgePresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The play controls of feature 373 and the progression controls of feature 375 (R02-G08-05), in order.
    @Test func theControlsAreThePlayAndProgressionActions() {
        var ids: [String] = []
        for control in FacetedForgeExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["piece.cut", "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                        "mode.practice", "mode.campaign", "tutorial.dismiss"])
        #expect(ids == FacetedForgeExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in FacetedForgeExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(FacetedForgeExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let shell: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == FacetedForgeExperienceCore.qualityTiers)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(FacetedForgePalette.ground == SIMD3<Double>(7.0 / 255, 9.0 / 255, 15.0 / 255))
        #expect(FacetedForgePalette.ice == SIMD3<Double>(191.0 / 255, 230.0 / 255, 245.0 / 255))
        #expect(FacetedForgePalette.highlight == SIMD3<Double>(242.0 / 255, 251.0 / 255, 255.0 / 255))
        #expect(FacetedForgePalette.ruby == SIMD3<Double>(200.0 / 255, 22.0 / 255, 60.0 / 255))
        #expect(FacetedForgePalette.amber == SIMD3<Double>(255.0 / 255, 179.0 / 255, 71.0 / 255))
        #expect(FacetedForgePalette.lattice == SIMD3<Double>(255.0 / 255, 226.0 / 255, 168.0 / 255))
        #expect(FacetedForgePalette.sliver == SIMD3<Double>(255.0 / 255, 77.0 / 255, 109.0 / 255))
        #expect(FacetedForgePalette.hex == ["#07090F", "#BFE6F5", "#C8163C", "#FFB347", "#FFE2A8"])
    }

    /// The frame probes are declared once a real frame was drawn.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try FacetedForgeTest.core(shell))
        #expect(probes.count == 2)
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
    }

    @Test func theDescriptionNamesTheLevelAndTarget() throws {
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let shell: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        let core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let level: FacetedForgeLevel = core.play.level
        let choice: FacetedForgePreviewChoice = FacetedForgePreviewChoice.initial(core.play)
        #expect(text.contains("Faceted Forge level 21."), "\(text)")
        #expect(text.contains("0 of \(level.budget) cuts spent."), "\(text)")
        #expect(text.contains("Target: \(level.targetDescription())."), "\(text)")
        #expect(text.contains("1 piece: piece 1: the whole crystal"), "\(text)")
        let direction: String = FacetedForgeDirection.all[choice.direction].name
        #expect(text.contains("Next cut: piece \(choice.piece + 1), direction \(direction), depth \(choice.depth)."),
                "\(text)")
        // The mirror follows the description, and the choice starts at the opening choice.
        #expect(shell.presenter.mirror.levelNumber == 21)
        #expect(shell.presenter.mirror.budget == level.budget)
        #expect(shell.presenter.mirror.cuts == 0)
        #expect(shell.presenter.mirror.pieceNames.count == 1)
        #expect(shell.presenter.mirror.targetLabel == "Target: " + level.targetDescription())
        #expect(shell.presenter.mirror.status == "Ready")
        #expect(shell.presenter.mirror.choice == choice)
    }

    @Test func theDescriptionNamesAWin() throws {
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let shell: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: 1)
        let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty)
        for action in actions {
            let issued = FacetedForgeTest.control(action)
            let result: ActionResult = core.apply(ExperienceAction(control: issued.control, values: issued.values,
                                                                   step: 0))
            #expect(result == .accepted, "\(issued.control) \(issued.values): \(result.code)")
        }
        #expect(core.play.stage == .won)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The pieces match the target."), "\(text)")
        #expect(text.contains("\(actions.count) of \(core.play.level.budget) cuts spent."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
    }

    @Test func theDescriptionNamesABudgetFailure() throws {
        let id: ExperienceID = try #require(FacetedForgeExperience.id)
        let shell: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        // Neutral cuts for the whole budget, the last one failing the play by budget.
        var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: 1)
        let budget: Int = core.play.level.budget
        let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.neutralCuts(level: 1, count: budget,
                                                                                    endsInFailure: true)
        #expect(actions.count == budget, "level 1 has \(budget) neutral cuts")
        for action in actions {
            let issued = FacetedForgeTest.control(action)
            let result: ActionResult = core.apply(ExperienceAction(control: issued.control, values: issued.values,
                                                                   step: 0))
            #expect(result == .accepted, "\(issued.control) \(issued.values): \(result.code)")
        }
        #expect(core.play.stage == .failed)
        #expect(core.play.failure == .budget)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The cut budget ran out before the pieces matched the target."), "\(text)")
        #expect(text.contains("Faceted Forge level 1."), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        print("faceted-forge budget failure description: \(text)")
    }

    /// A sliver failure (found by `FacetedForgeTest.sliverFailure`) names its piece and cut in the description, and the
    /// frame shows the sliver-cross colour near the failed piece's opened centre.
    @Test func aSliverFailureNamesItsPieceAndCutAndIsMarked() async throws {
        let found = try #require(try FacetedForgeTest.sliverFailure(), "a cut of some level leaves a sliver")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: UInt64(found.level - 1))
        for action in found.actions {
            let issued = FacetedForgeTest.control(action)
            #expect(shell.handle(control: issued.control, values: issued.values) == .accepted,
                    "\(issued.control) \(issued.values)")
        }
        let core: FacetedForgeExperienceCore = try FacetedForgeTest.core(shell)
        #expect(core.play.stage == .failed)
        #expect(core.play.failure == .sliver(found.piece, found.cut))
        let text: String = shell.presenter.describe(core)
        let named: String = "Cut \(found.cut + 1) left piece \(found.piece + 1) thinner than the sliver limit."
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // Level-2 draws no glow shells, so nothing additive lies over the cross; the opening is full at time 1. Since
        // feature 376 the cross fades in over 0.15 s (the lights), so the frames are taken once it has settled.
        FacetedForgeTest.pin(session, shell, tier: 2)
        let reduceMotion: Bool = shell.presenter.reduceMotion
        let times: [Double] = [1, 2]
        for time in times {
            let rgba: [UInt8] = try FacetedForgeTest.still(session, time: time)
            let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.failure == .sliver(found.piece, found.cut))
            #expect(snapshot.failurePiece == found.piece)
            #expect(FacetedForgeTest.sliverNear(rgba, snapshot: snapshot, reduceMotion: reduceMotion),
                    "level \(found.level) time \(time): the sliver cross is drawn over piece \(found.piece + 1)")
            FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: reduceMotion, expectCutFace: true,
                                        "sliver failure time \(time)")
        }
        session.qualityPin = 0
        print("faceted-forge sliver failure: level \(found.level), \(found.actions.count) cuts, \(named)")
    }
}
#endif
