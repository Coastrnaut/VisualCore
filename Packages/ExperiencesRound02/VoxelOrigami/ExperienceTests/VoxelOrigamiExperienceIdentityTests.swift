// VoxelOrigamiExperienceIdentityTests — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005, 007, 008). The
// experience's id is the catalog id, the factory builds a shell around the presenter with the accessibility settings
// passed through, the controls are the five declared actions in order, the registration facts hold (100 certified
// levels, schema 2, the tiers level-0 … level-2), and the presenter holds no GPU object and no snapshot before setup.
// iOS only, as the target.
#if os(iOS)
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VoxelOrigamiCore

@MainActor
@Suite struct VoxelOrigamiExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(VoxelOrigamiExperience.id?.rawValue == "r02-g15.voxel-origami")
        #expect(VoxelOrigamiExperienceCore.experienceID == "r02-g15.voxel-origami")
    }

    /// The registration's content facts: 100 certified levels, schema 2, three tiers.
    @Test func theRegistrationFactsHold() {
        #expect(VoxelOrigamiExperienceCore.levelNumbers == 1...100)
        #expect(VoxelOrigamiExperienceCore.certifiedCandidates.count == 100)
        #expect(VoxelOrigamiExperienceCore.schemaVersion == 2)
        var names: [String] = []
        for level in VoxelOrigamiExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(VoxelOrigamiExperienceCore.qualityTiers == 3)
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in VoxelOrigamiExperienceCore.controls { ids.append(control.id) }
        #expect(ids == VoxelOrigamiExperienceCore.actionIDs)
        #expect(ids == ["hinge.turn", "play.undo", "play.redo", "level.next", "hinge.choose", "level.select",
                        "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"])
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(VoxelOrigamiExperience.id)
        let shell: ExperienceShell<VoxelOrigamiPresenter> =
            VoxelOrigamiExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.voxelBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        let plain: ExperienceShell<VoxelOrigamiPresenter> = VoxelOrigamiExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
    }
}
#endif
