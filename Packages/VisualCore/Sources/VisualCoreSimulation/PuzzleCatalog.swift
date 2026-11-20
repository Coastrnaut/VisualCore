// PuzzleCatalog — feature 224 (R02-F24) T-R02F24-003 (FR-R02F24-001, 002, 005, 006; clarifications Q1, Q2, Q5;
// SC-R02F24-001, 004; research R1). An ordered catalog of puzzle levels with their difficulties and a content digest
// (the SHA-256 hex of "<id>\n" followed by each level identity and "\n"), its schema-1 stored form, and the builder
// that makes a catalog deterministically from a plan: a global candidate index n derives every generator seed, each
// stage is ordered by difficulty then identity, and the finished order must keep the plan's progression rule.
import Foundation
import VisualCoreMath

/// One catalog position: a level and the difficulty measured from its certificate.
public struct PuzzleCatalogEntry<Rules: PuzzleRules>: Sendable, Equatable {
    /// The level.
    public let level: PuzzleLevel<Rules>
    /// Its difficulty, from its certificate.
    public let difficulty: PuzzleDifficulty

    /// An entry of the given level and difficulty; neither is checked here (the checker judges them).
    public init(level: PuzzleLevel<Rules>, difficulty: PuzzleDifficulty) {
        self.level = level
        self.difficulty = difficulty
    }
}

/// An ordered catalog of levels of one rules family with a content digest.
public struct PuzzleCatalog<Rules: PuzzleRules>: Sendable, Equatable {
    /// The stored-form schema this version writes and the newest it reads.
    public static var schema: Int { 1 }

    /// The catalog id, a lowercase slug.
    public let id: String
    /// The entries in catalog order.
    public let entries: [PuzzleCatalogEntry<Rules>]
    /// The SHA-256 hex of "<id>\n" followed by each entry's level identity and "\n".
    public let digest: String

    /// A catalog of the given entries; its digest is computed from them. Duplicates and uncertified levels are
    /// accepted: only ``PuzzleCatalogChecker`` judges them, and ``PuzzleCatalogBuilder`` never produces them.
    ///
    /// - Throws: `.plan("id")` unless `id` is a lowercase slug; `.plan("entries")` for no entries or more than
    ///   ``PuzzleCatalogPlan/maxLevels`` (1,000).
    public init(id: String, entries: [PuzzleCatalogEntry<Rules>]) throws(ContentError) {
        guard PuzzleError.isSlug(id) else { throw .plan("id") }
        guard !entries.isEmpty, entries.count <= PuzzleCatalogPlan.maxLevels else { throw .plan("entries") }
        var identities: [String] = []
        identities.reserveCapacity(entries.count)
        for entry in entries { identities.append(entry.level.identity) }
        self.init(id: id, entries: entries, digest: Self.digest(id: id, identities: identities))
    }

    /// A catalog with a stated digest, unchecked; for tests that need a value the public initialiser never makes.
    init(id: String, entries: [PuzzleCatalogEntry<Rules>], digest: String) {
        self.id = id
        self.entries = entries
        self.digest = digest
    }

    /// The SHA-256 hex (64 lower-case digits) of the UTF-8 of `id` + "\n" followed by each identity + "\n".
    public static func digest(id: String, identities: [String]) -> String {
        var bytes: [UInt8] = Array(id.utf8)
        bytes.append(0x0A)
        for identity in identities {
            bytes.append(contentsOf: identity.utf8)
            bytes.append(0x0A)
        }
        return StableHash.sha256Hex(bytes)
    }

    /// One stored entry: the level's own stored form (identity included) and the difficulty.
    private struct EntryForm: Codable {
        var level: PuzzleLevel<Rules>
        var difficulty: PuzzleDifficulty
    }

    /// The stored form: schema, id, digest and entries.
    private struct Form: Codable {
        var schema: Int
        var id: String
        var digest: String
        var entries: [EntryForm]
    }

    /// Only the schema, read before the rest so a newer layout is recognised.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// This catalog as its stored form.
    private var storedForm: Form {
        var forms: [EntryForm] = []
        forms.reserveCapacity(entries.count)
        for entry in entries { forms.append(EntryForm(level: entry.level, difficulty: entry.difficulty)) }
        return Form(schema: Self.schema, id: id, digest: digest, entries: forms)
    }

    /// Rebuilds a catalog from a stored form whose schema was already checked: the public initialiser's rules, then
    /// the recomputed digest against the stored one.
    private static func rebuilt(from form: Form) throws(ContentError) -> PuzzleCatalog {
        guard form.schema >= 1 else { throw .malformed("schema \(form.schema)") }
        var entries: [PuzzleCatalogEntry<Rules>] = []
        entries.reserveCapacity(form.entries.count)
        for entry in form.entries {
            entries.append(PuzzleCatalogEntry(level: entry.level, difficulty: entry.difficulty))
        }
        let catalog: PuzzleCatalog
        do {
            catalog = try PuzzleCatalog(id: form.id, entries: entries)
        } catch {
            throw .malformed(error.reasonCode)
        }
        guard catalog.digest == form.digest else { throw .edited }
        return catalog
    }

