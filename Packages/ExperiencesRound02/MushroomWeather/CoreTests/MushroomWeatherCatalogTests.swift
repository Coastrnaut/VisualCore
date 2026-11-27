// MushroomWeatherCatalogTests — feature 492 (R02-G20-02) T-R02G2002-006 (FR-R02G2002-001 … 007; SC-R02G2002-001 …
// 005; clarifications Q1 … Q5). The 100-level catalog: manifest shape (20 levels per band), the pinned digest,
// R02-F24's standard progression rule on the witness length in manifest order and non-decreasing band means, adjacent
// levels with a different floor or colonies (the neighbour rule), every stored witness replayed to a win through the
// play within its budget, an independent enumeration on the two levels with the fewest sites, then fewest colonies, in
// each band (ties by level number: every arrangement of pods on distinct sites, vents toggled and moonlight within a
// distance below the plan, judged by the kernel's weather without the solver's order or loss: none wins, and one at
// exactly the plan's distance does), one fully re-verified decode per band, and the witness files in
// docs/games/mushroom-weather/levels/ compared byte for byte with the regenerated witnesses in 20 groups of 5 levels
// (each level generated after the stored level before it, the neighbour rule's input). The files are written only when
// MUSHROOM_WEATHER_WRITE_WITNESSES=1 is set, with `swift test --no-parallel` so the groups run in order. Stored files
// are read with the plain decoder except in the re-verified test. Explicit types and plain loops (CI type-check rule).
// Modelled on MicroscopicAuroraCatalogTests (feature 482).
import Foundation
@testable import MushroomWeatherCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MushroomWeather, the package,
/// Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(MushroomWeatherGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> MushroomWeatherWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(MushroomWeatherWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[MushroomWeatherWitness], any Error> = Result {
    var result: [MushroomWeatherWitness] = []
    for entry in MushroomWeatherManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [MushroomWeatherWitness] { try stored.get() }

