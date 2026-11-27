// BinaryGardensLevel — feature 501 (R02-G21-01) T-R02G2101-002 (FR-R02G2101-001, 002, 009, 011, 013;
// SC-R02G2101-001, 005; clarifications Q1 … Q5). An immutable Binary Gardens level: 2 … 8 strictly increasing ring
// radii (each 1 … 40 units); the stars' shared angular speed ω 1 … 3 steps per tick; 1 … 4 strictly increasing
// luminosity levels (each 1 … 64 units); exactly two stars, each with a starting ring, phase 0 … 47 and luminosity and
// which of them can be adjusted; a tilt range 0 … T_max (T_max 0 … 6) with a starting tilt; the stars' minimum separation
// σ 0 … 16 units; the flux clamp radius r_min 1 … 8 units; 1 … 5 garden worlds (radius 1 … 60, phase 0 … 47, speed
// −4 … 4, flux bounds 0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤ 200 000 milliflux, window 1 … 48, bloom band
// 0 ≤ B_lo ≤ B_hi ≤ 9 600 000); a lethal tolerance E 0 … 12; an action budget 1 … 24; a difficulty 1 … 5 and whether a
// tutorial precedes play. A level is refused when nothing is adjustable, a star's luminosity is adjustable with a single
// luminosity level, the starting stars break the separation at a tick of 0 … 47, or the starting arrangement already
// wins. Its fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys, fingerprint excluded); the
// stored form is re-checked on decode. Stars, rings, worlds, bands, measures and progress are named in words
// (FR-R02G2101-013). Modelled on `MushroomWeatherLevel` (feature 491).
//
// Feature 502 (R02-G21-02) T-R02G2102-002 (FR-R02G2102-006, 009; SC-R02G2102-007; clarification Q1; research R1, R2),
// additive: a level may declare a phase step g ∈ {1, 2, 3, 4, 6, 8, 12, 16, 24} (the divisors of 48 up to 24), the
// grid on which its star phases lie. After "nothing adjustable" and before the encoding, "separation" and "already won",
// the level refuses "phase step" (g not a listed divisor) and then "phase off grid" (a starting phase not a multiple of
// g). g = 1 is the default and is omitted from the stored form, so a level without a phase step encodes, fingerprints
// and plays byte for byte as in feature 501.
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Binary Gardens level.
public struct BinaryGardensLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The ring counts.
    public static let ringCounts: ClosedRange<Int> = 2...8
    /// The ring radii in distance units.
    public static let ringRadiusRange: ClosedRange<Int> = 1...40
    /// The stars' shared angular speeds ω in phase steps per tick.
    public static let starSpeeds: ClosedRange<Int> = 1...3
    /// The luminosity level counts.
    public static let luminosityCounts: ClosedRange<Int> = 1...4
    /// The luminosity levels in luminosity units.
    public static let luminosityRange: ClosedRange<Int> = 1...64
    /// The phases of one cycle.
    public static let phases: ClosedRange<Int> = 0...47
    /// The largest tilts T_max in phase steps (at most 45°).
    public static let maxTilts: ClosedRange<Int> = 0...6
    /// The minimum separations σ in distance units (0 means none).
    public static let separations: ClosedRange<Int> = 0...16
    /// The clamp radii r_min in distance units.
    public static let clampRadii: ClosedRange<Int> = 1...8
    /// The world counts.
    public static let worldCounts: ClosedRange<Int> = 1...5
    /// The world orbit radii in distance units.
    public static let worldRadii: ClosedRange<Int> = 1...60
    /// The world speeds in phase steps per tick.
    public static let worldSpeeds: ClosedRange<Int> = -4...4
    /// The largest flux bound in milliflux.
    public static let maximumFlux: Int = 200_000
    /// The required windows W in ticks.
    public static let windows: ClosedRange<Int> = 1...48
    /// The largest bloom bound.
    public static let maximumBloom: Int = 9_600_000
    /// The lethal tolerances E in ticks.
    public static let tolerances: ClosedRange<Int> = 0...12
    /// The action budgets.
    public static let budgets: ClosedRange<Int> = 1...24
    /// The phase steps a level may declare: the divisors of 48 up to 24 (1 is feature 501's behaviour, every phase).
    public static let phaseSteps: [Int] = [1, 2, 3, 4, 6, 8, 12, 16, 24]

    /// The level's id, a lowercase slug.
    public let id: String
    /// The seed the level was generated from (0 for hand-made levels).
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The ring radii in distance units, 2 … 8 strictly increasing values of 1 … 40.
    public let ringRadii: [Int]
    /// The stars' shared angular speed ω, 1 … 3 phase steps per tick.
    public let starSpeed: Int
    /// The luminosity levels in luminosity units, 1 … 4 strictly increasing values of 1 … 64.
    public let luminosityLevels: [Int]
    /// The two stars (star 1 first), with their starting values and adjustable flags.
    public let stars: [BinaryGardensStar]
    /// The largest tilt T_max, 0 … 6 steps (0: the tilt is locked).
    public let maxTilt: Int
    /// The starting tilt, 0 … T_max.
    public let startTilt: Int
    /// The stars' minimum separation σ, 0 … 16 units (0 means none).
    public let minimumSeparation: Int
    /// The flux clamp radius r_min, 1 … 8 units.
    public let clampRadius: Int
    /// The garden worlds, by index (numbered from 1 in words).
    public let worlds: [BinaryGardensWorld]
    /// The lethal tolerance E, 0 … 12 ticks: a lethal run of E + 1 ticks fails.
    public let lethalTolerance: Int
    /// The action budget, 1 … 24.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The phase step g, one of ``phaseSteps``: every star phase lies on the grid 0, g, 2g, … (1, the default: every
    /// phase 0 … 47, feature 501's behaviour; omitted from the stored form).
    public let phaseStep: Int
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked.
    ///
    /// - Parameter phaseStep: the phase step g, one of ``phaseSteps`` (default 1: every phase, as in feature 501).
    /// - Throws: `.level(name)` naming the first value outside its range or rule; "phase step" (g not one of
    ///   ``phaseSteps``) and "phase off grid" (a starting phase not a multiple of g) after "nothing adjustable" and
    ///   before "separation" and "already won".
    public init(id: String, seed: UInt64, difficulty: Int, ringRadii: [Int], starSpeed: Int, luminosityLevels: [Int],
                stars: [BinaryGardensStar], maxTilt: Int, startTilt: Int, minimumSeparation: Int, clampRadius: Int,
                worlds: [BinaryGardensWorld], lethalTolerance: Int, budget: Int,
                tutorial: Bool, phaseStep: Int = 1) throws(BinaryGardensError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, ringRadii: ringRadii, starSpeed: starSpeed,
                      luminosityLevels: luminosityLevels, stars: stars, maxTilt: maxTilt, startTilt: startTilt,
                      minimumSeparation: minimumSeparation, clampRadius: clampRadius, worlds: worlds,
                      lethalTolerance: lethalTolerance, budget: budget, tutorial: tutorial, refusingAWin: true,
                      phaseStep: phaseStep)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// reports passes false); `phaseStep` as in the public initialiser.
    init(id: String, seed: UInt64, difficulty: Int, ringRadii: [Int], starSpeed: Int, luminosityLevels: [Int],
         stars: [BinaryGardensStar], maxTilt: Int, startTilt: Int, minimumSeparation: Int, clampRadius: Int,
         worlds: [BinaryGardensWorld], lethalTolerance: Int, budget: Int, tutorial: Bool,
         refusingAWin: Bool, phaseStep: Int = 1) throws(BinaryGardensError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.ringCounts.contains(ringRadii.count) else { throw .level("ring count") }
        guard ringRadii.allSatisfy({ Self.ringRadiusRange.contains($0) }) else { throw .level("ring radius") }
        guard Self.isStrictlyIncreasing(ringRadii) else { throw .level("ring order") }
        guard Self.starSpeeds.contains(starSpeed) else { throw .level("star speed") }
        guard Self.luminosityCounts.contains(luminosityLevels.count) else { throw .level("luminosity count") }
        guard luminosityLevels.allSatisfy({ Self.luminosityRange.contains($0) }) else {
            throw .level("luminosity level")
        }
        guard Self.isStrictlyIncreasing(luminosityLevels) else { throw .level("luminosity order") }
        guard stars.count == 2 else { throw .level("stars") }
        for star in stars {
            guard ringRadii.indices.contains(star.ring) else { throw .level("star ring") }
            guard Self.phases.contains(star.phase) else { throw .level("star phase") }
            guard luminosityLevels.indices.contains(star.luminosity) else { throw .level("star luminosity") }
            guard !star.luminosityAdjustable || luminosityLevels.count > 1 else {
                throw .level("single luminosity adjustable")
            }
        }
        guard Self.maxTilts.contains(maxTilt) else { throw .level("max tilt") }
        guard (0...maxTilt).contains(startTilt) else { throw .level("start tilt") }
        guard Self.separations.contains(minimumSeparation) else { throw .level("minimum separation") }
        guard Self.clampRadii.contains(clampRadius) else { throw .level("clamp radius") }
        guard Self.worldCounts.contains(worlds.count) else { throw .level("worlds") }
        for world in worlds {
            guard Self.worldRadii.contains(world.radius) else { throw .level("world radius") }
            guard Self.phases.contains(world.phase) else { throw .level("world phase") }
            guard Self.worldSpeeds.contains(world.speed) else { throw .level("world speed") }
            guard 0 <= world.lethalLow, world.lethalLow < world.comfortLow, world.comfortLow <= world.comfortHigh,
                  world.comfortHigh < world.lethalHigh, world.lethalHigh <= Self.maximumFlux else {
                throw .level("flux bounds")
            }
            guard Self.windows.contains(world.window) else { throw .level("window") }
            guard 0 <= world.bloomLow, world.bloomLow <= world.bloomHigh, world.bloomHigh <= Self.maximumBloom else {
                throw .level("bloom band")
            }
        }
        guard Self.tolerances.contains(lethalTolerance) else { throw .level("lethal tolerance") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        var adjustable: Bool = maxTilt > 0
        for star in stars where star.ringAdjustable || star.phaseAdjustable || star.luminosityAdjustable {
            adjustable = true
        }
        guard adjustable else { throw .level("nothing adjustable") }
        guard Self.phaseSteps.contains(phaseStep) else { throw .level("phase step") }
        for star in stars where star.phase % phaseStep != 0 { throw .level("phase off grid") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, ringRadii: ringRadii,
                              starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: stars, maxTilt: maxTilt,
                              startTilt: startTilt, minimumSeparation: minimumSeparation, clampRadius: clampRadius,
                              worlds: worlds, lethalTolerance: lethalTolerance, budget: budget, tutorial: tutorial,
                              phaseStep: phaseStep == 1 ? nil : phaseStep)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.ringRadii = ringRadii
        self.starSpeed = starSpeed
        self.luminosityLevels = luminosityLevels
        self.stars = stars
        self.maxTilt = maxTilt
        self.startTilt = startTilt
        self.minimumSeparation = minimumSeparation
        self.clampRadius = clampRadius
        self.worlds = worlds
        self.lethalTolerance = lethalTolerance
        self.budget = budget
        self.tutorial = tutorial
        self.phaseStep = phaseStep
        self.fingerprint = StableHash.sha256Hex(Array(data))
        guard BinaryGardensSky.keepsSeparation(self, arrangement: start) else { throw .level("separation") }
        if refusingAWin {
            guard !BinaryGardensSky.report(self, arrangement: start).wins else { throw .level("already won") }
        }
    }

    /// A probe level that skips the "already won" rule, for reading the reports of other arrangements (the content
    /// pipeline, the fixtures and hand-made test levels); every other rule is checked, the phase step included.
    static func probe(ringRadii: [Int], starSpeed: Int, luminosityLevels: [Int], stars: [BinaryGardensStar],
                      maxTilt: Int, startTilt: Int, minimumSeparation: Int, clampRadius: Int,
                      worlds: [BinaryGardensWorld], lethalTolerance: Int,
                      budget: Int = 1, phaseStep: Int = 1) throws(BinaryGardensError) -> BinaryGardensLevel {
        try BinaryGardensLevel(id: "probe", seed: 0, difficulty: 1, ringRadii: ringRadii, starSpeed: starSpeed,
                               luminosityLevels: luminosityLevels, stars: stars, maxTilt: maxTilt,
                               startTilt: startTilt, minimumSeparation: minimumSeparation, clampRadius: clampRadius,
                               worlds: worlds, lethalTolerance: lethalTolerance, budget: budget, tutorial: false,
                               refusingAWin: false, phaseStep: phaseStep)
    }

    /// Whether `step` is a phase a star of this level may take: 0 … 47 and a multiple of ``phaseStep``.
    public func allowsPhase(_ step: Int) -> Bool {
        Self.phases.contains(step) && step % phaseStep == 0
    }

    /// The starting arrangement: both stars' starting rings, phases and luminosities and the starting tilt.
    public var start: BinaryGardensArrangement {
        BinaryGardensArrangement(rings: stars.map(\.ring), phases: stars.map(\.phase),
                                 luminosities: stars.map(\.luminosity), tilt: startTilt)
    }

    /// The report of the starting arrangement.
    public var startReport: BinaryGardensReport { BinaryGardensSky.report(self, arrangement: start) }

    /// Whether `values` is strictly increasing.
    static func isStrictlyIncreasing(_ values: [Int]) -> Bool {
        for index in values.indices.dropFirst() where values[index - 1] >= values[index] { return false }
        return true
    }

    /// `value` with its digits grouped in threes by spaces: "41 250", "9 600 000", "-1 015".
    public static func grouped(_ value: Int) -> String {
        let digits: [Character] = Array(String(value.magnitude))
        var text: String = ""
        for (position, digit) in digits.enumerated() {
            if position > 0 && (digits.count - position) % 3 == 0 { text += " " }
            text.append(digit)
        }
        return value < 0 ? "-" + text : text
    }

    /// "1 tick" or "12 ticks".
    static func ticksWords(_ count: Int) -> String { count == 1 ? "1 tick" : "\(count) ticks" }

    /// A walk tick in words: "tick 17", or "tick 50 (tick 2 of the next cycle)" for a tick beyond 48.
    static func walkTickWords(_ tick: Int) -> String {
        guard tick > BinaryGardensSky.cycle else { return "tick \(tick)" }
        return "tick \(tick) (tick \(tick - BinaryGardensSky.cycle) of the next cycle)"
    }

    /// Star `star` (0-based) in words with its ring, the ring's radius, its phase and its luminosity: "star 1 on ring 3,
    /// 12 units, phase 9, luminosity 24".
    public func starDescription(_ star: Int, arrangement: BinaryGardensArrangement) -> String {
        let ring: Int = arrangement.rings[star]
        return "star \(star + 1) on ring \(ring + 1), \(ringRadii[ring]) units, phase \(arrangement.phases[star]), "
            + "luminosity \(luminosityLevels[arrangement.luminosities[star]])"
    }

    /// World `world` (0-based) at tick `tick` (1 … 48) in words with its flux, the tick's band and the comfortable band:
    /// "world 2 at tick 17: 41 250 milliflux, comfortable, band 30 000 … 52 000".
    public func worldTickDescription(_ world: Int, tick: Int, report: BinaryGardensReport) -> String {
        let light: BinaryGardensWorldLight = report.worlds[world]
        let rules: BinaryGardensWorld = worlds[world]
        return "world \(world + 1) at tick \(tick): " + Self.grouped(light.flux[tick - 1]) + " milliflux, "
            + light.bands[tick - 1].words + ", band " + Self.grouped(rules.comfortLow) + " … "
            + Self.grouped(rules.comfortHigh)
    }

    /// World `world` (0-based) in words with its window, its longest lethal run and its integral: "world 2: window of 31
    /// ticks from tick 5, 24 required; longest lethal run 1 of 2 allowed; integral 1 980 000, bloom band
    /// 1 900 000 … 2 100 000" ("no comfortable window" when no tick is comfortable).
    public func worldDescription(_ world: Int, report: BinaryGardensReport) -> String {
        let light: BinaryGardensWorldLight = report.worlds[world]
        let rules: BinaryGardensWorld = worlds[world]
        let window: String = light.window == 0 ? "no comfortable window"
            : "window of " + Self.ticksWords(light.window) + " from tick \(light.windowStart)"
        return "world \(world + 1): " + window + ", \(rules.window) required; longest lethal run "
            + "\(light.longestLethalRun) of \(lethalTolerance) allowed; integral " + Self.grouped(light.integral)
            + ", bloom band " + Self.grouped(rules.bloomLow) + " … " + Self.grouped(rules.bloomHigh)
    }

    /// A failure in words: "world 1 froze at tick 50 (tick 2 of the next cycle)", "world 2 scorched at tick 7",
    /// "world 1 has a comfortable window of only 20 ticks, 24 required", "world 3 wilted: integral 1 800 000 below the
    /// bloom band 1 900 000 … 2 100 000", "world 3 bleached: integral 2 200 000 above the bloom band …".
    public func failureDescription(_ failure: BinaryGardensFailure) -> String {
        switch failure {
        case .frozen(let world, let tick):
            "world \(world + 1) froze at " + Self.walkTickWords(tick)
        case .scorched(let world, let tick):
            "world \(world + 1) scorched at " + Self.walkTickWords(tick)
        case .unstable(let world, let window, let required):
            "world \(world + 1) has a comfortable window of only " + Self.ticksWords(window) + ", \(required) required"
        case .wilted(let world, let integral, let low, let high):
            "world \(world + 1) wilted: integral " + Self.grouped(integral) + " below the bloom band "
                + Self.grouped(low) + " … " + Self.grouped(high)
        case .bleached(let world, let integral, let low, let high):
            "world \(world + 1) bleached: integral " + Self.grouped(integral) + " above the bloom band "
                + Self.grouped(low) + " … " + Self.grouped(high)
        }
    }

    /// The progress in words: both stars, the tilt, every world, the closest approach of the stars, the predicted
    /// outcome and the actions left, joined by "; ".
    public func progressDescription(report: BinaryGardensReport, arrangement: BinaryGardensArrangement,
                                    actionsLeft: Int) -> String {
        var parts: [String] = []
        for star in 0..<2 { parts.append(starDescription(star, arrangement: arrangement)) }
        parts.append("tilt \(arrangement.tilt) of \(maxTilt) steps")
        for world in worlds.indices where world < report.worlds.count {
            parts.append(worldDescription(world, report: report))
        }
        let apart: Int = BinaryGardensSky.integerSquareRoot(report.minimumSeparationSquared)
            / BinaryGardensSky.positionScale
        parts.append("stars closest at tick \(report.minimumSeparationTick), \(apart) units apart, "
                     + "\(minimumSeparation) required")
        if let failure = report.failure {
            parts.append("running now would fail: " + failureDescription(failure))
        } else {
            parts.append("running now would win")
        }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Binary Gardens level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint, in this order: broken JSON, a newer schema,
    /// a schema below 1 or a missing field, a value the initialiser refuses, a fingerprint that does not match.
    ///
    /// - Throws: `.malformed("unreadable")` for broken JSON or a missing field; `.newerSchema(s)` above ``schema``;
    ///   `.malformed("schema <s>")` below 1; `.level(reason)` for stored values the initialiser refuses;
    ///   `.malformed("fingerprint")` for a fingerprint that does not match the canonical text.
    public static func decode(_ data: Data) throws(BinaryGardensError) -> BinaryGardensLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: BinaryGardensLevel
        do {
            level = try stored.content.level()
        } catch {
            if case .level = error { throw error }
            throw .malformed(error.reasonCode)
        }
        guard level.fingerprint == stored.fingerprint else { throw .malformed("fingerprint") }
        return level
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// Whether `id` is a lowercase slug of 1 … 64 characters: a … z, 0 … 9 and single inner hyphens.
    static func isSlug(_ id: String) -> Bool {
        let scalars = Array(id.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 64, scalars.first != "-", scalars.last != "-" else { return false }
        var previousHyphen = false
        for s in scalars {
            let hyphen = s == "-"
            guard hyphen || ("a"..."z").contains(s) || ("0"..."9").contains(s) else { return false }
            if hyphen && previousHyphen { return false }
            previousHyphen = hyphen
        }
        return true
    }

    /// The fingerprinted content: every stored field but the fingerprint, the schema included.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let ringRadii: [Int]
        let starSpeed: Int
        let luminosityLevels: [Int]
        let stars: [BinaryGardensStar]
        let maxTilt: Int
        let startTilt: Int
        let minimumSeparation: Int
        let clampRadius: Int
        let worlds: [BinaryGardensWorld]
        let lethalTolerance: Int
        let budget: Int
        let tutorial: Bool
        /// The phase step when above 1; nil (omitted from the JSON and the fingerprint text) for 1.
        let phaseStep: Int?

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, ringRadii: [Int], starSpeed: Int,
             luminosityLevels: [Int], stars: [BinaryGardensStar], maxTilt: Int, startTilt: Int,
             minimumSeparation: Int, clampRadius: Int, worlds: [BinaryGardensWorld], lethalTolerance: Int,
             budget: Int, tutorial: Bool, phaseStep: Int? = nil) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.ringRadii = ringRadii
            self.starSpeed = starSpeed
            self.luminosityLevels = luminosityLevels
            self.stars = stars
            self.maxTilt = maxTilt
            self.startTilt = startTilt
            self.minimumSeparation = minimumSeparation
            self.clampRadius = clampRadius
            self.worlds = worlds
            self.lethalTolerance = lethalTolerance
            self.budget = budget
            self.tutorial = tutorial
            self.phaseStep = phaseStep
        }

        init(level: BinaryGardensLevel) {
            self.init(schema: BinaryGardensLevel.schema, id: level.id, seed: level.seed, difficulty: level.difficulty,
                      ringRadii: level.ringRadii, starSpeed: level.starSpeed,
                      luminosityLevels: level.luminosityLevels, stars: level.stars, maxTilt: level.maxTilt,
                      startTilt: level.startTilt, minimumSeparation: level.minimumSeparation,
                      clampRadius: level.clampRadius, worlds: level.worlds, lethalTolerance: level.lethalTolerance,
                      budget: level.budget, tutorial: level.tutorial,
                      phaseStep: level.phaseStep == 1 ? nil : level.phaseStep)
        }

        /// The level of this content, re-checked.
        func level() throws(BinaryGardensError) -> BinaryGardensLevel {
            try BinaryGardensLevel(id: id, seed: seed, difficulty: difficulty, ringRadii: ringRadii,
                                   starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: stars,
                                   maxTilt: maxTilt, startTilt: startTilt, minimumSeparation: minimumSeparation,
                                   clampRadius: clampRadius, worlds: worlds, lethalTolerance: lethalTolerance,
                                   budget: budget, tutorial: tutorial, phaseStep: phaseStep ?? 1)
        }
    }

    /// The stored form: the content flattened with its fingerprint.
    struct Stored: Codable {
        let content: Content
        let fingerprint: String

        init(content: Content, fingerprint: String) {
            self.content = content
            self.fingerprint = fingerprint
        }

        private enum Keys: String, CodingKey { case fingerprint }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            fingerprint = try c.decode(String.self, forKey: .fingerprint)
            content = try Content(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            try content.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(fingerprint, forKey: .fingerprint)
        }
    }
}

extension BinaryGardensLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = BinaryGardensError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        guard stored.content.schema >= 1 else {
            let code = BinaryGardensError.malformed("schema").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = BinaryGardensError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
