// CelestialEclipseLabExperienceIdentityTests — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-005, 007, 008).
// The experience's id is the catalog id; the registry's factory (`make(id:storage:reduceMotion:reduceFlashing:)`,
// which does not depend on the registration) builds a shell around the presenter with the accessibility settings
// passed through, as does the tests' factory; the controls are the seven declared actions in order; the registration
// facts hold (100 certified levels, schema 2 since feature 465, the tiers level-0 … level-2); the presenter's quality levels equal the
// Core's `qualityTiers`; the presenter holds no GPU object and no snapshot before setup; and it declares its two frame
// probes (the backdrop corners) once a frame was drawn. iOS only, as the target.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct CelestialEclipseLabExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(CelestialEclipseLabExperience.id?.rawValue == "r02-g17.celestial-eclipse-lab")
        #expect(CelestialEclipseLabExperienceCore.experienceID == "r02-g17.celestial-eclipse-lab")
    }

    /// The registration's content facts: 100 certified levels, schema 3 (feature 467), three tiers.
    @Test func theRegistrationFactsHold() {
        #expect(CelestialEclipseLabExperienceCore.levelNumbers == 1...100)
        #expect(CelestialEclipseLabExperienceCore.certifiedCandidates.count == 100)
        #expect(CelestialEclipseLabExperienceCore.schemaVersion == 3)
        var names: [String] = []
        for level in CelestialEclipseLabExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(CelestialEclipseLabExperienceCore.qualityTiers == 3)
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in CelestialEclipseLabExperienceCore.controls { ids.append(control.id) }
        #expect(ids == CelestialEclipseLabExperienceCore.actionIDs)
        #expect(ids == ["orbit.phase", "clock.run", "play.undo", "play.redo", "level.next", "orbit.choose",
                        "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss", "replay.start", "replay.step", "replay.stop", "settings.sound"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers`, named as the tiers.
    @Test func thePresentersQualityLevelsEqualTheCoresTiers() throws {
        let id: ExperienceID = try #require(CelestialEclipseLabExperience.id)
        let shell: ExperienceShell<CelestialEclipseLabPresenter> = CelestialEclipseLabExperience.make(id: id)
        #expect(shell.qualityProfile.count == CelestialEclipseLabExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == CelestialEclipseLabExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in CelestialEclipseLabTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(CelestialEclipseLabExperience.id)
        let name: String = "celestial-eclipse-lab-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = CelestialEclipseLabExperience.make(id: id, storage: storage,
                                                                            reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == CelestialEclipseLabExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<CelestialEclipseLabPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(CelestialEclipseLabExperience.id)
        let shell: ExperienceShell<CelestialEclipseLabPresenter> =
            CelestialEclipseLabExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == CelestialEclipseLabShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.skyBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        #expect(shell.presenter.scene.lastPulse == 1)
        let plain: ExperienceShell<CelestialEclipseLabPresenter> = CelestialEclipseLabExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == CelestialEclipseLabShaders.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(CelestialEclipseLabExperience.id)
        let fresh: ExperienceShell<CelestialEclipseLabPresenter> = CelestialEclipseLabExperience.make(id: id)
        let opening: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try CelestialEclipseLabTest.core(shell))
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
