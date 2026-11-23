// AcousticConstellatorWitness — feature 422 (R02-G13-02) T-R02G1302-005 (FR-R02G1302-004; SC-R02G1302-003, 005;
// clarifications Q2, Q4). The solver witness of one generated level: the manifest number, the level's stored form, the
// actions (the plan's links in pair order, then its nudges in star order, then one listen), the 16-hex state digest
// of the play's links and phases after every action, the play fingerprints after `begin`, after `dismissTutorial`
// (when the level has a tutorial) and after each action, the counterexample (the size one below the plan, the count of
// the sets of that size the solver tried, none winning, and why), the difficulty and the candidates skipped. The stored
// form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both rebuild the
// witness from its level by replaying the actions on a fresh `AcousticConstellatorPlay` and recounting every smaller
// set with the solver's own depth-first walk over the solver's options; decoding refuses any stored value the rebuild
// does not reproduce and re-runs the solver, refusing a witness whose actions, smaller sets or solver work are not the
// solver's (feature 382's convergence lesson). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no set of one action fewer than a witness plan wins (clarification Q4).
///
/// Every winning plan links every missing symbol pair (a listen loses `missing` otherwise), so the solver only tries
/// sets that hold all of them plus `e` extra options (helper links and nudges). For a plan of `m` missing links and
/// `e` extra actions, ``size`` is `m + e − 1`:
/// - `e ≥ 1` (``reason`` `"tried"`): ``sets`` is the number of sets of `e − 1` extra options the solver listened to
///   (its remaining sets of that size, in its order), none winning. The sets of fewer extras are counted in the
///   difficulty's `smallerSets` (all smaller extra sizes together).
/// - `e = 0` (``reason`` `"missing"`): ``sets`` is 0; every set of fewer actions omits a missing symbol pair, so its
///   listen loses `missing` without being tried.
public struct AcousticConstellatorCounterexample: Sendable, Hashable, Codable {
    /// The reason for a plan without extra actions: every smaller set omits a missing symbol pair.
    public static let missing: String = "missing"
    /// The reason for a plan with extra actions: every set of one extra fewer was tried and lost.
    public static let tried: String = "tried"

    /// The size one below the plan: the actions (missing links included) of the sets refuted.
    public let size: Int
    /// The sets of ``size`` actions the solver listened to (the remaining sets of one extra fewer), none winning; 0
    /// when ``reason`` is `"missing"`.
    public let sets: Int
    /// `"tried"` or `"missing"`.
    public let reason: String

    /// A counterexample of the given values, unchecked.
    public init(size: Int, sets: Int, reason: String) {
        self.size = size
        self.sets = sets
        self.reason = reason
    }
}

