// CelestialEclipseLabGeneratorTests — feature 462 (R02-G17-02) T-R02G1702-004 (FR-R02G1702-001, 005, 007;
// SC-R02G1702-001, 003, 004; clarification Q1). Host checks of the constructive level generator: the manifest (100
// entries, numbers 1 … 100, 20 per band, budgets within the band's range, five emphases of 20 each); the five band
// profiles of clarification Q1 and the clamp of out-of-range bands; the level ids and bounds; the integer unit-circle
// table against round(1000·cos), round(1000·sin) computed here with Foundation (tests only; the generator uses no
// floating point); `scaled` rounding half away from zero; candidate and generation determinism; the drawing order of
// clarification Q1 re-implemented independently here (body count, Fisher–Yates depth ranks, per body period, centre,
// semi-axes, direction, tilt and radius, the horizon, the winning phases, the target count and windows, the moved
// bodies and their different phases), with eclipse events and the judge recomputed here, compared with `candidate` on
// sampled (entry, index) pairs of every band, nil candidates explained (too few events or already won); every candidate
// against its band, the kernel ranges and the depth order; the filters of `generate` (`skipped` is the first candidate
// with a minimal plan in the band's range and within the budget); the neighbour rule (FR-R02G1702-007); and the refusal
// `.generation(number)` past the candidate bound. Only a few entries are generated here (no whole catalog), so every
// test stays short in a debug build. Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite("CelestialEclipseLabGenerator")
struct CelestialEclipseLabGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw: three per band, several emphases.
    static let redrawNumbers: [Int] = [1, 3, 8, 21, 27, 36, 41, 50, 59, 61, 70, 79, 81, 90, 100]

    /// The candidate indices re-drawn per sampled entry.
    static let redrawIndices: [Int] = [0, 1, 4, 9]

    /// The manifest numbers generated here (bands 1 … 4; band 5's solver searches are the longest and are left to
    /// the catalog tests).
    static let generateNumbers: [Int] = [1, 4, 21, 41, 61]

    /// The five control emphases of the archived table.
    static let emphases: [String] = [
        "inspect timeline", "commit order", "set orbital phase", "adjust inclination", "schedule eclipse",
    ]

    /// The band profiles exactly as clarification Q1 writes them (bodies, targets, horizon, moved, plan range).
    static let documented: [CelestialEclipseLabBandProfile] = [
        CelestialEclipseLabBandProfile(bodies: 3...3, targets: 1...2, horizon: 24...32, moved: 2, planRange: 1...2),
        CelestialEclipseLabBandProfile(bodies: 3...4, targets: 2...3, horizon: 28...36, moved: 3, planRange: 2...3),
        CelestialEclipseLabBandProfile(bodies: 4...5, targets: 2...3, horizon: 32...40, moved: 4, planRange: 3...4),
        CelestialEclipseLabBandProfile(bodies: 5...6, targets: 3...4, horizon: 36...44, moved: 4, planRange: 3...4),
        CelestialEclipseLabBandProfile(bodies: 6...6, targets: 3...4, horizon: 40...48, moved: 5, planRange: 4...5),
    ]

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> CelestialEclipseLabManifestEntry {
        CelestialEclipseLabManifest.entries[number - 1]
    }

    /// An eclipse event recomputed here: the pair in depth order and the first tick of the run.
    struct Event: Equatable {
        let front: Int
        let back: Int
        let first: Int
    }

    /// Why an independently re-drawn candidate gives no level.
    enum Reason: Equatable {
        /// The candidate gives a level.
        case none
        /// The winning timeline has fewer events than the target count.
        case tooFewEvents
        /// The starting phases already win.
        case alreadyWon
    }

    /// A candidate re-drawn independently of the generator.
    struct Drawn {
        let count: Int
        let ranks: [Int]
        let bodies: [CelestialEclipseLabBody]
        let horizon: Int
        let winning: [Int]
        let targetCount: Int
        let events: [Event]
        let target: [CelestialEclipseLabTarget]
        let phases: [Int]
        let moved: Int
        let reason: Reason
    }

    /// round(1000·cos(2πk/p)), round(1000·sin(2πk/p)) for k = 0 … p − 1, computed here with Foundation.
    static func referenceTable(_ period: Int) -> [(Int, Int)] {
        var rows: [(Int, Int)] = []
        for k in 0..<period {
            let angle: Double = 2.0 * Double.pi * Double(k) / Double(period)
            let cosine: Int = Int((1000.0 * cos(angle)).rounded(.toNearestOrAwayFromZero))
            let sine: Int = Int((1000.0 * sin(angle)).rounded(.toNearestOrAwayFromZero))
            rows.append((cosine, sine))
        }
        return rows
    }

    /// `value · unit / 1000` rounded half away from zero, computed here in floating point (exact for these sizes).
    static func referenceScaled(_ value: Int, _ unit: Int) -> Int {
        Int((Double(value * unit) / 1000.0).rounded(.toNearestOrAwayFromZero))
    }

    /// The eclipse events of `bodies` with `phases` over ticks 0 … horizon − 1, recomputed here by direct enumeration:
    /// for every pair the front body is the one whose smallest z is above the other's largest z; an eclipse tick has
    /// squared projected distance strictly below (ra + rb)²; an event is the first tick of a run; events are ordered
    /// by first tick, then front, then back.
    static func events(_ bodies: [CelestialEclipseLabBody], horizon: Int, phases: [Int]) -> [Event] {
        var result: [Event] = []
        let count: Int = bodies.count
        for i in 0..<count {
            var j: Int = i + 1
            while j < count {
                let iMin: Int = bodies[i].orbit.map(\.z).min() ?? 0
                let jMax: Int = bodies[j].orbit.map(\.z).max() ?? 0
                let front: Int = iMin > jMax ? i : j
                let back: Int = iMin > jMax ? j : i
                let reach: Int = bodies[front].radius + bodies[back].radius
                var inside: Bool = false
                for tick in 0..<horizon {
                    let fOrbit: [CelestialEclipseLabVector] = bodies[front].orbit
                    let bOrbit: [CelestialEclipseLabVector] = bodies[back].orbit
                    let p: CelestialEclipseLabVector = fOrbit[(tick + phases[front]) % fOrbit.count]
                    let q: CelestialEclipseLabVector = bOrbit[(tick + phases[back]) % bOrbit.count]
                    let dx: Int = p.x - q.x
                    let dy: Int = p.y - q.y
                    let now: Bool = dx * dx + dy * dy < reach * reach
                    if now && !inside { result.append(Event(front: front, back: back, first: tick)) }
                    inside = now
                }
                j += 1
            }
        }
        result.sort { (lhs: Event, rhs: Event) -> Bool in
            if lhs.first != rhs.first { return lhs.first < rhs.first }
            if lhs.front != rhs.front { return lhs.front < rhs.front }
            return lhs.back < rhs.back
        }
        return result
    }

    /// Whether `events` win `target`, judged here: a match advances, any other event before the last match fails,
    /// events after the last match are ignored, targets left at the end fail.
    static func wins(_ events: [Event], _ target: [CelestialEclipseLabTarget]) -> Bool {
        var matched: Int = 0
        for event in events {
            if matched == target.count { break }
            let next: CelestialEclipseLabTarget = target[matched]
            guard event.front == next.front, event.back == next.back, event.first >= next.open,
                  event.first <= next.close else { return false }
            matched += 1
        }
        return matched == target.count
    }

    /// Candidate `index` of `entry` drawn independently in the order of clarification Q1.
    static func redraw(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> Drawn {
        let band: Int = min(5, max(1, entry.band))
        let profile: CelestialEclipseLabBandProfile = documented[band - 1]
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // 1. The body count.
        let count: Int = random.int(profile.bodies)
        // 2. A depth rank per body: Fisher–Yates over 0 … count − 1 from the last index down.
        var ranks: [Int] = []
        for r in 0..<count { ranks.append(r) }
        var last: Int = count - 1
        while last > 0 {
            let other: Int = random.int(0...last)
            let held: Int = ranks[last]
            ranks[last] = ranks[other]
            ranks[other] = held
            last -= 1
        }
        // 3. Per body: period, centre x and y, semi-axes a and b, direction, tilt, then the radius.
        var bodies: [CelestialEclipseLabBody] = []
        for body in 0..<count {
            let period: Int = random.int(4...8)
            let cx: Int = random.int(-8...8)
            let cy: Int = random.int(-8...8)
            let a: Int = random.int(3...10)
            let b: Int = random.int(3...10)
            let forward: Bool = random.int(0...1) == 0
            let tilt: Int = random.int(-1...1)
            let layer: Int = 4 * ranks[body] - 12
            let table: [(Int, Int)] = referenceTable(period)
            var orbit: [CelestialEclipseLabVector] = []
            for k in 0..<period {
                let step: Int = forward ? k : (period - k) % period
                let cosine: Int = table[step].0
                let sine: Int = table[step].1
                orbit.append(CelestialEclipseLabVector(cx + referenceScaled(a, cosine), cy + referenceScaled(b, sine),
                                                       layer + referenceScaled(tilt, sine)))
            }
            let radius: Int = random.int(1...4)
            bodies.append(CelestialEclipseLabBody(orbit: orbit, radius: radius, fixed: body == 0))
        }
        // 4. The horizon, the winning phases, the target count.
        let horizon: Int = random.int(profile.horizon)
        var winning: [Int] = []
        for body in bodies { winning.append(random.int(0...(body.orbit.count - 1))) }
        let targetCount: Int = random.int(profile.targets)
        let all: [Event] = events(bodies, horizon: horizon, phases: winning)
        if all.count < targetCount {
            return Drawn(count: count, ranks: ranks, bodies: bodies, horizon: horizon, winning: winning,
                         targetCount: targetCount, events: all, target: [], phases: winning, moved: 0,
                         reason: .tooFewEvents)
        }
        // 5. The target: the first targetCount events, each window drawn open then close.
        var target: [CelestialEclipseLabTarget] = []
        for position in 0..<targetCount {
            let event: Event = all[position]
            let open: Int = max(0, event.first - random.int(0...2))
            let close: Int = min(horizon - 1, event.first + random.int(0...2))
            target.append(CelestialEclipseLabTarget(front: event.front, back: event.back, open: open, close: close))
        }
        // 6. The moved count (a one-value draw), then each a drawn movable body given a drawn different phase.
        var phases: [Int] = winning
        var pool: [Int] = []
        for body in 1..<count { pool.append(body) }
        let moved: Int = min(random.int(profile.moved...profile.moved), pool.count)
        for _ in 0..<moved {
            let body: Int = pool.remove(at: random.int(0...(pool.count - 1)))
            var offset: Int = random.int(0...(bodies[body].orbit.count - 2))
            if offset >= winning[body] { offset += 1 }
            phases[body] = offset
        }
        let won: Bool = wins(events(bodies, horizon: horizon, phases: phases), target)
        return Drawn(count: count, ranks: ranks, bodies: bodies, horizon: horizon, winning: winning,
                     targetCount: targetCount, events: all, target: target, phases: phases, moved: moved,
                     reason: won ? .alreadyWon : .none)
    }

    /// The (front, back) pairs of `level`'s target, read here.
    static func targetPairs(_ level: CelestialEclipseLabLevel) -> [[Int]] {
        var result: [[Int]] = []
        for eclipse in level.target { result.append([eclipse.front, eclipse.back]) }
        return result
    }

    /// Whether candidate `index` of `entry` passes `generate`'s plan filters (ignoring the neighbour rule).
    static func qualifies(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> Bool {
        guard let level = CelestialEclipseLabGenerator.candidate(entry, index: index) else { return false }
        let range: ClosedRange<Int> = documented[entry.band - 1].planRange
        guard let plan = CelestialEclipseLabSolver.plan(level, maxChanges: range.upperBound) else { return false }
        return range.contains(plan.size) && plan.size <= entry.budget
    }

    /// Checks `level`, candidate `index` of `entry`, against its band profile, the kernel ranges, the depth order and
    /// the independently re-drawn winning phases.
    static func checkValues(_ level: CelestialEclipseLabLevel, _ entry: CelestialEclipseLabManifestEntry, index: Int) {
        let profile: CelestialEclipseLabBandProfile = documented[entry.band - 1]
        let label: String = "entry \(entry.number) candidate \(index)"
        #expect(level.id == String(format: "celestial-eclipse-lab-%03d", entry.number), "\(label)")
        #expect(level.seed == entry.seed, "\(label)")
        #expect(level.difficulty == entry.band, "\(label)")
        #expect(level.tutorial == (entry.number <= 3), "\(label)")
        #expect(level.budget == entry.budget, "\(label)")
        #expect(profile.bodies.contains(level.bodies.count), "\(label)")
        #expect(profile.horizon.contains(level.horizon), "\(label)")
        #expect(profile.targets.contains(level.target.count), "\(label)")
        #expect(CelestialEclipseLabLevel.bodyCounts.contains(level.bodies.count), "\(label)")
        #expect(CelestialEclipseLabLevel.horizons.contains(level.horizon), "\(label)")
        #expect(CelestialEclipseLabLevel.targetCounts.contains(level.target.count), "\(label)")
        #expect(CelestialEclipseLabLevel.budgets.contains(level.budget), "\(label)")
        var layers: Set<Int> = []
        for (number, body) in level.bodies.enumerated() {
            #expect(body.fixed == (number == 0), "\(label) body \(number)")
            #expect((4...8).contains(body.period), "\(label) body \(number)")
            #expect((1...4).contains(body.radius), "\(label) body \(number)")
            for p in body.orbit {
                #expect(CelestialEclipseLabLevel.coordinates.contains(p.x), "\(label)")
                #expect(CelestialEclipseLabLevel.coordinates.contains(p.y), "\(label)")
                #expect(CelestialEclipseLabLevel.coordinates.contains(p.z), "\(label)")
            }
            // Position 0 has sine 0, so its depth is the body's layer 4·rank − 12.
            layers.insert(body.orbit[0].z)
        }
        var expectedLayers: Set<Int> = []
        for rank in 0..<level.bodies.count { expectedLayers.insert(4 * rank - 12) }
        #expect(layers == expectedLayers, "\(label)")
        for i in 0..<level.bodies.count {
            var j: Int = i + 1
            while j < level.bodies.count {
                let ordered: Bool = level.bodies[i].nearestBack > level.bodies[j].farthestFront
                    || level.bodies[j].nearestBack > level.bodies[i].farthestFront
                #expect(ordered, "\(label) pair \(i) \(j)")
                j += 1
            }
        }
        // The target is the first target-count events of the winning phases' timeline.
        let drawn: Drawn = redraw(entry, index: index)
        let all: [Event] = events(level.bodies, horizon: level.horizon, phases: drawn.winning)
        #expect(all.count >= level.target.count, "\(label)")
        for (position, eclipse) in level.target.enumerated() where position < all.count {
            let event: Event = all[position]
            #expect(eclipse.front == event.front && eclipse.back == event.back, "\(label) target \(position)")
            #expect(level.bodies[eclipse.front].nearestBack > level.bodies[eclipse.back].farthestFront, "\(label)")
            #expect(eclipse.open <= event.first && event.first <= eclipse.close, "\(label) target \(position)")
            #expect(eclipse.open >= max(0, event.first - 2), "\(label) target \(position)")
            #expect(eclipse.close <= min(level.horizon - 1, event.first + 2), "\(label) target \(position)")
        }
        #expect(CelestialEclipseLabSky.timeline(level, phases: drawn.winning).wins, "\(label)")
        #expect(!level.startTimeline.wins, "\(label)")
        // Exactly min(moved, movable) movable bodies differ from their winning phases; body 0 never does.
        var differing: Int = 0
        for body in 0..<level.bodies.count where level.phases[body] != drawn.winning[body] {
            #expect(body != 0, "\(label)")
            differing += 1
        }
        #expect(differing == min(profile.moved, level.bodies.count - 1), "\(label)")
    }

    @Test("the manifest: 100 entries, 20 per band, budgets in the band's range, five emphases")
    func manifest() {
        let entries: [CelestialEclipseLabManifestEntry] = CelestialEclipseLabManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        var perEmphasis: [String: Int] = [:]
        var seeds: Set<UInt64> = []
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1, "entry \(entry.number)")
            let low: Int = 8 + 2 * (entry.band - 1)
            #expect((low...(low + 3)).contains(entry.budget), "entry \(entry.number)")
            #expect(Self.emphases.contains(entry.emphasis), "entry \(entry.number)")
            perBand[entry.band, default: 0] += 1
            perEmphasis[entry.emphasis, default: 0] += 1
            seeds.insert(entry.seed)
        }
        for band in 1...5 { #expect(perBand[band] == 20) }
        for emphasis in Self.emphases { #expect(perEmphasis[emphasis] == 20) }
        #expect(seeds.count == 100)
    }

    @Test("band profiles of clarification Q1 and the clamp")
    func bandProfiles() {
        for band in 1...5 {
            #expect(CelestialEclipseLabBandProfile.of(band: band) == Self.documented[band - 1], "band \(band)")
        }
        #expect(CelestialEclipseLabBandProfile.of(band: 0) == .of(band: 1))
        #expect(CelestialEclipseLabBandProfile.of(band: -4) == .of(band: 1))
        #expect(CelestialEclipseLabBandProfile.of(band: 6) == .of(band: 5))
        #expect(CelestialEclipseLabBandProfile.of(band: 99) == .of(band: 5))
        let first: CelestialEclipseLabBandProfile = .of(band: 1)
        #expect(first.bodies == 3...3)
        #expect(first.targets == 1...2)
        #expect(first.horizon == 24...32)
        #expect(first.moved == 2)
        #expect(first.planRange == 1...2)
        let fifth: CelestialEclipseLabBandProfile = .of(band: 5)
        #expect(fifth.bodies == 6...6)
        #expect(fifth.targets == 3...4)
        #expect(fifth.horizon == 40...48)
        #expect(fifth.moved == 5)
        #expect(fifth.planRange == 4...5)
    }

    @Test("level ids, bounds and the generation reason code")
    func levelIDsAndBounds() {
        #expect(CelestialEclipseLabGenerator.levelID(1) == "celestial-eclipse-lab-001")
        #expect(CelestialEclipseLabGenerator.levelID(42) == "celestial-eclipse-lab-042")
        #expect(CelestialEclipseLabGenerator.levelID(100) == "celestial-eclipse-lab-100")
        #expect(CelestialEclipseLabGenerator.maxCandidates == 256)
        #expect(CelestialEclipseLabGenerator.catalogID == "celestial-eclipse-lab")
        #expect(CelestialEclipseLabError.generation(7).reasonCode == "r02-g17.generation")
        #expect(CelestialEclipseLabError.generation(7) != .generation(8))
    }

    @Test("the integer unit-circle table equals round(1000·cos), round(1000·sin)")
    func unitCircle() {
        let table: [Int: [(Int, Int)]] = CelestialEclipseLabGenerator.unitCircle
        #expect(table.keys.sorted() == [4, 5, 6, 7, 8])
        for period in 4...8 {
            guard let rows = table[period] else {
                Issue.record("period \(period) missing")
                continue
            }
            #expect(rows.count == period, "period \(period)")
            let reference: [(Int, Int)] = Self.referenceTable(period)
            for k in 0..<min(rows.count, period) {
                #expect(abs(rows[k].0) <= 1000 && abs(rows[k].1) <= 1000, "period \(period) row \(k)")
                #expect(rows[k].0 == reference[k].0, "period \(period) row \(k) cos")
                #expect(rows[k].1 == reference[k].1, "period \(period) row \(k) sin")
            }
            if let zero = rows.first {
                #expect(zero.0 == 1000 && zero.1 == 0, "period \(period)")
            }
        }
    }

    @Test("scaled rounds half away from zero")
    func scaledRounding() {
        #expect(CelestialEclipseLabGenerator.scaled(3, 500) == 2)
        #expect(CelestialEclipseLabGenerator.scaled(-3, 500) == -2)
        #expect(CelestialEclipseLabGenerator.scaled(3, -500) == -2)
        #expect(CelestialEclipseLabGenerator.scaled(-3, -500) == 2)
        #expect(CelestialEclipseLabGenerator.scaled(1, 500) == 1)
        #expect(CelestialEclipseLabGenerator.scaled(-1, 500) == -1)
        #expect(CelestialEclipseLabGenerator.scaled(1, 499) == 0)
        #expect(CelestialEclipseLabGenerator.scaled(-1, 499) == 0)
        #expect(CelestialEclipseLabGenerator.scaled(0, 951) == 0)
        #expect(CelestialEclipseLabGenerator.scaled(10, 1000) == 10)
        #expect(CelestialEclipseLabGenerator.scaled(-10, -1000) == 10)
        for value in -10...10 {
            for unit in [-1000, -975, -951, -866, -809, -707, -588, -500, -223, 0, 309, 434, 623, 782, 1000] {
                #expect(CelestialEclipseLabGenerator.scaled(value, unit) == Self.referenceScaled(value, unit),
                        "scaled(\(value), \(unit))")
            }
        }
    }

    @Test("candidates and generation are deterministic; indices differ")
    func determinism() throws {
        for number in Self.redrawNumbers {
            let entry: CelestialEclipseLabManifestEntry = Self.entry(number)
            var fingerprints: Set<String> = []
            var valid: Int = 0
            for index in 0..<6 {
                let first: CelestialEclipseLabLevel? = CelestialEclipseLabGenerator.candidate(entry, index: index)
                let second: CelestialEclipseLabLevel? = CelestialEclipseLabGenerator.candidate(entry, index: index)
                #expect(first == second, "entry \(number) candidate \(index)")
                #expect(first?.fingerprint == second?.fingerprint)
                if let level = first {
                    valid += 1
                    fingerprints.insert(level.fingerprint)
                }
            }
            #expect(fingerprints.count == valid, "entry \(number)")
        }
        let entry: CelestialEclipseLabManifestEntry = Self.entry(1)
        let a: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry, previous: nil)
        let b: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry, previous: nil)
        #expect(a == b)
        #expect(a.level.fingerprint == b.level.fingerprint)
    }

    @Test("the drawing order of clarification Q1, re-drawn independently")
    func drawingOrder() {
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: CelestialEclipseLabManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let label: String = "entry \(number) candidate \(index)"
                let drawn: Drawn = Self.redraw(entry, index: index)
                let level: CelestialEclipseLabLevel? = CelestialEclipseLabGenerator.candidate(entry, index: index)
                guard let level else {
                    // A nil candidate must be explained by the re-draw: too few events or already won.
                    #expect(drawn.reason != .none, "\(label): nil but the re-draw finds a valid level")
                    continue
                }
                #expect(drawn.reason == .none, "\(label): a level but the re-draw finds \(drawn.reason)")
                compared += 1
                #expect(level.bodies.count == drawn.count, "\(label)")
                #expect(level.bodies == drawn.bodies, "\(label) bodies")
                #expect(level.horizon == drawn.horizon, "\(label) horizon")
                #expect(level.target == drawn.target, "\(label) target")
                #expect(level.phases == drawn.phases, "\(label) phases")
                #expect(level.target.count == drawn.targetCount, "\(label)")
                let rebuilt: CelestialEclipseLabLevel? = try? CelestialEclipseLabLevel(
                    id: String(format: "celestial-eclipse-lab-%03d", entry.number), seed: entry.seed,
                    difficulty: entry.band, bodies: drawn.bodies, horizon: drawn.horizon, target: drawn.target,
                    phases: drawn.phases, budget: entry.budget, tutorial: entry.number <= 3)
                #expect(rebuilt?.fingerprint == level.fingerprint, "\(label) fingerprint")
            }
        }
        #expect(compared > 0)
    }

    @Test("nil candidates are explained by the level rules or the event count")
    func nilCandidates() {
        for number in Self.redrawNumbers {
            let entry: CelestialEclipseLabManifestEntry = Self.entry(number)
            for index in 0..<12 {
                let drawn: Drawn = Self.redraw(entry, index: index)
                let level: CelestialEclipseLabLevel? = CelestialEclipseLabGenerator.candidate(entry, index: index)
                let label: String = "entry \(number) candidate \(index)"
                switch drawn.reason {
                case .none: #expect(level != nil, "\(label)")
                case .tooFewEvents:
                    #expect(level == nil, "\(label)")
                    #expect(drawn.events.count < drawn.targetCount, "\(label)")
                case .alreadyWon:
                    #expect(level == nil, "\(label)")
                    var refusal: CelestialEclipseLabError? = nil
                    do {
                        _ = try CelestialEclipseLabLevel(
                            id: CelestialEclipseLabGenerator.levelID(entry.number), seed: entry.seed,
                            difficulty: entry.band, bodies: drawn.bodies, horizon: drawn.horizon,
                            target: drawn.target, phases: drawn.phases, budget: entry.budget,
                            tutorial: entry.number <= 3)
                    } catch {
                        refusal = error
                    }
                    #expect(refusal == .level("already won"), "\(label)")
                }
            }
        }
    }

    @Test("every candidate holds its band's values, the kernel ranges and the depth order")
    func candidateValues() {
        var checked: Int = 0
        for entry in CelestialEclipseLabManifest.entries where entry.number % 7 == 1 || entry.number <= 3 {
            for index in 0..<4 {
                guard let level = CelestialEclipseLabGenerator.candidate(entry, index: index) else { continue }
                Self.checkValues(level, entry, index: index)
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test("generate keeps the first qualifying candidate, its plan in the band's range and the budget")
    func filters() throws {
        var levels: [CelestialEclipseLabLevel] = []
        for number in Self.generateNumbers {
            let entry: CelestialEclipseLabManifestEntry = Self.entry(number)
            let generated: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry,
                                                                                                     previous: nil)
            let range: ClosedRange<Int> = Self.documented[entry.band - 1].planRange
            #expect(generated.entry == entry)
            #expect(generated.skipped >= 0 && generated.skipped < CelestialEclipseLabGenerator.maxCandidates)
            #expect(range.contains(generated.plan.size), "entry \(number)")
            #expect(generated.plan.size <= entry.budget, "entry \(number)")
            #expect(generated.plan.settingsByDepth.count == generated.plan.size, "entry \(number)")
            #expect(generated.level == CelestialEclipseLabGenerator.candidate(entry, index: generated.skipped))
            #expect(generated.difficulty == CelestialEclipseLabDifficulty(level: generated.level,
                                                                           plan: generated.plan))
            #expect(CelestialEclipseLabSolver.wins(generated.level, actions: generated.plan.actions), "entry \(number)")
            Self.checkValues(generated.level, entry, index: generated.skipped)
            for index in 0..<generated.skipped {
                #expect(!Self.qualifies(entry, index: index), "entry \(number) candidate \(index)")
            }
            levels.append(generated.level)
        }
        let digest: String = CelestialEclipseLabGenerator.catalogDigest(levels)
        #expect(digest == CelestialEclipseLabGenerator.catalogDigest(levels))
        #expect(digest != CelestialEclipseLabGenerator.catalogDigest(levels.reversed()))
    }

    @Test("the neighbour rule skips a candidate whose target pairs equal the previous level's")
    func neighbourRule() throws {
        for number in [1, 21, 41] {
            let entry: CelestialEclipseLabManifestEntry = Self.entry(number)
            let alone: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry, previous: nil)
            let pairs: [[Int]] = Self.targetPairs(alone.level)
            #expect(CelestialEclipseLabGenerator.pairs(alone.level) == pairs)
            // The previous level is the very candidate generate would otherwise return.
            let after: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry,
                                                                                                 previous: alone.level)
            #expect(after.level != alone.level, "entry \(number)")
            #expect(Self.targetPairs(after.level) != pairs, "entry \(number)")
            #expect(after.skipped > alone.skipped, "entry \(number)")
            // Between the two, every candidate fails a filter or repeats the pairs.
            var index: Int = alone.skipped + 1
            while index < after.skipped {
                if let level = CelestialEclipseLabGenerator.candidate(entry, index: index),
                   Self.targetPairs(level) != pairs {
                    #expect(!Self.qualifies(entry, index: index), "entry \(number) candidate \(index)")
                }
                index += 1
            }
            // A previous level with other pairs leaves the first qualifying candidate in place.
            let back: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry,
                                                                                                previous: after.level)
            #expect(back.skipped == alone.skipped, "entry \(number)")
            #expect(back.level == alone.level, "entry \(number)")
        }
    }

    @Test("past the candidate bound generate refuses with .generation(number)")
    func refusal() {
        // Entries whose every candidate the level rules refuse, so the 256 candidates are cheap (no solver runs):
        // band 0 gives difficulty 0 (outside 1 … 5) with band 1's profile, budget 30 and budget 0 lie outside the
        // budgets 1 … 24. A budget below the plan range (budget 1 for band 5, plans 4 … 5) would also refuse, but it
        // runs the solver on up to 256 band-5 candidates (each up to tens of thousands of settings), far beyond a
        // short test; budget 1 for band 1 does not force a refusal at all, since a one-change plan fits it.
        let seed: UInt64 = Self.entry(7).seed
        let cases: [CelestialEclipseLabManifestEntry] = [
            CelestialEclipseLabManifestEntry(number: 7, seed: seed, band: 0, budget: 9, emphasis: "commit order"),
            CelestialEclipseLabManifestEntry(number: 55, seed: Self.entry(55).seed, band: 3, budget: 30,
                                             emphasis: "set orbital phase"),
            CelestialEclipseLabManifestEntry(number: 88, seed: Self.entry(88).seed, band: 5, budget: 0,
                                             emphasis: "set orbital phase"),
        ]
        for entry in cases {
            var refusal: CelestialEclipseLabError? = nil
            do {
                _ = try CelestialEclipseLabGenerator.generate(entry, previous: nil)
            } catch {
                refusal = error
            }
            #expect(refusal == .generation(entry.number), "entry \(entry.number)")
            #expect(refusal?.reasonCode == "r02-g17.generation")
            for index in 0..<4 {
                #expect(CelestialEclipseLabGenerator.candidate(entry, index: index) == nil, "entry \(entry.number)")
            }
        }
    }
}
