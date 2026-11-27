// BinaryGardensRendererPurityTests — feature 503 (R02-G21-03) T-R02G2103-005 (FR-R02G2103-003, 004, 005;
// SC-R02G2103-002; clarifications Q4, Q5, renderer purity). Everything the renderer and the panel may do with the
// adapter — read snapshots at any presentation time (negative and non-finite ones included), read them repeatedly,
// build the system and glow meshes at any tier, change the quality tier, show any tick, step the host — leaves the
// adapter's digest, its play and the kernel's verdict (stage, failure and actions left) unchanged, over 200 seeded
// snapshots (fixture seed 2_503: random ring, phase, luminosity and tilt changes, odd values, runs, undo, redo and shown
// ticks on certified levels 1, 21, 41, 61, 81 and 91, each from its opening or with all but the last action of its
// certified plan made). Every snapshot's positions, fluxes, shares, bands, windows and integrals are the kernel's
// report of the current arrangement, recomputed independently (`BinaryGardensSky.report`); the drawn body positions
// are k · (kernel point) / 2^20 at the shown tick, every world's band and shares at the shown tick are the kernel's,
// so the drawn lighting, banding, gauges, window brackets and bloom markers (any tier, any time, any shown tick) are
// never a drawn value. The shown tick never leaves 1 … 48. Two snapshots of equal states at different times differ
// only in `time`. The six levels are certified once and reused, so the run stays short. Explicit types, plain loops,
// single-literal comments. Modelled on MushroomWeatherRendererPurityTests (feature 493).
@testable import BinaryGardensCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct BinaryGardensRendererPurityTests {
    typealias Core = BinaryGardensExperienceCore
    typealias G = BinaryGardensSceneGeometry

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage, the failure text and the actions left.
    static func verdict(_ core: Core) -> String {
        core.play.stage.rawValue + "/" + BinaryGardensPlay.text(core.play.failure) + "/"
            + String(core.play.actionsLeft)
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: BinaryGardensAction) -> ExperienceAction {
        switch action {
        case let .ring(star, index): return act("star.ring", [Double(star), Double(index)])
        case let .phase(star, step): return act("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index): return act("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step): return act("orbit.tilt", [Double(step)])
        case .run: return act("light.run")
        }
    }

    /// Checks that `snapshot` copies the play of `core` and that its positions and light are the kernel's, the report
    /// recomputed independently from the current arrangement, and the drawn centres are k · (kernel point) / 2^20.
    static func expectMirrors(_ snapshot: BinaryGardensSceneSnapshot, _ core: Core) {
        let play: BinaryGardensPlay = core.play
        let level: BinaryGardensLevel = play.level
        let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: play.arrangement)
        let tick: Int = core.shownTick
        #expect(report == play.report, "the play's report is the report of its arrangement")
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.shownTick == tick)
        #expect(tick >= 1 && tick <= 48, "the shown tick stays within 1 … 48")
        #expect(snapshot.starPositions == report.starPositions, "the drawn star positions are the kernel's")
        #expect(snapshot.arrangement == play.arrangement && snapshot.ringRadii == level.ringRadii)
        #expect(snapshot.worlds.count == level.worlds.count)
        let k: Double = snapshot.fitScale
        for star in 0..<2 {
            let p: BinaryGardensPoint = report.starPositions[tick - 1][star]
            let centre: SIMD3<Double> = G.starCentre(star, snapshot)
            let expected: SIMD3<Double> = SIMD3(Double(p.x), Double(p.y), Double(p.z)) * (k / 1_048_576)
            #expect(abs(centre.x - expected.x) + abs(centre.y - expected.y) + abs(centre.z - expected.z) < 1e-12)
        }
        for (index, world) in level.worlds.enumerated() {
            let drawn: BinaryGardensSceneWorld = snapshot.worlds[index]
            let light: BinaryGardensWorldLight = report.worlds[index]
            #expect(drawn.flux == light.flux && drawn.shares == light.shares && drawn.bands == light.bands)
            #expect(drawn.longestWindow == light.window && drawn.windowStart == light.windowStart)
            #expect(drawn.integral == light.integral && drawn.bloom == light.bloom)
            #expect(drawn.longestLethalRun == light.longestLethalRun)
            #expect(drawn.comfortLow == world.comfortLow && drawn.comfortHigh == world.comfortHigh)
            #expect(drawn.lethalHigh == world.lethalHigh && drawn.window == world.window)
            #expect(snapshot.band(index) == light.bands[tick - 1], "the drawn banding is the kernel's band")
            #expect(snapshot.share(index, star: 0) == light.shares[tick - 1][0], "the drawn light is the kernel's")
            #expect(snapshot.share(index, star: 1) == light.shares[tick - 1][1])
            let p: BinaryGardensPoint = report.worldPositions[tick - 1][index]
            let centre: SIMD3<Double> = G.worldCentre(index, snapshot)
            let expected: SIMD3<Double> = SIMD3(Double(p.x), Double(p.y), Double(p.z)) * (k / 1_048_576)
            #expect(abs(centre.x - expected.x) + abs(centre.y - expected.y) + abs(centre.z - expected.z) < 1e-12)
        }
        #expect(snapshot.failure == (play.failure ?? report.failure) && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.time.isFinite && snapshot.time >= 0)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: BinaryGardensSceneSnapshot, _ b: BinaryGardensSceneSnapshot) {
        #expect(a.ringRadii == b.ringRadii && a.luminosityLevels == b.luminosityLevels && a.maxTilt == b.maxTilt)
        #expect(a.phaseStep == b.phaseStep && a.lethalTolerance == b.lethalTolerance && a.worlds == b.worlds)
        #expect(a.arrangement == b.arrangement && a.starPositions == b.starPositions && a.shownTick == b.shownTick)
        #expect(a.fitScale == b.fitScale && a.failure == b.failure && a.stage == b.stage)
        #expect(a.actionsLeft == b.actionsLeft && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    /// A random action for `core`: mostly ring, phase, luminosity and tilt changes in the declared ranges, sometimes
    /// odd values, runs, undo, redo and shown ticks (some refused).
    static func randomAction(_ core: Core, _ random: inout SeededRandom) -> ExperienceAction {
        let level: BinaryGardensLevel = core.play.level
        let star: Double = Double(random.int(0...1))
        switch random.int(0...15) {
        case 0, 1:
            return act("star.ring", [star, Double(random.int(0...(level.ringRadii.count - 1)))])
        case 2, 3:
            let step: Int = random.int(0...(47 / level.phaseStep)) * level.phaseStep
            return act("star.phase", [star, Double(step)])
        case 4:
            return act("star.luminosity", [star, Double(random.int(0...(level.luminosityLevels.count - 1)))])
        case 5:
            return act("orbit.tilt", [Double(random.int(0...6))])
        case 6:
            // Odd values: a fraction, a phase off the grid, a ring out of range.
            switch random.int(0...2) {
            case 0: return act("star.ring", [0, 0.5])
            case 1: return act("star.phase", [star, 1])
            default: return act("star.ring", [0, 8])
            }
        case 7, 8:
            return act("play.undo")
        case 9:
            return act("play.redo")
        case 10:
            return act("light.run")
        default:
            return act("clock.show", [Double(random.int(0...52))])
        }
    }

    @Test func testBinaryGardensRendererpurityBoundary() async throws {
        // Direct example: level 1 after its certified plan, read at the boundary times, every tier and every tick.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("star.luminosity", [1, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        for time in times {
            let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: time)
            Self.expectMirrors(snapshot, core)
            #expect(snapshot.time == (time.isFinite ? max(0, time) : 0))
            #expect(try Self.digest(core) == before && core == copy)
        }
        let zero: BinaryGardensSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 1)
            _ = try G.systemMesh(snapshot, tier: core.renderTier)
            _ = try G.glowMesh(snapshot, tier: core.renderTier)
            #expect(try Self.digest(core) == before && core == copy)
        }
        // Every tick shown: the drawn bands and shares are the kernel's of that tick.
        let report: BinaryGardensReport = BinaryGardensSky.report(core.play.level, arrangement: core.play.arrangement)
        for tick in 1...48 {
            #expect(core.apply(Self.act("clock.show", [Double(tick)])) == .accepted)
            let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 1)
            for world in report.worlds.indices {
                #expect(snapshot.band(world) == report.worlds[world].bands[tick - 1])
                #expect(snapshot.share(world, star: 0) == report.worlds[world].shares[tick - 1][0])
            }
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
            let changes: [BinaryGardensAction] = try Core.generated(number: number).plan.actions
            for action in changes.dropLast() {
                #expect(prepared.apply(Self.act(action)) == .accepted)
            }
            openings.append(prepared)
        }
        var random = SeededRandom(seed: 2_503)
        var accepted: Int = 0
        var playing: Int = 0
        var won: Int = 0
        var failed: Int = 0
        var shownOthers: Int = 0
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for sample in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...8) {
                let action: ExperienceAction = Self.randomAction(core, &random)
                if core.apply(action).isAccepted { accepted += 1 }
                #expect(core.shownTick >= 1 && core.shownTick <= 48)
            }
            switch core.play.stage {
            case .won: won += 1
            case .failed: failed += 1
            default: playing += 1
            }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let records: [BinaryGardensRecord] = core.play.records
            let time: Double = Double(random.int(0...100_000)) / 7
            // Two presentations (the current tick at every tier, then a random tick at a random tier): the digest,
            // the play and the verdict hold.
            let current: Int = core.shownTick
            let other: Int = random.int(1...48)
            let presentations: [Int] = [current, other]
            for (position, presentation) in presentations.enumerated() {
                #expect(core.apply(Self.act("clock.show", [Double(presentation)])) == .accepted)
                if presentation != current { shownOthers += 1 }
                var first: BinaryGardensSceneSnapshot? = nil
                let tiers: [Int] = position == 0 ? [0, 1, 2] : [random.int(0...2)]
                for tier in tiers {
                    core.setQualityTier(tier)
                    #expect(core.renderTier == BinaryGardensTier.of(tier))
                    let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: time + Double(tier))
                    #expect(snapshot.shownTick == presentation)
                    #expect(snapshot.time == time + Double(tier))
                    if sample % 25 == 0 {
                        // Building the meshes reads the snapshot only.
                        _ = try G.systemMesh(snapshot, tier: core.renderTier)
                        _ = try G.glowMesh(snapshot, tier: core.renderTier)
                    }
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
            // A tick past the cycle is refused and changes nothing.
            let presented: Int = core.shownTick
            let late: ExperienceAction = Self.act("clock.show", [Double(random.int(49...60))])
            #expect(core.apply(late) == .rejected(.rule(code: BinaryGardensExperienceRule.tick)))
            #expect(core.shownTick == presented)
            // Read again at the same time: the same snapshot.
            let again: BinaryGardensSceneSnapshot = core.snapshot(time: time)
            #expect(core.snapshot(time: time) == again)
            // Odd times read as 0 and change nothing either.
            let oddSnapshot: BinaryGardensSceneSnapshot = core.snapshot(time: odd[random.int(0...2)])
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
