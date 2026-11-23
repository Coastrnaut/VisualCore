// HarmonicBridgesCatalogTests — feature 412 (R02-G12-02) T-R02G1202-006 (FR-R02G1202-001 … 006;
// SC-R02G1202-001 … 006; clarifications Q3 … Q5). The 100-level catalog: manifest shape (20 levels per band), the
// pinned digest, R02-F24's standard progression rule on the witness tuning count in manifest order and non-decreasing
// band means, every stored witness replayed to a win through the play within its budget (tunings at most budget − 1),
// an independent brute force on two levels per band (bands 1 … 3: the two levels with the fewest strings, every set of
// one tuning fewer than the plan over every peg 1 … 12 with the level's real reports, no pattern pruning; bands 4 and
// 5: the two levels with the fewest strings, every set of one tuning fewer over every distinct bridge pattern any peg
// gives, not only maximal ones; none wins and the plan wins), one fully re-verified decode per band, and the witness
// files in docs/games/harmonic-bridges/levels/ compared byte for byte with the regenerated witnesses in 20 groups of 5
// levels. The files are written only when HARMONIC_BRIDGES_WRITE_WITNESSES=1 is set. Generated levels are cached per
// process. Stored files are read with the plain decoder except in the re-verified test. Explicit types and plain loops
// (CI type-check rule).
@testable import HarmonicBridgesCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, HarmonicBridges, the package,
/// Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> HarmonicBridgesWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[HarmonicBridgesWitness], any Error> = Result {
    var result: [HarmonicBridgesWitness] = []
    for entry in HarmonicBridgesManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [HarmonicBridgesWitness] { try stored.get() }

/// The generated levels of this test process, by manifest number (each entry generated at most once).
private final class GeneratedCache: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var levels: [Int: HarmonicBridgesGenerated] = [:]

    /// The generated level of manifest number `number` (generation is deterministic, so a rare concurrent duplicate
    /// is harmless; the lock guards only the table, so groups generate in parallel).
    func generated(_ number: Int) throws -> HarmonicBridgesGenerated {
        lock.lock()
        let cached: HarmonicBridgesGenerated? = levels[number]
        lock.unlock()
        if let cached { return cached }
        let generated: HarmonicBridgesGenerated = try HarmonicBridgesGenerator.generate(
            HarmonicBridgesManifest.entries[number - 1])
        lock.lock()
        levels[number] = generated
        lock.unlock()
        return generated
    }
}

private let generatedCache: GeneratedCache = GeneratedCache()

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied.
private func played(_ level: HarmonicBridgesLevel, _ actions: [HarmonicBridgesAction]) throws -> HarmonicBridgesPlay {
    var play = HarmonicBridgesPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    for action in actions { try play.apply(action, expecting: play.fingerprint) }
    return play
}

/// The tunings (string, peg) of a witness's actions, in order.
private func tunings(_ actions: [HarmonicBridgesAction]) -> [(string: Int, peg: Int)] {
    var result: [(string: Int, peg: Int)] = []
    for action in actions {
        if case let .tune(string, peg) = action { result.append((string, peg)) }
    }
    return result
}

/// The unlocked strings of `level`, in index order.
private func unlockedStrings(_ level: HarmonicBridgesLevel) -> [Int] {
    var result: [Int] = []
    for (index, string) in level.strings.enumerated() where !string.locked { result.append(index) }
    return result
}

/// Advances `subset` (ascending indices below `count`) to the next subset of its size; false after the last.
private func nextCombination(_ subset: inout [Int], of count: Int) -> Bool {
    let size: Int = subset.count
    var position: Int = size - 1
    while position >= 0 && subset[position] == count - size + position { position -= 1 }
    if position < 0 { return false }
    subset[position] += 1
    var next: Int = position + 1
    while next < size {
        subset[next] = subset[next - 1] + 1
        next += 1
    }
    return true
}

/// Advances the odometer `digits` (position i below `limits[i]`), the last position fastest; false after the last.
private func nextDigits(_ digits: inout [Int], limits: [Int]) -> Bool {
    var position: Int = digits.count - 1
    while position >= 0 {
        digits[position] += 1
        if digits[position] < limits[position] { return true }
        digits[position] = 0
        position -= 1
    }
    return false
}

/// Brute force over pegs: the choices tried and the winning ones of every subset of `size` unlocked strings with every
/// peg 1 … 12 on each (no pattern pruning), each judged by the level's real report.
private func bruteForcePegs(_ level: HarmonicBridgesLevel, size: Int) -> (tried: Int, wins: Int) {
    let unlocked: [Int] = unlockedStrings(level)
    let start: [Int] = level.startingPegs
    if size == 0 { return (1, level.report(pegs: start).goalReachedInEveryStep ? 1 : 0) }
    if unlocked.count < size { return (0, 0) }
    let pegCount: Int = HarmonicBridgesLevel.pegs.count
    let limits: [Int] = Array(repeating: pegCount, count: size)
    var subset: [Int] = Array(0..<size)
    var tried: Int = 0
    var wins: Int = 0
    while true {
        var digits: [Int] = Array(repeating: 0, count: size)
        while true {
            var pegs: [Int] = start
            for position in 0..<size {
                pegs[unlocked[subset[position]]] = HarmonicBridgesLevel.pegs.lowerBound + digits[position]
            }
            tried += 1
            if level.report(pegs: pegs).goalReachedInEveryStep { wins += 1 }
            if !nextDigits(&digits, limits: limits) { break }
        }
        if !nextCombination(&subset, of: unlocked.count) { break }
    }
    return (tried, wins)
}

