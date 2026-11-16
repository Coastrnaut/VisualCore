// ImportFuzzTests — feature 114 (A15-P05) T-A15-508 (FR-A15-510; clarification Q4; research D4; SC-A15-503). The
// seeded fuzz corpus of the import, host-free and short: 2,000 files, seeds 1 to 2,000, each one of the five library
// molecules written as XYZ text or one of the refusal fixtures, changed by one to four mutations (byte flip, byte
// insert, byte delete, line duplicate, line delete, truncate, digit change) drawn from a SplitMix64 generator written
// here (never the system generator). Every file goes through the whole core import path: the size check, then
// `XYZParser.parse(_:)`, then `ImportedMolecule.make(atoms:)` (the rule `import.end` uses) and the state's import
// steps. Nothing traps; every refusal is a typed reason with a line exactly when the reason names one; every accepted
// molecule has 1…500 atoms, finite coordinates within 1,000 Å, no pair closer than 0.4 Å and inferred single bonds;
// the state's import agrees with the rule. The files hold at most a few dozen atoms, so the pair checks stay small.
import Foundation
import Testing
@testable import MolecularExplorerCore

/// SplitMix64: a small deterministic generator for the corpus.
private struct SplitMix64: RandomNumberGenerator {
    /// The state.
    var state: UInt64

    /// The next 64-bit value.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<bound (0 for a bound of 0).
    mutating func below(_ bound: Int) -> Int {
        bound <= 0 ? 0 : Int(next() % UInt64(bound))
    }
}

/// The mutations of the corpus.
private enum Mutation: Int, CaseIterable {
    /// One bit of one byte flipped.
    case byteFlip
    /// One byte inserted (mostly from the XYZ alphabet).
    case byteInsert
    /// One byte deleted.
    case byteDelete
    /// One line written twice.
    case lineDuplicate
    /// One line removed.
    case lineDelete
    /// The file cut at a random length.
    case truncate
    /// One decimal digit replaced by another.
    case digitChange
}

@Suite struct ImportFuzzTests {
    /// The bytes an insert mostly draws from: digits, signs, separators, line endings and letters of the syntax.
    private static let alphabet: [UInt8] = Array("0123456789 \t\n\r.-+eEnNaAiIfFHCOClBr".utf8)

    /// The base files: the five library molecules as XYZ text and the refusal fixtures.
    private static func bases() -> [[UInt8]] {
        var texts: [String] = []
        for record in MoleculeLibraryData.records { texts.append(record.xyz) }
        texts.append("-3\nnegative count\nO 0 0 0\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n")
        texts.append("3\nNaN coordinate\nO 0 0 0\nH 0.2774 nan 0.2544\nH 0.6068 -0.2383 -0.7169\n")
        texts.append("2\nclose atoms\nC 0 0 0\nC 0.39 0 0\n")
        texts.append("1\nunknown\nXe 0 0 0\n")
        texts.append("2\nfar\nH 0 0 999.9999\nH 0 0 -1000\n")
        texts.append("3\r\nwindows\r\nO 0 0 0\r\nH 0.2774 0.8929 0.2544\r\nH 0.6068 -0.2383 -0.7169\r\n")
        var bases: [[UInt8]] = []
        for text in texts { bases.append(Array(text.utf8)) }
        return bases
    }

