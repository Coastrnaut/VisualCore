// MicroscopicAuroraExperienceIdentityTests — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-005, 007, 008,
// 009). The experience's id is the catalog id; the registry's factory (`make(id:storage:reduceMotion:reduceFlashing:)`,
// which does not depend on the registration) builds a shell around the presenter with the accessibility settings
// passed through, as does the tests' factory; the controls are the seven declared actions in order; the registration
// facts hold (100 certified levels, schema 2, the tiers level-0 … level-2, the palette); the presenter's quality
// levels equal the Core's `qualityTiers`; the presenter holds no GPU object and no snapshot before setup; and it
// declares its two frame probes (the backdrop corners) once a frame was drawn. iOS only, as the target.
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct MicroscopicAuroraExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(MicroscopicAuroraExperience.id?.rawValue == "r02-g19.microscopic-aurora")
        #expect(MicroscopicAuroraExperienceCore.experienceID == "r02-g19.microscopic-aurora")
    }

    /// The registration's content facts: 100 certified levels, schema 2 (feature 485), three tiers, the five-colour palette.
    @Test func theRegistrationFactsHold() {
        #expect(MicroscopicAuroraExperienceCore.levelNumbers == 1...100)
        #expect(MicroscopicAuroraExperienceCore.certifiedCandidates.count == 100)
        #expect(MicroscopicAuroraExperienceCore.schemaVersion == 2)
        var names: [String] = []
        for level in MicroscopicAuroraExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(MicroscopicAuroraExperienceCore.qualityTiers == 3)
        #expect(MicroscopicAuroraPalette.hex == ["#04110F", "#8FF0D6", "#B58CE0", "#E9FFF8", "#0E2E2A"])
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in MicroscopicAuroraExperienceCore.controls { ids.append(control.id) }
        #expect(ids == MicroscopicAuroraExperienceCore.actionIDs)
        #expect(ids == ["well.place", "well.remove", "swim.play", "play.undo", "play.redo", "level.next",
                        "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers`, named as the tiers.
    @Test func thePresentersQualityLevelsEqualTheCoresTiers() throws {
        let id: ExperienceID = try #require(MicroscopicAuroraExperience.id)
        let shell: ExperienceShell<MicroscopicAuroraPresenter> = MicroscopicAuroraExperience.make(id: id)
        #expect(shell.qualityProfile.count == MicroscopicAuroraExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == MicroscopicAuroraExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in MicroscopicAuroraTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(MicroscopicAuroraExperience.id)
        let name: String = "microscopic-aurora-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = MicroscopicAuroraExperience.make(id: id, storage: storage,
                                                                          reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == MicroscopicAuroraExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<MicroscopicAuroraPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through; nothing
    /// is built or drawn before setup.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(MicroscopicAuroraExperience.id)
        let shell: ExperienceShell<MicroscopicAuroraPresenter> =
            MicroscopicAuroraExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == MicroscopicAuroraShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.dishBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        let plain: ExperienceShell<MicroscopicAuroraPresenter> = MicroscopicAuroraExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == MicroscopicAuroraShaders.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(MicroscopicAuroraExperience.id)
        let fresh: ExperienceShell<MicroscopicAuroraPresenter> = MicroscopicAuroraExperience.make(id: id)
        let opening: MicroscopicAuroraExperienceCore = try MicroscopicAuroraExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MicroscopicAuroraTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try MicroscopicAuroraTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue, "\(probe.name)")
        }
        #expect(names == ["backdrop-top-left", "backdrop-bottom-right"])
        #expect(shell.frameProbes == probes, "the shell hands out the presenter's probes")
    }
}
#endif
