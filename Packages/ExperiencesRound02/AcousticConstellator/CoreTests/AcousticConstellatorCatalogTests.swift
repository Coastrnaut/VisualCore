// AcousticConstellatorCatalogTests — feature 422 (R02-G13-02) T-R02G1302-006 (FR-R02G1302-001 … 006;
// SC-R02G1302-001 … 006; clarifications Q3 … Q5). The 100-level catalog: manifest shape (20 levels per band), the
// pinned digest, R02-F24's standard progression rule on the witness action count in manifest order and non-decreasing
// band means, every stored witness replayed to a win through the play within its budget (actions at most budget − 1
// before the listen), an independent brute force on two levels per band (bands 1 … 3: the two levels with the fewest
// stars, every multiset of at most one action fewer than the plan over every action the play accepts — every link,
// every unlink of a placed link, every nudge of ±1, no pruning — applied through the play and then a listen; bands 4
// and 5: the two levels with the fewest stars, every multiset of one action fewer over the pruned options — the missing
// symbol pairs always linked, plus helper links in pair order and nudges of ±1, enumerated here independently of the
// solver — none wins and the plan wins), one fully re-verified decode per band, and the witness files in
// docs/games/acoustic-constellator/levels/ compared byte for byte with the regenerated witnesses in 20 groups of 5
// levels. The files are written only when ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES=1 is set. Generated levels are cached
// per process. Stored files are read with the plain decoder except in the re-verified test. Explicit types and plain
// loops (CI type-check rule).
@testable import AcousticConstellatorCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, AcousticConstellator, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/acoustic-constellator/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(AcousticConstellatorGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> AcousticConstellatorWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(AcousticConstellatorWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[AcousticConstellatorWitness], any Error> = Result {
    var result: [AcousticConstellatorWitness] = []
    for entry in AcousticConstellatorManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [AcousticConstellatorWitness] { try stored.get() }

/// The generated levels of this test process, by manifest number (each entry generated at most once).
private final class GeneratedCache: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var levels: [Int: AcousticConstellatorGenerated] = [:]

    /// The generated level of manifest number `number` (generation is deterministic, so a rare concurrent duplicate
    /// is harmless; the lock guards only the table, so groups generate in parallel).
    func generated(_ number: Int) throws -> AcousticConstellatorGenerated {
        lock.lock()
        let cached: AcousticConstellatorGenerated? = levels[number]
        lock.unlock()
        if let cached { return cached }
        let generated: AcousticConstellatorGenerated = try AcousticConstellatorGenerator.generate(
            AcousticConstellatorManifest.entries[number - 1])
        lock.lock()
        levels[number] = generated
        lock.unlock()
        return generated
    }
}

private let generatedCache: GeneratedCache = GeneratedCache()

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: AcousticConstellatorLevel,
                    _ actions: [AcousticConstellatorAction]) -> AcousticConstellatorPlay? {
    var play = AcousticConstellatorPlay(level: level)
    do {
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions {
            guard play.stage == .playing else { return nil }
            try play.apply(action, expecting: play.fingerprint)
        }
    } catch {
        return nil
    }
    return play
}

/// Whether `actions` followed by one listen are all accepted by a fresh play of `level` and the listen wins; nil when
/// the play refuses an action (or the play ends before the listen).
private func listenWins(_ level: AcousticConstellatorLevel, _ actions: [AcousticConstellatorAction]) -> Bool? {
    guard var play = played(level, actions), play.stage == .playing else { return nil }
    do { try play.apply(.listen, expecting: play.fingerprint) } catch { return nil }
    return play.stage == .won
}

/// Advances the multiset `digits` (non-decreasing indices below `count`) to the next multiset of its size, the last
/// position fastest; false after the last.
private func nextMultiset(_ digits: inout [Int], of count: Int) -> Bool {
    var position: Int = digits.count - 1
    while position >= 0 && digits[position] == count - 1 { position -= 1 }
    if position < 0 { return false }
    digits[position] += 1
    var next: Int = position + 1
    while next < digits.count {
        digits[next] = digits[position]
        next += 1
    }
    return true
}

/// Every action the play of `level` could be offered, in a fixed order: every link (pair order), every unlink of a
/// pair that is not a fixed link (pair order; the play accepts it only once the link is placed), every nudge (star
/// order, −1 then +1). No pruning.
private func allActions(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorAction] {
    let n: Int = level.stars.count
    var links: [AcousticConstellatorAction] = []
    var unlinks: [AcousticConstellatorAction] = []
    for a in 0..<n {
        var b: Int = a + 1
        while b < n {
            links.append(.link(a, b))
            if !level.fixedLinks.contains(AcousticConstellatorLink(a: a, b: b)) { unlinks.append(.unlink(a, b)) }
            b += 1
        }
    }
    var nudges: [AcousticConstellatorAction] = []
    for star in 0..<n {
        nudges.append(.nudge(star, -1))
        nudges.append(.nudge(star, 1))
    }
    return links + unlinks + nudges
}

/// Brute force over every play action: every multiset of 0 … `size` actions of ``allActions(_:)``, applied through a
/// fresh play in that order and then a listen; the sequences the play accepted, those it refused, and the winning
/// ones.
private func bruteForceAllActions(_ level: AcousticConstellatorLevel,
                                  size: Int) -> (tried: Int, refused: Int, wins: Int) {
    let alphabet: [AcousticConstellatorAction] = allActions(level)
    var tried: Int = 0
    var refused: Int = 0
    var wins: Int = 0
    var count: Int = 0
    while count <= size {
        var digits: [Int] = Array(repeating: 0, count: count)
        while true {
            var actions: [AcousticConstellatorAction] = []
            for digit in digits { actions.append(alphabet[digit]) }
            if let won = listenWins(level, actions) {
                tried += 1
                if won { wins += 1 }
            } else {
                refused += 1
            }
            if !nextMultiset(&digits, of: alphabet.count) { break }
        }
        count += 1
    }
    return (tried, refused, wins)
}

/// One pruned option of the bands 4 and 5 brute force: a helper link or a nudge.
private struct PrunedOption {
    /// The helper link, or nil for a nudge.
    let link: AcousticConstellatorLink?
    /// The nudged star (−1 for a link).
    let star: Int
    /// The nudge step, −1 or +1 (0 for a link).
    let step: Int
}

/// Brute force over the pruned options: every multiset of `extras` options (helper links — the pairs neither fixed nor
/// missing, in pair order — then nudges, star order, −1 then +1), skipping a repeated helper link, opposite nudges on
/// one star and sets whose links (fixed, missing and helper) break the degree or link limit; each remaining set is
/// applied through a fresh play (the missing pairs and helper links in pair order, then the nudges) and a listen. The
/// sets judged and the winning ones.
private func bruteForcePruned(_ level: AcousticConstellatorLevel, extras: Int) -> (tried: Int, wins: Int) {
    let n: Int = level.stars.count
    let fixed: Set<AcousticConstellatorLink> = Set(level.fixedLinks)
    var missing: [AcousticConstellatorLink] = []
    for pair in level.symbol where !fixed.contains(pair) { missing.append(pair) }
    var options: [PrunedOption] = []
    for a in 0..<n {
        var b: Int = a + 1
        while b < n {
            let link = AcousticConstellatorLink(a: a, b: b)
            if !fixed.contains(link) && !missing.contains(link) {
                options.append(PrunedOption(link: link, star: -1, step: 0))
            }
            b += 1
        }
    }
    for star in 0..<n {
        options.append(PrunedOption(link: nil, star: star, step: -1))
        options.append(PrunedOption(link: nil, star: star, step: 1))
    }
    var digits: [Int] = Array(repeating: 0, count: extras)
    var tried: Int = 0
    var wins: Int = 0
    while true {
        var skip: Bool = false
        var links: [AcousticConstellatorLink] = level.fixedLinks + missing
        var helpers: [AcousticConstellatorLink] = missing
        var shift: [Int] = Array(repeating: 0, count: n)
        var previous: Int = -1
        for digit in digits {
            let option: PrunedOption = options[digit]
            if let link = option.link {
                if digit == previous { skip = true }
                links.append(link)
                helpers.append(link)
            } else {
                if shift[option.star] * option.step < 0 { skip = true }
                shift[option.star] += option.step
            }
            previous = digit
        }
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in links {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        if links.count > level.linkLimit { skip = true }
        for degree in degrees where degree > level.degreeLimit { skip = true }
        if !skip {
            var actions: [AcousticConstellatorAction] = []
            for link in helpers.sorted() { actions.append(.link(link.a, link.b)) }
            for star in 0..<n {
                var left: Int = abs(shift[star])
                while left > 0 {
                    actions.append(.nudge(star, shift[star] > 0 ? 1 : -1))
                    left -= 1
                }
            }
            tried += 1
            if listenWins(level, actions) == true { wins += 1 }
        }
        if !nextMultiset(&digits, of: options.count) { break }
    }
    return (tried, wins)
}

/// The two stored witnesses of `band` with the fewest stars (then the lowest number).
private func fewestStars(band: Int) throws -> [AcousticConstellatorWitness] {
    var candidates: [AcousticConstellatorWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.stars.count, $0.number) < ($1.level.stars.count, $1.number) }
    return Array(candidates.prefix(2))
}

/// The missing symbol pairs of `level` (not fixed links).
private func missingPairs(_ level: AcousticConstellatorLevel) -> Int {
    let fixed: Set<AcousticConstellatorLink> = Set(level.fixedLinks)
    var count: Int = 0
    for pair in level.symbol where !fixed.contains(pair) { count += 1 }
    return count
}

@Suite struct AcousticConstellatorCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<AcousticConstellatorRules>.digest(id: "acoustic-constellator",
    /// identities:)` over the 100 level fingerprints in manifest order, computed on 2026-11-23 from the generated
    /// catalog. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "4c50d04a181e11f815af9239b483914e0d7e1e339986a431f0c7c721edf07a12"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [AcousticConstellatorManifestEntry] = AcousticConstellatorManifest.entries
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
        #expect(entries[0].seed == 0xb98894a847e5ace7)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [AcousticConstellatorWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [AcousticConstellatorLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == AcousticConstellatorGenerator.levelID(index + 1))
        }
        let digest: String = AcousticConstellatorGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness action
    /// count in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [AcousticConstellatorWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: AcousticConstellatorLevel = witness.level
            let entry: AcousticConstellatorManifestEntry = AcousticConstellatorManifest.entries[witness.number - 1]
            let count: Int = witness.actions.count - 1
            #expect(witness.actions.last == .listen)
            #expect(count == witness.difficulty.actions)
            #expect(count >= 1)
            #expect(count <= level.budget - 1)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: AcousticConstellatorBandProfile = AcousticConstellatorBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) actions outside the band's range")
            #expect(profile.stars.contains(level.stars.count))
            #expect(witness.counterexample.size == count - 1)
            #expect(witness.difficulty.work <= AcousticConstellatorSolver.workBound)
            #expect((0..<AcousticConstellatorGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumActions[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumActions[band] >= sumActions[band - 1], "mean actions fall at band \(band + 1): \(sumActions)")
        }
    }

    /// SC-R02G1302-001 for all 100 levels: the witness actions replayed on a play win on the last one (the listen)
    /// within the budget, and the actions before it leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: AcousticConstellatorLevel = witness.level
            let play: AcousticConstellatorPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == witness.actions.count)
            #expect(witness.actions.count <= level.budget)
            let short: AcousticConstellatorPlay? = played(level, Array(witness.actions.dropLast()))
            #expect(short?.stage == .playing, "\(level.id) is not playing before its listen")
        }
    }

    /// SC-R02G1302-002 in bands 1 … 3 on the two levels with the fewest stars: no multiset of at most one action fewer
    /// than the plan, over every action the play accepts (links, unlinks of placed links, nudges of ±1; no pruning)
    /// applied through the play and then a listen, wins; the plan does.
    @Test(arguments: [1, 2, 3])
    func noSmallerPlanWinsOverEveryPlayAction(band: Int) throws {
        let witnesses: [AcousticConstellatorWitness] = try fewestStars(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let level: AcousticConstellatorLevel = witness.level
            let size: Int = witness.difficulty.actions - 1
            let result: (tried: Int, refused: Int, wins: Int) = bruteForceAllActions(level, size: size)
            #expect(result.tried >= 1, "\(level.id): nothing tried")
            #expect(result.wins == 0, "\(level.id): \(result.wins) of \(result.tried) smaller sequences win")
            #expect(listenWins(level, Array(witness.actions.dropLast())) == true, "\(level.id): the plan does not win")
        }
    }

    /// SC-R02G1302-002 in bands 4 and 5 on the two levels with the fewest stars: no multiset of one action fewer than
    /// the plan over the pruned options (the missing pairs always linked; helper links and nudges, enumerated here
    /// independently of the solver) wins, the count of sets judged equals the stored counterexample's, and the plan
    /// wins.
    @Test(arguments: [4, 5])
    func noSmallerPlanWinsOverThePrunedOptions(band: Int) throws {
        let witnesses: [AcousticConstellatorWitness] = try fewestStars(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let level: AcousticConstellatorLevel = witness.level
            let extras: Int = witness.difficulty.actions - missingPairs(level)
            #expect(extras >= 1, "\(level.id): a plan without extra actions in band \(band)")
            let result: (tried: Int, wins: Int) = bruteForcePruned(level, extras: extras - 1)
            #expect(result.tried >= 1, "\(level.id): nothing tried")
            #expect(result.wins == 0, "\(level.id): \(result.wins) of \(result.tried) smaller sets win")
            #expect(result.tried == witness.counterexample.sets, "\(level.id): \(result.tried) sets judged")
            #expect(listenWins(level, Array(witness.actions.dropLast())) == true, "\(level.id): the plan does not win")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: AcousticConstellatorWitness = try AcousticConstellatorWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == AcousticConstellatorManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte
    /// for byte (written only with ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: AcousticConstellatorGenerated = try generatedCache.generated(number)
            #expect(generated.level.id == AcousticConstellatorGenerator.levelID(number))
            let witness: AcousticConstellatorWitness = try AcousticConstellatorWitness.make(generated)
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
        for entry in AcousticConstellatorManifest.entries {
            #expect(names.contains(witnessName(entry.number)), "\(witnessName(entry.number)) is missing")
        }
    }
}