    /// The line ranges of `bytes` (split after each "\n"; the last line may lack one).
    private static func lineRanges(_ bytes: [UInt8]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x0A {
                ranges.append(start..<(index + 1))
                start = index + 1
            }
            index += 1
        }
        if start < bytes.count { ranges.append(start..<bytes.count) }
        return ranges
    }

    /// `bytes` changed by `mutation`, drawing positions from `generator`.
    private static func apply(_ mutation: Mutation, to bytes: [UInt8], _ generator: inout SplitMix64) -> [UInt8] {
        var result = bytes
        switch mutation {
        case .byteFlip:
            guard !result.isEmpty else { return result }
            let index = generator.below(result.count)
            result[index] ^= UInt8(1 << generator.below(8))
        case .byteInsert:
            let byte = generator.below(4) == 0 ? UInt8(generator.below(256)) : alphabet[generator.below(alphabet.count)]
            result.insert(byte, at: generator.below(result.count + 1))
        case .byteDelete:
            guard !result.isEmpty else { return result }
            result.remove(at: generator.below(result.count))
        case .lineDuplicate:
            let lines = lineRanges(result)
            guard !lines.isEmpty else { return result }
            let line = lines[generator.below(lines.count)]
            result.insert(contentsOf: Array(result[line]), at: line.upperBound)
        case .lineDelete:
            let lines = lineRanges(result)
            guard !lines.isEmpty else { return result }
            result.removeSubrange(lines[generator.below(lines.count)])
        case .truncate:
            result.removeSubrange(generator.below(result.count + 1)..<result.count)
        case .digitChange:
            var digits: [Int] = []
            for (index, byte) in result.enumerated() where byte >= 0x30 && byte <= 0x39 { digits.append(index) }
            guard !digits.isEmpty else { return result }
            result[digits[generator.below(digits.count)]] = UInt8(0x30 + generator.below(10))
        }
        return result
    }

    /// The file of `seed`: a base chosen by the generator with one to four mutations.
    private static func file(seed: UInt64, bases: [[UInt8]]) -> [UInt8] {
        var generator = SplitMix64(state: seed)
        var bytes = bases[generator.below(bases.count)]
        let count = 1 + generator.below(4)
        for _ in 0..<count {
            let mutation = Mutation(rawValue: generator.below(Mutation.allCases.count)) ?? .byteFlip
            bytes = apply(mutation, to: bytes, &generator)
        }
        return bytes
    }

    /// The problems of an accepted molecule against the import limits, empty when it is within them.
    private static func limitProblems(_ molecule: Molecule) -> [String] {
        var problems: [String] = []
        if molecule.atoms.isEmpty || molecule.atoms.count > 500 { problems.append("count \(molecule.atoms.count)") }
        for atom in molecule.atoms {
            let values = [atom.x, atom.y, atom.z]
            for value in values where !value.isFinite || abs(value) > 1_000 { problems.append("coordinate \(value)") }
            if Elements.element(symbol: atom.symbol) == nil { problems.append("element \(atom.symbol)") }
        }
        var j = 1
        while j < molecule.atoms.count {
            var i = 0
            while i < j {
                if molecule.atoms[i].distance(to: molecule.atoms[j]) < 0.4 { problems.append("pair \(i) \(j)") }
                i += 1
            }
            j += 1
        }
        for bond in molecule.bonds where bond.order != 1 || bond.origin != .inferred { problems.append("bond \(bond)") }
        if molecule.bonds != BondInference.bonds(for: molecule.atoms) { problems.append("bonds differ") }
        return problems
    }

    /// The reasons that never name a line.
    private static let lineless: Set<XYZRefusal.Reason> = [.empty, .tooLarge, .notText]

    @Test func twoThousandMutatedFilesNeverBreakTheImport() {
        let bases = Self.bases()
        var refusedBySize = 0
        var refusedByParser: [XYZRefusal.Reason: Int] = [:]
        var refusedByRule = 0
        var accepted = 0
        var problems: [String] = []
        for seed in UInt64(1)...2_000 {
            let bytes = Self.file(seed: seed, bases: bases)
            if MoleculeImport.sizeRefusal(byteCount: bytes.count) != nil {
                refusedBySize += 1
                continue
            }
            let parsed: ParsedXYZ
            switch XYZParser.parse(Data(bytes)) {
            case .failure(let refusal):
                refusedByParser[refusal.reason, default: 0] += 1
                if Self.lineless.contains(refusal.reason) != (refusal.line == nil) {
                    problems.append("seed \(seed): \(refusal) line")
                }
                if MoleculeImport.sentence(refusal).isEmpty { problems.append("seed \(seed): no sentence") }
                continue
            case .success(let value):
                parsed = value
            }
            let rule = ImportedMolecule.make(atoms: parsed.atoms)
            var state = MoleculeState.initial
            var steps = state.beginImport(count: parsed.atoms.count)
            for atom in parsed.atoms { steps = steps && state.addImportedAtom(atom) }
            let ended = steps ? state.endImport() : .failure(.badCount)
            switch rule {
            case .failure(let reason):
                refusedByRule += 1
                if ended != .failure(reason) && steps { problems.append("seed \(seed): state \(ended), rule \(reason)") }
            case .success(let imported):
                accepted += 1
                for line in Self.limitProblems(imported.molecule) { problems.append("seed \(seed): \(line)") }
                if ended != .success(imported) { problems.append("seed \(seed): the state's import differs") }
                if imported.molecule.atoms.count != parsed.atoms.count { problems.append("seed \(seed): atoms lost") }
            }
        }
        #expect(problems.isEmpty, "\(problems.prefix(10))")
        var parserTotal = 0
        for (_, count) in refusedByParser { parserTotal += count }
        #expect(refusedBySize + parserTotal + refusedByRule + accepted == 2_000)
        #expect(accepted > 0 && parserTotal > 0, "the corpus reaches both outcomes")
        #expect(refusedByParser.count >= 5, "the corpus reaches several parser reasons: \(refusedByParser)")
    }

    @Test func theCorpusIsDeterministic() {
        let bases = Self.bases()
        let seeds: [UInt64] = [1, 2, 1_000, 2_000]
        for seed in seeds {
            #expect(Self.file(seed: seed, bases: bases) == Self.file(seed: seed, bases: bases), "seed \(seed)")
        }
        #expect(Self.file(seed: 1, bases: bases) != Self.file(seed: 2, bases: bases))
    }
}
