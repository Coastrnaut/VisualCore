// BinaryGardensLevelTests — feature 501 (R02-G21-01) T-R02G2101-002 (FR-R02G2101-001, 002, 003, 004, 005, 009, 013,
// 014; SC-R02G2101-001, 003, 004, 005). The level's rules (every range and rule refused by name: id, difficulty, ring
// count, radius and order, star speed, luminosity count, level and order, the stars, their rings, phases and
// luminosities, a luminosity adjustable with a single level, the tilt range and start, the separation, the clamp radius,
// the worlds, their radius, phase, speed, flux bounds, window and bloom band, the tolerance, the budget, nothing
// adjustable, starting stars that break the separation, a starting arrangement that already wins), the cosine table
// against its definition (the nearest integer to 1024·cos(7.5°·k), the only use of `Foundation.cos`) and its symmetry
// rules, every body back at its start after 48 ticks, the fixtures' known arrangements, hand-computed positions and
// fluxes, its words, and the stored form (round trip, sorted keys, damaged, edited, newer and older forms refused).
// Explicit types, plain loops.
import Foundation
import Testing
@testable import BinaryGardensCore

@Suite struct BinaryGardensLevelTests {
    typealias Level = BinaryGardensLevel
    typealias Star = BinaryGardensStar
    typealias World = BinaryGardensWorld
    typealias Arrangement = BinaryGardensArrangement
    typealias Sky = BinaryGardensSky

    /// The first fixture, the base of every refusal case.
    static let base: BinaryGardensFixture = BinaryGardensFixture.all(count: 1)[0]

    /// A copy of the base level with some values changed.
    static func variant(id: String? = nil, difficulty: Int? = nil, ringRadii: [Int]? = nil, starSpeed: Int? = nil,
                        luminosityLevels: [Int]? = nil, stars: [Star]? = nil, maxTilt: Int? = nil,
                        startTilt: Int? = nil, minimumSeparation: Int? = nil, clampRadius: Int? = nil,
                        worlds: [World]? = nil, lethalTolerance: Int? = nil,
                        budget: Int? = nil) throws -> Level {
        let l: Level = base.level
        return try Level(id: id ?? l.id, seed: l.seed, difficulty: difficulty ?? l.difficulty,
                         ringRadii: ringRadii ?? l.ringRadii, starSpeed: starSpeed ?? l.starSpeed,
                         luminosityLevels: luminosityLevels ?? l.luminosityLevels, stars: stars ?? l.stars,
                         maxTilt: maxTilt ?? l.maxTilt, startTilt: startTilt ?? l.startTilt,
                         minimumSeparation: minimumSeparation ?? l.minimumSeparation,
                         clampRadius: clampRadius ?? l.clampRadius, worlds: worlds ?? l.worlds,
                         lethalTolerance: lethalTolerance ?? l.lethalTolerance, budget: budget ?? l.budget,
                         tutorial: l.tutorial)
    }

    /// A star with the given values, the others copied from `star`.
    static func star(_ star: Star, ring: Int? = nil, phase: Int? = nil, luminosity: Int? = nil,
                     ringAdjustable: Bool? = nil, phaseAdjustable: Bool? = nil,
                     luminosityAdjustable: Bool? = nil) -> Star {
        Star(ring: ring ?? star.ring, phase: phase ?? star.phase, luminosity: luminosity ?? star.luminosity,
             ringAdjustable: ringAdjustable ?? star.ringAdjustable,
             phaseAdjustable: phaseAdjustable ?? star.phaseAdjustable,
             luminosityAdjustable: luminosityAdjustable ?? star.luminosityAdjustable)
    }

