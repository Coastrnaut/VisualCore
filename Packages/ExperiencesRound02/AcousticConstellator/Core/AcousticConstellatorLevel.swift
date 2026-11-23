// AcousticConstellatorLevel — feature 421 (R02-G13-01) T-R02G1301-002 (FR-R02G1301-001, 002, 003, 009, 011, 013, 014;
// SC-R02G1301-001, 003, 005; clarifications Q1, Q2, Q4, Q5). An immutable Acoustic Constellator level: 3 … 8 stars
// (each with a drawing position on the 12 × 12 × 12 grid that never decides a rule, a natural rate 0 … 11 phase steps
// per tick and a starting phase 0 … 11), 0 … 6 fixed links the player cannot remove, a target symbol of 2 … 10 star
// pairs whose graph is connected, a coupling strength K 1 … 8, a degree limit D 2 … 4 (links per star, fixed links
// included), a link limit E from the symbol's size to 16 (links at once, fixed included), a snap limit σ 2 … 5, a
// coherence threshold θ 1 … n² (compared with n²R²), a hold H 2 … 12, a window W H … 48, an action budget 1 … 40, a
// difficulty 1 … 5 and whether a tutorial precedes play. Links and symbol pairs join distinct stars a < b with no pair
// repeated within a list; fixed links that break the degree or link limit are refused. The listen of any links and
// starting phases is the exact truth metric (AcousticConstellatorDynamics.swift). Its fingerprint is the SHA-256 hex of
// its canonical JSON (schema 1, sorted keys, stars as [x, y, z, rate, phase], fixed links and symbol as [a, b] pairs,
// fingerprint excluded); the stored form is re-checked on decode. Stars, links and progress are named in words
// (FR-R02G1301-013); star and tick numbers in words are their indices, counted from 0.
import Foundation
import VisualCoreMath

/// A star: a drawing position (x, y, z each 0 … 11; it never decides a rule), a natural rate 0 … 11 phase steps per
/// tick and a starting phase 0 … 11. Stored as `[x, y, z, rate, phase]`.
public struct AcousticConstellatorStar: Sendable, Hashable, Codable {
    /// The drawing column, 0 … 11.
    public let x: Int
    /// The drawing row, 0 … 11.
    public let y: Int
    /// The drawing depth, 0 … 11.
    public let z: Int
    /// The natural rate ω, 0 … 11 phase steps per tick.
    public let rate: Int
    /// The starting phase φ₀, 0 … 11.
    public let phase: Int

    /// A star; the level checks the ranges.
    public init(x: Int, y: Int, z: Int, rate: Int, phase: Int) {
        self.x = x
        self.y = y
        self.z = z
        self.rate = rate
        self.phase = phase
    }

    /// Decodes `[x, y, z, rate, phase]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Int.self)
        y = try c.decode(Int.self)
        z = try c.decode(Int.self)
        rate = try c.decode(Int.self)
        phase = try c.decode(Int.self)
        guard c.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "a star is [x, y, z, rate, phase]")
        }
    }

    /// Encodes `[x, y, z, rate, phase]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
        try c.encode(z)
        try c.encode(rate)
        try c.encode(phase)
    }
}

