// BinaryGardensGeneratorTests — feature 502 (R02-G21-02) T-R02G2102-004 (FR-R02G2102-001, 007, 009; SC-R02G2102-001,
// 003, 004; clarification Q1; research R4, R5, R7, R12, R15). Host checks of the level generator: the manifest (100
// entries, 20 per band, budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, five emphases × 20); the level ids;
// candidate and generation determinism; the band profiles exactly as clarification Q1 writes them (confirmed unchanged
// by the research R4 measurement of 2026-11-27); the drawing order of clarification Q1 and research R15, re-derived
// draw by draw from the seed for every drawn candidate of indices 0 … 5 of the first two entries of every band; those
// candidates against their band profile and the kernel ranges (adjustable count, rings, radii, luminosity levels 4 … 32,
// phase step, T_max, worlds, σ, ω, clamp radius 2 … 4, world radius largest ring + 3 … min(60, largest + 20), world
// phase 0 … 47, world speed ±1 … ±3, tolerance, the emphasised control adjustable); the winning and starting phases
// on the band's grid; the start differing from the winning arrangement in exactly the band's plan length of adjustable
// controls, locked controls at their winning values; the bounds of `bounds(flux:trim:comfort:lethal:bloom:slack:)` on
// hand fluxes (exact values, the c_lo = 0 skip, the λ_hi guard tested as a bound: at most 166 400 under the kernel's
// 128 000-milliflux cap) and containing every winning run (no lethal tick, window and bloom kept); `isReducible`; ids,
// tutorial (levels 1 … 3), difficulty (= band) and budget; the filters of `generate` (`skipped` is the first candidate
// whose ring radii and worlds differ from the previous level's and whose minimal plan has the band's plan length and
// replays); the neighbour rule (FR-R02G2102-007) with the accepted level itself as the previous one; the refusal
// `.generation(number)` provoked with an entry whose budget the kernel refuses, so every candidate is nil; and the
// catalog digest; and the content pipeline's sources (Core/Content: manifest, difficulty, solver, generator, witness)
// hold no clock, time interval, floating point or run-time trigonometry, as feature 501's kernel sources do. Only a
// handful of entries are generated (cached in a `static let`), never the whole catalog. Explicit types and plain loops
// keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensGeneratorTests {
    typealias Control = BinaryGardensControl

    /// The first two manifest numbers of every band.
    static let bandPairs: [Int] = [1, 2, 21, 22, 41, 42, 61, 62, 81, 82]

    /// The candidate indices checked against their band per sampled entry.
    static let rangeIndices: Range<Int> = 0..<6

    /// The generated levels of `bandPairs`, each pair chained as in the catalog (the second's previous is the first).
    static let generated: [Int: BinaryGardensGenerated] = {
        var result: [Int: BinaryGardensGenerated] = [:]
        var index: Int = 0
        while index < bandPairs.count {
            let first: BinaryGardensGenerated? = try? BinaryGardensGenerator.generate(entry(bandPairs[index]),
                                                                                      previous: nil)
            if let first {
                result[bandPairs[index]] = first
                let second: BinaryGardensGenerated? = try? BinaryGardensGenerator.generate(
                    entry(bandPairs[index + 1]), previous: first.level)
                if let second { result[bandPairs[index + 1]] = second }
            }
            index += 2
        }
        return result
    }()

    /// The drafts of `bandPairs` at `rangeIndices`, keyed "number/index" (nil drafts are left out).
    static let drafts: [String: BinaryGardensDraft] = {
        var result: [String: BinaryGardensDraft] = [:]
        for number in bandPairs {
            for index in rangeIndices {
                if let draft = BinaryGardensGenerator.draft(entry(number), index: index) {
                    result["\(number)/\(index)"] = draft
                }
            }
        }
        return result
    }()

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> BinaryGardensManifestEntry { BinaryGardensManifest.entries[number - 1] }

    /// The controls of `level` that are adjustable, in the fixed order.
    static func adjustable(_ level: BinaryGardensLevel) -> [Control] {
        var result: [Control] = []
        for control in Control.allCases where control.isAdjustable(in: level) { result.append(control) }
        return result
    }

    @Test func manifestHasTheHundredPlannedEntries() {
        let entries: [BinaryGardensManifestEntry] = BinaryGardensManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        var perEmphasis: [String: Int] = [:]
        var seeds: Set<UInt64> = []
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1, "entry \(entry.number)")
            let low: Int = 6 + 2 * entry.band
            #expect((low...(low + 3)).contains(entry.budget), "entry \(entry.number)")
            #expect(BinaryGardensLevel.budgets.contains(entry.budget))
            perBand[entry.band, default: 0] += 1
            perEmphasis[entry.emphasis, default: 0] += 1
            seeds.insert(entry.seed)
        }
        #expect(seeds.count == 100)
        #expect(perBand == [1: 20, 2: 20, 3: 20, 4: 20, 5: 20])
        #expect(perEmphasis == ["adjust orbit": 20, "phase twin stars": 20, "set luminosity": 20, "watch world": 20,
                                "commit light window": 20])
        #expect(entries[0] == BinaryGardensManifestEntry(number: 1, seed: 0xb483df8eac48b035, band: 1, budget: 9,
                                                          emphasis: "watch world"))
        #expect(BinaryGardensManifest.provenance.contains("6.21.18"))
    }

    @Test func levelIDsAreZeroPadded() {
        #expect(BinaryGardensGenerator.levelID(1) == "binary-gardens-001")
        #expect(BinaryGardensGenerator.levelID(42) == "binary-gardens-042")
        #expect(BinaryGardensGenerator.levelID(100) == "binary-gardens-100")
        #expect(BinaryGardensGenerator.catalogID == "binary-gardens")
        #expect(BinaryGardensGenerator.maxRedraws == 16)
    }

    /// Clarification Q1's profiles (adjustable controls, rings, luminosity levels, phase step, T_max, worlds, σ, ω
    /// maximum, trim k, m ‰, ℓ ‰, b ‰, s, E, plan p), confirmed by the research R4 measurement.
    @Test func bandProfilesMatchTheClarification() {
        let expected: [BinaryGardensBandProfile] = [
            BinaryGardensBandProfile(adjustable: 2, rings: 3...3, ringRadii: 2...12, luminosities: 2...2, phaseStep: 8,
                                     maxTilt: 2...2, worlds: 1...1, separation: 0...0, maxStarSpeed: 1, trim: 1,
                                     comfortMargin: 60...90, lethalMargin: 300, bloomMargin: 150, windowSlack: 4...8,
                                     tolerance: 6...8, plan: 1),
            BinaryGardensBandProfile(adjustable: 3, rings: 3...4, ringRadii: 2...12, luminosities: 2...3, phaseStep: 8,
                                     maxTilt: 2...3, worlds: 1...2, separation: 0...0, maxStarSpeed: 2, trim: 4,
                                     comfortMargin: 40...70, lethalMargin: 250, bloomMargin: 100, windowSlack: 3...6,
                                     tolerance: 4...6, plan: 2),
            BinaryGardensBandProfile(adjustable: 4, rings: 4...4, ringRadii: 2...16, luminosities: 3...3, phaseStep: 6,
                                     maxTilt: 3...3, worlds: 2...2, separation: 2...4, maxStarSpeed: 2, trim: 6,
                                     comfortMargin: 30...50, lethalMargin: 200, bloomMargin: 80, windowSlack: 2...4,
                                     tolerance: 3...5, plan: 3),
            BinaryGardensBandProfile(adjustable: 5, rings: 4...5, ringRadii: 2...16, luminosities: 3...3, phaseStep: 6,
                                     maxTilt: 3...3, worlds: 2...3, separation: 2...5, maxStarSpeed: 3, trim: 8,
                                     comfortMargin: 20...40, lethalMargin: 150, bloomMargin: 60, windowSlack: 1...3,
                                     tolerance: 2...4, plan: 3),
            BinaryGardensBandProfile(adjustable: 5, rings: 5...5, ringRadii: 2...16, luminosities: 3...4, phaseStep: 6,
                                     maxTilt: 3...3, worlds: 3...3, separation: 3...6, maxStarSpeed: 3, trim: 10,
                                     comfortMargin: 10...30, lethalMargin: 100, bloomMargin: 40, windowSlack: 0...2,
                                     tolerance: 1...3, plan: 4),
        ]
        var plans: [Int] = []
        for band in 1...5 {
            #expect(BinaryGardensBandProfile.of(band: band) == expected[band - 1], "band \(band)")
            plans.append(BinaryGardensBandProfile.of(band: band).plan)
        }
        #expect(BinaryGardensBandProfile.of(band: 6) == expected[4])
        #expect(plans == [1, 2, 3, 3, 4])
    }

    @Test func candidatesAndGenerationAreDeterministic() throws {
        for number in [1, 41, 81] {
            let entry: BinaryGardensManifestEntry = Self.entry(number)
            for index in 0..<3 {
                #expect(BinaryGardensGenerator.candidate(entry, index: index)
                            == BinaryGardensGenerator.candidate(entry, index: index), "entry \(number) \(index)")
            }
            let cached: BinaryGardensGenerated = try #require(Self.generated[number])
            let again: BinaryGardensGenerated = try BinaryGardensGenerator.generate(entry, previous: nil)
            #expect(again == cached, "entry \(number)")
            #expect(again.level.fingerprint == cached.level.fingerprint)
        }
    }

    /// The draws of clarification Q1 and research R15, re-derived from the seed and compared value by value.
    @Test func candidatesFollowTheDrawingOrder() throws {
        var checked: Int = 0
        for number in Self.bandPairs {
            let entry: BinaryGardensManifestEntry = Self.entry(number)
            let profile: BinaryGardensBandProfile = .of(band: entry.band)
            for index in Self.rangeIndices {
                guard let draft = Self.drafts["\(number)/\(index)"] else { continue }
                let level: BinaryGardensLevel = draft.level
                let label: String = "entry \(number) candidate \(index)"
                checked += 1
                var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
                var adjustable: [Control] = []
                var pool: [Control] = Control.allCases
                let offsets: [String: Int] = ["adjust orbit": 0, "phase twin stars": 1, "set luminosity": 2]
                if let offset = offsets[entry.emphasis] {
                    let control: Control = try #require(Control(rawValue: random.int(0...1) * 3 + offset))
                    adjustable.append(control)
                    pool.removeAll { $0 == control }
                }
                var i: Int = 0
                while adjustable.count < profile.adjustable {
                    pool.swapAt(i, i + random.index(below: pool.count - i))
                    adjustable.append(pool[i])
                    i += 1
                }
                #expect(draft.adjustable == adjustable, "\(label)")
                #expect(Self.adjustable(level) == adjustable.sorted { $0.rawValue < $1.rawValue }, "\(label)")
                #expect(level.starSpeed == random.int(1...profile.maxStarSpeed), "\(label)")
                let ringCount: Int = random.int(profile.rings)
                var radii: [Int] = []
                while radii.count < ringCount {
                    let value: Int = random.int(profile.ringRadii)
                    if !radii.contains(value) { radii.append(value) }
                }
                #expect(level.ringRadii == radii.sorted(), "\(label)")
                let luminosityCount: Int = random.int(profile.luminosities)
                var luminosities: [Int] = []
                while luminosities.count < luminosityCount {
                    let value: Int = random.int(4...32)
                    if !luminosities.contains(value) { luminosities.append(value) }
                }
                #expect(level.luminosityLevels == luminosities.sorted(), "\(label)")
                #expect(level.phaseStep == profile.phaseStep, "\(label)")
                let maxTilt: Int = adjustable.contains(.tilt) ? random.int(profile.maxTilt) : 0
                #expect(level.maxTilt == maxTilt, "\(label)")
                #expect(level.minimumSeparation == random.int(profile.separation), "\(label)")
                #expect(level.clampRadius == random.int(2...4), "\(label)")
                // The winning arrangement, redrawn until the stars keep σ.
                var winning: BinaryGardensArrangement?
                for _ in 0..<16 where winning == nil {
                    var rings: [Int] = []
                    var phases: [Int] = []
                    var lights: [Int] = []
                    for _ in 0..<2 {
                        rings.append(random.int(0...(radii.count - 1)))
                        phases.append(profile.phaseStep * random.int(0...(48 / profile.phaseStep - 1)))
                        lights.append(random.int(0...(luminosities.count - 1)))
                    }
                    let drawn = BinaryGardensArrangement(rings: rings, phases: phases, luminosities: lights,
                                                         tilt: random.int(0...maxTilt))
                    if BinaryGardensSky.keepsSeparation(level, arrangement: drawn) { winning = drawn }
                }
                #expect(draft.winning == winning, "\(label)")
                // The worlds' orbits, then the margins, then the tolerance.
                let largest: Int = radii.max() ?? 0
                let worldCount: Int = random.int(profile.worlds)
                #expect(level.worlds.count == worldCount, "\(label)")
                var orbits: [[Int]] = []
                for _ in 0..<worldCount {
                    let radius: Int = random.int((largest + 3)...min(60, largest + 20))
                    let phase: Int = random.int(0...47)
                    let magnitude: Int = random.int(1...3)
                    orbits.append([radius, phase, random.index(below: 2) == 1 ? -magnitude : magnitude])
                }
                var margins: [[Int]] = []
                for _ in 0..<worldCount {
                    margins.append([random.int(profile.comfortMargin), random.int(profile.windowSlack)])
                }
                for (w, world) in level.worlds.enumerated() where w < orbits.count {
                    #expect([world.radius, world.phase, world.speed] == orbits[w], "\(label) world \(w)")
                }
                #expect(level.lethalTolerance == random.int(profile.tolerance), "\(label)")
                // Each world's bounds from the winning run with its drawn margins.
                let won: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: draft.winning)
                for (w, world) in level.worlds.enumerated() where w < margins.count {
                    let b: BinaryGardensWorldBounds? = BinaryGardensGenerator.bounds(
                        flux: won.worlds[w].flux, trim: profile.trim, comfort: margins[w][0],
                        lethal: profile.lethalMargin, bloom: profile.bloomMargin, slack: margins[w][1])
                    let expected = BinaryGardensWorldBounds(lethalLow: world.lethalLow, comfortLow: world.comfortLow,
                                                            comfortHigh: world.comfortHigh,
                                                            lethalHigh: world.lethalHigh, window: world.window,
                                                            bloomLow: world.bloomLow, bloomHigh: world.bloomHigh)
                    #expect(b == expected, "\(label) world \(w)")
                }
                // The changed controls by a partial shuffle of the adjustable ones, then their starting values.
                var changedPool: [Control] = adjustable
                var changed: [Control] = []
                for k in 0..<profile.plan {
                    changedPool.swapAt(k, k + random.index(below: changedPool.count - k))
                    changed.append(changedPool[k])
                }
                #expect(draft.changed == changed, "\(label)")
                var start: BinaryGardensArrangement?
                for _ in 0..<16 where start == nil {
                    var drawn: BinaryGardensArrangement = try #require(winning)
                    for control in changed {
                        var others: [Int] = []
                        for value in control.values(in: level) where value != control.value(of: draft.winning) {
                            others.append(value)
                        }
                        drawn = control.setting(others[random.int(0...(others.count - 1))], in: drawn)
                    }
                    if BinaryGardensSky.keepsSeparation(level, arrangement: drawn) { start = drawn }
                }
                #expect(level.start == start, "\(label)")
            }
        }
        #expect(checked >= 20, "checked \(checked)")
    }

    @Test func candidatesRespectTheirBandAndTheKernelRanges() {
        var checked: Int = 0
        for number in Self.bandPairs {
            let entry: BinaryGardensManifestEntry = Self.entry(number)
            let profile: BinaryGardensBandProfile = .of(band: entry.band)
            for index in Self.rangeIndices {
                guard let draft = Self.drafts["\(number)/\(index)"] else { continue }
                let level: BinaryGardensLevel = draft.level
                let label: String = "entry \(number) candidate \(index)"
                checked += 1
                let adjustable: [Control] = Self.adjustable(level)
                #expect(adjustable.count == profile.adjustable, "\(label)")
                #expect(profile.rings.contains(level.ringRadii.count), "\(label)")
                for radius in level.ringRadii { #expect(profile.ringRadii.contains(radius), "\(label)") }
                #expect(profile.luminosities.contains(level.luminosityLevels.count), "\(label)")
                for value in level.luminosityLevels {
                    #expect(BinaryGardensGenerator.luminosityRange.contains(value), "\(label)")
                    #expect((4...32).contains(value), "\(label)")
                }
                #expect(level.phaseStep == profile.phaseStep, "\(label)")
                #expect(level.maxTilt == 0 || profile.maxTilt.contains(level.maxTilt), "\(label)")
                #expect((level.maxTilt > 0) == adjustable.contains(.tilt), "\(label)")
                #expect(profile.worlds.contains(level.worlds.count), "\(label)")
                #expect(profile.separation.contains(level.minimumSeparation), "\(label)")
                #expect((1...profile.maxStarSpeed).contains(level.starSpeed), "\(label)")
                #expect((2...4).contains(level.clampRadius), "\(label)")
                #expect(profile.tolerance.contains(level.lethalTolerance), "\(label)")
                let largest: Int = level.ringRadii[level.ringRadii.count - 1]
                for world in level.worlds {
                    #expect(world.radius >= largest + 3 && world.radius <= min(60, largest + 20), "\(label)")
                    #expect((0...47).contains(world.phase), "\(label)")
                    #expect((1...3).contains(abs(world.speed)), "\(label)")
                    #expect(world.comfortLow >= 1 && world.lethalHigh <= 166_400, "\(label)")
                }
                // The emphasised control is adjustable.
                let offsets: [String: Int] = ["adjust orbit": 0, "phase twin stars": 1, "set luminosity": 2]
                if let offset = offsets[entry.emphasis] {
                    var emphasised: Bool = false
                    for control in adjustable where control.rawValue % 3 == offset && control != .tilt {
                        emphasised = true
                    }
                    #expect(emphasised, "\(label)")
                    let first: Control? = draft.adjustable.first
                    #expect(first != nil && first != .tilt && (first?.rawValue ?? -1) % 3 == offset, "\(label)")
                }
                // Phases on the grid; the start differs from the winning arrangement in exactly p adjustable controls.
                for star in 0..<2 {
                    #expect(level.start.phases[star] % profile.phaseStep == 0, "\(label)")
                    #expect(draft.winning.phases[star] % profile.phaseStep == 0, "\(label)")
                }
                var differing: [Control] = []
                for control in Control.allCases where control.value(of: draft.winning) != control.value(of: level.start) {
                    differing.append(control)
                }
                #expect(differing.count == profile.plan, "\(label)")
                #expect(Set(differing) == Set(draft.changed), "\(label)")
                for control in differing { #expect(control.isAdjustable(in: level), "\(label) \(control)") }
                #expect(BinaryGardensSky.keepsSeparation(level, arrangement: draft.winning), "\(label)")
                #expect(BinaryGardensSky.keepsSeparation(level, arrangement: level.start), "\(label)")
                #expect(!level.startReport.wins, "\(label)")
            }
        }
        #expect(checked >= 20, "checked \(checked)")
    }

    @Test func boundsAreExactAndHoldTheWinningRun() throws {
        // A hand flux: 1000 at ticks 1 … 24, 2000 at ticks 25 … 47, 4000 at tick 48.
        var flux: [Int] = Array(repeating: 1000, count: 24) + Array(repeating: 2000, count: 23)
        flux.append(4000)
        let b: BinaryGardensWorldBounds = try #require(BinaryGardensGenerator.bounds(
            flux: flux, trim: 2, comfort: 50, lethal: 300, bloom: 100, slack: 3))
        // c_lo = ⌊1000·950/1000⌋, c_hi = ⌈F₍₄₇₎ = 2000 · 1050/1000⌉, λ_lo = min(949, 700), λ_hi = max(2101, 5200).
        #expect(b.comfortLow == 950)
        #expect(b.comfortHigh == 2100)
        #expect(b.lethalLow == 700)
        #expect(b.lethalHigh == 5200)
        // 47 comfortable ticks in a cyclic run, minus the slack 3.
        #expect(b.window == 44)
        let integral: Int = 24 * 1000 + 23 * 2000 + 4000
        #expect(b.bloomLow == integral * 900 / 1000)
        #expect(b.bloomHigh == (integral * 1100 + 999) / 1000)
        // A dim world whose c_lo would be 0 is skipped; a slack larger than the window keeps W at 1.
        var dim: [Int] = Array(repeating: 0, count: 48)
        dim[5] = 3
        #expect(BinaryGardensGenerator.bounds(flux: dim, trim: 1, comfort: 50, lethal: 300, bloom: 100, slack: 0) == nil)
        let tight: BinaryGardensWorldBounds = try #require(BinaryGardensGenerator.bounds(
            flux: flux, trim: 1, comfort: 0, lethal: 0, bloom: 0, slack: 48))
        #expect(tight.window == 1)
        #expect(tight.lethalLow == 999 && tight.lethalHigh == 4001)
        // The λ_hi guard as a bound: at the kernel's cap of 2 · 64 000 milliflux and the widest margins, λ_hi is
        // 166 400 ≤ 200 000; only an impossible flux of 160 000 trips it.
        let capped: [Int] = Array(repeating: 128_000, count: 48)
        let top: BinaryGardensWorldBounds = try #require(BinaryGardensGenerator.bounds(
            flux: capped, trim: 1, comfort: 90, lethal: 300, bloom: 150, slack: 4))
        #expect(top.lethalHigh == 166_400)
        #expect(top.comfortHigh == 139_520)
        #expect(top.lethalHigh <= BinaryGardensLevel.maximumFlux)
        #expect(top.bloomHigh <= BinaryGardensLevel.maximumBloom)
        let impossible: [Int] = Array(repeating: 160_000, count: 48)
        #expect(BinaryGardensGenerator.bounds(flux: impossible, trim: 1, comfort: 90, lethal: 300, bloom: 150,
                                              slack: 4) == nil)
        #expect(BinaryGardensSky.flux(luminosity: 64, squaredDistance: 0, clampRadius: 1) == 64_000)
        // Every sampled candidate's winning run: no lethal tick, every window and bloom band kept, a win.
        for (key, draft) in Self.drafts {
            let level: BinaryGardensLevel = draft.level
            let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: draft.winning)
            #expect(report.wins, "\(key)")
            for (w, world) in level.worlds.enumerated() {
                let light: BinaryGardensWorldLight = report.worlds[w]
                #expect(light.longestLethalRun == 0, "\(key) world \(w)")
                #expect(light.window >= world.window, "\(key) world \(w)")
                #expect(light.bloom == .inside, "\(key) world \(w)")
                let profile: BinaryGardensBandProfile = .of(band: level.difficulty)
                let sorted: [Int] = light.flux.sorted()
                #expect(world.comfortLow <= sorted[profile.trim - 1], "\(key) world \(w)")
                #expect(world.comfortHigh >= sorted[48 - profile.trim], "\(key) world \(w)")
            }
        }
    }

    @Test func reducibleWinsAreDetected() throws {
        var checked: Int = 0
        for (key, draft) in Self.drafts {
            #expect(!BinaryGardensGenerator.isReducible(draft.level, winning: draft.winning, changed: draft.changed),
                    "\(key)")
            // A "changed" control that the start already shares puts back nothing: the winning arrangement itself.
            var shared: Control?
            for control in Control.allCases
                where control.value(of: draft.winning) == control.value(of: draft.level.start) && shared == nil {
                shared = control
            }
            if let shared {
                #expect(BinaryGardensGenerator.isReducible(draft.level, winning: draft.winning,
                                                           changed: draft.changed + [shared]), "\(key)")
                checked += 1
            }
            // Putting back every changed control is the start, which never wins.
            var start: BinaryGardensArrangement = draft.winning
            for control in draft.changed { start = control.setting(control.value(of: draft.level.start), in: start) }
            #expect(start == draft.level.start, "\(key)")
        }
        #expect(checked >= 10)
    }

    @Test func levelsCarryIdTutorialBandAndBudget() throws {
        for number in Self.bandPairs {
            let generated: BinaryGardensGenerated = try #require(Self.generated[number], "entry \(number)")
            let entry: BinaryGardensManifestEntry = Self.entry(number)
            #expect(generated.entry == entry)
            #expect(generated.level.id == BinaryGardensGenerator.levelID(number))
            #expect(generated.level.seed == entry.seed)
            #expect(generated.level.difficulty == entry.band)
            #expect(generated.level.budget == entry.budget)
            #expect(generated.level.tutorial == (number <= 3), "entry \(number)")
            #expect(generated.difficulty == BinaryGardensDifficulty(level: generated.level, plan: generated.plan))
            #expect(generated.plan.size <= generated.level.budget)
        }
        var three: BinaryGardensLevel?
        var four: BinaryGardensLevel?
        var index: Int = 0
        while (three == nil || four == nil) && index < 8 {
            three = three ?? BinaryGardensGenerator.candidate(Self.entry(3), index: index)
            four = four ?? BinaryGardensGenerator.candidate(Self.entry(4), index: index)
            index += 1
        }
        #expect(try #require(three).tutorial)
        #expect(try #require(four).tutorial == false)
    }

    @Test func generateTakesTheFirstQualifyingCandidate() throws {
        #expect(Self.generated.count == Self.bandPairs.count)
        for number in Self.bandPairs {
            let generated: BinaryGardensGenerated = try #require(Self.generated[number], "entry \(number)")
            let entry: BinaryGardensManifestEntry = Self.entry(number)
            let profile: BinaryGardensBandProfile = .of(band: entry.band)
            let previous: BinaryGardensLevel? = number % 20 == 2 ? Self.generated[number - 1]?.level : nil
            #expect(generated.skipped < BinaryGardensGenerator.maxCandidates)
            #expect(generated.plan.size == profile.plan, "entry \(number)")
            #expect(BinaryGardensSolver.replayWins(generated.level, actions: generated.plan.actions))
            #expect(generated.level == BinaryGardensGenerator.candidate(entry, index: generated.skipped))
            if let previous {
                #expect(previous.ringRadii != generated.level.ringRadii || previous.worlds != generated.level.worlds,
                        "entry \(number)")
            }
            for index in 0..<generated.skipped {
                guard let level = BinaryGardensGenerator.candidate(entry, index: index) else { continue }
                if let previous, previous.ringRadii == level.ringRadii, previous.worlds == level.worlds { continue }
                if let plan = BinaryGardensSolver.plan(level, maxDepth: profile.plan), plan.size == profile.plan {
                    #expect(!BinaryGardensSolver.replayWins(level, actions: plan.actions),
                            "entry \(number) candidate \(index) qualifies before \(generated.skipped)")
                }
            }
        }
    }

    @Test func neighbourRuleSkipsTheSameRingsAndWorlds() throws {
        for number in [1, 41, 81] {
            let generated: BinaryGardensGenerated = try #require(Self.generated[number])
            let previous: BinaryGardensLevel = try #require(
                BinaryGardensGenerator.candidate(Self.entry(number), index: generated.skipped))
            let again: BinaryGardensGenerated = try BinaryGardensGenerator.generate(Self.entry(number),
                                                                                    previous: previous)
            #expect(again.skipped > generated.skipped, "entry \(number)")
            let same: Bool = again.level.ringRadii == previous.ringRadii && again.level.worlds == previous.worlds
            #expect(!same, "entry \(number)")
            #expect(again.level.fingerprint != previous.fingerprint, "entry \(number)")
        }
    }

    @Test func generationRefusesAfterTheCandidateBound() {
        #expect(BinaryGardensGenerator.maxCandidates == 64)
        let base: BinaryGardensManifestEntry = Self.entry(7)
        let refused = BinaryGardensManifestEntry(number: 7, seed: base.seed, band: base.band, budget: 0,
                                                 emphasis: base.emphasis)
        #expect(BinaryGardensGenerator.candidate(refused, index: 0) == nil)
        #expect(throws: BinaryGardensError.generation(7)) {
            try BinaryGardensGenerator.generate(refused, previous: nil)
        }
        #expect(BinaryGardensError.generation(7).reasonCode == "r02-g21.generation")
    }

    /// The content pipeline's sources: the Swift files of Core/Content next to this test directory.
    static func contentSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let content: URL = tests.deletingLastPathComponent().appendingPathComponent("Core/Content")
        var sources: [(name: String, text: String)] = []
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: content.path)
        for name in names.sorted() where name.hasSuffix(".swift") {
            sources.append((name, try String(contentsOf: content.appendingPathComponent(name), encoding: .utf8)))
        }
        return sources
    }

    @Test func theContentPipelineHoldsNoClockOrFloatingPoint() throws {
        let sources: [(name: String, text: String)] = try Self.contentSources()
        var names: [String] = []
        for source in sources { names.append(source.name) }
        #expect(names == ["BinaryGardensDifficulty.swift", "BinaryGardensGenerator.swift",
                          "BinaryGardensManifest.swift", "BinaryGardensSolver.swift", "BinaryGardensWitness.swift"])
        let forbidden: [String] = ["Da" + "te(", "Dispatch" + "Time", "CFAbsolute" + "Time", "Time" + "Interval",
                                   "Dou" + "ble", "Flo" + "at", "clo" + "ck", "si" + "n(", "co" + "s(", "sq" + "rt(",
                                   "Continuous" + "Clock", "Suspending" + "Clock", "process" + "Info"]
        for source in sources {
            for line in source.text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                for token in forbidden { #expect(!trimmed.contains(token), "\(source.name): \(token)") }
            }
        }
    }

    @Test func catalogDigestFollowsTheFingerprints() throws {
        let one: BinaryGardensLevel = try #require(Self.generated[1]?.level)
        let two: BinaryGardensLevel = try #require(Self.generated[2]?.level)
        let other: BinaryGardensLevel = try #require(Self.generated[21]?.level)
        let digest: String = BinaryGardensGenerator.catalogDigest([one, two])
        #expect(digest == BinaryGardensGenerator.catalogDigest([one, two]))
        #expect(digest.count == 64)
        #expect(digest != BinaryGardensGenerator.catalogDigest([one, other]))
        #expect(digest != BinaryGardensGenerator.catalogDigest([two, one]))
        #expect(digest == PuzzleCatalog<BinaryGardensPuzzle>.digest(id: "binary-gardens",
                                                                     identities: [one.fingerprint, two.fingerprint]))
    }
}
