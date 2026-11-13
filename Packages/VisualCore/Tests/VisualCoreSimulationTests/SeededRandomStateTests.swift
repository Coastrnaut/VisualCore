// SeededRandomStateTests — feature 203 R02-F03 T-R02F03-008 (FR-R02F03-030..033): saving and restoring the full
// generator state (version 1: seed plus the four xoshiro256** words as 16 lower-case hexadecimal digits).
import Foundation
import Testing
@testable import VisualCoreSimulation

private let hex16 = String(repeating: "0", count: 15) + "1"

@Test func stateRestoresAndContinuesSameSequence() throws {
    var original = SeededRandom(seed: 42)
    for _ in 0..<100 { _ = original.next() }
    let saved = original.state
    var restored = try SeededRandom(restoring: saved)
    #expect(restored == original)
    #expect(restored.seed == original.seed)
    let a = (0..<100).map { _ in original.next() }, b = (0..<100).map { _ in restored.next() }
    #expect(a == b)
    #expect(restored == original)
}

@Test func stateHasVersionSeedAndFourLowerHexWords() {
    let s = SeededRandom(seed: 42).state
    #expect(s.version == 1)
    #expect(s.seed == "000000000000002a")
    #expect(s.words.count == 4)
    let allowed = Set("0123456789abcdef")
    for w in s.words + [s.seed] { #expect(w.count == 16 && w.allSatisfy { allowed.contains($0) }) }
    // SplitMix64(42) first output, the first state word.
    var sm = SplitMix64(seed: 42)
    #expect(s.words[0] == String(sm.next(), radix: 16).leftPadded16)
}

@Test func stateJSONRoundTrip() throws {
    var r = SeededRandom(seed: 0xDEAD_BEEF_0123_4567)
    for _ in 0..<37 { _ = r.next() }
    let data = try JSONEncoder().encode(r.state)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["version"] as? Int == 1)
    #expect(object?["seed"] as? String == "deadbeef01234567")
    #expect((object?["words"] as? [String])?.count == 4)
    let decoded = try JSONDecoder().decode(SeededRandom.State.self, from: data)
    #expect(decoded == r.state)
    var restored = try SeededRandom(restoring: decoded)
    #expect(restored == r)
    #expect(restored.next() == r.next())
}

@Test func refusesUnsupportedVersion() {
    let s = SeededRandom(seed: 1).state
    for v in [0, 2, -1] {
        let bad = SeededRandom.State(version: v, seed: s.seed, words: s.words)
        #expect(throws: RandomStateError.unsupportedVersion(v)) { try SeededRandom(restoring: bad) }
    }
}

@Test func refusesWrongWordCount() {
    let s = SeededRandom(seed: 1).state
    for words in [[], Array(s.words.prefix(3)), s.words + [hex16]] {
        let bad = SeededRandom.State(version: 1, seed: s.seed, words: words)
        #expect(throws: RandomStateError.wrongWordCount) { try SeededRandom(restoring: bad) }
    }
}

@Test func refusesMalformedWordsAndSeed() {
    let s = SeededRandom(seed: 1).state
    let malformed = ["", "1", "000000000000000g", "000000000000000A", "00000000000000001", "0x00000000000001",
                     " 000000000000001", "+00000000000001f", "-00000000000001f"]
    for text in malformed {
        var words = s.words; words[2] = text
        #expect(throws: RandomStateError.malformedWord(text)) {
            try SeededRandom(restoring: SeededRandom.State(version: 1, seed: s.seed, words: words))
        }
        #expect(throws: RandomStateError.malformedWord(text)) {
            try SeededRandom(restoring: SeededRandom.State(version: 1, seed: text, words: s.words))
        }
    }
}

@Test func refusesAllZeroWords() {
    let zero = String(repeating: "0", count: 16)
    let bad = SeededRandom.State(version: 1, seed: "000000000000002a", words: [zero, zero, zero, zero])
    #expect(throws: RandomStateError.allZero) { try SeededRandom(restoring: bad) }
    // One non-zero word is enough.
    #expect((try? SeededRandom(restoring: SeededRandom.State(version: 1, seed: zero,
                                                               words: [zero, zero, zero, hex16]))) != nil)
}

@Test func existingEqualityAndOutputUnchanged() {
    var a = SeededRandom(seed: 7), b = SeededRandom(seed: 7)
    #expect(a == b)
    #expect(SeededRandom(seed: 7) != SeededRandom(seed: 8))
    _ = a.next()
    #expect(a != b)
    _ = b.next()
    #expect(a == b)
    var g = SeededRandom(seed: 42)
    #expect(g.next() == 0x1578_0B2E_0C2E_C716)
    // Same words, different seed: still unequal, as before.
    let s = SeededRandom(seed: 7).state
    let other = try? SeededRandom(restoring: SeededRandom.State(version: 1, seed: "0000000000000008", words: s.words))
    #expect(other != SeededRandom(seed: 7))
}

private extension String {
    var leftPadded16: String { String(repeating: "0", count: max(0, 16 - count)) + self }
}
