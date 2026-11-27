// MushroomWeatherExperienceIdentityTests — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-005, 007, 008). The
// experience's id is the catalog id; the registry's factory (`make(id:storage:reduceMotion:reduceFlashing:)`, which
// does not depend on the registration) builds a shell around the presenter with the accessibility settings passed
// through, as does the tests' factory; the controls are the fourteen declared actions in order (nine until feature 495
// T-R02G2005-005 added level.select, mode.daily, mode.practice, mode.campaign and tutorial.dismiss); the registration
// facts hold (100 certified levels, schema 2 since feature 495, the tiers level-0 … level-2, the palette #050A1A,
// #5FD3A0, #F2A93B, #3A6FD8, #12261C); the presenter's quality levels equal the names of the Core's `qualityProfile`;
// the presenter holds no GPU object and no snapshot before setup; Reduce Motion stops the droplets and motes (`motion`
// 0) and Reduce Flashing caps the glow; and the presenter declares its two frame probes (the backdrop corners) once a
// frame was drawn. iOS only, as the target.
#if os(iOS)
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct MushroomWeatherExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(MushroomWeatherExperience.id?.rawValue == "r02-g20.mushroom-weather")
        #expect(MushroomWeatherExperienceCore.experienceID == "r02-g20.mushroom-weather")
    }

    /// The registration's content facts: 100 certified levels, schema 2 (feature 495), three tiers, the five-colour
    /// palette.
    @Test func theRegistrationFactsHold() {
        #expect(MushroomWeatherExperienceCore.levelNumbers == 1...100)
        #expect(MushroomWeatherExperienceCore.certifiedCandidates.count == 100)
        #expect(MushroomWeatherExperienceCore.schemaVersion == 2)
        var names: [String] = []
        for level in MushroomWeatherExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(MushroomWeatherExperienceCore.qualityTiers == 3)
        #expect(MushroomWeatherPalette.hex == ["#050A1A", "#5FD3A0", "#F2A93B", "#3A6FD8", "#12261C"])
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in MushroomWeatherExperienceCore.controls { ids.append(control.id) }
        #expect(ids == MushroomWeatherExperienceCore.actionIDs)
        #expect(ids == ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo", "play.redo",
                        "level.next", "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss"])
    }

    /// The presenter's quality levels are as many as the Core's `qualityTiers` and equal the names of its
    /// `qualityProfile`.
    @Test func thePresentersQualityLevelsEqualTheCoresProfile() throws {
        let id: ExperienceID = try #require(MushroomWeatherExperience.id)
        let shell: ExperienceShell<MushroomWeatherPresenter> = MushroomWeatherExperience.make(id: id)
        #expect(shell.qualityProfile.count == MushroomWeatherExperienceCore.qualityTiers)
        #expect(shell.presenter.qualityLevels.count == MushroomWeatherExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var coreNames: [String] = []
        for level in MushroomWeatherExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        var tierNames: [String] = []
        for tier in MushroomWeatherTier.all { tierNames.append(tier.name) }
        #expect(names == coreNames)
        #expect(shell.presenter.qualityLevels == coreNames)
        #expect(coreNames == tierNames)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience without any
    /// registration, with the Core's quality levels, and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(MushroomWeatherExperience.id)
        let name: String = "mushroom-weather-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = MushroomWeatherExperience.make(id: id, storage: storage,
                                                                        reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == MushroomWeatherExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<MushroomWeatherPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The tests' factory builds a shell around the presenter and passes the accessibility settings through to the
    /// scene (`motion` 0, the glow capped); nothing is built or drawn before setup.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(MushroomWeatherExperience.id)
        let shell: ExperienceShell<MushroomWeatherPresenter> =
            MushroomWeatherExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.motion == 0)
        #expect(shell.presenter.scene.glowLimit == MushroomWeatherShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        #expect(shell.presenter.scene.forestBuilds == 0 && shell.presenter.scene.glowBuilds == 0)
        let plain: ExperienceShell<MushroomWeatherPresenter> = MushroomWeatherExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedMotion && !plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.motion == 1)
        #expect(plain.presenter.scene.glowLimit == MushroomWeatherShaders.standardGlowLimit)
    }

    /// No frame probe before a frame; after one, the two backdrop corners, through the shell as well.
    @Test func theProbesAreDeclaredAfterAFrame() async throws {
        let id: ExperienceID = try #require(MushroomWeatherExperience.id)
        let fresh: ExperienceShell<MushroomWeatherPresenter> = MushroomWeatherExperience.make(id: id)
        let opening: MushroomWeatherExperienceCore = try MushroomWeatherExperienceCore.opening(number: 1)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MushroomWeatherTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try MushroomWeatherTest.core(shell))
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
