// MushroomWeatherRendererPurityTests — feature 493 (R02-G20-03) T-R02G2003-005 (FR-R02G2003-003, 004, 005;
// SC-R02G2003-002; clarifications Q4, Q5, renderer purity). Everything the renderer and the panel may do with the
// adapter — read snapshots at any presentation time (negative and non-finite ones included), read them repeatedly,
// change the quality tier, show any cycle, step the host — leaves the adapter's digest, its play and the kernel's
// verdict (stage, failure and actions left) unchanged, over 200 seeded snapshots (fixture seed 2_493: random pod
// placements on the level's sites and elsewhere, removals, vent and moonlight changes, odd values, runs, undo, redo and
// shown cycles on certified levels 1, 21, 41, 61, 81 and 91, each from its opening or with all but the last action of
// its certified plan made). Every snapshot's humidity fields are the kernel's fields of the predicted run of the
// current arrangement, recomputed independently (`MushroomWeatherForest.run(…, keepFields: true)`); the drawn humidity
// of every cell at the shown cycle is that cycle's kernel humidity; the colonies' bands, runs and in-band flags, the
// pods' growth cycles and the failure are the kernel's, so the drawn mist, caps and gauges (any tier, any time, any
// shown cycle) are never a drawn value. The shown cycle never leaves 0 … cycles run. Two snapshots of equal states at
// different times differ only in `time`. The six levels are certified once and reused, so the run stays short.
// Explicit types, plain loops, single-literal comments. Modelled on MicroscopicAuroraRendererPurityTests (feature 483).
@testable import MushroomWeatherCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MushroomWeatherRendererPurityTests {
    typealias Core = MushroomWeatherExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + MushroomWeatherPlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: MushroomWeatherAction) -> ExperienceAction {
        switch action {
        case let .place(slot, cell):
            return act("pod.place", [Double(slot), Double(cell.row), Double(cell.column)])
        case let .remove(slot):
            return act("pod.remove", [Double(slot)])
        case let .vent(index, open):
            return act("vent.set", [Double(index), open ? 1 : 0])
        case let .moonlight(level):
            return act("moon.set", [Double(level)])
        case .run:
            return act("weather.run")
        }
    }

    /// Checks that `snapshot` copies the play of `core` and that its humidity, colonies and pods are the kernel's, the
    /// fields recomputed independently from the current arrangement.
    static func expectMirrors(_ snapshot: MushroomWeatherSceneSnapshot, _ core: Core) {
        let play: MushroomWeatherPlay = core.play
        let level: MushroomWeatherLevel = play.level
        let report: MushroomWeatherReport = play.report
        let cycle: Int = core.shownCycle
        let run: (report: MushroomWeatherReport, fields: [[Int]]) =
            MushroomWeatherForest.run(level, arrangement: play.arrangement, keepFields: true)
        #expect(run.report == report, "the play's report is the run of its arrangement")
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownCycle == cycle)
        #expect(cycle >= 0 && cycle <= report.cycles, "the shown cycle stays within the cycles run")
        #expect(snapshot.cyclesRun == report.cycles && run.fields.count == report.cycles + 1)
        #expect(snapshot.fields == run.fields, "the drawn humidity fields are the kernel's")
        #expect(snapshot.shownField == run.fields[cycle], "the drawn humidity is the kernel's at the shown cycle")
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: MushroomWeatherCell = MushroomWeatherCell(row: row, column: column)
                #expect(snapshot.humidity(cell) == run.fields[cycle][level.index(of: cell)])
            }
        }
        #expect(snapshot.colonies.count == level.colonies.count)
        for (index, colony) in level.colonies.enumerated() {
            let drawn: MushroomWeatherSceneColony = snapshot.colonies[index]
            let humidity: Int = run.fields[cycle][level.index(of: colony.cell)]
            #expect(drawn.cell == colony.cell && drawn.low == colony.low && drawn.high == colony.high)
            #expect(drawn.survivalFloor == colony.survivalFloor)
            #expect(drawn.inBand == colony.isInBand(humidity), "the drawn cap's band is the kernel's")
            #expect(drawn.finalRun == report.colonies[index].finalRun)
            #expect(drawn.longestRun == report.colonies[index].longestRun)
        }
        #expect(snapshot.rows == level.rows && snapshot.columns == level.columns && snapshot.blocked == level.blocked)
        #expect(snapshot.moldBound == level.moldBound && snapshot.requiredCycles == level.required)
        #expect(snapshot.pods == play.arrangement.pods && snapshot.grownAt == report.grownAt)
        for slot in play.arrangement.pods.indices {
            let grown: Bool = report.grownAt[slot].map { cycle >= $0 } ?? false
            #expect(snapshot.isGrown(slot) == grown)
        }
        #expect(snapshot.sites == (level.sites ?? []) && snapshot.vents == level.vents.map(\.cell))
        #expect(snapshot.ventsOpen == play.arrangement.ventsOpen && snapshot.moonlight == play.arrangement.moonlight)
        #expect(snapshot.failure == (play.failure ?? report.failure) && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: MushroomWeatherSceneSnapshot, _ b: MushroomWeatherSceneSnapshot) {
        #expect(a.rows == b.rows && a.columns == b.columns && a.blocked == b.blocked && a.fields == b.fields)
        #expect(a.cyclesRun == b.cyclesRun && a.shownCycle == b.shownCycle && a.moldBound == b.moldBound)
        #expect(a.colonies == b.colonies && a.requiredCycles == b.requiredCycles && a.pods == b.pods)
        #expect(a.grownAt == b.grownAt && a.sites == b.sites && a.vents == b.vents && a.ventsOpen == b.ventsOpen)
        #expect(a.moonlight == b.moonlight && a.failure == b.failure && a.stage == b.stage)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly pod placements on the level's sites, sometimes elsewhere or with odd values,
    /// removals, vent and moonlight changes, runs, undo, redo and shown cycles.
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let level: MushroomWeatherLevel = core.play.level
        let sites: [MushroomWeatherCell] = level.sites ?? []
        let slots: Int = level.podRules.slots
        switch random.int(0...15) {
        case 0...4:
            let slot: Double = Double(random.int(0...(slots - 1)))
            if sites.isEmpty || random.int(0...5) == 0 {
                let row: Double = Double(random.int(0...(level.rows - 1)))
                let column: Double = Double(random.int(0...(level.columns - 1)))
                return act("pod.place", [slot, row, column])
            }
            let site: MushroomWeatherCell = sites[random.int(0...(sites.count - 1))]
            return act("pod.place", [slot, Double(site.row), Double(site.column)])
        case 5:
            return act("pod.remove", [Double(random.int(0...(slots - 1)))])
        case 6:
            let vent: Double = Double(random.int(0...max(level.vents.count - 1, 0)))
            return act("vent.set", [vent, Double(random.int(0...1))])
        case 7:
            return act("moon.set", [Double(random.int(MushroomWeatherLevel.moonlightLevels))])
        case 8:
            // Odd values: a fraction, a slot out of range.
            return random.int(0...1) == 0 ? act("pod.place", [0, 0.5, 4]) : act("pod.remove", [6])
        case 9, 10:
            return act("play.undo")
        case 11:
            return act("play.redo")
        case 12:
            return act("weather.run")
        default:
            return act("clock.show", [Double(random.int(0...(core.play.report.cycles + 4)))])
        }
    }

    @Test func testMushroomWeatherRendererpurityBoundary() async throws {
        // Direct example: level 1 after its certified plan, read at the boundary times, every tier and every cycle.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == .accepted)
        #expect(core.apply(Self.act("vent.set", [0, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: MushroomWeatherSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        // Every cycle shown: the drawn humidity of every cell is the kernel's humidity of that cycle.
        let run: (report: MushroomWeatherReport, fields: [[Int]]) =
            MushroomWeatherForest.run(core.play.level, arrangement: core.play.arrangement, keepFields: true)
        for cycle in 0...core.play.report.cycles {
            #expect(core.apply(Self.act("clock.show", [Double(cycle)])) == .accepted)
            let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownField == run.fields[cycle])
            #expect(try Self.digest(core) == before && core == copy)
        }
        Self.expectMirrors(core.snapshot(time: 1), core)
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Six certified levels, certified once; each also with all but the last action of its certified plan made, so
        // that many samples are one action from a win.
        let numbers: [Int] = [1, 21, 41, 61, 81, 91]
        var openings: [Core] = []
        for number in numbers {
            let opening: Core = try Core.opening(number: number)
            openings.append(opening)
            var prepared: Core = opening
            let changes: [MushroomWeatherAction] = try Core.generated(number: number).plan.actions
            for action in changes.dropLast() {
                #expect(prepared.apply(Self.act(action)) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_493)
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
                #expect(core.shownCycle >= 0 && core.shownCycle <= core.play.report.cycles)
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let records: [MushroomWeatherRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two presentations (the current cycle at every tier, then a random cycle of the run at a random tier):
            // the digest, the play and the verdict hold.
            let cycles: Int = core.play.report.cycles
            let current: Int = core.shownCycle
            let other: Int = random.int(0...cycles)
            let presentations: [Int] = [current, other]
            for (position, presentation) in presentations.enumerated() {
                #expect(core.apply(Self.act("clock.show", [Double(presentation)])) == .accepted)
                if presentation != current { shownOthers += 1 }
                var first: MushroomWeatherSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    #expect(core.renderTier == MushroomWeatherTier.of(tier))
                    let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.shownCycle == presentation)
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
            // A cycle past the cycles run is refused and changes nothing.
            let presented: Int = core.shownCycle
            let late: ExperienceAction = Self.act("clock.show", [Double(cycles + 1)])
            #expect(core.apply(late) == .rejected(.rule(code: MushroomWeatherExperienceRule.cycle)))
            #expect(core.shownCycle == presented)
            // Read again at the same time: the same snapshot.
            let again: MushroomWeatherSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
            Self.expectSameButTime(oddSnapshot, again)
            #expect(oddSnapshot.time == 0)
            core.setQualityTier(random.int(-1...3))
            #expect(try Self.digest(core) == before)
            #expect(core == copy && core.play.records == records)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 150 && playing > 30 && shownOthers > 100, "the samples spread over plays and cycles")
        #expect(won + failed > 0, "the samples include decided plays")
    }
}
