// StateDigestTests — feature 188 T-U02-006 (FR-U02-013, FR-U02-015): the byte layout of data-model.md section 3
// field by field, the separation of neighbouring fields and sequences, the refusal of values that are not finite,
// and the text form of a digest.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath

@Suite struct StateDigestTests {
    /// The 8 bytes of a 64-bit value, the most significant first, written without the code under test.
    private func be64(_ value: UInt64) -> [UInt8] {
        (0..<8).map { UInt8((value >> UInt64(56 - $0 * 8)) & 0xff) }
    }

    /// The expected bytes of a String field.
    private func stringField(_ text: String) -> [UInt8] {
        [0x04] + be64(UInt64(text.utf8.count)) + Array(text.utf8)
    }

    /// The expected bytes of the domain `d`, the first field of every builder of these tests.
    private var domain: [UInt8] { [0x04, 0, 0, 0, 0, 0, 0, 0, 1, 0x64] }

    // MARK: Layout, field by field

    @Test func domainIsTheFirstField() {
        let builder = DigestBuilder(domain: "a05.infinite-geometry")
        #expect(builder.fieldCount == 1)
        #expect(builder.finish().hex == StableHash.sha256Hex(stringField("a05.infinite-geometry")))
        #expect(DigestBuilder(domain: "d").finish().hex == StableHash.sha256Hex(domain))
        #expect(DigestBuilder(domain: "").finish().hex == StableHash.sha256Hex([0x04, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(DigestBuilder(domain: "a").finish() != DigestBuilder(domain: "b").finish())
    }