/// The bridge pattern of string `string` at `peg` as a bit set (bit t: a bridge in step t), from the kernel's
/// resonance.
private func patternBits(_ level: HarmonicBridgesLevel, string: Int, peg: Int) -> Int {
    var bits: Int = 0
    for step in 0..<level.steps.count where level.resonance(string, step: step, peg: peg).bridge { bits |= 1 << step }
    return bits
}

/// Whether the start reaches the goal in every step when string s has bridge pattern `bits[s]`, by a fixed-point
/// relaxation over the strings (independent of the kernel's breadth-first search and the solver's search).
private func reachesInEveryStep(_ level: HarmonicBridgesLevel, bits: [Int]) -> Bool {
    for step in 0..<level.steps.count {
        var reached: [Bool] = Array(repeating: false, count: level.islands.count)
        reached[level.start] = true
        var changed: Bool = true
        while changed {
            changed = false
            for (index, string) in level.strings.enumerated() where bits[index] & (1 << step) != 0 {
                if reached[string.a] != reached[string.b] {
                    reached[string.a] = true
                    reached[string.b] = true
                    changed = true
                }
            }
        }
        if !reached[level.goal] { return false }
    }
    return true
}

/// Brute force over patterns: the choices tried and the winning ones of every subset of `size` unlocked strings with
/// every distinct bridge pattern any peg 1 … 12 gives each (maximal or not, the starting pattern included).
private func bruteForcePatterns(_ level: HarmonicBridgesLevel, size: Int) -> (tried: Int, wins: Int) {
    let unlocked: [Int] = unlockedStrings(level)
    var start: [Int] = []
    for (index, string) in level.strings.enumerated() {
        start.append(patternBits(level, string: index, peg: string.peg))
    }
    if size == 0 { return (1, reachesInEveryStep(level, bits: start) ? 1 : 0) }
    if unlocked.count < size { return (0, 0) }
    var patterns: [[Int]] = []
    for string in unlocked {
        var distinct: [Int] = []
        for peg in HarmonicBridgesLevel.pegs {
            let bits: Int = patternBits(level, string: string, peg: peg)
            if !distinct.contains(bits) { distinct.append(bits) }
        }
        patterns.append(distinct)
    }
    var subset: [Int] = Array(0..<size)
    var tried: Int = 0
    var wins: Int = 0
    while true {
        var limits: [Int] = []
        for position in 0..<size { limits.append(patterns[subset[position]].count) }
        var digits: [Int] = Array(repeating: 0, count: size)
        while true {
            var bits: [Int] = start
            for position in 0..<size {
                let slot: Int = subset[position]
                bits[unlocked[slot]] = patterns[slot][digits[position]]
            }
            tried += 1
            if reachesInEveryStep(level, bits: bits) { wins += 1 }
            if !nextDigits(&digits, limits: limits) { break }
        }
        if !nextCombination(&subset, of: unlocked.count) { break }
    }
    return (tried, wins)
}

/// The two stored witnesses of `band` with the fewest strings (then the lowest number).
private func fewestStrings(band: Int) throws -> [HarmonicBridgesWitness] {
    var candidates: [HarmonicBridgesWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.strings.count, $0.number) < ($1.level.strings.count, $1.number) }
    return Array(candidates.prefix(2))
}

/// The starting pegs of `level` with the witness tunings applied.
private func planPegs(_ level: HarmonicBridgesLevel, _ actions: [HarmonicBridgesAction]) -> [Int] {
    var pegs: [Int] = level.startingPegs
    for tuning in tunings(actions) { pegs[tuning.string] = tuning.peg }
    return pegs
}

