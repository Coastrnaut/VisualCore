// CelestialEclipseLabLevel — feature 461 (R02-G17-01) T-R02G1701-002 (FR-R02G1701-001, 002, 009, 011, 013;
// SC-R02G1701-001, 005; clarifications Q1 … Q5). An immutable Celestial Eclipse Lab level: 2 … 6 bodies (each with an
// orbit of 4 … 24 lattice positions, coordinates −32 … 32, a disc radius 1 … 8 and a fixed flag), at least one movable;
// every pair of bodies depth-ordered (the front body's smallest z above the back body's largest z); a horizon of 8 … 96
// ticks; a target of 1 … 6 eclipses (two different bodies, the front one the front of its pair, a window 0 ≤ open ≤
// close ≤ horizon − 1); the starting phases (one per body, 0 … period − 1), which must not already win; an action
// budget 1 … 24; a difficulty 1 … 5 and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its
// canonical JSON (schema 1, sorted keys, fingerprint excluded); the stored form is re-checked on decode. Bodies,
// eclipses and progress are named in words (FR-R02G1701-013); body numbers are their indices. Modelled on
// `StarlitCartoucheLevel` (feature 451).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Celestial Eclipse Lab level.
public struct CelestialEclipseLabLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The number of bodies.
    public static let bodyCounts: ClosedRange<Int> = 2...6
    /// The orbit lengths (periods) in ticks.
    public static let periods: ClosedRange<Int> = 4...24
    /// The lattice coordinates.
    public static let coordinates: ClosedRange<Int> = -32...32
    /// The disc radii.
    public static let radii: ClosedRange<Int> = 1...8
    /// The horizons in ticks.
    public static let horizons: ClosedRange<Int> = 8...96
    /// The target lengths.
    public static let targetCounts: ClosedRange<Int> = 1...6
    /// The action budgets.
    public static let budgets: ClosedRange<Int> = 1...24

    /// The level's id, a lowercase slug.
    public let id: String
    /// The seed the level was generated from (0 for hand-made levels).
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The bodies, numbered by index.
    public let bodies: [CelestialEclipseLabBody]
    /// The horizon: the clock runs ticks 0 … horizon − 1.
    public let horizon: Int
    /// The target sequence of eclipses.
    public let target: [CelestialEclipseLabTarget]
    /// The starting phase of each body.
    public let phases: [Int]
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, bodies: [CelestialEclipseLabBody], horizon: Int,
                target: [CelestialEclipseLabTarget], phases: [Int], budget: Int,
                tutorial: Bool = false) throws(CelestialEclipseLabError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, bodies: bodies, horizon: horizon, target: target,
                      phases: phases, budget: budget, tutorial: tutorial, refusingAWin: true)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// intervals passes false).
    init(id: String, seed: UInt64, difficulty: Int, bodies: [CelestialEclipseLabBody], horizon: Int,
         target: [CelestialEclipseLabTarget], phases: [Int], budget: Int, tutorial: Bool,
         refusingAWin: Bool) throws(CelestialEclipseLabError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.bodyCounts.contains(bodies.count) else { throw .level("bodies") }
        for body in bodies {
            guard Self.periods.contains(body.period) else { throw .level("orbit") }
            for p in body.orbit {
                guard Self.coordinates.contains(p.x), Self.coordinates.contains(p.y), Self.coordinates.contains(p.z)
                else { throw .level("position") }
            }
            guard Self.radii.contains(body.radius) else { throw .level("radius") }
        }
        guard bodies.contains(where: { !$0.fixed }) else { throw .level("movable") }
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let ordered: Bool = bodies[i].nearestBack > bodies[j].farthestFront
                    || bodies[j].nearestBack > bodies[i].farthestFront
                guard ordered else { throw .level("depth order") }
            }
        }
        guard Self.horizons.contains(horizon) else { throw .level("horizon") }
        guard Self.targetCounts.contains(target.count) else { throw .level("target") }
        for eclipse in target {
            guard eclipse.front >= 0, eclipse.front < bodies.count, eclipse.back >= 0, eclipse.back < bodies.count,
                  eclipse.front != eclipse.back else { throw .level("target bodies") }
            guard bodies[eclipse.front].nearestBack > bodies[eclipse.back].farthestFront else {
                throw .level("target front")
            }
            guard eclipse.open >= 0, eclipse.open <= eclipse.close, eclipse.close <= horizon - 1 else {
                throw .level("target window")
            }
        }
        guard phases.count == bodies.count else { throw .level("phases") }
        for (index, phase) in phases.enumerated() {
            guard phase >= 0, phase < bodies[index].period else { throw .level("phase") }
        }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, bodies: bodies,
                              horizon: horizon, target: target, phases: phases, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.bodies = bodies
        self.horizon = horizon
        self.target = target
        self.phases = phases
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        if refusingAWin {
            guard !CelestialEclipseLabSky.timeline(self, phases: phases).wins else { throw .level("already won") }
        }
    }

    /// A probe level that skips the "already won" rule, for reading the intervals of other phases (the content
    /// pipeline and the fixtures); every other rule is checked.
    static func probe(bodies: [CelestialEclipseLabBody], horizon: Int, target: [CelestialEclipseLabTarget],
                      phases: [Int]) throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        try CelestialEclipseLabLevel(id: "probe", seed: 0, difficulty: 1, bodies: bodies, horizon: horizon,
                                     target: target, phases: phases, budget: 1, tutorial: false, refusingAWin: false)
    }

    /// The predicted timeline of the starting phases.
    public var startTimeline: CelestialEclipseLabTimeline {
        CelestialEclipseLabSky.timeline(self, phases: phases)
    }

    /// "body 3".
    public func bodyName(_ index: Int) -> String { "body \(index)" }

    /// "body 2 in front of body 4".
    public func eclipseName(front: Int, back: Int) -> String {
        "\(bodyName(front)) in front of \(bodyName(back))"
    }

    /// "body 2 in front of body 4 from tick 7 to tick 9, total".
    public func intervalDescription(_ interval: CelestialEclipseLabInterval) -> String {
        let span: String = interval.first == interval.last
            ? "at tick \(interval.first)" : "from tick \(interval.first) to tick \(interval.last)"
        return eclipseName(front: interval.front, back: interval.back) + " " + span + ", "
            + interval.visibility.rawValue
    }

    /// The progress in words: the target eclipses matched, the next one with its window, and the actions left.
    public func progressDescription(timeline: CelestialEclipseLabTimeline, actionsLeft: Int) -> String {
        var parts: [String] = ["\(timeline.matched) of \(target.count) eclipses in order"]
        if timeline.matched < target.count {
            let next: CelestialEclipseLabTarget = target[timeline.matched]
            parts.append("next: " + eclipseName(front: next.front, back: next.back)
                         + " between tick \(next.open) and tick \(next.close)")
        }
        parts.append(timeline.wins ? "a run now would win" : "a run now would fail")
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Celestial Eclipse Lab level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: CelestialEclipseLabLevel
        do {
            level = try stored.content.level()
        } catch {
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

    /// The fingerprinted content.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let bodies: [CelestialEclipseLabBody]
        let horizon: Int
        let target: [CelestialEclipseLabTarget]
        let phases: [Int]
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, bodies: [CelestialEclipseLabBody],
             horizon: Int, target: [CelestialEclipseLabTarget], phases: [Int], budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.bodies = bodies
            self.horizon = horizon
            self.target = target
            self.phases = phases
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: CelestialEclipseLabLevel) {
            self.init(schema: CelestialEclipseLabLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, bodies: level.bodies, horizon: level.horizon,
                      target: level.target, phases: level.phases, budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
            try CelestialEclipseLabLevel(id: id, seed: seed, difficulty: difficulty, bodies: bodies, horizon: horizon,
                                         target: target, phases: phases, budget: budget, tutorial: tutorial)
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

extension CelestialEclipseLabLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = CelestialEclipseLabError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = CelestialEclipseLabError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
