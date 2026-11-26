// MicroscopicAuroraRendererPurityTests — feature 483 (R02-G19-03) T-R02G1903-005 (FR-R02G1903-003, 005;
// SC-R02G1903-002; clarifications Q4, Q5, renderer purity). Everything the renderer and the panel may do with the
// adapter — read snapshots at any presentation time (negative and non-finite ones included), read them repeatedly,
// change the quality tier, show any tick, step the host — leaves the adapter's digest, its play and the kernel's
// verdict (stage, failure and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_483: random
// placements on the level's sites and elsewhere, removals, odd values, plays, undo, redo and shown ticks on certified
// levels 1, 21, 41, 61, 81 and 91, each from its opening or with all but the last placement of its certified plan
// made). Every snapshot's swimmers stand at the kernel's positions of the predicted swim of the current wells,
// recomputed independently (`MicroscopicAuroraDish.swim(…, keepPositions: true)`); the drawn swimmer at the shown tick
// is that tick's kernel position; its density, lit and stray cells, coverage, coherence and failure are the kernel's
// report, so the drawn ribbons, cells and gauges (any tier, any time, any shown tick) are never a drawn value. The
// shown tick never leaves 0 … ticks swum. Two snapshots of equal states at different times differ only in `time`. The
// six levels are certified once and reused, so the run stays short. Explicit types, plain loops, single-literal
// comments. Modelled on ApsidesWorkshopRendererPurityTests (feature 473).
@testable import MicroscopicAuroraCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MicroscopicAuroraRendererPurityTests {
    typealias Core = MicroscopicAuroraExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + MicroscopicAuroraPlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: MicroscopicAuroraAction) -> ExperienceAction {
        switch action {
        case let .place(slot, well):
            let sense: Double = well.sense == .clockwise ? 0 : 1
            return act("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                      Double(well.strength), sense])
        case let .remove(slot):
            return act("well.remove", [Double(slot)])
        case .play:
            return act("swim.play")
        }
    }

    /// Checks that `snapshot` copies the play of `core` and that its swimmers, cells and gauges are the kernel's, the
    /// positions recomputed independently from the current wells.
    static func expectMirrors(_ snapshot: MicroscopicAuroraSceneSnapshot, _ core: Core) {
        let play: MicroscopicAuroraPlay = core.play
        let level: MicroscopicAuroraLevel = play.level
        let report: MicroscopicAuroraReport = play.report
        let tick: Int = core.shownTick
        let swim: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(level, wells: play.placedWells, keepPositions: true)
        #expect(swim.report == report, "the play's report is the swim of its wells")
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownTick == tick)
        #expect(tick >= 0 && tick <= report.ticks, "the shown tick stays within the ticks swum")
        #expect(snapshot.ticksSwum == report.ticks && swim.positions.count == report.ticks + 1)
        #expect(snapshot.positions.count == level.swimmers.count)
        #expect(snapshot.velocities.count == level.swimmers.count)
        for swimmer in level.swimmers.indices {
            var drawn: [MicroscopicAuroraPoint] = []
            for positions in swim.positions { drawn.append(positions[swimmer]) }
            #expect(snapshot.positions[swimmer] == drawn, "the drawn ribbon is the kernel's positions")
            #expect(snapshot.position(swimmer) == swim.positions[tick][swimmer],
                    "the drawn swimmer is the kernel's position at the shown tick")
            #expect(snapshot.velocities[swimmer].count == report.ticks + 1)
            #expect(snapshot.velocities[swimmer].last == report.finalSwimmers[swimmer].velocity)
            #expect(snapshot.positions[swimmer].last == report.finalSwimmers[swimmer].position)
        }
        #expect(snapshot.radius == level.radius && snapshot.density == report.density)
        #expect(snapshot.litStencil == report.litStencil && snapshot.stencil == level.stencil)
        var stray: [MicroscopicAuroraCell] = []
        for index in report.density.indices where report.density[index] >= level.threshold {
            let cell = MicroscopicAuroraCell(row: index / MicroscopicAuroraDish.cells,
                                             column: index % MicroscopicAuroraDish.cells)
            if !level.stencil.contains(cell) { stray.append(cell) }
        }
        #expect(snapshot.stray == stray)
        #expect(snapshot.sites == (level.sites ?? []) && snapshot.wells == play.wells)
        #expect(snapshot.coverage == report.coverage && snapshot.requiredCoverage == level.coverage)
        #expect(snapshot.coherence == report.smallestCoherence && snapshot.requiredCoherence == level.coherence)
        #expect(snapshot.swarm == level.swimmers.count)
        #expect(snapshot.failure == (play.failure ?? report.failure) && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: MicroscopicAuroraSceneSnapshot, _ b: MicroscopicAuroraSceneSnapshot) {
        #expect(a.radius == b.radius && a.positions == b.positions && a.velocities == b.velocities)
        #expect(a.ticksSwum == b.ticksSwum && a.shownTick == b.shownTick && a.density == b.density)
        #expect(a.litStencil == b.litStencil && a.stray == b.stray && a.stencil == b.stencil && a.sites == b.sites)
        #expect(a.wells == b.wells && a.coverage == b.coverage && a.requiredCoverage == b.requiredCoverage)
        #expect(a.coherence == b.coherence && a.requiredCoherence == b.requiredCoherence && a.swarm == b.swarm)
        #expect(a.failure == b.failure && a.stage == b.stage && a.actionsLeft == b.actionsLeft)
        #expect(a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly placements on the level's sites, sometimes elsewhere or with odd values,
    /// removals, plays, undo, redo and shown ticks.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let sites: [MicroscopicAuroraCell] = core.play.level.sites ?? []
        switch random.int(0...13) {
        case 0...4:
            let slot: Double = Double(random.int(0...2))
            let strength: Double = Double(random.int(MicroscopicAuroraWell.strengths))
            let sense: Double = Double(random.int(0...1))
            if sites.isEmpty || random.int(0...5) == 0 {
                let row: Double = Double(random.int(0...23))
                let column: Double = Double(random.int(0...23))
                return act("well.place", [slot, row, column, strength, sense])
            }
            let site: MicroscopicAuroraCell = sites[random.int(0...(sites.count - 1))]
            return act("well.place", [slot, Double(site.row), Double(site.column), strength, sense])
        case 5:
            return act("well.remove", [Double(random.int(0...2))])
        case 6:
            // Odd values: a fraction, a slot out of range.
            return random.int(0...1) == 0 ? act("well.place", [0, 9.5, 7, 1, 0]) : act("well.remove", [3])
        case 7, 8:
            return act("play.undo")
        case 9:
            return act("play.redo")
        case 10:
            return act("swim.play")
        default:
            return act("clock.show", [Double(random.int(0...(core.play.report.ticks + 4)))])
        }
    }

    @Test func testMicroscopicAuroraRendererpurityBoundary() async throws {
        // Direct example: level 1 after its certified placement, read at the boundary times, every tier and every
        // tick.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("well.place", [0, 11, 18, 2, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        // Every tick shown: the drawn swimmers stand at the kernel's positions of that tick.
        let swim: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(core.play.level, wells: core.play.placedWells, keepPositions: true)
        for tick in 0...core.play.report.ticks {
            #expect(core.apply(Self.act("clock.show", [Double(tick)])) == .accepted)
            let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 1)
            for swimmer in core.play.level.swimmers.indices {
                #expect(snapshot.position(swimmer) == swim.positions[tick][swimmer])
            }
            #expect(try Self.digest(core) == before && core == copy)
        }
        Self.expectMirrors(core.snapshot(time: 1), core)
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last placement of its certified plan made,
        // so that many samples are one placement from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let changes: [MicroscopicAuroraAction] = try Core.generated(number: number).plan.actions
            for action in changes.dropLast() {
                #expect(prepared.apply(Self.act(action)) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_483)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var shownOthers: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...8) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
                #expect(core.shownTick >= 0 && core.shownTick <= core.play.report.ticks)
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let records: [MicroscopicAuroraRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two presentations (the current tick at every tier, then a random tick of the swim at a random tier): the
            // digest, the play and the verdict hold.
            let ticks: Int = core.play.report.ticks
            let current: Int = core.shownTick
            let other: Int = random.int(0...ticks)
            let presentations: [Int] = [current, other]
            for (position, presentation) in presentations.enumerated() {
                #expect(core.apply(Self.act("clock.show", [Double(presentation)])) == .accepted)
                if presentation != current { shownOthers += 1 }
                var first: MicroscopicAuroraSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.shownTick == presentation)
                    #expect(snapshot.time == time + Double(tier))
                    if let first {
                        // Equal states at different times and tiers: only `time` differs.
                        Self.expectSameButTime(first, snapshot)
                        #expect(first != snapshot)
                    } else {
                        // The first tier's snapshot is checked against the kernel; the others equal it but in time.
                        Self.expectMirrors(snapshot, core)
                        first = snapshot
                    }
                    core.update(step: 1)
                }
                #expect(try Self.digest(core) == before && core == copy)
            }
            // A tick past the ticks swum is refused and changes nothing.
            let presented: Int = core.shownTick
            let late: ExperienceAction = Self.act("clock.show", [Double(ticks + 1)])
            #expect(core.apply(late) == .rejected(.rule(code: MicroscopicAuroraExperienceRule.tick)))
            #expect(core.shownTick == presented)
            // Read again at the same time: the same snapshot.
            let again: MicroscopicAuroraSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == records)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 150 && playing > 30 && shownOthers > 100, "the samples spread over plays and ticks")
        #expect(won + failed > 0, "the samples include decided plays")
    }
}