/// An immutable, fingerprinted Acoustic Constellator level.
public struct AcousticConstellatorLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed difficulties.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The allowed star counts.
    public static let starCounts: ClosedRange<Int> = 3...8
    /// The allowed drawing coordinates (x, y and z).
    public static let coordinates: ClosedRange<Int> = 0...11
    /// The allowed natural rates, in phase steps per tick.
    public static let rates: ClosedRange<Int> = 0...11
    /// The allowed starting phases.
    public static let phases: ClosedRange<Int> = 0...11
    /// The allowed fixed-link counts.
    public static let fixedCounts: ClosedRange<Int> = 0...6
    /// The allowed symbol sizes, in pairs.
    public static let symbolSizes: ClosedRange<Int> = 2...10
    /// The allowed coupling strengths K.
    public static let couplings: ClosedRange<Int> = 1...8
    /// The allowed degree limits D.
    public static let degreeLimits: ClosedRange<Int> = 2...4
    /// The largest link limit E (the smallest is the symbol's size).
    public static let maxLinkLimit: Int = 16
    /// The allowed snap limits σ.
    public static let snapLimits: ClosedRange<Int> = 2...5
    /// The allowed holds H.
    public static let holds: ClosedRange<Int> = 2...12
    /// The largest window W (the smallest is the hold).
    public static let maxWindow: Int = 48
    /// The allowed action budgets.
    public static let budgets: ClosedRange<Int> = 1...40

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The stars, by index, with their starting phases.
    public let stars: [AcousticConstellatorStar]
    /// The fixed links (the player cannot remove them), in list order.
    public let fixedLinks: [AcousticConstellatorLink]
    /// The target symbol's pairs, in list order; its graph is connected.
    public let symbol: [AcousticConstellatorLink]
    /// The coupling strength K, 1 … 8.
    public let coupling: Int
    /// The degree limit D: links per star, fixed links included.
    public let degreeLimit: Int
    /// The link limit E: links at once, fixed links included.
    public let linkLimit: Int
    /// The snap limit σ: a link snaps when its |gap| exceeds it.
    public let snapLimit: Int
    /// The coherence threshold θ, 1 … n², compared with n²R² = A + B√3.
    public let threshold: Int
    /// The hold H: consecutive coherent ticks that win.
    public let hold: Int
    /// The window W: ticks a listen runs at most.
    public let window: Int
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"stars"` (a count outside 3 … 8, a coordinate, rate or
    ///   phase outside 0 … 11), `"fixedLinks"` (a count outside 0 … 6, a star out of range, a ≥ b, a repeated pair),
    ///   `"symbol"` (a size outside 2 … 10, a star out of range, a ≥ b, a repeated pair, a disconnected graph),
    ///   `"coupling"`, `"degreeLimit"`, `"linkLimit"` (below the symbol's size or above 16), `"snapLimit"`,
    ///   `"threshold"` (outside 1 … n²), `"hold"`, `"window"` (outside H … 48), `"budget"`, or `"fixedLimits"` (the
    ///   fixed links take a star above D or number more than E).
    public init(id: String, seed: UInt64, difficulty: Int, stars: [AcousticConstellatorStar],
                fixedLinks: [AcousticConstellatorLink], symbol: [AcousticConstellatorLink], coupling: Int,
                degreeLimit: Int, linkLimit: Int, snapLimit: Int, threshold: Int, hold: Int, window: Int, budget: Int,
                tutorial: Bool = false) throws(AcousticConstellatorError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.starCounts.contains(stars.count) else { throw .level("stars") }
        for star in stars {
            guard Self.coordinates.contains(star.x), Self.coordinates.contains(star.y),
                  Self.coordinates.contains(star.z), Self.rates.contains(star.rate),
                  Self.phases.contains(star.phase) else { throw .level("stars") }
        }
        let n: Int = stars.count
        guard Self.fixedCounts.contains(fixedLinks.count), Self.validPairs(fixedLinks, stars: n) else {
            throw .level("fixedLinks")
        }
        guard Self.symbolSizes.contains(symbol.count), Self.validPairs(symbol, stars: n) else {
            throw .level("symbol")
        }
        guard AcousticConstellatorClock.joins(Self.starsOf(symbol), links: symbol, count: n) else {
            throw .level("symbol")
        }
        guard Self.couplings.contains(coupling) else { throw .level("coupling") }
        guard Self.degreeLimits.contains(degreeLimit) else { throw .level("degreeLimit") }
        guard linkLimit >= symbol.count, linkLimit <= Self.maxLinkLimit else { throw .level("linkLimit") }
        guard Self.snapLimits.contains(snapLimit) else { throw .level("snapLimit") }
        guard threshold >= 1, threshold <= n * n else { throw .level("threshold") }
        guard Self.holds.contains(hold) else { throw .level("hold") }
        guard window >= hold, window <= Self.maxWindow else { throw .level("window") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard fixedLinks.count <= linkLimit else { throw .level("fixedLimits") }
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in fixedLinks {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        for degree in degrees where degree > degreeLimit { throw .level("fixedLimits") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, stars: stars,
                              fixedLinks: fixedLinks, symbol: symbol, coupling: coupling, degreeLimit: degreeLimit,
                              linkLimit: linkLimit, snapLimit: snapLimit, threshold: threshold, hold: hold,
                              window: window, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.stars = stars
        self.fixedLinks = fixedLinks
        self.symbol = symbol
        self.coupling = coupling
        self.degreeLimit = degreeLimit
        self.linkLimit = linkLimit
        self.snapLimit = snapLimit
        self.threshold = threshold
        self.hold = hold
        self.window = window
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The starting phases, one per star.
    public var startingPhases: [Int] { stars.map(\.phase) }

    /// The natural rates, one per star.
    public var naturalRates: [Int] { stars.map(\.rate) }

    /// The symbol's stars, in increasing order.
    public var symbolStars: [Int] { Self.starsOf(symbol) }

    /// The graph-isomorphism label of the target symbol's graph on all stars.
    public var symbolLabel: String { AcousticConstellatorLabel.label(stars: stars.count, links: symbol) }

    /// The truth metric of a listen of `links` (in their list order) from starting `phases` (one per star).
    public func listen(links: [AcousticConstellatorLink], phases: [Int]) -> AcousticConstellatorListen {
        AcousticConstellatorListen.run(rates: naturalRates, phases: phases, links: links, symbol: symbol,
                                       coupling: coupling, snapLimit: snapLimit, threshold: threshold, hold: hold,
                                       window: window)
    }

    /// Star `index` in words: "star 2, rate 3, phase 7".
    public func starName(_ index: Int, phase: Int) -> String {
        "star \(index), rate \(stars[index].rate), phase \(phase)"
    }

    /// `link` in words at `phases`: "link star 0 to star 3, gap 2" (the gap is the size of the signed gap).
    public func linkName(_ link: AcousticConstellatorLink, phases: [Int]) -> String {
        let gap: Int = abs(AcousticConstellatorClock.gap(phases[link.a], phases[link.b]))
        return "link star \(link.a) to star \(link.b), gap \(gap)"
    }

    /// The progress in words, for the last tick of `listen`: "tick 6 of 20: order 9 plus 2 root 3, threshold 12,
    /// coherent, run 4 of 4, 1 link snapped; won on tick 6; 5 actions left".
    public func progressDescription(listen: AcousticConstellatorListen, actionsLeft: Int) -> String {
        let tick: Int = listen.lastTick
        let parts: [Int] = listen.order[tick]
        let root: String
        if parts[1] == 0 {
            root = ""
        } else if parts[1] > 0 {
            root = " plus \(parts[1]) root 3"
        } else {
            root = " minus \(-parts[1]) root 3"
        }
        let coherence: String = listen.coherent[tick] ? "coherent" : "not coherent"
        let count: Int = listen.snappedCount
        let snapped: String = count == 1 ? "1 link snapped" : "\(count) links snapped"
        let outcome: String
        switch listen.outcome {
        case .won(let at): outcome = "won on tick \(at)"
        case .missing(let pair): outcome = "missing link star \(pair.a) to star \(pair.b)"
        case .disconnected(let at, let link):
            outcome = "disconnected on tick \(at) by link star \(link.a) to star \(link.b)"
        case .incoherent(let run): outcome = "incoherent, longest run \(run)"
        }
        let left: String = actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left"
        return "tick \(tick) of \(window): order \(parts[0])\(root), threshold \(threshold), \(coherence), run "
            + "\(listen.currentRun) of \(hold), \(snapped); \(outcome); \(left)"
    }

    /// Whether `pairs` join distinct stars a < b within 0 ..< `stars`, with no pair repeated.
    static func validPairs(_ pairs: [AcousticConstellatorLink], stars: Int) -> Bool {
        var seen: Set<AcousticConstellatorLink> = []
        for pair in pairs {
            guard pair.a >= 0, pair.b < stars, pair.a < pair.b else { return false }
            guard seen.insert(pair).inserted else { return false }
        }
        return true
    }

    /// The stars that `pairs` touch, in increasing order.
    static func starsOf(_ pairs: [AcousticConstellatorLink]) -> [Int] {
        var stars: Set<Int> = []
        for pair in pairs {
            stars.insert(pair.a)
            stars.insert(pair.b)
        }
        return stars.sorted()
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("an Acoustic Constellator level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: AcousticConstellatorLevel
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
        let stars: [AcousticConstellatorStar]
        let fixedLinks: [AcousticConstellatorLink]
        let symbol: [AcousticConstellatorLink]
        let coupling: Int
        let degreeLimit: Int
        let linkLimit: Int
        let snapLimit: Int
        let threshold: Int
        let hold: Int
        let window: Int
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, stars: [AcousticConstellatorStar],
             fixedLinks: [AcousticConstellatorLink], symbol: [AcousticConstellatorLink], coupling: Int,
             degreeLimit: Int, linkLimit: Int, snapLimit: Int, threshold: Int, hold: Int, window: Int, budget: Int,
             tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.stars = stars
            self.fixedLinks = fixedLinks
            self.symbol = symbol
            self.coupling = coupling
            self.degreeLimit = degreeLimit
            self.linkLimit = linkLimit
            self.snapLimit = snapLimit
            self.threshold = threshold
            self.hold = hold
            self.window = window
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: AcousticConstellatorLevel) {
            self.init(schema: AcousticConstellatorLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, stars: level.stars, fixedLinks: level.fixedLinks,
                      symbol: level.symbol, coupling: level.coupling, degreeLimit: level.degreeLimit,
                      linkLimit: level.linkLimit, snapLimit: level.snapLimit, threshold: level.threshold,
                      hold: level.hold, window: level.window, budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
            try AcousticConstellatorLevel(id: id, seed: seed, difficulty: difficulty, stars: stars,
                                          fixedLinks: fixedLinks, symbol: symbol, coupling: coupling,
                                          degreeLimit: degreeLimit, linkLimit: linkLimit, snapLimit: snapLimit,
                                          threshold: threshold, hold: hold, window: window, budget: budget,
                                          tutorial: tutorial)
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

extension AcousticConstellatorLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = AcousticConstellatorError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = AcousticConstellatorError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
