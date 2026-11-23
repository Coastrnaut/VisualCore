// EchoCartographerCatalogTests — feature 402 (R02-G11-02) T-R02G1102-006 (FR-R02G1102-001, 002, 003, 004, 005;
// SC-R02G1102-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band means
// of the witness pulse count, every stored witness replayed to a win through the play within its energy (pulses at most
// energy − 1), an independent brute force on the two smallest regions of each band (path lengths by fixed-point
// relaxation, every beacon-count subset of the region: exactly one placement fits after the witness pulses, the true
// beacons, and at least two fit every pulse but the last), one fully re-verified decode per band, and the witness files
// in docs/games/echo-cartographer/levels/ compared byte for byte with the regenerated witnesses in 20 groups of 5 levels.
// The files are written only when ECHO_CARTOGRAPHER_WRITE_WITNESSES=1 is set. Stored files are read with the plain
// decoder (the level re-checked) except in the re-verified test. Explicit types and plain loops (CI type-check rule).
@testable import EchoCartographerCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/echo-cartographer/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(EchoCartographerGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> EchoCartographerWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(EchoCartographerWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[EchoCartographerWitness], any Error> = Result {
    var result: [EchoCartographerWitness] = []
    for entry in EchoCartographerManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [EchoCartographerWitness] { try stored.get() }

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied.
private func played(_ level: EchoCartographerLevel, _ actions: [EchoCartographerAction]) throws -> EchoCartographerPlay {
    var play = EchoCartographerPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    for action in actions { try play.apply(action, expecting: play.fingerprint) }
    return play
}

/// Path lengths from `from` by fixed-point relaxation over open side neighbours (independent of the kernel's search).
private func relaxed(_ chamber: EchoCartographerChamber, from: EchoCartographerCell) -> [Int] {
    let unreachable: Int = Int.max
    var lengths: [Int] = Array(repeating: unreachable, count: chamber.cellCount)
    lengths[from.y * chamber.width + from.x] = 0
    var changed: Bool = true
    while changed {
        changed = false
        for y in 0..<chamber.height {
            for x in 0..<chamber.width {
                let index: Int = y * chamber.width + x
                if chamber.walls.contains(index) { continue }
                var best: Int = lengths[index]
                let steps: [(Int, Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
                for (dx, dy) in steps {
                    let nx: Int = x + dx
                    let ny: Int = y + dy
                    if nx < 0 || ny < 0 || nx >= chamber.width || ny >= chamber.height { continue }
                    let n: Int = ny * chamber.width + nx
                    if chamber.walls.contains(n) || lengths[n] == unreachable { continue }
                    best = min(best, lengths[n] + 1)
                }
                if best < lengths[index] {
                    lengths[index] = best
                    changed = true
                }
            }
        }
    }
    return lengths
}

/// The pulses (emitters) of a witness's actions, in order.
private func pulses(_ actions: [EchoCartographerAction]) -> [EchoCartographerCell] {
    var cells: [EchoCartographerCell] = []
    for action in actions {
        if case let .pulse(x, y) = action { cells.append(EchoCartographerCell(x: x, y: y)) }
    }
    return cells
}

/// Brute force: the number of beacon-count subsets of the region (reachable open cells other than the entry) whose
/// sorted relaxed distances from every emitter in `emitters` equal those of the true beacons, and whether the true
/// beacons are among them.
private func bruteForce(_ level: EchoCartographerLevel, emitters: [EchoCartographerCell]) -> (count: Int, truth: Bool) {
    let chamber: EchoCartographerChamber = level.chamber
    let fromEntry: [Int] = relaxed(chamber, from: level.entry)
    let entryIndex: Int = level.entry.y * chamber.width + level.entry.x
    var region: [Int] = []
    for index in 0..<chamber.cellCount where fromEntry[index] != Int.max && index != entryIndex { region.append(index) }
    var tables: [[Int]] = []
    var wanted: [[Int]] = []
    for emitter in emitters {
        let table: [Int] = relaxed(chamber, from: emitter)
        tables.append(table)
        var echo: [Int] = []
        for beacon in level.beacons { echo.append(table[beacon.y * chamber.width + beacon.x]) }
        wanted.append(echo.sorted())
    }
    let truthSet: [Int] = level.beacons.map { $0.y * chamber.width + $0.x }.sorted()
    let k: Int = level.beacons.count
    var indices: [Int] = Array(0..<k)
    var count: Int = 0
    var truth: Bool = false
    if region.count < k { return (0, false) }
    while true {
        var fits: Bool = true
        for j in 0..<emitters.count {
            var distances: [Int] = []
            for i in indices { distances.append(tables[j][region[i]]) }
            if distances.sorted() != wanted[j] {
                fits = false
                break
            }
        }
        if fits {
            count += 1
            var chosen: [Int] = []
            for i in indices { chosen.append(region[i]) }
            if chosen == truthSet { truth = true }
        }
        // Next k-combination of 0 ..< region.count.
        var position: Int = k - 1
        while position >= 0 && indices[position] == region.count - k + position { position -= 1 }
        if position < 0 { break }
        indices[position] += 1
        var next: Int = position + 1
        while next < k {
            indices[next] = indices[next - 1] + 1
            next += 1
        }
    }
    return (count, truth)
}

@Suite struct EchoCartographerCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "a32a593b898acf77bd86c25509a68e0b5f8a1227f356d2d3b91c8cfff5c8dca9"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [EchoCartographerManifestEntry] = EchoCartographerManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.energy))
            perBand[entry.band - 1] += 1
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(Set(entries.map(\.seed)).count == 100)
        #expect(entries[0].seed == 0x3cfb16de6f757496)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [EchoCartographerWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [EchoCartographerLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == EchoCartographerGenerator.levelID(index + 1))
        }
        let digest: String = EchoCartographerGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Winnable within the energy, each band's pulse range, the progression rule and the band means of the witness pulse
    /// count (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsEnergyAndKeepsTheProgression() throws {
        let witnesses: [EchoCartographerWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumPulses: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: EchoCartographerLevel = witness.level
            let count: Int = pulses(witness.actions).count
            #expect(count == witness.difficulty.pulses)
            #expect(count <= level.energy - 1)
            let profile: EchoCartographerBandProfile = EchoCartographerBandProfile.of(band: level.difficulty)
            #expect(profile.pulses.contains(count))
            #expect(profile.sizes.contains(level.chamber.width) && profile.sizes.contains(level.chamber.height))
            #expect(profile.beacons.contains(level.beacons.count))
            #expect(witness.difficulty.region >= EchoCartographerGenerator.minimumRegion)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumPulses[level.difficulty - 1] += count
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumPulses[band] >= sumPulses[band - 1], "mean pulses fall at band \(band + 1): \(sumPulses)")
        }
    }

    /// SC-R02G1102-001 for all 100 levels: the witness actions replayed on a play win on the last one within the energy.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: EchoCartographerLevel = witness.level
            let play: EchoCartographerPlay = try played(level, witness.actions)
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.energy >= 1)
            let short: EchoCartographerPlay = try played(level, Array(witness.actions.dropLast()))
            #expect(short.stage == .playing, "\(level.id) is won one action short")
        }
    }

    /// SC-R02G1102-002 and 005 on the two smallest regions of each band: by brute force, exactly one placement (the true
    /// beacons) fits after the witness pulses, and at least two fit every pulse but the last.
    @Test(arguments: [1, 2, 3, 4, 5])
    func theInferenceProofIsCheckedByBruteForce(band: Int) throws {
        var candidates: [EchoCartographerWitness] = []
        for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
        candidates.sort { ($0.difficulty.region, $0.number) < ($1.difficulty.region, $1.number) }
        for witness in candidates.prefix(2) {
            let level: EchoCartographerLevel = witness.level
            let emitters: [EchoCartographerCell] = pulses(witness.actions)
            let after = bruteForce(level, emitters: emitters)
            #expect(after.count == 1, "\(level.id): \(after.count) placements fit after the witness")
            #expect(after.truth, "\(level.id): the true beacons do not fit")
            let before = bruteForce(level, emitters: Array(emitters.dropLast()))
            #expect(before.count >= 2, "\(level.id): \(before.count) placements fit one pulse short")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: EchoCartographerWitness = try EchoCartographerWitness.decode(data)
        #expect(witness.number == number)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with ECHO_CARTOGRAPHER_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["ECHO_CARTOGRAPHER_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: EchoCartographerGenerated = try EchoCartographerGenerator.generate(
                EchoCartographerManifest.entries[number - 1])
            let witness: EchoCartographerWitness = try EchoCartographerWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(number)) differs from the regenerated witness")
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