    /// The stored form as JSON with sorted keys: schema, id, digest and entries, each entry holding the level's own
    /// stored form (with its identity) and its difficulty.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(storedForm)
        } catch {
            // Every level encodes by its own contract and every other value is an integer or a string; a failure
            // here breaks the PuzzleRules contract, a programming error.
            preconditionFailure("PuzzleCatalog.encoded: \(error)")
        }
    }

    /// Reads a catalog from its stored form: the schema first, then every level through its own decoding (rules
    /// re-run, identity checked), then the public initialiser's rules and the recomputed digest.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, any refused level or a refused id or entry count; `.edited` when
    ///   the stored digest does not match the entries.
    public static func decode(_ data: Data) throws(ContentError) -> PuzzleCatalog {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        let form: Form
        do {
            form = try decoder.decode(Form.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        return try rebuilt(from: form)
    }
}

extension PuzzleCatalog: Codable {
    private enum ProbeKeys: String, CodingKey { case schema }

    /// Encodes the catalog as its schema-1 stored form.
    public func encode(to encoder: any Encoder) throws {
        try storedForm.encode(to: encoder)
    }

    /// Decodes a catalog with every rule of ``decode(_:)``; a refusal is a `DecodingError.dataCorrupted` whose
    /// description is the reason code.
    public init(from decoder: any Decoder) throws {
        let probe = try decoder.container(keyedBy: ProbeKeys.self)
        let schema: Int = try probe.decode(Int.self, forKey: .schema)
        guard schema <= Self.schema else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: ContentError.newerSchema(schema).reasonCode))
        }
        let form = try Form(from: decoder)
        do {
            self = try Self.rebuilt(from: form)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// Builds puzzle catalogs from plans.
public enum PuzzleCatalogBuilder {
    /// Builds the catalog of `plan` deterministically.
    ///
    /// A global candidate index n starts at 0. Each stage s (from 0) is filled with `count` distinct levels: every
    /// call runs ``PuzzleGenerator/generate(seed:attempts:rules:budget:uniqueness:make:)`` with seed
    /// `SeedDerivation.derive(plan.seed, index: n)`, the stage's attempts, budget and uniqueness, and `make` given the
    /// stage; n advances by one per call. A level whose content (its identity without the seed) is already in the catalog is
    /// skipped. Each stage's
    /// levels are ordered by difficulty, then identity; the stages are concatenated in plan order and the result must
    /// keep `plan.rule`.
    ///
    /// - Throws: `.planFailed(stage: s, calls: c)` when a call finds no certified level (c counts that call) or
    ///   when 4 × count calls have not filled the stage; `.progression(i)` at the first position that breaks the rule.
    public static func build<R: PuzzleRules>(
        _ plan: PuzzleCatalogPlan, rules: R,
        make: (inout SeededRandom, PuzzleCatalogStage) -> (start: R.State, solution: [R.Move])?
    ) throws(ContentError) -> PuzzleCatalog<R> {
        var n: UInt64 = 0
        var seen: Set<String> = []
        var all: [PuzzleCatalogEntry<R>] = []
        for (s, stage) in plan.stages.enumerated() {
            let limit: Int = 4 * stage.count
            var calls: Int = 0
            var stageEntries: [PuzzleCatalogEntry<R>] = []
            while stageEntries.count < stage.count {
                guard calls < limit else { throw .planFailed(stage: s, calls: calls) }
                let seed: UInt64 = SeedDerivation.derive(plan.seed, index: n)
                n += 1
                calls += 1
                let generation: PuzzleGeneration<R>
                do {
                    generation = try PuzzleGenerator.generate(
                        seed: seed, attempts: stage.attempts, rules: rules, budget: stage.budget,
                        uniqueness: stage.uniqueness,
                        make: { (rng: inout SeededRandom) -> (start: R.State, solution: [R.Move])? in
                            make(&rng, stage)
                        })
                } catch {
                    throw .planFailed(stage: s, calls: calls)
                }
                let identity: String = generation.level.contentKey
                if seen.contains(identity) { continue }
                guard let difficulty = PuzzleDifficulty(certificate: generation.certificate) else {
                    // A valid certificate always has a shortest length; refuse rather than trust one without.
                    throw .planFailed(stage: s, calls: calls)
                }
                seen.insert(identity)
                stageEntries.append(PuzzleCatalogEntry(level: generation.level, difficulty: difficulty))
            }
            stageEntries.sort { (a: PuzzleCatalogEntry<R>, b: PuzzleCatalogEntry<R>) -> Bool in
                if a.difficulty != b.difficulty { return a.difficulty < b.difficulty }
                return a.level.identity < b.level.identity
            }
            all.append(contentsOf: stageEntries)
        }
        var difficulties: [PuzzleDifficulty] = []
        difficulties.reserveCapacity(all.count)
        for entry in all { difficulties.append(entry.difficulty) }
        if let breach = plan.rule.breach(difficulties) { throw .progression(breach.index) }
        return try PuzzleCatalog(id: plan.id, entries: all)
    }
}

extension PuzzleLevel {
    /// The identity of the same level without its generator seed: two levels with equal content keys are the same
    /// puzzle for the player, whatever seed produced them (implementation, 2026-11-20: the identity includes the
    /// seed, and every builder call derives a new one, so duplicates are judged on this key).
    var contentKey: String {
        guard seed != nil else { return identity }
        do {
            return try PuzzleLevel(rulesID: rulesID, start: start, solution: solution, uniqueness: uniqueness,
                                   budget: budget, seed: nil).identity
        } catch {
            // Unreachable: the same values already passed this initialiser when the level was made.
            return identity
        }
    }
}
