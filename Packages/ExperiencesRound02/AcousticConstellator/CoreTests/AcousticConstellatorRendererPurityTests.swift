// AcousticConstellatorRendererPurityTests — feature 423 (R02-G13-03) T-R02G1303-005 (FR-R02G1303-003, 005;
// clarification Q4, renderer purity). Everything the renderer may do with the adapter — read snapshots at any
// presentation time (negative and non-finite ones included), read them repeatedly, change the quality tier, step the
// host — leaves the adapter's digest, its state and the kernel's verdict (stage, failure and actions left) unchanged,
// over 200 seeded snapshots (fixture seed 2_423: random links, unlinks, nudges, listens, odd stars and steps, undo and
// redo on certified levels 1, 21, 41, 61, 81 and 100, each from its opening or with its witness's links made). Every
// snapshot's report is the kernel's exact listen of the play's links and phases, and is checked tick by tick against
// the kernel's clock: the phases of every tick (the
// phases the drawn pulse and hands read) equal the kernel's tick of the links still joined, every snapped link is the
// one the kernel's snap rule breaks on that tick, and the order parameter and coherence of every tick are the kernel's
// exact integer values, so the drawn pulse (presentation only, any tier, any time) never changes a phase, a snap or the
// coherence. Two snapshots of equal states at different times or tiers differ only in `time`. The six levels are
// certified once and reused, so the run stays short. Explicit types, plain loops.
@testable import AcousticConstellatorCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AcousticConstellatorRendererPurityTests {
    typealias Core = AcousticConstellatorExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure when it failed, and the actions left.
    static func verdict(_ core: Core) -> String {
        var text: String = core.play.stage.rawValue + "/"
        switch core.play.failure {
        case let .missing(pair)?: text += "missing \(pair.a) \(pair.b)"
        case let .disconnected(tick, link)?: text += "disconnected \(tick) \(link.a) \(link.b)"
        case let .incoherent(run)?: text += "incoherent \(run)"
        case let .budget(index)?: text += "budget \(index)"
        case nil: text += "-"
        }
        text += "/\(core.play.actionsLeft)"
        return text
    }

    /// Checks that `snapshot` copies the play of `core` and carries the kernel's exact listen, tick by tick against
    /// the kernel's clock, so no drawn value can stand in for a phase, a snap or the coherence.
    static func expectMirrors(_ snapshot: AcousticConstellatorSceneSnapshot, _ core: Core) {
        let play: AcousticConstellatorPlay = core.play
        let level: AcousticConstellatorLevel = play.level
        #expect(snapshot.levelNumber == core.levelNumber)
        #expect(snapshot.stars == level.stars && snapshot.links == play.links && snapshot.phases == play.phases)
        #expect(snapshot.fixedLinks == level.fixedLinks.sorted() && snapshot.symbol == level.symbol.sorted())
        let exact: AcousticConstellatorListen = level.listen(links: play.links, phases: play.phases)
        #expect(snapshot.report == play.report && snapshot.report == exact)
        #expect(snapshot.ticks == max(1, exact.phases.count))
        // Tick by tick with the kernel's clock: the links still joined move the phases, then the snap rule breaks.
        let rates: [Int] = level.naturalRates
        var alive: [Bool] = Array(repeating: true, count: play.links.count)
        var snappedBy: [Bool] = Array(repeating: false, count: play.links.count)
        for tick in 0..<exact.phases.count {
            let phases: [Int] = snapshot.phases(at: tick)
            if tick == 0 {
                #expect(phases == play.phases, "tick 0")
            } else {
                var remaining: [AcousticConstellatorLink] = []
                for index in 0..<play.links.count where alive[index] { remaining.append(play.links[index]) }
                let moved: [Int] = AcousticConstellatorClock.tick(phases: snapshot.phases(at: tick - 1), rates: rates,
                                                                  links: remaining, coupling: level.coupling)
                #expect(phases == moved, "phases \(tick)")
                for index in 0..<play.links.count where alive[index] {
                    let snaps: Bool = AcousticConstellatorClock.snaps(play.links[index], phases: moved,
                                                                      limit: level.snapLimit)
                    #expect(exact.snapped[tick].contains(index) == snaps, "snap \(tick) \(index)")
                    if snaps {
                        alive[index] = false
                        snappedBy[index] = true
                    }
                }
            }
            for index in 0..<play.links.count {
                #expect(snapshot.isSnapped(index, at: tick) == snappedBy[index], "snapped \(tick) \(index)")
                let link: AcousticConstellatorLink = play.links[index]
                let gap: Int = abs(AcousticConstellatorClock.gap(phases[link.a], phases[link.b]))
                #expect(snapshot.gap(index, at: tick) == gap && snapshot.isTeal(index, at: tick) == (gap <= 1))
            }
            // The order parameter and coherence: the kernel's exact integers, never a drawn value.
            let parts: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(phases)
            #expect(exact.order[tick] == [parts.a, parts.b], "order \(tick)")
            #expect(snapshot.isCoherent(at: tick) == exact.coherent[tick], "coherent \(tick)")
            if exact.coherent[tick] {
                #expect(AcousticConstellatorClock.atLeast(a: parts.a, b: parts.b, threshold: level.threshold))
            }
            #expect(snapshot.run(at: tick) <= snapshot.hold)
        }
        // The shown tick's phases (the pulse and the hands) are the kernel's phases of that tick.
        let shown: Int = snapshot.shownTick
        #expect(shown >= 0 && shown < snapshot.ticks)
        #expect(snapshot.phases(at: shown) == exact.phases[min(shown, exact.phases.count - 1)])
        #expect(snapshot.threshold == level.threshold && snapshot.hold == level.hold && snapshot.window == level.window)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: AcousticConstellatorSceneSnapshot, _ b: AcousticConstellatorSceneSnapshot) {
        #expect(a.stars == b.stars && a.links == b.links && a.fixedLinks == b.fixedLinks && a.symbol == b.symbol)
        #expect(a.phases == b.phases && a.report == b.report && a.threshold == b.threshold && a.hold == b.hold)
        #expect(a.window == b.window && a.stage == b.stage && a.failure == b.failure)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly links, unlinks and nudges of the level's stars, sometimes a listen, odd stars
    /// and steps, undo and redo.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let count: Int = core.play.level.stars.count
        switch random.int(0...13) {
        case 0...3:
            let a: Double = Double(random.int(0...(count - 1)))
            let b: Double = Double(random.int(0...(count - 1)))
            return ExperienceAction(control: "link.add", values: [a, b], step: 0)
        case 4, 5:
            let a: Double = Double(random.int(0...(count - 1)))
            let b: Double = Double(random.int(0...(count - 1)))
            return ExperienceAction(control: "link.remove", values: [a, b], step: 0)
        case 6, 7:
            let star: Double = Double(random.int(0...(count - 1)))
            let step: Double = random.int(0...1) == 0 ? -1 : 1
            return ExperienceAction(control: "star.nudge", values: [star, step], step: 0)
        case 8:
            return ExperienceAction(control: "constellation.listen", step: 0)
        case 9:
            let star: Double = Double(random.int(0...7))
            let step: Double = Double(random.int(-1...1))
            return ExperienceAction(control: "star.nudge", values: [star, step], step: 0)
        case 10, 11:
            return ExperienceAction(control: "play.undo", step: 0)
        default:
            return ExperienceAction(control: "play.redo", step: 0)
        }
    }

    @Test func testAcousticConstellatorRendererpurityBoundary() async throws {
        // Direct example: level 1 after its witness link, read at the boundary times and every tier.
        var core: Core = try await Core.prepare(seed: 0)
        let link = ExperienceAction(control: "link.add", values: [0, 1], step: 0)
        #expect(core.apply(link) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: AcousticConstellatorSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with its witness's links made, so that the whole symbol is
        // linked and the listen runs past tick 0 in many samples.
        let numbers: [Int] = [1, 21, 41, 61, 81, 100]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var linked: Core = opening
            for action in try Core.generated(number: number).actions {
                guard case let .link(a, b) = action else { continue }
                let add = ExperienceAction(control: "link.add", values: [Double(a), Double(b)], step: 0)
                #expect(linked.apply(add) == .accepted)
            }
            openings.append(linked)
        }
        var random = SeededRandom(seed: 2_423)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var withTicks: Int = 0
        var withSnaps: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...16) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            if core.play.report.phases.count > 1 { withTicks += 1 }
            if core.play.report.snappedCount > 0 { withSnaps += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            var first: AcousticConstellatorSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: time + Double(tier))
                Self.expectMirrors(snapshot, core)
                #expect(snapshot.time == time + Double(tier))
                // Read again at the same time: the same snapshot.
                #expect(core.snapshot(time: time + Double(tier)) == snapshot)
                if let first {
                    // Equal states at different times and tiers: only `time` differs.
                    Self.expectSameButTime(first, snapshot)
                    #expect(first != snapshot)
                } else {
                    first = snapshot
                }
                core.update(step: 1)
            }
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectMirrors(oddSnapshot, core)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && withTicks > 60,
                "accepted \(accepted) playing \(playing) ticks \(withTicks)")
        #expect(won + failed > 0 && withSnaps > 0, "won \(won) failed \(failed) snaps \(withSnaps)")
    }
}