/// The arrangement actions of a witness (its actions without the closing run).
private func changes(_ witness: MushroomWeatherWitness) -> [MushroomWeatherAction] {
    var result: [MushroomWeatherAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: MushroomWeatherLevel, _ actions: [MushroomWeatherAction]) -> MushroomWeatherPlay? {
    var play = MushroomWeatherPlay(level: level)
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

/// Whether some arrangement of `level` within distance `limit` of its start wins, judged by the kernel's weather: pods
/// on distinct sites (pods are identical, so a set of sites), any set of vents toggled, the moonlight kept or changed
/// to another level, costing one per pod, one per toggled vent and one for a changed moonlight (an enumeration of its
/// own, independent of the solver's order and loss).
private func winsWithin(_ level: MushroomWeatherLevel, limit: Int) -> Bool {
    let sites: [MushroomWeatherCell] = level.sites ?? []
    let slots: Int = level.podRules.slots
    let ventCount: Int = level.vents.count
    var moonOptions: [(level: Int, cost: Int)] = [(level.start.moonlight, 0)]
    for moon in 0...3 where moon != level.start.moonlight { moonOptions.append((moon, 1)) }
    var podSets: [[MushroomWeatherCell]] = []
    func collect(_ from: Int, _ chosen: [MushroomWeatherCell]) {
        podSets.append(chosen)
        if chosen.count == slots || chosen.count == limit { return }
        var index: Int = from
        while index < sites.count {
            collect(index + 1, chosen + [sites[index]])
            index += 1
        }
    }
    collect(0, [])
    for pods in podSets {
        var mask: Int = 0
        while mask < (1 << ventCount) {
            let toggled: Int = mask.nonzeroBitCount
            for moon in moonOptions where pods.count + toggled + moon.cost <= limit {
                var slotsFilled: [MushroomWeatherCell?] = Array(repeating: nil, count: slots)
                for (slot, cell) in pods.enumerated() { slotsFilled[slot] = cell }
                var vents: [Bool] = level.start.ventsOpen
                for index in 0..<ventCount where mask & (1 << index) != 0 { vents[index].toggle() }
                let arrangement = MushroomWeatherArrangement(pods: slotsFilled, ventsOpen: vents,
                                                             moonlight: moon.level)
                if MushroomWeatherForest.report(level, arrangement: arrangement).wins { return true }
            }
            mask += 1
        }
    }
    return false
}

/// The two stored witnesses of `band` with the fewest sites, then the fewest colonies (then the lowest number).
private func fewestSites(band: Int) throws -> [MushroomWeatherWitness] {
    var candidates: [MushroomWeatherWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort {
        ($0.level.sites?.count ?? 0, $0.level.colonies.count, $0.number)
            < ($1.level.sites?.count ?? 0, $1.level.colonies.count, $1.number)
    }
    return Array(candidates.prefix(2))
}

@Suite struct MushroomWeatherCatalogTests {
    /// The pinned catalog digest: `MushroomWeatherGenerator.catalogDigest` over the 100 levels in manifest order,
    /// measured on 2026-11-26 from the prototype and the production generator alike. An intended rule, generator or
    /// seed change re-pins it after review.
    static let pinnedDigest = "a71fe37a03ecb54e1a1b3e73c490119e3a18cf04ce5395307f504e54c6c584e5"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [MushroomWeatherManifestEntry] = MushroomWeatherManifest.entries
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
    }

    /// The digest over the stored levels (equal to the generated ones: see the group tests) is pinned; the ids follow
    /// the manifest; adjacent levels differ in floor or colonies (FR-R02G2002-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [MushroomWeatherWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [MushroomWeatherLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == MushroomWeatherGenerator.levelID(index + 1))
            if index > 0 {
                let before: MushroomWeatherLevel = witnesses[index - 1].level
                let sameFloor: Bool = before.rows == witness.level.rows && before.columns == witness.level.columns
                    && before.blocked == witness.level.blocked
                let sameColonies: Bool = before.colonies == witness.level.colonies
                #expect(!(sameFloor && sameColonies), "\(witness.level.id) repeats its neighbour")
            }
        }
        let digest: String = MushroomWeatherGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's profile, R02-F24's standard progression rule on the witness length in
    /// manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [MushroomWeatherWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: MushroomWeatherLevel = witness.level
            let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[witness.number - 1]
            let count: Int = changes(witness).count
            #expect(witness.actions.last == .run)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.actions)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: MushroomWeatherBandProfile = MushroomWeatherBandProfile.of(band: level.difficulty)
            #expect(count == profile.plan, "\(level.id): \(count) actions, the band's plan is \(profile.plan)")
            #expect(level.sites?.count == profile.sites)
            #expect(level.vents.count == profile.vents)
            #expect(level.podRules.slots == profile.slots)
            #expect(level.colonies.count == profile.colonies)
            #expect(profile.rows.contains(level.rows))
            #expect(profile.columns.contains(level.columns))
            #expect(profile.blocked.contains(level.blocked.count))
            var noPod: Bool = true
            for pod in level.start.pods where pod != nil { noPod = false }
            #expect(noPod, "\(level.id) starts with a pod")
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= MushroomWeatherSolver.workBound)
            #expect((0..<MushroomWeatherGenerator.maxCandidates).contains(witness.skipped))
            #expect(witness.report.balances)
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

    /// SC-R02G2002-001 for all 100 levels: the witness actions replayed on a play, then the run, win within the budget;
    /// the actions alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: MushroomWeatherLevel = witness.level
            let play: MushroomWeatherPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == changes(witness).count)
            let before: MushroomWeatherPlay? = played(level, changes(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its run")
        }
    }

    /// SC-R02G2002-002 on the two levels with the fewest sites, then colonies, in each band: the independent
    /// enumeration finds no win below the plan's distance and a win at exactly it.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noArrangementAtASmallerDistanceWins(band: Int) throws {
        let witnesses: [MushroomWeatherWitness] = try fewestSites(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.actions
            #expect(!winsWithin(witness.level, limit: size - 1), "\(witness.level.id) is won with fewer actions")
            #expect(winsWithin(witness.level, limit: size), "\(witness.level.id) is not won with its actions")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: MushroomWeatherWitness = try MushroomWeatherWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == MushroomWeatherManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with MUSHROOM_WEATHER_WRITE_WITNESSES=1). Each level is generated after the level before it —
    /// the stored one for the group's first level, which its own group checks against its regeneration.
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["MUSHROOM_WEATHER_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        var previous: MushroomWeatherLevel? = nil
        if group > 0 { previous = try storedWitness(5 * group).level }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: MushroomWeatherGenerated = try MushroomWeatherGenerator.generate(
                MushroomWeatherManifest.entries[number - 1], previous: previous)
            #expect(generated.level.id == MushroomWeatherGenerator.levelID(number))
            let witness: MushroomWeatherWitness = try MushroomWeatherWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let storedData: Data = try Data(contentsOf: url)
            #expect(storedData == data, "\(witnessName(number)) differs from the regenerated witness")
            previous = generated.level
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let all: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
        var names: [String] = []
        for name in all where name.hasSuffix(".witness.json") { names.append(name) }
        #expect(names.count == 100)
    }
}
