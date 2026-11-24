// MoonlitMechanismExperienceIdentityTests — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005, 007, 008). The
// experience's id is the catalog id, the factory builds a shell around the presenter with the accessibility settings
// passed through, the controls are the eight declared actions in order, the registration facts hold (100 certified
// levels, schema 2, the tiers level-0 … level-2), and the presenter holds no GPU object and no snapshot before setup.
// iOS only, as the target.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct MoonlitMechanismExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(MoonlitMechanismExperience.id?.rawValue == "r02-g14.moonlit-mechanism")
        #expect(MoonlitMechanismExperienceCore.experienceID == "r02-g14.moonlit-mechanism")
    }

    /// The registration's content facts: 100 certified levels, schema 1, three tiers.
    @Test func theRegistrationFactsHold() {
        #expect(MoonlitMechanismExperienceCore.levelNumbers == 1...100)
        #expect(MoonlitMechanismExperienceCore.certifiedCandidates.count == 100)
        #expect(MoonlitMechanismExperienceCore.schemaVersion == 2)
        var names: [String] = []
        for level in MoonlitMechanismExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(MoonlitMechanismExperienceCore.qualityTiers == 3)
    }

    /// The controls are the declared actions in order.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        for control in MoonlitMechanismExperienceCore.controls { ids.append(control.id) }
        #expect(ids == MoonlitMechanismExperienceCore.actionIDs)
        #expect(ids == ["handle.turn", "gear.reseat", "lamp.step", "machine.run", "play.undo", "play.redo",
                        "level.next", "frame.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss"])
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(MoonlitMechanismExperience.id)
        let shell: ExperienceShell<MoonlitMechanismPresenter> =
            MoonlitMechanismExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<MoonlitMechanismPresenter> = MoonlitMechanismExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
    }
}
#endif
