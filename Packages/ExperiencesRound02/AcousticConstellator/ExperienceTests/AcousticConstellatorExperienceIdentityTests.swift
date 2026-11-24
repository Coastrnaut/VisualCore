// AcousticConstellatorExperienceIdentityTests — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-003, 004, 005,
// 007, 008, 009; clarifications Q2, Q3, Q4, Q5). The experience's id is the catalog id, the factory (with and without
// storage) builds a shell around the presenter (with the accessibility settings passed through), the controls are the
// declared actions in order with their arities and ranges (twelve since feature 425), the registration facts hold (100
// certified levels, schema 2 since feature 425, the tiers level-0 … level-2, the palette's five hex strings), the
// quality profile's levels equal the Core's `qualityTiers` and the presenter's, the palette is clarification Q3's
// colours, the frame probes are none before a frame and the two dark sky corners after one (declared, as the round-two
// X gates require), the description names the level and the progress, and the mirror follows the description with the panel's choice opening on star 0 and
// partner 1, clamped to the level's stars, and returning to star 0 and partner 1 on a new level (since feature 425
// (R02-G13-05) T-R02G1305-005 the next level opens only after a win: `level.next` before it is refused
// `r02-g13.locked`). iOS only, as the target.
#if os(iOS)
import Foundation
import AcousticConstellatorCore
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct AcousticConstellatorExperienceIdentityTests {
    /// The experience's id is the catalog id.
    @Test func theIdIsTheCatalogId() {
        #expect(AcousticConstellatorExperience.id?.rawValue == "r02-g13.acoustic-constellator")
        #expect(AcousticConstellatorExperienceCore.experienceID == "r02-g13.acoustic-constellator")
        #expect(AcousticConstellatorTest.id.rawValue == AcousticConstellatorExperienceCore.experienceID)
    }

    /// The registration's content facts: 100 certified levels, schema 2 (since feature 425), three tiers, five palette
    /// hex strings.
    @Test func theRegistrationFactsHold() {
        #expect(AcousticConstellatorExperienceCore.levelNumbers == 1...100)
        #expect(AcousticConstellatorExperienceCore.certifiedCandidates.count == 100)
        #expect(AcousticConstellatorExperienceCore.schemaVersion == 2)   // schema 2 since feature 425
        #expect(AcousticConstellatorExperienceCore.levelNumber(forSeed: 0) == 1)
        #expect(AcousticConstellatorExperienceCore.levelNumber(forSeed: 199) == 100)
        #expect(AcousticConstellatorPalette.hex == ["#05060F", "#F4F1E8", "#3FD6C6", "#8A5A9C", "#B8C0D0"])
        var names: [String] = []
        for level in AcousticConstellatorExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
    }

    /// The factory builds a shell around the presenter and passes the accessibility settings through.
    @Test func theFactoryBuildsAShellAroundThePresenter() throws {
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let shell: ExperienceShell<AcousticConstellatorPresenter> =
            AcousticConstellatorExperience.make(id: id, reduceMotion: true, reduceFlashing: true)
        #expect(shell.id == id)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.reduceFlashing)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(shell.presenter.scene.reducedFlash)
        #expect(shell.presenter.scene.glowLimit == AcousticConstellatorShaders.glowGainCap)
        #expect(shell.presenter.tierLog.isEmpty)
        #expect(shell.presenter.lastSnapshot == nil)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(shell.presenter.scene.liveObjectCount == 0, "no GPU object before setup")
        let plain: ExperienceShell<AcousticConstellatorPresenter> = AcousticConstellatorExperience.make(id: id)
        #expect(!plain.presenter.reduceMotion && !plain.presenter.reduceFlashing)
        #expect(!plain.presenter.scene.reduceMotion)
        #expect(!plain.presenter.scene.reducedFlash)
        #expect(plain.presenter.scene.glowLimit == AcousticConstellatorShaders.standardGlowLimit)
    }

    /// The registry's factory, `make(id:storage:reduceMotion:reduceFlashing:)`, builds the experience with the
    /// presenter's quality levels and passes the settings through.
    @Test func theRegistryFactoryBuildsTheExperience() throws {
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let name: String = "acoustic-constellator-identity-tests"
        let root: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let experience: any Experience = AcousticConstellatorExperience.make(id: id, storage: storage,
                                                                             reduceMotion: true, reduceFlashing: false)
        #expect(experience.id == id)
        #expect(experience.qualityProfile.count == AcousticConstellatorExperienceCore.qualityTiers)
        let shell = try #require(experience as? ExperienceShell<AcousticConstellatorPresenter>)
        #expect(shell.presenter.reduceMotion)
        #expect(!shell.presenter.reduceFlashing)
        #expect(experience.frameProbes.isEmpty, "no probes before a frame")
    }

    /// The controls are the declared actions in order: the seven of feature 423 (`link.add` and `link.remove` [star
    /// 0 … 7, star 0 … 7], `star.nudge` [star 0 … 7, step −1 … 1], then four without values), then (feature 425)
    /// `level.select` [1 … 100], `mode.daily` [year 1 … 9999, month 1 … 12, day 1 … 31], `mode.practice`,
    /// `mode.campaign` and `tutorial.dismiss`.
    @Test func theControlsAreTheDeclaredActions() {
        var ids: [String] = []
        var arities: [Int] = []
        for control in AcousticConstellatorExperienceCore.controls {
            ids.append(control.id)
            arities.append(control.ranges.count)
        }
        #expect(ids == ["link.add", "link.remove", "star.nudge", "constellation.listen", "play.undo", "play.redo",
                        "level.next", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                        "tutorial.dismiss"])
        #expect(ids == AcousticConstellatorExperienceCore.actionIDs)
        #expect(arities == [2, 2, 2, 0, 0, 0, 0, 1, 3, 0, 0, 0])
        let controls: [ExperienceControl] = AcousticConstellatorExperienceCore.controls
        for index in 0..<2 where controls[index].ranges.count == 2 {
            #expect(controls[index].ranges[0] == 0.0...7.0, "\(controls[index].id) first star")
            #expect(controls[index].ranges[1] == 0.0...7.0, "\(controls[index].id) second star")
        }
        let nudge: ExperienceControl = controls[2]
        #expect(nudge.ranges.count == 2)
        if nudge.ranges.count == 2 {
            #expect(nudge.ranges[0] == 0.0...7.0, "star range \(nudge.ranges[0])")
            #expect(nudge.ranges[1] == -1.0...1.0, "step range \(nudge.ranges[1])")
        }
        let select: ExperienceControl = controls[7]
        #expect(select.ranges == [1.0...100.0], "level range \(select.ranges)")
        let daily: ExperienceControl = controls[8]
        #expect(daily.ranges == [1.0...9999.0, 1.0...12.0, 1.0...31.0], "date ranges \(daily.ranges)")
    }

    /// The quality profile names level-0 … level-2 and equals the presenter's (the X follow-through declares the same
    /// count).
    @Test func theQualityLevelsEqualTheCoresTiers() throws {
        var names: [String] = []
        for level in AcousticConstellatorExperienceCore.qualityProfile.levels { names.append(level.name) }
        #expect(AcousticConstellatorExperienceCore.qualityTiers == 3)
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let shell: ExperienceShell<AcousticConstellatorPresenter> = AcousticConstellatorExperience.make(id: id)
        var presenterNames: [String] = []
        for level in shell.qualityProfile.levels { presenterNames.append(level.name) }
        #expect(presenterNames == names)
        #expect(shell.qualityProfile.count == AcousticConstellatorExperienceCore.qualityTiers)
    }

    /// The palette is clarification Q3's colours.
    @Test func thePaletteIsTheClarificationsColours() {
        typealias P = AcousticConstellatorPalette
        #expect(P.sky == SIMD3<Double>(5.0 / 255, 6.0 / 255, 15.0 / 255))
        #expect(P.star == SIMD3<Double>(244.0 / 255, 241.0 / 255, 232.0 / 255))
        #expect(P.hand == SIMD3<Double>(244.0 / 255, 241.0 / 255, 232.0 / 255))
        #expect(P.silver == SIMD3<Double>(184.0 / 255, 192.0 / 255, 208.0 / 255))
        #expect(P.teal == SIMD3<Double>(63.0 / 255, 214.0 / 255, 198.0 / 255))
        #expect(P.guide == SIMD3<Double>(138.0 / 255, 90.0 / 255, 156.0 / 255))
        #expect(P.broken == SIMD3<Double>(255.0 / 255, 107.0 / 255, 74.0 / 255))
        #expect(P.coherenceLit == SIMD3<Double>(63.0 / 255, 214.0 / 255, 198.0 / 255))
        #expect(P.coherenceUnlit == SIMD3<Double>(42.0 / 255, 36.0 / 255, 51.0 / 255))
        #expect(P.thresholdMark == SIMD3<Double>(244.0 / 255, 241.0 / 255, 232.0 / 255))
        #expect(P.holdLit == SIMD3<Double>(63.0 / 255, 214.0 / 255, 198.0 / 255))
        #expect(P.holdUnlit == SIMD3<Double>(58.0 / 255, 51.0 / 255, 72.0 / 255))
        #expect(P.movesLit == SIMD3<Double>(184.0 / 255, 192.0 / 255, 208.0 / 255))
        #expect(P.movesUnlit == SIMD3<Double>(42.0 / 255, 36.0 / 255, 51.0 / 255))
        #expect(P.shell == SIMD3<Double>(111.0 / 255, 224.0 / 255, 216.0 / 255))
        #expect(P.glow == SIMD3<Double>(143.0 / 255, 244.0 / 255, 234.0 / 255))
    }

    /// No probes before a frame; two dark sky corners after a real frame, and their pixels are the sky.
    @Test func theProbesAreTheSkyCornersAfterARealFrame() async throws {
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let bare: ExperienceShell<AcousticConstellatorPresenter> = AcousticConstellatorExperience.make(id: id)
        let opening: AcousticConstellatorExperienceCore = try AcousticConstellatorExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try AcousticConstellatorTest.core(shell))
        #expect(probes.count == 2, "two sky corners are declared")
        var names: Set<String> = []
        for probe in probes {
            names.insert(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names.count == probes.count, "the probe names are distinct")
        #expect(!shell.frameProbes.isEmpty, "the shell exposes the presenter's probes")
        #expect(shell.presenter.scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        for probe in probes {
            let got = AcousticConstellatorTest.pixelAtFraction(rgba, probe.x, probe.y,
                                                               width: AcousticConstellatorTest.width,
                                                               height: AcousticConstellatorTest.height)
            let distance: Double = AcousticConstellatorTest.channelDistance(got.colour, AcousticConstellatorPalette.sky)
            #expect(distance <= AcousticConstellatorTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }

    /// The description names the level and the progress; the mirror follows it.
    @Test func theDescriptionNamesTheLevelAndTheProgress() throws {
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let shell: ExperienceShell<AcousticConstellatorPresenter> = AcousticConstellatorExperience.make(id: id)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorExperienceCore.opening(number: 44)
        let level: AcousticConstellatorLevel = core.play.level
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("Acoustic Constellator level 44."), "\(text)")
        #expect(text.contains(core.play.progressDescription), "\(text)")
        let mirror: AcousticConstellatorMirror = shell.presenter.mirror
        #expect(mirror.levelNumber == 44)
        #expect(mirror.actionsLeft == level.budget)
        #expect(mirror.budget == level.budget)
        #expect(mirror.status == "Ready")
        #expect(mirror.failureText == nil)
        // After the certified arrangement the description counts the actions spent.
        let arranged: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.arranged(44)
        let spent: Int = try AcousticConstellatorTest.certifiedArrangement(44).count
        let after: String = shell.presenter.describe(arranged)
        #expect(after.contains(arranged.play.progressDescription), "\(after)")
        #expect(shell.presenter.mirror.status == "Playing")
        #expect(shell.presenter.mirror.actionsLeft == level.budget - spent)
    }

    /// The panel's choice opens on star 0 and partner 1, is clamped to the level's stars, and returns to star 0 and
    /// partner 1 on a new level.
    @Test func theMirrorChoiceOpensOnStarZeroAndPartnerOne() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 23)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        let mirror: AcousticConstellatorMirror = shell.presenter.mirror
        #expect(mirror.star == AcousticConstellatorExperienceCore.openingStar, "chosen star \(mirror.star)")
        #expect(mirror.partner == AcousticConstellatorExperienceCore.openingPartner, "chosen partner \(mirror.partner)")
        let stars: Int = core.play.level.stars.count
        mirror.stepStar(-1)
        #expect(mirror.star == 0, "clamped at the first star")
        mirror.stepStar(stars + 5)
        #expect(mirror.star == stars - 1, "clamped at the last star")
        mirror.stepPartner(-20)
        #expect(mirror.partner >= 0 && mirror.partner < stars, "partner \(mirror.partner) within the stars")
        mirror.stepPartner(20)
        #expect(mirror.partner >= 0 && mirror.partner < stars, "partner \(mirror.partner) within the stars")
        // The choice is presentation state: moving it changed nothing in the kernel.
        let before: String = try AcousticConstellatorTest.digest(shell)
        try AcousticConstellatorTest.draw(session)
        #expect(try AcousticConstellatorTest.digest(shell) == before)
        #expect(mirror.star == stars - 1, "a frame of the same level keeps the choice")
        // The next level chooses its star 0 and partner 1 (since feature 425 level 25 opens with level 24's win; before
        // it `level.next` is refused `r02-g13.locked`).
        #expect(shell.handle(control: "level.next")
            == .rejected(.rule(code: AcousticConstellatorExperienceRule.locked)))
        AcousticConstellatorTest.issue(shell, try AcousticConstellatorTest.certifiedActions(24))
        #expect(try AcousticConstellatorTest.core(shell).play.stage == .won)
        #expect(shell.handle(control: "level.next") == .accepted)
        try AcousticConstellatorTest.draw(session)
        let next: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        #expect(next.levelNumber == 25)
        #expect(mirror.star == AcousticConstellatorExperienceCore.openingStar)
        #expect(mirror.partner == AcousticConstellatorExperienceCore.openingPartner)
    }
}
#endif