@Suite struct HarmonicBridgesCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<HarmonicBridgesRules>.digest(id: "harmonic-bridges", identities:)`
    /// over the 100 level fingerprints in manifest order, computed on 2026-11-23 from the generated catalog. An
    /// intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "b832e7eef70880b12895f1e047d0baaf6a51fdd0a14ce9e655f02c022ab3c737"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [HarmonicBridgesManifestEntry] = HarmonicBridgesManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            perBand[entry.band - 1] += 1
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        var seeds: Set<UInt64> = []
        for entry in entries { seeds.insert(entry.seed) }
        #expect(seeds.count == 100)
        #expect(entries[0].seed == 0x2fed66950e84a850)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [HarmonicBridgesWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [HarmonicBridgesLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == HarmonicBridgesGenerator.levelID(index + 1))
        }
        let digest: String = HarmonicBridgesGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's tuning range, R02-F24's standard progression rule on the witness tuning
    /// count in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [HarmonicBridgesWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumTunings: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: HarmonicBridgesLevel = witness.level
            let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[witness.number - 1]
            let count: Int = tunings(witness.actions).count
            #expect(count == witness.difficulty.tunings)
            #expect(count >= 1)
            #expect(count <= level.budget - 1)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: HarmonicBridgesBandProfile = HarmonicBridgesBandProfile.of(band: level.difficulty)
            #expect(profile.scrambled.contains(count), "\(level.id): \(count) tunings outside the band's range")
            #expect(witness.counterexample.size == count - 1)
            #expect(witness.counterexample.choices == witness.difficulty.smallerChoices)
            #expect(witness.difficulty.work <= HarmonicBridgesSolver.workBound)
            difficulties.append(PuzzleDifficulty(shortest: count, explored: witness.difficulty.work))
            sumTunings[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumTunings[band] >= sumTunings[band - 1], "mean tunings fall at band \(band + 1): \(sumTunings)")
        }
    }

    /// SC-R02G1202-001 for all 100 levels: the witness actions replayed on a play win on the last one (the test) within
    /// the budget, and the tunings alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: HarmonicBridgesLevel = witness.level
            let play: HarmonicBridgesPlay = try played(level, witness.actions)
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.actionsLeft >= 0)
            #expect(play.actionsSpent == witness.actions.count)
            #expect(witness.actions.count <= level.budget)
            let short: HarmonicBridgesPlay = try played(level, Array(witness.actions.dropLast()))
            #expect(short.stage == .playing, "\(level.id) is not playing before its test")
        }
    }

    /// SC-R02G1202-002 in bands 1 … 3 on the two levels with the fewest strings: no set of one tuning fewer than the
    /// plan, over every peg 1 … 12 (no pattern pruning) and judged by real reports, wins; the plan does.
    @Test(arguments: [1, 2, 3])
    func noSmallerPlanWinsOverEveryPeg(band: Int) throws {
        let witnesses: [HarmonicBridgesWitness] = try fewestStrings(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let level: HarmonicBridgesLevel = witness.level
            let size: Int = tunings(witness.actions).count - 1
            let result: (tried: Int, wins: Int) = bruteForcePegs(level, size: size)
            #expect(result.tried >= 1, "\(level.id): nothing tried")
            #expect(result.wins == 0, "\(level.id): \(result.wins) of \(result.tried) smaller choices win")
            #expect(level.report(pegs: planPegs(level, witness.actions)).goalReachedInEveryStep,
                    "\(level.id): the plan does not win")
        }
    }

    /// SC-R02G1202-002 in bands 4 and 5 on the two levels with the fewest strings: no set of one tuning fewer than the
    /// plan, over every distinct bridge pattern any peg gives (not only maximal ones), wins; the plan does.
    @Test(arguments: [4, 5])
    func noSmallerPlanWinsOverEveryPattern(band: Int) throws {
        let witnesses: [HarmonicBridgesWitness] = try fewestStrings(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let level: HarmonicBridgesLevel = witness.level
            let size: Int = tunings(witness.actions).count - 1
            let result: (tried: Int, wins: Int) = bruteForcePatterns(level, size: size)
            #expect(result.tried >= 1, "\(level.id): nothing tried")
            #expect(result.wins == 0, "\(level.id): \(result.wins) of \(result.tried) smaller choices win")
            let pegs: [Int] = planPegs(level, witness.actions)
            var bits: [Int] = []
            for index in 0..<level.strings.count { bits.append(patternBits(level, string: index, peg: pegs[index])) }
            #expect(reachesInEveryStep(level, bits: bits), "\(level.id): the plan does not win")
            #expect(level.report(pegs: pegs).goalReachedInEveryStep, "\(level.id): the plan's report does not win")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: HarmonicBridgesWitness = try HarmonicBridgesWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == HarmonicBridgesManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte
    /// for byte (written only with HARMONIC_BRIDGES_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["HARMONIC_BRIDGES_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: HarmonicBridgesGenerated = try generatedCache.generated(number)
            #expect(generated.level.id == HarmonicBridgesGenerator.levelID(number))
            let witness: HarmonicBridgesWitness = try HarmonicBridgesWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let storedData: Data = try Data(contentsOf: url)
            #expect(storedData == data, "\(witnessName(number)) differs from the regenerated witness")
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let all: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
        var names: [String] = []
        for name in all where name.hasSuffix(".witness.json") { names.append(name) }
        #expect(names.count == 100)
        for entry in HarmonicBridgesManifest.entries {
            #expect(names.contains(witnessName(entry.number)), "\(witnessName(entry.number)) is missing")
        }
    }
}
