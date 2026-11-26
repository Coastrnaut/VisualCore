// ApsidesWorkshopExperienceIdentityTests — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-005, 007, 008, 009).
// The experience's id is the catalog id; the registry's factory (`make(id:storage:reduceMotion:reduceFlashing:)`, which
// does not depend on the registration) builds a shell around the presenter with the accessibility settings passed
// through, as does the tests' factory; the controls are the declared actions in order (seven, twelve since feature 475,
// sixteen since 477); the registration facts hold (100 certified levels, schema 3 since feature 477, the tiers level-0
// … level-2, the palette); the presenter's quality levels equal the Core's `qualityTiers`; the presenter holds no GPU
// object and no snapshot before setup; and it declares its two frame probes (the backdrop corners) once a frame was
// drawn. iOS only, as the target.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ApsidesWorkshopExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(ApsidesWorkshopExperience.id?.rawValue == "r02-g18.apsides-workshop")
        #expect(ApsidesWorkshopExperienceCore.experienceID == "r02-g18.apsides-workshop")
    }

    /// The registration's content facts: 100 certified levels, schema 2, three tiers, the five-colour palette.
    @Test func theRegistrationFactsHold() {
        #expect(ApsidesWorkshopExperienceCore.levelNumbers == 1...100)
        #expect(ApsidesWorkshopExperienceCore.certifiedCandidates.count == 100)
        // Schema 3 since feature 477 (R02-G18-07) T-R02G1807-003: results with traces and the sound choice.
        #expect(ApsidesWorkshopExperienceCore.schemaVersion == 3)
        var names: [String] = []
        for level in ApsidesWorkshopExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(ApsidesWorkshopExperienceCore.qualityTiers == 3)
        #expect(ApsidesWorkshopPalette.hex == ["#0A0B1F", "#E8F1FF", "#C2456E", "#8C93B8", "#1A1438"])
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in ApsidesWorkshopExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ApsidesWorkshopExperienceCore.actionIDs)
        #expect(ids == ["orbit.periapsis", "orbit.size", "orbit.play", "play.undo", "play.redo", "level.next",
                        "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss", "replay.start", "replay.step", "replay.stop", "settings.sound"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers`, named as the tiers.
    @Test func thePresentersQualityLevelsEqualTheCoresTiers() throws {
        let id: ExperienceID = try #require(ApsidesWorkshopExperience.id)
        let shell: ExperienceShell<ApsidesWorkshopPresenter> = ApsidesWorkshopExperience.make(id: id)
        #expect(shell.qualityProfile.count == ApsidesWorkshopExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == ApsidesWorkshopExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in ApsidesWorkshopTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(ApsidesWorkshopExperience.id)
        let name: String = "apsides-workshop-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = ApsidesWorkshopExperience.make(id: id, storage: storage,
                                                                        reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == ApsidesWorkshopExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<ApsidesWorkshopPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through; nothing
    /// is built or drawn before setup.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(ApsidesWorkshopExperience.id)
        let shell: ExperienceShell<ApsidesWorkshopPresenter> =
            ApsidesWorkshopExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == ApsidesWorkshopShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.compassBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        #expect(shell.presenter.scene.lastPulse == 1)
        let plain: ExperienceShell<ApsidesWorkshopPresenter> = ApsidesWorkshopExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == ApsidesWorkshopShaders.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(ApsidesWorkshopExperience.id)
        let fresh: ExperienceShell<ApsidesWorkshopPresenter> = ApsidesWorkshopExperience.make(id: id)
        let opening: ApsidesWorkshopExperienceCore = try ApsidesWorkshopExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try ApsidesWorkshopTest.core(shell))
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
