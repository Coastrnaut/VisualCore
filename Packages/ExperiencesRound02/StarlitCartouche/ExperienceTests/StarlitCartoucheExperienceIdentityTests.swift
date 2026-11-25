// StarlitCartoucheExperienceIdentityTests — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005, 007, 008). The
// experience's id is the catalog id, the factory builds a shell around the presenter with the accessibility settings
// passed through, the controls are the ten declared actions in order (feature 455), the registration facts hold (100
// certified levels, schema 1, the tiers level-0 … level-2), the presenter's quality levels equal the Core's
// `qualityTiers`, the presenter holds no GPU object and no snapshot before setup, and it declares its two frame probes
// once a frame was drawn. iOS only, as the target.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct StarlitCartoucheExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(StarlitCartoucheExperience.id?.rawValue == "r02-g16.starlit-cartouche")
        #expect(StarlitCartoucheExperienceCore.experienceID == "r02-g16.starlit-cartouche")
    }

    /// The registration's content facts: 100 certified levels, schema 2 (feature 455), three tiers.
    @Test func theRegistrationFactsHold() {
        #expect(StarlitCartoucheExperienceCore.levelNumbers == 1...100)
        #expect(StarlitCartoucheExperienceCore.certifiedCandidates.count == 100)
        #expect(StarlitCartoucheExperienceCore.schemaVersion == 2)
        var names: [String] = []
        for level in StarlitCartoucheExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(StarlitCartoucheExperienceCore.qualityTiers == 3)
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in StarlitCartoucheExperienceCore.controls { ids.append(control.id) }
        #expect(ids == StarlitCartoucheExperienceCore.actionIDs)
        #expect(ids == ["route.fly", "play.undo", "play.redo", "level.next", "route.choose", "level.select",
                        "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers`, named as the tiers.
    @Test func thePresentersQualityLevelsEqualTheCoresTiers() throws {
        let id: ExperienceID = try #require(StarlitCartoucheExperience.id)
        let shell: ExperienceShell<StarlitCartouchePresenter> = StarlitCartoucheExperience.make(id: id)
        #expect(shell.qualityProfile.count == StarlitCartoucheExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in StarlitCartoucheTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(StarlitCartoucheExperience.id)
        let shell: ExperienceShell<StarlitCartouchePresenter> =
            StarlitCartoucheExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.lastGlide == 1)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.chartBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        #expect(shell.presenter.scene.lastFirmamentAngle == 0)
        let plain: ExperienceShell<StarlitCartouchePresenter> = StarlitCartoucheExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(StarlitCartouchePresenter.glideSeconds == 0.5)
    }

    /// No frame probe before a frame; after one, the two firmament corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(StarlitCartoucheExperience.id)
        let fresh: ExperienceShell<StarlitCartouchePresenter> = StarlitCartoucheExperience.make(id: id)
        let opening: StarlitCartoucheExperienceCore = try StarlitCartoucheExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try StarlitCartoucheTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue, "\(probe.name)")
        }
        #expect(names == ["firmament-top-left", "firmament-bottom-right"])
        #expect(shell.frameProbes == probes, "the shell hands out the presenter's probes")
    }
}
#endif
