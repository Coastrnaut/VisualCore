// AmethystEscapeExperienceIdentityTests — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-004, 005, 008;
// clarifications Q2, Q3, Q5). The experience's id is the catalog id, the factory (with and without storage) builds a
// shell around the presenter (with the accessibility settings passed through), the controls are the fourteen declared
// actions in order, the quality profile's levels are the catalog tiers level-0 … level-2 and equal the presenter's,
// the palette is the clarification's colours and the catalog's five hex strings, and the description names the level,
// the moves, the pearl, the exit gap and every shell, a won play's escape and a failure with its reason. iOS only, as
// the target.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct AmethystEscapeExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(AmethystEscapeExperience.id?.rawValue == "r02-g07.amethyst-escape")
        #expect(AmethystEscapeExperienceCore.experienceID == "r02-g07.amethyst-escape")
    }

    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> =
            AmethystEscapeExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == AmethystEscapeShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        let plain: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == AmethystEscapeShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let name: String = "amethyst-escape-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = AmethystEscapeExperience.make(id: id, storage: storage, reduceMotion: true,
                                                                       reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == AmethystEscapeExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<AmethystEscapePresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The five play actions (feature 363), the five progression actions (feature 365) and the four replay and sound
    /// actions (feature 367), in order.
    @Test func theControlsAreTheFourteenActions() {
        var ids: [String] = []
        for control in AmethystEscapeExperienceCore.controls { ids.append(control.id) }
        #expect(ids == ["shell.rotate", "pearl.advance", "play.undo", "play.redo", "level.next", "level.select",
                        "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss", "replay.start",
                        "replay.step", "replay.stop", "settings.sound"])
        #expect(ids == AmethystEscapeExperienceCore.actionIDs)
    }

    @Test func theQualityProfileNamesTheCatalogLevels() throws {
        var names: [String] = []
        for level in AmethystEscapeExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(AmethystEscapeExperienceCore.qualityTiers == 3)
        // The presenter's quality levels are the Core's tiers (the X follow-through declares the same count).
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
    }

    @Test func thePaletteIsTheClarificationsColours() {
        #expect(AmethystEscapePalette.backdrop == SIMD3<Double>(10.0 / 255, 6.0 / 255, 20.0 / 255))
        #expect(AmethystEscapePalette.amethyst == SIMD3<Double>(142.0 / 255, 79.0 / 255, 216.0 / 255))
        #expect(AmethystEscapePalette.platinum == SIMD3<Double>(214.0 / 255, 220.0 / 255, 230.0 / 255))
        #expect(AmethystEscapePalette.pearl == SIMD3<Double>(246.0 / 255, 242.0 / 255, 255.0 / 255))
        #expect(AmethystEscapePalette.exit == SIMD3<Double>(184.0 / 255, 240.0 / 255, 255.0 / 255))
        #expect(AmethystEscapePalette.hex == ["#0A0614", "#8E4FD8", "#D6DCE6", "#F6F2FF", "#B8F0FF"])
    }

    @Test func theDescriptionNamesTheLevelAndShells() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        let core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 21)
        let text: String = shell.presenter.describe(core)
        let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0)
        let level: AmethystEscapeLevel = core.play.level
        #expect(text.contains("Amethyst Escape level 21."), "\(text)")
        #expect(text.contains("0 of \(snapshot.budget) moves spent."), "\(text)")
        #expect(text.contains("The exit gap is at \(level.sectorName(snapshot.exitGap))."), "\(text)")
        #expect(text.contains("The pearl is in \(level.shellName(snapshot.pearl.shell))"), "\(text)")
        for index in level.shells.indices {
            #expect(text.lowercased().contains(level.shellName(index).lowercased() + ":"), "\(text)")
        }
        // The mirror follows the description.
        #expect(shell.presenter.mirror.levelNumber == 21)
        #expect(shell.presenter.mirror.shellNames.count == snapshot.shells.count)
        #expect(shell.presenter.mirror.budget == snapshot.budget)
        #expect(shell.presenter.mirror.status == "Ready")
    }

    @Test func theDescriptionNamesAWin() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty)
        for action in actions {
            let issued = AmethystEscapeTest.control(action)
            let result: ActionResult = core.apply(ExperienceAction(control: issued.control, values: issued.values,
                                                                   step: 0))
            #expect(result == .accepted, "\(issued.control) \(issued.values): \(result.code)")
        }
        #expect(core.play.stage == .won)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The pearl escaped through the exit gap."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.pearlLabel == "The pearl is outside the crystal")
    }

    @Test func theDescriptionNamesAFailure() throws {
        let id: ExperienceID = try #require(AmethystEscapeExperience.id)
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        // Turning the innermost shell + and − alternately never wins, so the last move of the budget fails the play.
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let budget: Int = core.snapshot(time: 0).budget
        for move in 0..<budget {
            let step: Double = move % 2 == 0 ? 1 : -1
            let result: ActionResult = core.apply(ExperienceAction(control: "shell.rotate", values: [0, step],
                                                                   step: 0))
            #expect(result == .accepted, "move \(move): \(result.code)")
        }
        #expect(core.play.stage == .failed)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The move budget ran out before the pearl escaped."), "\(text)")
        #expect(text.contains("Amethyst Escape level 1."), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        print("amethyst-escape failure description: \(text)")
    }

    /// A seeded search over the certified levels (seed 2_363) for a play whose advance drops the pearl into a blocked
    /// wedge; nil when none is found within the bounds.
    static func wedgeFailure() throws -> (level: Int, actions: [(String, [Double])], shell: Int, sector: Int)? {
        var state: UInt64 = 2_363
        func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
        for level in 1...100 {
            for _ in 0..<20 {
                var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: level)
                var actions: [(String, [Double])] = []
                let shells: Int = core.play.level.shells.count
                for _ in 0..<core.play.level.budget {
                    let action: (String, [Double]) = next(3) == 0
                        ? ("pearl.advance", [])
                        : ("shell.rotate", [Double(next(shells)), next(2) == 0 ? -1 : 1])
                    guard core.apply(ExperienceAction(control: action.0, values: action.1, step: 0)) == .accepted
                    else { continue }
                    actions.append(action)
                    if case .wedge(let shell, let sector) = core.play.failure {
                        return (level, actions, shell, sector)
                    }
                    if core.play.stage != .playing { break }
                }
            }
        }
        return nil
    }

    /// T-R02G0703-014: a pearl that falls into a blocked wedge fails the play; the description names that wedge's
    /// shell and sector, and the frame tints that wedge amber.
    @Test func aWedgeFailureNamesItsWedgeAndTintsItAmber() async throws {
        let found = try #require(try Self.wedgeFailure(), "a seeded play drops the pearl into a blocked wedge")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: UInt64(found.level - 1))
        for action in found.actions {
            #expect(shell.handle(control: action.0, values: action.1) == .accepted, "\(action.0) \(action.1)")
        }
        let core: AmethystEscapeExperienceCore = try AmethystEscapeTest.core(shell)
        #expect(core.play.stage == .failed && core.play.failure == .wedge(found.shell, found.sector))
        let level: AmethystEscapeLevel = core.play.level
        let text: String = shell.presenter.describe(core)
        let named: String = "The pearl fell into the blocked wedge of \(level.shellName(found.shell)), "
            + "\(level.sectorName(found.sector))."
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "))
        // The failed wedge's amber fades in (feature 366: 0.15 s, eased lights); a still at 0 s, then one at 1 s, once
        // the fade has finished.
        _ = try AmethystEscapeTest.still(session, time: 0)
        let rgba: [UInt8] = try AmethystEscapeTest.still(session, time: 1)
        let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == .wedge(found.shell, found.sector))
        // The failure's sector is absolute; the wedge's own sector is (sector − offset) mod sectors.
        let offset: Int = snapshot.shells[found.shell].offset
        let own: Int = ((found.sector - offset) % snapshot.sectors + snapshot.sectors) % snapshot.sectors
        #expect(AmethystEscapeTest.amberNear(rgba, snapshot: snapshot, shell: found.shell, sector: own),
                "level \(found.level): the failed wedge is amber")
        print("amethyst-escape wedge failure: level \(found.level), \(found.actions.count) actions, \(named)")
    }
}
#endif