/// The replayable proof that a generated Acoustic Constellator level is won by its solver's plan and that no set of
/// one action fewer wins (clarification Q4).
public struct AcousticConstellatorWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: AcousticConstellatorLevel
    /// The witness actions: the plan's links in pair order, its nudges in star order (one per step), then one listen,
    /// which wins.
    public let actions: [AcousticConstellatorAction]
    /// The state digest (``digest(links:phases:)``) of the play's links and phases after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The proof that one action fewer cannot win.
    public let counterexample: AcousticConstellatorCounterexample
    /// The level's difficulty, with the solver's smaller sets and work.
    public let difficulty: AcousticConstellatorDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: AcousticConstellatorLevel, actions: [AcousticConstellatorAction], digests: [String],
         fingerprints: [String], counterexample: AcousticConstellatorCounterexample,
         difficulty: AcousticConstellatorDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of a state: `links=` and the links sorted in pair order as `a-b` joined by `,`, then
    /// `;phases=` and the phases in star order joined by `,`. Example: `links=0-1,1-2;phases=3,0,11`.
    public static func canonicalText(links: [AcousticConstellatorLink], phases: [Int]) -> String {
        var parts: [String] = []
        for link in links.sorted() { parts.append(String(link.a) + "-" + String(link.b)) }
        var values: [String] = []
        for phase in phases { values.append(String(phase)) }
        return "links=" + parts.joined(separator: ",") + ";phases=" + values.joined(separator: ",")
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(links:phases:)`` (the sorted links and the phases).
    public static func digest(links: [AcousticConstellatorLink], phases: [Int]) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(links: links, phases: phases).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its actions on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `acoustic-constellator-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate
    ///   `skipped` of its manifest entry), `"actions"` (not one or more links in strictly ascending pair order and
    ///   nudges of ±1 in star order without opposite steps on one star, at least one in all, followed by one listen),
    ///   `"replay"` (a refused action, no win on the last action or a win or failure before it), `"counterexample"`
    ///   (a set of fewer extra actions wins, the recount passes the work bound, or the recount is not the plan's
    ///   `smallerSets`) and `"difficulty"` (not the difficulty of the level and plan).
    public static func make(_ generated: AcousticConstellatorGenerated) throws(AcousticConstellatorError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= AcousticConstellatorManifest.entries.count,
              AcousticConstellatorManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: generated.actions, work: generated.plan.work,
                                      skipped: generated.skipped)
        guard witness.difficulty.smallerSets == generated.plan.smallerSets else { throw .witness("counterexample") }
        guard witness.difficulty == generated.difficulty else { throw .witness("difficulty") }
        return witness
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
            preconditionFailure("an Acoustic Constellator witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a fresh play, every smaller
    /// set is recounted, the difficulty is recomputed with the stored solver work, every stored value must equal the
    /// rebuilt one, and the solver run again must find the stored actions, smaller sets and work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"counterexample"` or `"difficulty"` for a stored value
    ///   the rebuild does not reproduce; `.witness("solution")` when the solver, run again on the level, does not find
    ///   exactly the stored actions with the stored smaller sets and work.
    public static func decode(_ data: Data) throws(AcousticConstellatorError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .witness("schema") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("unreadable")
        }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, actions: stored.actions,
                                      work: stored.difficulty.work, skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        // The solver's own result (feature 382's convergence lesson): another winning plan of the same size or an
        // edited work count is refused too.
        guard let plan = AcousticConstellatorSolver.plan(stored.level),
              AcousticConstellatorSolver.actions(plan) == stored.actions,
              plan.smallerSets == stored.difficulty.smallerSets,
              plan.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, the state digest after each action and whether any action before the last found the play no longer
    /// playing; nil when a stage event or an action is refused.
    static func replay(_ level: AcousticConstellatorLevel, actions: [AcousticConstellatorAction])
        -> (play: AcousticConstellatorPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = AcousticConstellatorPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            fingerprints.append(play.fingerprint)
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(digest(links: play.links, phases: play.phases))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The number of sets the solver listens to at each extra size 0 … `extras` − 1, recounted with the solver's own
    /// depth-first walk (``AcousticConstellatorSolver/Search``) over the options the solver builds (helper links in
    /// pair order that fit the degree and link limits, then nudges in star order, −1 then +1); nil when the fixed
    /// links and the missing symbol pairs break a limit, when any of those sets wins, or when more than
    /// ``AcousticConstellatorSolver/workBound`` listens would be run.
    static func smallerSets(_ level: AcousticConstellatorLevel, extras: Int) -> [Int]? {
        let n: Int = level.stars.count
        let base: [AcousticConstellatorLink] = (level.fixedLinks + AcousticConstellatorSolver.missing(level)).sorted()
        let baseSet: Set<AcousticConstellatorLink> = Set(base)
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in base {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        guard base.count <= level.linkLimit, degrees.allSatisfy({ $0 <= level.degreeLimit }) else { return nil }
        var options: [AcousticConstellatorSolver.Option] = []
        if base.count < level.linkLimit {
            for a in 0..<n {
                for b in (a + 1)..<max(a + 1, n) {
                    let link = AcousticConstellatorLink(a: a, b: b)
                    if baseSet.contains(link) { continue }
                    if degrees[a] >= level.degreeLimit || degrees[b] >= level.degreeLimit { continue }
                    options.append(.link(link))
                }
            }
        }
        for star in 0..<n {
            options.append(.nudge(star: star, step: -1))
            options.append(.nudge(star: star, step: 1))
        }
        var search = AcousticConstellatorSolver.Search(level: level, base: base, degrees: degrees, options: options,
                                                      workBound: AcousticConstellatorSolver.workBound)
        var counts: [Int] = []
        var extra: Int = 0
        while extra < extras {
            let before: Int = search.work
            guard search.walk(size: extra) == .lost else { return nil }
            counts.append(search.work - before)
            extra += 1
        }
        return counts
    }

    /// Builds a witness from its level, actions and solver work, checking every part.
    private static func build(number: Int, level: AcousticConstellatorLevel, actions: [AcousticConstellatorAction],
                              work: Int, skipped: Int) throws(AcousticConstellatorError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...AcousticConstellatorManifest.entries.count).contains(number),
              level.id == AcousticConstellatorGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<AcousticConstellatorGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: AcousticConstellatorManifestEntry = AcousticConstellatorManifest.entries[number - 1]
        guard entry.number == number, AcousticConstellatorGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Shape: links in strictly ascending pair order, then nudges of ±1 in star order (no opposite steps on one
        // star), at least one action in all, then one listen.
        guard actions.count >= 2, actions[actions.count - 1] == .listen else { throw .witness("actions") }
        var links: [AcousticConstellatorLink] = []
        var nudges: [AcousticConstellatorNudge] = []
        for action in actions.dropLast() {
            switch action {
            case .link(let a, let b):
                guard nudges.isEmpty, a < b else { throw .witness("actions") }
                let link = AcousticConstellatorLink(a: a, b: b)
                if let previous = links.last, !(previous < link) { throw .witness("actions") }
                links.append(link)
            case .nudge(let star, let step):
                guard step == 1 || step == -1 else { throw .witness("actions") }
                let nudge = AcousticConstellatorNudge(star: star, step: step)
                if let previous = nudges.last {
                    guard (previous.star, previous.step) <= (star, step) else { throw .witness("actions") }
                    if previous.star == star && previous.step != step { throw .witness("actions") }
                }
                nudges.append(nudge)
            case .unlink, .listen:
                throw .witness("actions")
            }
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        // Recount: every set of fewer extra actions loses; a plan without extras is refuted by its missing pairs.
        let required: Set<AcousticConstellatorLink> = Set(AcousticConstellatorSolver.missing(level))
        guard required.isSubset(of: Set(links)) else { throw .witness("replay") }
        let extras: Int = links.count - required.count + nudges.count
        guard let counts = smallerSets(level, extras: extras) else { throw .witness("counterexample") }
        var smaller: Int = 0
        for count in counts { smaller += count }
        let counterexample: AcousticConstellatorCounterexample
        if extras == 0 {
            counterexample = AcousticConstellatorCounterexample(size: links.count + nudges.count - 1, sets: 0,
                                                                reason: AcousticConstellatorCounterexample.missing)
        } else {
            counterexample = AcousticConstellatorCounterexample(size: links.count + nudges.count - 1,
                                                                sets: counts[extras - 1],
                                                                reason: AcousticConstellatorCounterexample.tried)
        }
        let plan = AcousticConstellatorPlan(links: links, nudges: nudges, smallerSets: smaller, work: work)
        let difficulty = AcousticConstellatorDifficulty(level: level, plan: plan)
        return Self(number: number, level: level, actions: actions, digests: run.digests,
                    fingerprints: run.fingerprints, counterexample: counterexample, difficulty: difficulty,
                    skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, counterexample, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        guard c.contains(.level) else {
            let context = DecodingError.Context(codingPath: c.codingPath, debugDescription: "level")
            throw DecodingError.keyNotFound(CodingKeys.level, context)
        }
        do { level = try c.decode(AcousticConstellatorLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([AcousticConstellatorAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        counterexample = try c.decode(AcousticConstellatorCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(AcousticConstellatorDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(digests, forKey: .digests)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
