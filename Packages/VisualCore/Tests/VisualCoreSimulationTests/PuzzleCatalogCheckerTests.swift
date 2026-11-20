// PuzzleCatalogCheckerTests — feature 224 (R02-F24) T-R02F24-004 (FR-R02F24-003; clarification Q3; SC-R02F24-002).
// Sound lights-out catalogs built by hand pass; 100 seeded catalogs with exactly one planted fault each (uncertified
// level, duplicate, difficulty mismatch, drop, jump, digest mismatch) report exactly that issue at that position; every
// breach and every issue of a position is reported in order; the same catalog always gives the same report.
import Testing
@testable import VisualCoreSimulation

@Suite("PuzzleCatalogChecker")
struct PuzzleCatalogCheckerTests {
    let lightsOut = LightsOutRules()
    let slidingRow = SlidingRowRules()

    /// A lights-out level solved by pressing `cells`; its shortest solution is `cells.count` (distinct cells).
    func level(_ cells: [Int], rulesID: String? = nil) throws -> PuzzleLevel<LightsOutRules> {
        var start: UInt16 = 0
        for move in cells {
            start = lightsOut.apply(move, to: start)!
        }
        return try PuzzleLevel<LightsOutRules>(rulesID: rulesID ?? lightsOut.rulesID, start: start, solution: cells,
                                               budget: FairnessBudget(maxLength: 9))
    }

    /// A catalog entry carrying the level's certificate difficulty.
    func entry(_ level: PuzzleLevel<LightsOutRules>) -> PuzzleCatalogEntry<LightsOutRules> {
        let certificate: PuzzleCertificate = PuzzleValidator.certify(level, rules: lightsOut)
        let difficulty: PuzzleDifficulty = PuzzleDifficulty(certificate: certificate)!
        return PuzzleCatalogEntry<LightsOutRules>(level: level, difficulty: difficulty)
    }

    /// A level of `size` distinct seeded cells whose start is not in `used`; the start is added to `used`.
    func freshLevel(size: Int, _ random: inout SeededRandom, used: inout Set<UInt16>) throws -> PuzzleLevel<LightsOutRules> {
        while true {
            let cells: [Int] = Array(random.shuffled(Array(0..<9)).prefix(size))
            let candidate: PuzzleLevel<LightsOutRules> = try level(cells)
            if !used.contains(candidate.start) {
                used.insert(candidate.start)
                return candidate
            }
        }
    }

    /// Sound entries: 5 … 8 levels whose sizes start at 1 or 2 and rise by 0 or 1 up to 5, ordered by difficulty, then
    /// identity. The starts used are returned so planted levels stay distinct.
    func soundEntries(_ random: inout SeededRandom) throws -> (entries: [PuzzleCatalogEntry<LightsOutRules>], used: Set<UInt16>) {
        var used: Set<UInt16> = []
        var entries: [PuzzleCatalogEntry<LightsOutRules>] = []
        let count: Int = random.int(5...8)
        var size: Int = random.int(1...2)
        for _ in 0..<count {
            let made: PuzzleLevel<LightsOutRules> = try freshLevel(size: size, &random, used: &used)
            entries.append(entry(made))
            size = min(5, size + random.int(0...1))
        }
        entries.sort { (a: PuzzleCatalogEntry<LightsOutRules>, b: PuzzleCatalogEntry<LightsOutRules>) -> Bool in
            if a.difficulty != b.difficulty { return a.difficulty < b.difficulty }
            return a.level.identity < b.level.identity
        }
        return (entries, used)
    }

    @Test("sound hand-built catalogs pass and repeat")
    func soundCatalogsPass() throws {
        var random: SeededRandom = SeededRandom(seed: 2_024)
        for k in 0..<50 {
            let sound = try soundEntries(&random)
            let catalog: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>(id: "sound-\(k)",
                                                                                           entries: sound.entries)
            let report: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
            #expect(report.passes, "catalog \(k): \(report.issues)")
            #expect(report.issues.isEmpty)
            let again: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
            #expect(again == report)
        }
    }

