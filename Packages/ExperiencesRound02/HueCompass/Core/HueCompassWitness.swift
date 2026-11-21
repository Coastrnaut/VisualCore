// HueCompassWitness — feature 332 (R02-G04-02) T-R02G0402-005 (FR-R02G0402-004; SC-R02G0402-003, 005; clarifications
// Q2, Q4). The solver witness of one generated level: the actions (for each probe bearing in order the shortest turn to
// it, when not zero, then the probe; then the smallest acceptable selection of the true target's class), the clues, the
// number of candidates still consistent with every clue so far after each probe, the play fingerprints after `begin`
// (and `dismissTutorial`) and after each action, the near miss (the bearing target + bearing tolerance + 1 with the
// target's band, which fails), the insufficient smaller probe set with two targets no one selection accepts together,
// the difficulty and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing
// newline. Making and decoding both rebuild the witness from its level and actions — replay, clues, counts, fingerprints,
// soundness of the probes, the near miss, the ambiguity and the difficulty (by its own deduction, independent of
// `HueCompassSolver.solve`) — and refuse any value the rebuild does not reproduce.
import Foundation

/// The replayable proof that a generated Hue Compass level is settled by its probes, won by its selection, lost by a near
/// miss and not settled by a smaller probe set.
public struct HueCompassWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level.
    public let level: HueCompassLevel
    /// The actions of the solution, in order.
    public let actions: [HueCompassAction]
    /// The clues the probes returned, in order.
    public let clues: [HueCompassClue]
    /// After each probe, the number of candidates still consistent with every clue so far.
    public let counts: [Int]
    /// The play fingerprint after `begin` (and `dismissTutorial` when the level has a tutorial), then after each action.
    public let fingerprints: [String]
    /// The selection of bearing target + bearing tolerance + 1 (mod 96) with the target's band; it fails.
    public let nearMiss: HueCompassSelection
    /// A probe set one smaller than the solution's with two consistent targets no one selection accepts together.
    public let ambiguity: HueCompassAmbiguity
    /// The level's difficulty.
    public let difficulty: HueCompassDifficulty
    /// The candidates the generator skipped before accepting this level, 0 … 63.
    public let skipped: Int

    /// A witness of the given values (not checked).
    private init(number: Int, level: HueCompassLevel, actions: [HueCompassAction], clues: [HueCompassClue],
                 counts: [Int], fingerprints: [String], nearMiss: HueCompassSelection, ambiguity: HueCompassAmbiguity,
                 difficulty: HueCompassDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.clues = clues
        self.counts = counts
        self.fingerprints = fingerprints
        self.nearMiss = nearMiss
        self.ambiguity = ambiguity
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The actions of `solution` on `level`: from the start, for each probe bearing in order the shortest turn to it
    /// (−47 … 48, 48 for the opposite bearing; omitted when 0) and the probe; then the smallest acceptable selection
    /// (bearing first, then band, each from 0) for the candidates consistent with the true target's clues. The selection
    /// is omitted when that class has none, so such actions never win.
    public static func actions(for solution: HueCompassSolution, level: HueCompassLevel) -> [HueCompassAction] {
        actions(probes: solution.probes, level: level, deduction: HueCompassDeduction(level))
    }

    /// The witness of a generated level, built by replaying its solution's actions on a new play and re-deriving every
    /// part.
    ///
    /// - Throws: `.witness("ambiguity")` when the solution has no ambiguity or it is not valid; `.witness(part)` for any
    ///   other part the rebuild refuses (see ``decode(_:)``).
    public static func make(_ generated: HueCompassGenerated) throws(HueCompassError) -> Self {
        let level: HueCompassLevel = generated.level
        guard let ambiguity = generated.solution.ambiguity else { throw .witness("ambiguity") }
        let deduction = HueCompassDeduction(level)
        let actions: [HueCompassAction] = actions(probes: generated.solution.probes, level: level, deduction: deduction)
        return try build(number: generated.entry.number, level: level, actions: actions, ambiguity: ambiguity,
                         difficulty: generated.difficulty, skipped: generated.skipped, deduction: deduction)
    }

    /// The stored form: JSON with sorted keys, pretty-printed, without escaped slashes, followed by one newline.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        do {
            var data: Data = try encoder.encode(self)
            data.append(0x0A)
            return data
        } catch {
            preconditionFailure("a Hue Compass witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it by rebuilding it from its level and actions.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys or a
    ///   schema below 1; `.witness("level")` for a level the level rules refuse (an edited field breaks its
    ///   fingerprint); `.witness(part)` with `"actions"` (not the canonical actions of their probes), `"replay"` (a
    ///   refused action or no win), `"soundness"` (a class of consistent candidates after the probes has no selection, or
    ///   more than two probes), `"near-miss"`, `"ambiguity"`, `"difficulty"` (including probes that are not the first
    ///   settling set), `"number"`, `"skipped"`, `"fingerprints"`, `"clues"` or `"counts"` for a value the rebuild does
    ///   not reproduce.
    public static func decode(_ data: Data) throws(HueCompassError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .malformed("unreadable")
        }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, actions: stored.actions,
                                      ambiguity: stored.ambiguity, difficulty: stored.difficulty,
                                      skipped: stored.skipped, deduction: HueCompassDeduction(stored.level))
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.clues == stored.clues else { throw .witness("clues") }
        guard rebuilt.counts == stored.counts else { throw .witness("counts") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        return stored
    }

    /// The near miss of `level`: bearing target + bearing tolerance + 1 (mod 96) with the target's band.
    static func nearMiss(of level: HueCompassLevel) -> HueCompassSelection {
        HueCompassSelection(bearing: HueCompassWheel.mod(level.target + level.bearingTolerance + 1,
                                                         HueCompassWheel.bearings),
                            band: level.targetBand)
    }

    /// The signed shortest turn from `from` to `to`, −47 … 48 (48 for opposite bearings).
    static func shortestTurn(from: Int, to: Int) -> Int {
        let d: Int = HueCompassWheel.mod(to - from, HueCompassWheel.bearings)
        return d <= HueCompassWheel.bearings / 2 ? d : d - HueCompassWheel.bearings
    }

    /// The canonical actions of the probe bearings `probes` on `level`.
    static func actions(probes: [Int], level: HueCompassLevel,
                        deduction: HueCompassDeduction) -> [HueCompassAction] {
        var result: [HueCompassAction] = []
        var bearing: Int = level.start
        for p in probes {
            let next: Int = HueCompassWheel.mod(p, HueCompassWheel.bearings)
            let turn: Int = shortestTurn(from: bearing, to: next)
            if turn != 0 { result.append(.turn(turn)) }
            result.append(.probe)
            bearing = next
        }
        let members: [Int] = deduction.consistent(with: level.target, probes: probes)
        if let selection = deduction.selection(for: members) {
            result.append(.select(bearing: selection.bearing, band: selection.band))
        }
        return result
    }

    /// The probe bearings of `actions` from `start`, in order.
    static func probeBearings(_ actions: [HueCompassAction], start: Int) -> [Int] {
        var bearing: Int = start
        var probes: [Int] = []
        for action in actions {
            switch action {
            case .turn(let steps): bearing = HueCompassWheel.mod(bearing + steps, HueCompassWheel.bearings)
            case .probe: probes.append(bearing)
            case .select: break
            }
        }
        return probes
    }

    /// Rebuilds a witness from its level and actions, checking every part.
    private static func build(number: Int, level: HueCompassLevel, actions: [HueCompassAction],
                              ambiguity: HueCompassAmbiguity, difficulty: HueCompassDifficulty, skipped: Int,
                              deduction: HueCompassDeduction) throws(HueCompassError) -> Self {
        let probes: [Int] = probeBearings(actions, start: level.start)
        guard actions == Self.actions(probes: probes, level: level, deduction: deduction) else {
            throw .witness("actions")
        }
        // Replay on a new play.
        var play = HueCompassPlay(level: level)
        var fingerprints: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
        } catch {
            throw .witness("replay")
        }
        guard play.stage == .won else { throw .witness("replay") }
        // Counts: candidates consistent with every clue so far, after each probe.
        var counts: [Int] = []
        for index in probes.indices {
            let prefix: [Int] = Array(probes[0...index])
            counts.append(deduction.consistent(with: level.target, probes: prefix).count)
        }
        // Soundness: every class of consistent candidates after the probes has a selection.
        guard probes.count <= HueCompassSolver.maximumDepth, deduction.settles(probes) else {
            throw .witness("soundness")
        }
        let miss: HueCompassSelection = nearMiss(of: level)
        guard !level.accepts(bearing: miss.bearing, band: miss.band) else { throw .witness("near-miss") }
        guard deduction.isValid(ambiguity, smallest: probes.count) else { throw .witness("ambiguity") }
        // Difficulty: the probes are the first settling set, and every metric is reproduced.
        guard let first = deduction.firstSettling(depth: HueCompassSolver.maximumDepth), first.probes == probes else {
            throw .witness("difficulty")
        }
        let recomputed = HueCompassDifficulty(smallest: probes.count,
                                              largestAfterBestSingle: deduction.bestSingle().largest,
                                              bearingTolerance: level.bearingTolerance,
                                              bandTolerance: level.bandTolerance,
                                              clearShare: HueCompassBandProfile.of(band: level.band).clearShare,
                                              work: first.work)
        guard recomputed == difficulty else { throw .witness("difficulty") }
        guard (1...100).contains(number) else { throw .witness("number") }
        guard (0...63).contains(skipped) else { throw .witness("skipped") }
        return Self(number: number, level: level, actions: actions, clues: play.clues, counts: counts,
                    fingerprints: fingerprints, nearMiss: miss, ambiguity: ambiguity, difficulty: difficulty,
                    skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, clues, counts, fingerprints, nearMiss, ambiguity, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        do { level = try c.decode(HueCompassLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([HueCompassAction].self, forKey: .actions)
        clues = try c.decode([HueCompassClue].self, forKey: .clues)
        counts = try c.decode([Int].self, forKey: .counts)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        nearMiss = try c.decode(HueCompassSelection.self, forKey: .nearMiss)
        ambiguity = try c.decode(HueCompassAmbiguity.self, forKey: .ambiguity)
        difficulty = try c.decode(HueCompassDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(clues, forKey: .clues)
        try c.encode(counts, forKey: .counts)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(ambiguity, forKey: .ambiguity)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}

/// The witness's own deduction over one level (clarification Q2), independent of `HueCompassSolver.solve`: the clue of
/// every candidate target at every bearing, as a code hue gap × 512 + depth (depth ≤ 423).
struct HueCompassDeduction {
    /// The level.
    let level: HueCompassLevel
    /// The candidates: bearings farther from the start than the bearing tolerance, ascending.
    let candidates: [Int]
    /// The clue code of target t at bearing b, at index b × 96 + t.
    let codes: [Int]
    /// The number of distinct clue codes (13 hue gaps × 512 depths).
    static let codeRange: Int = 13 * 512

    init(_ level: HueCompassLevel) {
        self.level = level
        let n: Int = HueCompassWheel.bearings
        var candidates: [Int] = []
        for t in 0..<n where HueCompassWheel.bearingDistance(t, level.start) > level.bearingTolerance {
            candidates.append(t)
        }
        self.candidates = candidates
        var bands: [Int] = []
        for b in 0..<n { bands.append(level.band(of: b)) }
        var codes: [Int] = Array(repeating: 0, count: n * n)
        for b in 0..<n {
            for t in 0..<n {
                var depth: Int = 0
                for inside in HueCompassWheel.arc(from: b, to: t) { depth += level.fog[inside] }
                codes[b * n + t] = HueCompassWheel.bandDistance(bands[b], bands[t]) * 512 + depth
            }
        }
        self.codes = codes
    }

    /// The clue code of target `t` at bearing `b`.
    func code(_ b: Int, _ t: Int) -> Int { codes[b * HueCompassWheel.bearings + t] }

    /// The candidates with the same clues as `target` at every bearing of `probes`, ascending.
    func consistent(with target: Int, probes: [Int]) -> [Int] {
        var result: [Int] = []
        for c in candidates {
            var same: Bool = true
            for p in probes where code(p, c) != code(p, target) {
                same = false
                break
            }
            if same { result.append(c) }
        }
        return result
    }

    /// The candidates grouped by their clues at `probes` (at most four probes), each class ascending.
    func classes(_ probes: [Int]) -> [[Int]] {
        var index: [Int: Int] = [:]
        var result: [[Int]] = []
        for c in candidates {
            var key: Int = 0
            for p in probes { key = key * Self.codeRange + code(p, c) }
            if let i = index[key] {
                result[i].append(c)
            } else {
                index[key] = result.count
                result.append([c])
            }
        }
        return result
    }

    /// The smallest acceptable selection for `members` (bearing first, then band, each from 0), or nil.
    func selection(for members: [Int]) -> HueCompassSelection? {
        guard let first = members.first else { return nil }
        var bearing: Int?
        for offset in -level.bearingTolerance...level.bearingTolerance {
            let b: Int = HueCompassWheel.mod(first + offset, HueCompassWheel.bearings)
            var ok: Bool = true
            for m in members where HueCompassWheel.bearingDistance(b, m) > level.bearingTolerance {
                ok = false
                break
            }
            if ok, bearing.map({ b < $0 }) ?? true { bearing = b }
        }
        guard let bearing else { return nil }
        var band: Int?
        let firstBand: Int = level.band(of: first)
        for offset in -level.bandTolerance...level.bandTolerance {
            let k: Int = HueCompassWheel.mod(firstBand + offset, HueCompassWheel.bands)
            var ok: Bool = true
            for m in members where HueCompassWheel.bandDistance(k, level.band(of: m)) > level.bandTolerance {
                ok = false
                break
            }
            if ok, band.map({ k < $0 }) ?? true { band = k }
        }
        guard let band else { return nil }
        return HueCompassSelection(bearing: bearing, band: band)
    }

    /// Whether every class of `probes` has a selection.
    func settles(_ probes: [Int]) -> Bool {
        for members in classes(probes) where selection(for: members) == nil { return false }
        return true
    }

    /// The first settling probe set in the solver's order (empty, singles, pairs, each lexicographic) up to `depth` ≤ 2,
    /// with the number of sets tried.
    func firstSettling(depth: Int) -> (probes: [Int], work: Int)? {
        let n: Int = HueCompassWheel.bearings
        var work: Int = 1
        if settles([]) { return ([], work) }
        guard depth >= 1 else { return nil }
        for a in 0..<n {
            work += 1
            if settles([a]) { return ([a], work) }
        }
        guard depth >= 2 else { return nil }
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) {
                work += 1
                if settles([a, b]) { return ([a, b], work) }
            }
        }
        return nil
    }

    /// The single bearing whose largest class is smallest (lowest bearing on a tie), with that size.
    func bestSingle() -> (bearing: Int, largest: Int) {
        var best: (bearing: Int, largest: Int) = (0, Int.max)
        for b in 0..<HueCompassWheel.bearings {
            var largest: Int = 0
            for members in classes([b]) { largest = max(largest, members.count) }
            if largest < best.largest { best = (b, largest) }
        }
        return best
    }

    /// Whether `ambiguity` is a probe set of `smallest − 1` ascending bearings with two ascending candidate targets that
    /// share every clue of it and that no one selection accepts together.
    func isValid(_ ambiguity: HueCompassAmbiguity, smallest: Int) -> Bool {
        let probes: [Int] = ambiguity.probes
        guard probes.count == smallest - 1 else { return false }
        for (i, p) in probes.enumerated() {
            guard (0..<HueCompassWheel.bearings).contains(p) else { return false }
            if i > 0 && probes[i - 1] >= p { return false }
        }
        let targets: [Int] = ambiguity.targets
        guard targets.count == 2, targets[0] < targets[1], candidates.contains(targets[0]),
              candidates.contains(targets[1]) else { return false }
        for p in probes where code(p, targets[0]) != code(p, targets[1]) { return false }
        return selection(for: targets) == nil
    }
}