    @Test func intLayout() {
        let table: [(Int, [UInt8])] = [
            (0, [0, 0, 0, 0, 0, 0, 0, 0]),
            (258, [0, 0, 0, 0, 0, 0, 0x01, 0x02]),
            (-1, [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            (-2, [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe]),
            (0x0102_0304_0506_0708, [1, 2, 3, 4, 5, 6, 7, 8]),
            (Int(Int64.min), [0x80, 0, 0, 0, 0, 0, 0, 0]),
        ]
        for (value, bytes) in table {
            var builder = DigestBuilder(domain: "d")
            builder.add(value)
            #expect(builder.fieldCount == 2)
            #expect(builder.finish().hex == StableHash.sha256Hex(domain + [0x01] + bytes), "Int \(value)")
        }
    }

    @Test func uint64Layout() {
        let table: [(UInt64, [UInt8])] = [
            (0, [0, 0, 0, 0, 0, 0, 0, 0]),
            (258, [0, 0, 0, 0, 0, 0, 0x01, 0x02]),
            (0x0102_0304_0506_0708, [1, 2, 3, 4, 5, 6, 7, 8]),
            (UInt64.max, [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        ]
        for (value, bytes) in table {
            var builder = DigestBuilder(domain: "d")
            builder.add(value)
            #expect(builder.fieldCount == 2)
            #expect(builder.finish().hex == StableHash.sha256Hex(domain + [0x02] + bytes), "UInt64 \(value)")
        }
    }

    @Test func boolLayout() {
        var no = DigestBuilder(domain: "d")
        no.add(false)
        #expect(no.finish().hex == StableHash.sha256Hex(domain + [0x03, 0x00]))
        var yes = DigestBuilder(domain: "d")
        yes.add(true)
        #expect(yes.finish().hex == StableHash.sha256Hex(domain + [0x03, 0x01]))
        #expect(yes.fieldCount == 2)
    }

    @Test func stringLayout() {
        var builder = DigestBuilder(domain: "d")
        builder.add("abc")
        #expect(builder.finish().hex == StableHash.sha256Hex(domain + [0x04, 0, 0, 0, 0, 0, 0, 0, 3, 0x61, 0x62, 0x63]))

        // The length counts UTF-8 bytes, not characters: "é" is 0xC3 0xA9.
        var accented = DigestBuilder(domain: "d")
        accented.add("é")
        #expect(accented.finish().hex == StableHash.sha256Hex(domain + [0x04, 0, 0, 0, 0, 0, 0, 0, 2, 0xc3, 0xa9]))

        var empty = DigestBuilder(domain: "d")
        empty.add("")
        #expect(empty.finish().hex == StableHash.sha256Hex(domain + [0x04, 0, 0, 0, 0, 0, 0, 0, 0]))

        let long = String(repeating: "x", count: 300)
        var longBuilder = DigestBuilder(domain: "d")
        longBuilder.add(long)
        let expected = domain + [0x04, 0, 0, 0, 0, 0, 0, 0x01, 0x2c] + [UInt8](repeating: 0x78, count: 300)
        #expect(longBuilder.finish().hex == StableHash.sha256Hex(expected))
    }

    @Test func bytesLayout() {
        var builder = DigestBuilder(domain: "d")
        builder.add([0xde, 0xad, 0xbe, 0xef] as [UInt8])
        #expect(builder.fieldCount == 2)
        #expect(builder.finish().hex
            == StableHash.sha256Hex(domain + [0x05, 0, 0, 0, 0, 0, 0, 0, 4, 0xde, 0xad, 0xbe, 0xef]))

        var empty = DigestBuilder(domain: "d")
        empty.add([UInt8]())
        #expect(empty.finish().hex == StableHash.sha256Hex(domain + [0x05, 0, 0, 0, 0, 0, 0, 0, 0]))

        // The same content as text and as bytes differs by its tag.
        var text = DigestBuilder(domain: "d")
        text.add("abc")
        var raw = DigestBuilder(domain: "d")
        raw.add([0x61, 0x62, 0x63] as [UInt8])
        #expect(text.finish() != raw.finish())
    }

    @Test func doubleLayout() throws {
        let table: [(Double, [UInt8])] = [
            (0.0, [0, 0, 0, 0, 0, 0, 0, 0]),
            (1.0, [0x3f, 0xf0, 0, 0, 0, 0, 0, 0]),
            (1.5, [0x3f, 0xf8, 0, 0, 0, 0, 0, 0]),
            (-2.0, [0xc0, 0, 0, 0, 0, 0, 0, 0]),
            (0.1, [0x3f, 0xb9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9a]),
            (Double.greatestFiniteMagnitude, [0x7f, 0xef, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            (Double.leastNonzeroMagnitude, [0, 0, 0, 0, 0, 0, 0, 1]),
        ]
        for (value, bytes) in table {
            var builder = DigestBuilder(domain: "d")
            try builder.add(value)
            #expect(builder.fieldCount == 2)
            #expect(builder.finish().hex == StableHash.sha256Hex(domain + [0x06] + bytes), "Double \(value)")
        }
    }

    @Test func sequenceCountLayout() {
        var builder = DigestBuilder(domain: "d")
        builder.add(count: 3)
        #expect(builder.fieldCount == 2)
        #expect(builder.finish().hex == StableHash.sha256Hex(domain + [0x07, 0, 0, 0, 0, 0, 0, 0, 3]))

        var none = DigestBuilder(domain: "d")
        none.add(count: 0)
        #expect(none.finish().hex == StableHash.sha256Hex(domain + [0x07, 0, 0, 0, 0, 0, 0, 0, 0]))

        // A count and an Int of the same value differ by their tag.
        var plain = DigestBuilder(domain: "d")
        plain.add(3)
        #expect(builder.finish() != plain.finish())
    }

    @Test func severalFieldsAreConcatenatedInOrder() throws {
        var builder = DigestBuilder(domain: "d")
        builder.add(7)
        builder.add(UInt64(9))
        builder.add(true)
        builder.add("hi")
        builder.add([0xaa] as [UInt8])
        try builder.add(1.0)
        builder.add(count: 2)
        #expect(builder.fieldCount == 8)
        var expected = domain
        expected += [0x01, 0, 0, 0, 0, 0, 0, 0, 7]
        expected += [0x02, 0, 0, 0, 0, 0, 0, 0, 9]
        expected += [0x03, 0x01]
        expected += [0x04, 0, 0, 0, 0, 0, 0, 0, 2, 0x68, 0x69]
        expected += [0x05, 0, 0, 0, 0, 0, 0, 0, 1, 0xaa]
        expected += [0x06, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0]
        expected += [0x07, 0, 0, 0, 0, 0, 0, 0, 2]
        #expect(builder.finish().hex == StableHash.sha256Hex(expected))

        // The order of the fields matters, and finishing does not change the builder.
        var swapped = DigestBuilder(domain: "d")
        swapped.add(UInt64(9))
        swapped.add(7)
        var ordered = DigestBuilder(domain: "d")
        ordered.add(7)
        ordered.add(UInt64(9))
        #expect(swapped.finish() != ordered.finish())
        #expect(builder.finish() == builder.finish())
    }

    // MARK: Separation

    @Test func neighbouringStringsDoNotMerge() {
        var first = DigestBuilder(domain: "d")
        first.add("ab")
        first.add("c")
        var second = DigestBuilder(domain: "d")
        second.add("a")
        second.add("bc")
        var joined = DigestBuilder(domain: "d")
        joined.add("abc")
        #expect(first.finish() != second.finish())
        #expect(first.finish() != joined.finish())
        #expect(second.finish() != joined.finish())
        #expect(first.finish().hex == StableHash.sha256Hex(domain + stringField("ab") + stringField("c")))
        #expect(second.finish().hex == StableHash.sha256Hex(domain + stringField("a") + stringField("bc")))

        // The domain does not merge with the first field either.
        var left = DigestBuilder(domain: "ab")
        left.add("c")
        var right = DigestBuilder(domain: "a")
        right.add("bc")
        #expect(left.finish() != right.finish())
    }

    @Test func intAndUInt64OfTheSameValueDiffer() {
        for value in [0, 1, 42, Int.max] {
            var signed = DigestBuilder(domain: "d")
            signed.add(value)
            var unsigned = DigestBuilder(domain: "d")
            unsigned.add(UInt64(value))
            #expect(signed.finish() != unsigned.finish(), "value \(value)")
        }
    }

    @Test func countSeparatesSequences() {
        func digest(_ sequences: [[Int]]) -> StateDigest {
            var builder = DigestBuilder(domain: "d")
            for sequence in sequences {
                builder.add(count: sequence.count)
                for value in sequence { builder.add(value) }
            }
            return builder.finish()
        }
        #expect(digest([[1, 2], [3]]) != digest([[1], [2, 3]]))
        #expect(digest([[1, 2, 3], []]) != digest([[], [1, 2, 3]]))
        #expect(digest([[1, 2], [3]]) == digest([[1, 2], [3]]))

        func int(_ value: UInt8) -> [UInt8] { [0x01, 0, 0, 0, 0, 0, 0, 0, value] }
        func count(_ value: UInt8) -> [UInt8] { [0x07, 0, 0, 0, 0, 0, 0, 0, value] }
        let expected = domain + count(2) + int(1) + int(2) + count(1) + int(3)
        #expect(digest([[1, 2], [3]]).hex == StableHash.sha256Hex(expected))
    }

    // MARK: Doubles

    @Test func negativeZeroEqualsZero() throws {
        var negative = DigestBuilder(domain: "d")
        try negative.add(-0.0)
        var positive = DigestBuilder(domain: "d")
        try positive.add(0.0)
        #expect(negative.finish() == positive.finish())
        #expect(negative.finish().hex == StableHash.sha256Hex(domain + [0x06, 0, 0, 0, 0, 0, 0, 0, 0]))
        // The sign of every other value stays.
        var minusOne = DigestBuilder(domain: "d")
        try minusOne.add(-1.0)
        var plusOne = DigestBuilder(domain: "d")
        try plusOne.add(1.0)
        #expect(minusOne.finish() != plusOne.finish())
    }

    @Test func nonFiniteDoublesThrowWithTheFieldIndex() {
        let refused: [Double] = [.nan, .signalingNaN, -Double.nan, .infinity, -.infinity]
        for value in refused {
            // Directly after the domain the field would have had index 1.
            var first = DigestBuilder(domain: "d")
            #expect(throws: DigestError.nonFinite(field: 1)) { try first.add(value) }

            // After the domain and three more fields it would have had index 4.
            var later = DigestBuilder(domain: "d")
            later.add(1)
            later.add("x")
            later.add(true)
            #expect(throws: DigestError.nonFinite(field: 4)) { try later.add(value) }
        }
    }

    @Test func aRefusedDoubleAppendsNothing() throws {
        var builder = DigestBuilder(domain: "d")
        builder.add(5)
        let before = builder.finish()
        #expect(throws: DigestError.nonFinite(field: 2)) { try builder.add(Double.nan) }
        #expect(throws: DigestError.nonFinite(field: 2)) { try builder.add(Double.infinity) }
        #expect(throws: DigestError.nonFinite(field: 2)) { try builder.add(-Double.infinity) }
        #expect(builder.fieldCount == 2)
        #expect(builder.finish() == before)
        #expect(before.hex == StableHash.sha256Hex(domain + [0x01, 0, 0, 0, 0, 0, 0, 0, 5]))

        // The builder goes on as if the refused value had never been offered.
        try builder.add(2.0)
        #expect(builder.fieldCount == 3)
        let expected = domain + [0x01, 0, 0, 0, 0, 0, 0, 0, 5] + [0x06, 0x40, 0, 0, 0, 0, 0, 0, 0]
        #expect(builder.finish().hex == StableHash.sha256Hex(expected))
    }

    // MARK: StateDigest

    @Test func hexAcceptsExactly64LowerCaseHexadecimalDigits() {
        let good = String(repeating: "0123456789abcdef", count: 4)
        #expect(StateDigest(hex: good)?.hex == good)
        #expect(StateDigest(hex: good)?.description == good)
        #expect(StateDigest(hex: String(repeating: "0", count: 64)) != nil)
        #expect(StateDigest(hex: String(repeating: "f", count: 64)) != nil)

        let bad: [String] = [
            "",
            String(good.dropLast()),
            good + "0",
            good.uppercased(),
            String(good.dropLast()) + "g",
            String(good.dropLast()) + "F",
            String(good.dropLast()) + " ",
            String(good.dropLast()) + "é",
            String(good.dropLast(2)) + "é",
            String(good.dropLast()) + "٣",
            "0x" + String(good.dropLast(2)),
        ]
        for text in bad { #expect(StateDigest(hex: text) == nil, "accepted \(text)") }
    }

    @Test func finishGives64LowerCaseDigitsAndIsAValidDigest() {
        // The SHA-256 of the domain "abc" as a String field.
        let digest = DigestBuilder(domain: "abc").finish()
        #expect(digest.hex.utf8.count == 64)
        #expect(StateDigest(hex: digest.hex) == digest)
        #expect(digest.description == digest.hex)
        #expect(digest.hex == StableHash.sha256Hex([0x04, 0, 0, 0, 0, 0, 0, 0, 3, 0x61, 0x62, 0x63]))
        #expect(Set([digest, DigestBuilder(domain: "abc").finish(), DigestBuilder(domain: "abd").finish()]).count == 2)
    }

    @Test func codableAsOneJSONString() throws {
        let hex = String(repeating: "0123456789abcdef", count: 4)
        let digest = try #require(StateDigest(hex: hex))

        // Inside an array, so the test does not depend on top-level fragments.
        let data = try JSONEncoder().encode([digest])
        #expect(String(decoding: data, as: UTF8.self) == "[\"\(hex)\"]")
        #expect(try JSONDecoder().decode([StateDigest].self, from: data) == [digest])
        #expect(try JSONDecoder().decode([String].self, from: data) == [hex])

        struct Holder: Codable, Equatable { let digest: StateDigest }
        let held = try JSONEncoder().encode(Holder(digest: digest))
        #expect(String(decoding: held, as: UTF8.self) == "{\"digest\":\"\(hex)\"}")
        #expect(try JSONDecoder().decode(Holder.self, from: held) == Holder(digest: digest))
    }

    @Test func decodingAMalformedTextIsDataCorrupted() {
        let hex = String(repeating: "0123456789abcdef", count: 4)
        let malformed = ["[\"\"]", "[\"abc\"]", "[\"\(hex.uppercased())\"]", "[\"\(hex)0\"]", "[\"\(hex.dropLast())g\"]"]
        for json in malformed {
            do {
                _ = try JSONDecoder().decode([StateDigest].self, from: Data(json.utf8))
                Issue.record("decoded \(json)")
            } catch DecodingError.dataCorrupted {
                // expected
            } catch {
                Issue.record("unexpected error \(error) for \(json)")
            }
        }
        // A value that is not a string is a decoding error too.
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([StateDigest].self, from: Data("[12]".utf8))
        }
    }
}