    @Test("100 seeded catalogs with one planted fault report exactly that issue")
    func plantedFaults() throws {
        var random: SeededRandom = SeededRandom(seed: 2_024)
        var kinds: [Int] = [0, 0, 0, 0, 0, 0]
        for k in 0..<100 {
            let kind: Int = k % 6
            let sound = try soundEntries(&random)
            var entries: [PuzzleCatalogEntry<LightsOutRules>] = sound.entries
            var used: Set<UInt16> = sound.used
            let id: String = "faulted-\(k)"
            var expected: [PuzzleCatalogIssue] = []
            var catalog: PuzzleCatalog<LightsOutRules>
            switch kind {
            case 0:
                // Uncertified: the same level under the other fixture's rules id, stored difficulty unchanged.
                let p: Int = random.int(0...(entries.count - 1))
                let original: PuzzleLevel<LightsOutRules> = entries[p].level
                let wrong: PuzzleLevel<LightsOutRules> = try level(original.solution, rulesID: slidingRow.rulesID)
                entries[p] = PuzzleCatalogEntry<LightsOutRules>(level: wrong, difficulty: entries[p].difficulty)
                expected = [.uncertified(index: p, verdict: .wrongRules)]
                catalog = try PuzzleCatalog<LightsOutRules>(id: id, entries: entries)
            case 1:
                // Duplicate: a copy right after its original keeps every neighbour step within the rule.
                let j: Int = random.int(0...(entries.count - 1))
                entries.insert(entries[j], at: j + 1)
                expected = [.duplicate(index: j + 1, first: j)]
                catalog = try PuzzleCatalog<LightsOutRules>(id: id, entries: entries)
            case 2:
                // Difficulty mismatch: one more explored state than the certificate, shortest unchanged.
                let p: Int = random.int(0...(entries.count - 1))
                let stored: PuzzleDifficulty = entries[p].difficulty
                let altered: PuzzleDifficulty = PuzzleDifficulty(shortest: stored.shortest, explored: stored.explored + 1)
                entries[p] = PuzzleCatalogEntry<LightsOutRules>(level: entries[p].level, difficulty: altered)
                expected = [.difficultyMismatch(index: p)]
                catalog = try PuzzleCatalog<LightsOutRules>(id: id, entries: entries)
            case 3:
                // Drop: a fresh level two longer than the first, placed in front (the first is at most 2, so ≤ 4).
                let size: Int = entries[0].difficulty.shortest + 2
                let made: PuzzleLevel<LightsOutRules> = try freshLevel(size: size, &random, used: &used)
                entries.insert(entry(made), at: 0)
                expected = [.drop(index: 1)]
                catalog = try PuzzleCatalog<LightsOutRules>(id: id, entries: entries)
            case 4:
                // Jump: a fresh level four longer than the last, appended (the last is at most 5, so ≤ 9).
                let size: Int = entries[entries.count - 1].difficulty.shortest + 4
                let made: PuzzleLevel<LightsOutRules> = try freshLevel(size: size, &random, used: &used)
                entries.append(entry(made))
                expected = [.jump(index: entries.count - 1)]
                catalog = try PuzzleCatalog<LightsOutRules>(id: id, entries: entries)
            default:
                // Digest mismatch: only the internal unchecked initialiser can store a wrong digest.
                let wrong: String = String(repeating: "0", count: 64)
                catalog = PuzzleCatalog<LightsOutRules>(id: id, entries: entries, digest: wrong)
                expected = [.digestMismatch]
            }
            let report: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
            #expect(report.issues == expected, "catalog \(k) kind \(kind)")
            #expect(!report.passes)
            let again: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
            #expect(again == report)
            kinds[kind] += 1
        }
        #expect(kinds == [17, 17, 17, 17, 16, 16])
    }

    @Test("every breach is reported, not only the first")
    func everyBreach() throws {
        let sizes: [[Int]] = [[0, 1, 2, 3, 4], [5], [4, 5, 6, 7, 8], [3]]
        var entries: [PuzzleCatalogEntry<LightsOutRules>] = []
        for cells in sizes {
            entries.append(entry(try level(cells)))
        }
        let catalog: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>(id: "breaches", entries: entries)
        let report: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
        let expected: [PuzzleCatalogIssue] = [.drop(index: 1), .jump(index: 2), .drop(index: 3)]
        #expect(report.issues == expected)
        let lenient: ProgressionRule = try ProgressionRule(maxDrop: 4, maxJump: 4)
        #expect(PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: lenient).passes)
    }

    @Test("issues of one position come in order, the digest last")
    func issueOrder() throws {
        let first: PuzzleCatalogEntry<LightsOutRules> = entry(try level([0]))
        let wrong: PuzzleLevel<LightsOutRules> = try level([1, 2], rulesID: slidingRow.rulesID)
        let second: PuzzleCatalogEntry<LightsOutRules> =
            PuzzleCatalogEntry<LightsOutRules>(level: wrong, difficulty: PuzzleDifficulty(shortest: 2, explored: 5))
        let third: PuzzleCatalogEntry<LightsOutRules> =
            PuzzleCatalogEntry<LightsOutRules>(level: first.level, difficulty: PuzzleDifficulty(shortest: 6, explored: 0))
        let catalog: PuzzleCatalog<LightsOutRules> =
            PuzzleCatalog<LightsOutRules>(id: "ordered", entries: [first, second, third], digest: "edited")
        let report: PuzzleCatalogReport = PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard)
        let expected: [PuzzleCatalogIssue] = [
            .uncertified(index: 1, verdict: .wrongRules), .duplicate(index: 2, first: 0), .difficultyMismatch(index: 2),
            .jump(index: 2), .digestMismatch,
        ]
        #expect(report.issues == expected)
        #expect(PuzzleCatalogChecker.check(catalog, rules: lightsOut, rule: .standard) == report)
    }
}
