// BinaryGardensPreviewTests — feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-008; SC-R02G2104-003, 006;
// clarification Q3; research R4). The preview is the kernel's own judgement: for 200 seeded previews on certified
// levels (plays walked by seeded actions, some to no action left) the preview of a random ring, phase, luminosity or
// tilt change — in range or not, on or off the phase grid, on locked or free controls — equals what the play itself
// does with that action: an accepted action gives the play's arrangement and report (and its verdict), a refused one
// the play's refusal in the play's order (the change rule first, then no action left), and `.action("unchanged")` and
// `.run` give no preview. The snapshot keeps every other field, clearing restores it exactly, a level of another shape
// gives no preview, and previewing never changes the adapter's digest. Seed 2_504; explicit types, plain loops.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensPreviewTests {
    typealias Snapshot = BinaryGardensSceneSnapshot

    /// The seed of feature 504's tests.
    static let seed: UInt64 = 2_504

    /// The sampled catalog levels (numbers 1 … 100), two per difficulty band.
    static let numbers: [Int] = [1, 7, 21, 30, 41, 50, 61, 74, 81, 95]

    /// The sampled certified levels, certified once per process.
    static let levels: [BinaryGardensLevel] = {
        var result: [BinaryGardensLevel] = []
        for number in numbers {
            do {
                result.append(try BinaryGardensExperienceCore.level(number: number))
            } catch {
                fatalError("level \(number) does not certify: \(error)")
            }
        }
        return result
    }()

    /// A fresh play of `level` in stage `playing`.
    static func playing(_ level: BinaryGardensLevel) throws -> BinaryGardensPlay {
        var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A random arrangement action of `level` (stars 0 … 1, rings, phases, luminosities and tilts drawn a little
    /// beyond their ranges, phases on or off the grid).
    static func randomChange(_ random: inout SeededRandom, _ level: BinaryGardensLevel) -> BinaryGardensAction {
        let star: Int = random.int(0...1)
        switch random.int(0...3) {
        case 0:
            return .ring(star: star, index: random.int(0...level.ringRadii.count))
        case 1:
            let grid: Bool = random.int(0...3) > 0
            let step: Int = grid ? level.phaseStep * random.int(0...(47 / level.phaseStep)) : random.int(0...48)
            return .phase(star: star, step: step)
        case 2:
            return .luminosity(star: star, index: random.int(0...level.luminosityLevels.count))
        default:
            return .tilt(step: random.int(0...(level.maxTilt + 1)))
        }
    }

    /// What the play does with `action`: its arrangement and report after it, or its refusal.
    static func played(_ play: BinaryGardensPlay, _ action: BinaryGardensAction)
        -> (arrangement: BinaryGardensArrangement, report: BinaryGardensReport)? {
        var copy: BinaryGardensPlay = play
        do {
            try copy.apply(action, expecting: copy.fingerprint)
        } catch {
            return nil
        }
        return (copy.arrangement, copy.report)
    }

    /// The play's refusal of `action`, nil when it accepts.
    static func refusal(_ play: BinaryGardensPlay, _ action: BinaryGardensAction) -> BinaryGardensError? {
        var copy: BinaryGardensPlay = play
        do throws(BinaryGardensError) {
            try copy.apply(action, expecting: copy.fingerprint)
        } catch {
            return error
        }
        return nil
    }

    /// Plays from walking `level` by up to `steps` seeded accepted actions (so some reach no action left).
    static func walked(_ random: inout SeededRandom, _ level: BinaryGardensLevel,
                       steps: Int) throws -> BinaryGardensPlay {
        var play: BinaryGardensPlay = try playing(level)
        var attempts: Int = 0
        var done: Int = 0
        while done < steps && attempts < 200 {
            attempts += 1
            let action: BinaryGardensAction = randomChange(&random, level)
            if refusal(play, action) == nil {
                try play.apply(action, expecting: play.fingerprint)
                done += 1
            }
        }
        return play
    }

    @Test func twoHundredPreviewsEqualTheKernelsJudgement() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var accepted: Int = 0
        var refused: Int = 0
        var budget: Int = 0
        var none: Int = 0
        var checked: Int = 0
        var level: Int = 0
        while checked < 200 {
            let entry: BinaryGardensLevel = Self.levels[level % Self.levels.count]
            level += 1
            let steps: Int = random.int(0...(entry.budget + 1))
            let play: BinaryGardensPlay = try Self.walked(&random, entry, steps: steps)
            let snapshot: Snapshot = Snapshot(play: play, shownTick: random.int(1...48), levelNumber: 1, time: 0)
            for _ in 0..<4 {
                let change: BinaryGardensAction = Self.randomChange(&random, entry)
                let previewed: Snapshot = snapshot.previewing(change, level: entry)
                let error: BinaryGardensError? = Self.refusal(play, change)
                checked += 1
                if let refusal = error {
                    if refusal == .action("unchanged") {
                        #expect(previewed.preview == nil, "\(change)")
                        none += 1
                        continue
                    }
                    let preview: BinaryGardensPreview = try #require(previewed.preview, "\(change) \(refusal)")
                    #expect(preview.change == change)
                    #expect(preview.outcome == .refused(refusal), "\(change)")
                    #expect(preview.report == nil && preview.wins == nil && preview.refusal == refusal)
                    if refusal == .budget { budget += 1 } else { refused += 1 }
                } else {
                    let after: (arrangement: BinaryGardensArrangement, report: BinaryGardensReport) =
                        try #require(Self.played(play, change))
                    let preview: BinaryGardensPreview = try #require(previewed.preview, "\(change)")
                    #expect(preview.outcome == .accepted(arrangement: after.arrangement, report: after.report))
                    #expect(preview.report == after.report && preview.arrangement == after.arrangement)
                    #expect(preview.wins == after.report.wins && preview.refusal == nil)
                    #expect(after.report == BinaryGardensSky.report(entry, arrangement: after.arrangement))
                    accepted += 1
                }
                // Presentation only: every other field stays, clearing restores the snapshot exactly.
                #expect(previewed.clearingPreview() == snapshot)
                #expect(previewed.arrangement == snapshot.arrangement && previewed.worlds == snapshot.worlds)
                #expect(previewed.actionsLeft == snapshot.actionsLeft && previewed.stage == snapshot.stage)
            }
        }
        #expect(checked >= 200)
        #expect(accepted > 20 && refused > 20 && budget > 0 && none > 0,
                "accepted \(accepted) refused \(refused) budget \(budget) none \(none)")
    }

    @Test func refusalsComeInThePlaysOrder() throws {
        let level: BinaryGardensLevel = Self.levels[2]
        var play: BinaryGardensPlay = try Self.playing(level)
        // Spend every action with accepted changes.
        var random: SeededRandom = SeededRandom(seed: Self.seed + 1)
        var guardCount: Int = 0
        while play.actionsLeft > 0 && guardCount < 500 {
            guardCount += 1
            let action: BinaryGardensAction = Self.randomChange(&random, level)
            if Self.refusal(play, action) == nil { try play.apply(action, expecting: play.fingerprint) }
        }
        try #require(play.actionsLeft == 0)
        let snapshot: Snapshot = Snapshot(play: play, shownTick: 48, levelNumber: 3, time: 0)
        // With no action left, a change the change rule refuses is refused by it first, a change it accepts by the
        // budget, and an unchanged value gives no preview.
        let outOfRange: BinaryGardensAction = .ring(star: 0, index: level.ringRadii.count)
        #expect(snapshot.previewing(outOfRange, level: level).preview?.outcome
                == .refused(.action("ring out of range")))
        #expect(Self.refusal(play, outOfRange) == .action("ring out of range"))
        let same: BinaryGardensAction = .tilt(step: snapshot.arrangement.tilt)
        if level.maxTilt > 0 {
            #expect(snapshot.previewing(same, level: level).preview == nil)
        }
        var budgetSeen: Bool = false
        for star in 0..<2 {
            for index in level.ringRadii.indices {
                let change: BinaryGardensAction = .ring(star: star, index: index)
                let expected: BinaryGardensError? = Self.refusal(play, change)
                let preview: BinaryGardensPreview? = snapshot.previewing(change, level: level).preview
                if expected == .action("unchanged") {
                    #expect(preview == nil)
                } else if let error = expected {
                    #expect(preview?.outcome == .refused(error))
                    if error == .budget { budgetSeen = true }
                }
            }
        }
        if level.stars[0].ringAdjustable || level.stars[1].ringAdjustable { #expect(budgetSeen) }
        // `.run` never previews; neither does a level of another shape.
        #expect(snapshot.previewing(.run, level: level).preview == nil)
        var other: BinaryGardensLevel? = nil
        for candidate in Self.levels where candidate.ringRadii != level.ringRadii { other = candidate }
        let wrong: BinaryGardensLevel = try #require(other)
        #expect(snapshot.previewing(.ring(star: 0, index: 0), level: wrong).preview == nil)
        #expect(BinaryGardensPreview.of(.run, arrangement: level.start, actionsLeft: 3, level: level) == nil)
        let malformed: BinaryGardensArrangement = BinaryGardensArrangement(rings: [0], phases: [0], luminosities: [0],
                                                                          tilt: 0)
        #expect(BinaryGardensPreview.of(.tilt(step: 0), arrangement: malformed, actionsLeft: 3, level: level) == nil)
    }

    @Test func previewingNeverChangesTheDigest() async throws {
        var core: BinaryGardensExperienceCore = try await BinaryGardensExperienceCore.prepare(seed: 20)
        var builder: DigestBuilder = DigestBuilder(domain: BinaryGardensExperienceCore.experienceID)
        try core.writeDigest(into: &builder)
        let before: StateDigest = builder.finish()
        let level: BinaryGardensLevel = core.play.level
        let snapshot: Snapshot = core.snapshot(time: 0)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 2)
        for _ in 0..<20 {
            let previewed: Snapshot = snapshot.previewing(Self.randomChange(&random, level), level: level)
            _ = BinaryGardensSceneGeometry.drawnSnapshot(previewed)
            _ = previewed.inspecting(0)
        }
        core.setQualityTier(1)
        var after: DigestBuilder = DigestBuilder(domain: BinaryGardensExperienceCore.experienceID)
        try core.writeDigest(into: &after)
        #expect(after.finish() == before)
        #expect(core.snapshot(time: 0) == snapshot)
    }
}