    /// A world with the given values, the others copied from `world`.
    static func world(_ world: World, radius: Int? = nil, phase: Int? = nil, speed: Int? = nil,
                      lethalLow: Int? = nil, comfortLow: Int? = nil, comfortHigh: Int? = nil, lethalHigh: Int? = nil,
                      window: Int? = nil, bloomLow: Int? = nil, bloomHigh: Int? = nil) -> World {
        World(radius: radius ?? world.radius, phase: phase ?? world.phase, speed: speed ?? world.speed,
              lethalLow: lethalLow ?? world.lethalLow, comfortLow: comfortLow ?? world.comfortLow,
              comfortHigh: comfortHigh ?? world.comfortHigh, lethalHigh: lethalHigh ?? world.lethalHigh,
              window: window ?? world.window, bloomLow: bloomLow ?? world.bloomLow,
              bloomHigh: bloomHigh ?? world.bloomHigh)
    }

    /// The reason payload of a level refusal, or "none".
    static func refusal(_ build: () throws -> Level) -> String {
        do {
            _ = try build()
            return "none"
        } catch let error as BinaryGardensError {
            if case .level(let name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    /// A wide world (every tick comfortable at any flux of 1 … 199 999, any integral blooms).
    static func wide(radius: Int, phase: Int = 0, speed: Int = 0) -> World {
        World(radius: radius, phase: phase, speed: speed, lethalLow: 0, comfortLow: 1, comfortHigh: 199_999,
              lethalHigh: 200_000, window: 1, bloomLow: 0, bloomHigh: Level.maximumBloom)
    }

    /// A hand probe level: rings `ringRadii`, the two stars on rings 0 and 1 at phases `phases`, luminosity levels
    /// `luminosities` (star i at level i when there are two, else level 0), the given worlds, speed, tilt and clamp.
    static func hand(ringRadii: [Int] = [2, 10], phases: [Int] = [0, 24], luminosities: [Int] = [4, 16],
                     starSpeed: Int = 1, tilt: Int = 0, maxTilt: Int = 6, clampRadius: Int = 1,
                     separation: Int = 0, worlds: [World], tolerance: Int = 0) throws -> Level {
        let second: Int = luminosities.count > 1 ? 1 : 0
        let stars: [Star] = [
            Star(ring: 0, phase: phases[0], luminosity: 0, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: false),
            Star(ring: 1, phase: phases[1], luminosity: second, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: false),
        ]
        return try Level.probe(ringRadii: ringRadii, starSpeed: starSpeed, luminosityLevels: luminosities,
                               stars: stars, maxTilt: maxTilt, startTilt: tilt, minimumSeparation: separation,
                               clampRadius: clampRadius, worlds: worlds, lethalTolerance: tolerance)
    }

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: Level = Self.base.level
        let data: Data = level.encoded()
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level && decoded.fingerprint == level.fingerprint)
        let json: Level = try JSONDecoder().decode(Level.self, from: data)
        #expect(json == level)
        #expect(level.encoded() == data)
        #expect(level.fingerprint.count == 64)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"budget\":") && text.contains("\"fingerprint\":\"\(level.fingerprint)\""))
        let keys: [String] = ["\"budget\"", "\"clampRadius\"", "\"difficulty\"", "\"fingerprint\"", "\"id\"",
                              "\"lethalTolerance\"", "\"luminosityLevels\"", "\"maxTilt\"", "\"minimumSeparation\"",
                              "\"ringRadii\"", "\"schema\":1", "\"seed\"", "\"starSpeed\"", "\"stars\"",
                              "\"startTilt\"", "\"tutorial\"", "\"worlds\""]
        var position: String.Index = text.startIndex
        for key in keys {
            guard let range = text.range(of: key, range: position..<text.endIndex) else {
                Issue.record("missing or out of order: \(key)")
                continue
            }
            position = range.upperBound
        }
        #expect(text.contains("\"stars\":[{\"luminosity\":") && text.contains("\"worlds\":[{\"bloomHigh\":"))
        #expect(text.contains("\"luminosityAdjustable\":") && text.contains("\"lethalLow\":"))
        #expect(level.start == Arrangement(rings: level.stars.map(\.ring), phases: level.stars.map(\.phase),
                                           luminosities: level.stars.map(\.luminosity), tilt: level.startTilt))
    }

    @Test func theKnownArrangementsWinAndTheStartsDoNot() {
        for fixture in BinaryGardensFixture.all(count: 30) {
            #expect(!fixture.level.startReport.wins)
            let report: BinaryGardensReport = Sky.report(fixture.level, arrangement: fixture.winning)
            #expect(report.wins)
            for (index, light) in report.worlds.enumerated() {
                #expect(light.window >= fixture.level.worlds[index].window)
                #expect(light.longestLethalRun <= fixture.level.lethalTolerance || light.longestLethalRun == 0)
                #expect(light.bloom == .inside)
            }
            #expect(fixture.actions.last == .run && fixture.actions.count - 1 <= fixture.level.budget)
            #expect(Sky.keepsSeparation(fixture.level, arrangement: fixture.level.start))
            #expect(Sky.keepsSeparation(fixture.level, arrangement: fixture.winning))
        }
    }

    @Test func theFixturesAreDeterministic() {
        let first: [BinaryGardensFixture] = BinaryGardensFixture.all(count: 5)
        let second: [BinaryGardensFixture] = BinaryGardensFixture.all(count: 5)
        for i in 0..<5 {
            #expect(first[i].level == second[i].level && first[i].actions == second[i].actions)
        }
    }

    @Test func theCosineTableIsItsDefinition() {
        #expect(Sky.cycle == 48 && Sky.cosine.count == 48)
        let quarter: [Int] = [1024, 1015, 989, 946, 887, 812, 724, 623, 512, 392, 265, 134, 0]
        for k in 0...12 { #expect(Sky.cosine[k] == quarter[k]) }
        for k in 13...24 { #expect(Sky.cosine[k] == -Sky.cosine[24 - k], "symmetry \(k)") }
        for k in 25...36 { #expect(Sky.cosine[k] == -Sky.cosine[k - 24], "symmetry \(k)") }
        for k in 37...47 { #expect(Sky.cosine[k] == Sky.cosine[48 - k], "symmetry \(k)") }
        for k in 0..<48 {
            let exact: Double = 1024 * cos(Double(k) * 7.5 * Double.pi / 180)
            #expect(Sky.cosine[k] == Int(exact.rounded()), "nearest integer \(k)")
            #expect(Sky.sine(k) == Sky.cosine[(k + 36) % 48])
            let exactSine: Double = 1024 * sin(Double(k) * 7.5 * Double.pi / 180)
            #expect(Sky.sine(k) == Int(exactSine.rounded()), "sine \(k)")
        }
        #expect(Sky.sine(-12) == -1024 && Sky.sine(60) == 1024)
    }

    @Test func everyBodyIsBackAtItsStartAfterACycle() {
        for start in 0..<48 {
            for speed in -4...4 {
                #expect(Sky.phase(start, speed: speed, tick: 48) == start)
                for tick in 0...60 {
                    let p: Int = Sky.phase(start, speed: speed, tick: tick)
                    #expect(p >= 0 && p < 48 && p == Sky.phase(start, speed: speed, tick: tick + 48))
                }
            }
        }
        #expect(Sky.phase(3, speed: -4, tick: 1) == 47 && Sky.phase(0, speed: 3, tick: 17) == 3)
        for fixture in BinaryGardensFixture.all(count: 20) {
            let level: Level = fixture.level
            let report: BinaryGardensReport = level.startReport
            let zero: [BinaryGardensPoint] = Sky.starPositions(level, level.start, tick: 0)
            #expect(report.starPositions[47] == zero)
            for (index, world) in level.worlds.enumerated() {
                #expect(report.worldPositions[47][index] == Sky.worldPosition(radius: world.radius,
                                                                               phase: world.phase))
            }
            #expect(report.starPositions.count == 48 && report.worldPositions.count == 48)
        }
    }

    @Test func positionsAndFluxAreExactByHand() throws {
        let unit: Int = 1 << 20
        #expect(Sky.worldPosition(radius: 1, phase: 0) == BinaryGardensPoint(x: unit, y: 0, z: 0))
        #expect(Sky.worldPosition(radius: 3, phase: 12) == BinaryGardensPoint(x: 0, y: 3 * unit, z: 0))
        #expect(Sky.worldPosition(radius: 2, phase: 1) == BinaryGardensPoint(x: 2 * 1015 * 1024, y: 2 * 134 * 1024,
                                                                              z: 0))
        // A star at phase 12 (on the y axis) under tilt 6 (45°): y = ρ·1024·724, z = ρ·1024·724.
        #expect(Sky.starPosition(radius: 5, phase: 12, tilt: 6) == BinaryGardensPoint(x: 0, y: 5 * 1024 * 724,
                                                                                       z: 5 * 1024 * 724))
        #expect(Sky.starPosition(radius: 5, phase: 0, tilt: 6) == BinaryGardensPoint(x: 5 * unit, y: 0, z: 0))
        #expect(Sky.starPosition(radius: 4, phase: 7, tilt: 0) == Sky.worldPosition(radius: 4, phase: 7))
        let a = BinaryGardensPoint(x: unit, y: 0, z: 0)
        let b = BinaryGardensPoint(x: 0, y: 0, z: 0)
        #expect(Sky.squaredDistance(a, b) == 1 << 40)
        #expect(Sky.squaredDistance(BinaryGardensPoint(x: 3 * unit, y: 0, z: 0),
                                    BinaryGardensPoint(x: 0, y: 4 * unit, z: 0)) == 25 << 40)
        #expect(Sky.flux(luminosity: 1, squaredDistance: 1 << 40, clampRadius: 1) == 1000)
        #expect(Sky.flux(luminosity: 64, squaredDistance: 0, clampRadius: 1) == 64_000)
        #expect(Sky.flux(luminosity: 64, squaredDistance: 0, clampRadius: 8) == 1000)
        #expect(Sky.flux(luminosity: 7, squaredDistance: 9 << 40, clampRadius: 1) == 777)
        #expect(Sky.flux(luminosity: 1, squaredDistance: 10_000 << 40, clampRadius: 1) == 0)
        #expect(Sky.flux(luminosity: 3, squaredDistance: (4 << 40) - 1, clampRadius: 2) == 750)
        #expect(Sky.flux(luminosity: 3, squaredDistance: (4 << 40) + 1, clampRadius: 2) == 749)
        // A hand level: star 1 at the centre ring 2, star 2 on ring 10, a world held still at radius 6, phase 0.
        let level: Level = try Self.hand(worlds: [Self.wide(radius: 6)])
        let report: BinaryGardensReport = level.startReport
        // Tick 48 is tick 0: star 1 at (2, 0, 0), star 2 at (−10, 0, 0); distances 4 and 16 units.
        #expect(report.worlds[0].shares[47] == [4 * 1000 / 16, 16 * 1000 / 256])
        #expect(report.worlds[0].flux[47] == 250 + 62)
        var integral: Int = 0
        for value in report.worlds[0].flux { integral += value }
        #expect(report.worlds[0].integral == integral)
        // The stars are 12 units apart at phases 0 and 24 (axis phases); off the axes the table makes them nearer.
        let separation: (squared: Int, tick: Int) = Sky.minimumSeparation(level, level.start)
        #expect(report.minimumSeparationSquared == separation.squared && separation.squared <= 144 << 40)
    }

    @Test func startingArrangementsThatWinAreRefused() {
        let base: BinaryGardensFixture = Self.base
        var stars: [Star] = []
        for star in 0..<2 {
            stars.append(Self.star(base.level.stars[star], ring: base.winning.rings[star],
                                   phase: base.winning.phases[star], luminosity: base.winning.luminosities[star]))
        }
        #expect(Self.refusal { try Self.variant(stars: stars, startTilt: base.winning.tilt) } == "already won")
    }

    @Test func everyRangeIsRefusedByName() {
        let l: Level = Self.base.level
        let s0: Star = l.stars[0]
        let w0: World = l.worlds[0]
        let rest: [World] = Array(l.worlds.dropFirst())
        let first: Int = l.luminosityLevels[0]
        let duplicated: [Int] = l.luminosityLevels.count == 1 ? [first, first]
            : [first] + l.luminosityLevels.dropLast()
        let lockedStars: [Star] = l.stars.map {
            Self.star($0, ringAdjustable: false, phaseAdjustable: false, luminosityAdjustable: false)
        }
        let cases: [(String, () throws -> Level)] = [
            ("id", { try Self.variant(id: "Bad Id") }),
            ("id", { try Self.variant(id: "") }),
            ("difficulty", { try Self.variant(difficulty: 0) }),
            ("difficulty", { try Self.variant(difficulty: 6) }),
            ("ring count", { try Self.variant(ringRadii: [5]) }),
            ("ring count", { try Self.variant(ringRadii: [1, 2, 3, 4, 5, 6, 7, 8, 9]) }),
            ("ring radius", { try Self.variant(ringRadii: [0] + l.ringRadii.dropFirst()) }),
            ("ring radius", { try Self.variant(ringRadii: Array(l.ringRadii.dropLast()) + [41]) }),
            ("ring order", { try Self.variant(ringRadii: Array(l.ringRadii.reversed())) }),
            ("ring order", { try Self.variant(ringRadii: [l.ringRadii[0]] + l.ringRadii.dropLast()) }),
            ("star speed", { try Self.variant(starSpeed: 0) }),
            ("star speed", { try Self.variant(starSpeed: 4) }),
            ("luminosity count", { try Self.variant(luminosityLevels: []) }),
            ("luminosity count", { try Self.variant(luminosityLevels: [1, 2, 3, 4, 5]) }),
            ("luminosity level", { try Self.variant(luminosityLevels: [0] + l.luminosityLevels.dropFirst()) }),
            ("luminosity level", { try Self.variant(luminosityLevels: Array(l.luminosityLevels.dropLast()) + [65]) }),
            ("luminosity order", { try Self.variant(luminosityLevels: duplicated) }),
            ("stars", { try Self.variant(stars: [s0]) }),
            ("stars", { try Self.variant(stars: l.stars + [s0]) }),
            ("star ring", { try Self.variant(stars: [Self.star(s0, ring: l.ringRadii.count), l.stars[1]]) }),
            ("star ring", { try Self.variant(stars: [Self.star(s0, ring: -1), l.stars[1]]) }),
            ("star phase", { try Self.variant(stars: [Self.star(s0, phase: 48), l.stars[1]]) }),
            ("star phase", { try Self.variant(stars: [Self.star(s0, phase: -1), l.stars[1]]) }),
            ("star luminosity", { try Self.variant(stars: [Self.star(s0, luminosity: l.luminosityLevels.count),
                                                           l.stars[1]]) }),
            ("max tilt", { try Self.variant(maxTilt: 7, startTilt: 0) }),
            ("max tilt", { try Self.variant(maxTilt: -1, startTilt: 0) }),
            ("start tilt", { try Self.variant(startTilt: l.maxTilt + 1) }),
            ("start tilt", { try Self.variant(startTilt: -1) }),
            ("minimum separation", { try Self.variant(minimumSeparation: -1) }),
            ("minimum separation", { try Self.variant(minimumSeparation: 17) }),
            ("clamp radius", { try Self.variant(clampRadius: 0) }),
            ("clamp radius", { try Self.variant(clampRadius: 9) }),
            ("worlds", { try Self.variant(worlds: []) }),
            ("worlds", { try Self.variant(worlds: Array(repeating: w0, count: 6)) }),
            ("world radius", { try Self.variant(worlds: [Self.world(w0, radius: 0)] + rest) }),
            ("world radius", { try Self.variant(worlds: [Self.world(w0, radius: 61)] + rest) }),
            ("world phase", { try Self.variant(worlds: [Self.world(w0, phase: 48)] + rest) }),
            ("world phase", { try Self.variant(worlds: [Self.world(w0, phase: -1)] + rest) }),
            ("world speed", { try Self.variant(worlds: [Self.world(w0, speed: 5)] + rest) }),
            ("world speed", { try Self.variant(worlds: [Self.world(w0, speed: -5)] + rest) }),
            ("flux bounds", { try Self.variant(worlds: [Self.world(w0, lethalLow: -1)] + rest) }),
            ("flux bounds", { try Self.variant(worlds: [Self.world(w0, lethalLow: w0.comfortLow)] + rest) }),
            ("flux bounds", { try Self.variant(worlds: [Self.world(w0, comfortHigh: w0.comfortLow - 1)] + rest) }),
            ("flux bounds", { try Self.variant(worlds: [Self.world(w0, lethalHigh: w0.comfortHigh)] + rest) }),
            ("flux bounds", { try Self.variant(worlds: [Self.world(w0, lethalHigh: 200_001)] + rest) }),
            ("window", { try Self.variant(worlds: [Self.world(w0, window: 0)] + rest) }),
            ("window", { try Self.variant(worlds: [Self.world(w0, window: 49)] + rest) }),
            ("bloom band", { try Self.variant(worlds: [Self.world(w0, bloomLow: -1)] + rest) }),
            ("bloom band", { try Self.variant(worlds: [Self.world(w0, bloomLow: w0.bloomHigh + 1)] + rest) }),
            ("bloom band", { try Self.variant(worlds: [Self.world(w0, bloomHigh: 9_600_001)] + rest) }),
            ("lethal tolerance", { try Self.variant(lethalTolerance: -1) }),
            ("lethal tolerance", { try Self.variant(lethalTolerance: 13) }),
            ("budget", { try Self.variant(budget: 0) }),
            ("budget", { try Self.variant(budget: 25) }),
            ("nothing adjustable", { try Self.variant(stars: lockedStars, maxTilt: 0, startTilt: 0) }),
            ("single luminosity adjustable", {
                try Self.variant(luminosityLevels: [l.luminosityLevels[0]],
                                 stars: l.stars.map { Self.star($0, luminosity: 0, luminosityAdjustable: true) })
            }),
        ]
        for (name, build) in cases {
            #expect(Self.refusal(build) == name, "expected \(name)")
        }
        // The boundaries themselves are accepted by the range checks (budget 24, tolerance 12, 2 and 8 rings).
        #expect(Self.refusal { try Self.variant(budget: 24) } == "none")
        #expect(Self.refusal { try Self.variant(budget: 1) } == "none")
        #expect(Self.refusal { try Self.variant(lethalTolerance: 0) } != "lethal tolerance")
        #expect(Self.refusal { try Self.variant(lethalTolerance: 12) } != "lethal tolerance")
        // Tilt alone is enough to be adjustable.
        #expect(Self.refusal { try Self.variant(stars: lockedStars, maxTilt: 1, startTilt: 0) } != "nothing adjustable")
    }

    @Test func startingStarsThatBreakTheSeparationAreRefused() throws {
        let l: Level = Self.base.level
        let closest: Int = Sky.integerSquareRoot(l.startReport.minimumSeparationSquared) >> 20
        #expect(closest >= l.minimumSeparation)
        if closest + 1 <= Level.separations.upperBound {
            #expect(Self.refusal { try Self.variant(minimumSeparation: closest + 1) } == "separation")
        }
        // Both stars on the same ring at the same phase coincide at every tick: only σ = 0 holds (exactly at it).
        let together: Level = try Self.hand(ringRadii: [5, 6], phases: [3, 3], worlds: [Self.wide(radius: 30)])
        let same = Arrangement(rings: [0, 0], phases: [3, 3], luminosities: [0, 1], tilt: 0)
        #expect(Sky.keepsSeparation(together, arrangement: same))
        #expect(Sky.report(together, arrangement: same).minimumSeparationSquared == 0)
        #expect(Self.refusal {
            try Self.hand(ringRadii: [5, 6], phases: [3, 3], separation: 0, worlds: [Self.wide(radius: 30)])
        } == "none")
        // Rings 5 and 6 at one phase are 1 unit apart on the axes and nearer off them (C² + S² < 2^20 at step 4).
        #expect(Self.refusal {
            try Self.hand(ringRadii: [5, 6], phases: [3, 3], separation: 1, worlds: [Self.wide(radius: 30)])
        } == "separation")
    }

    @Test func theStoredFormRefusesDamage() throws {
        let level: Level = Self.base.level
        let data: Data = level.encoded()
        let text: String = String(decoding: data, as: UTF8.self)
        func code(_ text: String) -> String {
            do {
                _ = try Level.decode(Data(text.utf8))
                return "none"
            } catch {
                return error.reasonCode
            }
        }
        #expect(code(text) == "none")
        #expect(code("{") == "r02-g21.malformed")
        #expect(code("") == "r02-g21.malformed")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")) == "r02-g21.newer-schema")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")) == "r02-g21.malformed")
        let budget: Int = level.budget
        let edited: String = text.replacingOccurrences(of: "\"budget\":\(budget)",
                                                       with: "\"budget\":\(budget == 24 ? 23 : budget + 1)")
        #expect(edited != text)
        #expect(code(edited) == "r02-g21.malformed")
        #expect(code(text.replacingOccurrences(of: "\"starSpeed\":\(level.starSpeed)",
                                               with: "\"starSpeed\":0")) == "r02-g21.level")
        #expect(code(text.replacingOccurrences(of: "\"fingerprint\":\"\(level.fingerprint)\"",
                                               with: "\"fingerprint\":\"\(String(repeating: "0", count: 64))\""))
            == "r02-g21.malformed")
        #expect(code(text.replacingOccurrences(of: "\"clampRadius\":", with: "\"clampRadiux\":")) == "r02-g21.malformed")
        // A newer schema is reported before a missing field; a damaged value before the fingerprint.
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":3")
            .replacingOccurrences(of: "\"clampRadius\":", with: "\"clampRadiux\":")) == "r02-g21.newer-schema")
        do {
            _ = try Level.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":7").utf8))
            Issue.record("a newer schema decoded")
        } catch {
            #expect(error == .newerSchema(7))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Level.self, from: Data(edited.utf8))
        }
    }

    @Test func everythingIsNamedInWords() throws {
        #expect(Level.grouped(41_250) == "41 250" && Level.grouped(9_600_000) == "9 600 000")
        #expect(Level.grouped(0) == "0" && Level.grouped(999) == "999" && Level.grouped(1000) == "1 000")
        #expect(Level.grouped(-1015) == "-1 015")
        let stars: [Star] = [
            Star(ring: 2, phase: 9, luminosity: 1, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: true),
            Star(ring: 0, phase: 30, luminosity: 0, ringAdjustable: false, phaseAdjustable: true,
                 luminosityAdjustable: false),
        ]
        let world0 = World(radius: 20, phase: 0, speed: 0, lethalLow: 0, comfortLow: 1, comfortHigh: 199_999,
                           lethalHigh: 200_000, window: 1, bloomLow: 0, bloomHigh: 9_600_000)
        let world1 = World(radius: 30, phase: 5, speed: 1, lethalLow: 10_000, comfortLow: 30_000,
                           comfortHigh: 52_000, lethalHigh: 90_000, window: 24, bloomLow: 1_900_000,
                           bloomHigh: 2_100_000)
        let level: Level = try Level.probe(ringRadii: [4, 8, 12], starSpeed: 1, luminosityLevels: [10, 24],
                                           stars: stars, maxTilt: 6, startTilt: 2, minimumSeparation: 0,
                                           clampRadius: 1, worlds: [world0, world1], lethalTolerance: 2)
        #expect(level.starDescription(0, arrangement: level.start) == "star 1 on ring 3, 12 units, phase 9, luminosity 24")
        #expect(level.starDescription(1, arrangement: level.start) == "star 2 on ring 1, 4 units, phase 30, luminosity 10")
        var flux: [Int] = Array(repeating: 40_000, count: 48)
        flux[16] = 41_250
        let shares: [[Int]] = flux.map { [$0 - 1_250, 1_250] }
        let light: BinaryGardensWorldLight = Sky.light(shares: shares, world: world1)
        let lights: [BinaryGardensWorldLight] = [Sky.light(shares: shares, world: world0), light]
        let report = BinaryGardensReport(starPositions: [], worldPositions: [], worlds: lights,
                                         minimumSeparationSquared: 9 << 40, minimumSeparationTick: 3, failure: nil)
        #expect(level.worldTickDescription(1, tick: 17, report: report)
            == "world 2 at tick 17: 41 250 milliflux, comfortable, band 30 000 … 52 000")
        #expect(level.worldDescription(1, report: report)
            == "world 2: window of 48 ticks from tick 1, 24 required; longest lethal run 0 of 2 allowed; integral "
                + Level.grouped(light.integral) + ", bloom band 1 900 000 … 2 100 000")
        #expect(level.failureDescription(.frozen(world: 0, tick: 50)) == "world 1 froze at tick 50 (tick 2 of the next cycle)")
        #expect(level.failureDescription(.scorched(world: 1, tick: 7)) == "world 2 scorched at tick 7")
        #expect(level.failureDescription(.unstable(world: 0, window: 20, required: 24))
            == "world 1 has a comfortable window of only 20 ticks, 24 required")
        #expect(level.failureDescription(.wilted(world: 2, integral: 1_800_000, low: 1_900_000, high: 2_100_000))
            == "world 3 wilted: integral 1 800 000 below the bloom band 1 900 000 … 2 100 000")
        #expect(level.failureDescription(.bleached(world: 2, integral: 2_200_000, low: 1_900_000, high: 2_100_000))
            == "world 3 bleached: integral 2 200 000 above the bloom band 1 900 000 … 2 100 000")
        let words: String = level.progressDescription(report: report, arrangement: level.start, actionsLeft: 1)
        #expect(words.contains("star 1 on ring 3") && words.contains("star 2 on ring 1") && words.contains("tilt 2 of 6 steps")
            && words.contains("world 1: ") && words.contains("world 2: ")
            && words.contains("stars closest at tick 3, 3 units apart, 0 required")
            && words.contains("running now would win") && words.hasSuffix("1 action left"))
        let base: Level = Self.base.level
        let fail: String = base.progressDescription(report: base.startReport, arrangement: base.start, actionsLeft: 3)
        #expect(fail.contains("running now would fail: ") && fail.hasSuffix("3 actions left"))
        var dark: [Int] = Array(repeating: 0, count: 48)
        dark[0] = 1
        let none: BinaryGardensWorldLight = Sky.light(shares: dark.map { [$0, 0] }, world: world1)
        let darkReport = BinaryGardensReport(starPositions: [], worldPositions: [], worlds: [none, none],
                                             minimumSeparationSquared: 0, minimumSeparationTick: 0, failure: nil)
        #expect(level.worldDescription(1, report: darkReport).hasPrefix("world 2: no comfortable window, 24 required"))
        #expect(level.worldTickDescription(1, tick: 1, report: darkReport)
            == "world 2 at tick 1: 1 milliflux, lethal low, band 30 000 … 52 000")
    }
}
