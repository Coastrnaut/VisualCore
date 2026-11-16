// XYZParserTests — feature 110 (A15-P01) T-A15-103 (FR-A15-120; clarification Q3; spec Edge Cases; SC-A15-102). The
// strict XYZ parser, host-free and short: valid fixtures parse exactly (atoms, normalised symbols, positions, comment);
// Windows line endings, trailing spaces, a missing final newline, trailing blank lines and a leading byte-order mark
// are accepted; extra columns are ignored; `cl` becomes `Cl`; the comment is cut to 256 characters; every one of the
// twelve refusal reasons is produced with its expected line; the limits are inclusive (500 atoms, 65,536 bytes, a
// 256-byte line, a 1,000 Å coordinate) and one more is refused.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct XYZParserTests {
    /// Water as a valid XYZ text with a final newline.
    private let water = "3\nwater test\nO 0.0000 0.0000 0.0000\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n"

    /// Water's expected atoms.
    private let waterAtoms: [Atom] = [Atom(symbol: "O", x: 0, y: 0, z: 0),
                                      Atom(symbol: "H", x: 0.2774, y: 0.8929, z: 0.2544),
                                      Atom(symbol: "H", x: 0.6068, y: -0.2383, z: -0.7169)]

    /// The refusal of `text`, or nil when it parsed.
    private func refusal(_ text: String) -> XYZRefusal? {
        refusal(Data(text.utf8))
    }

    /// The refusal of `data`, or nil when it parsed.
    private func refusal(_ data: Data) -> XYZRefusal? {
        if case .failure(let refusal) = XYZParser.parse(data) { return refusal }
        return nil
    }

    /// A single-hydrogen file whose atom line has the coordinate `x`.
    private func oneAtom(x: String) -> String {
        "1\nc\nH \(x) 0 0\n"
    }

    @Test func theLimitsAreTheClarifiedOnes() {
        #expect(XYZParser.maxBytes == 65_536 && XYZParser.maxAtoms == 500 && XYZParser.maxLineBytes == 256)
        #expect(XYZParser.maxCommentCharacters == 256 && XYZParser.maxCoordinate == 1_000 && XYZParser.minDistance == 0.4)
        #expect(XYZRefusal.Reason.allCases.map(\.rawValue)
                == ["empty", "too-large", "not-text", "bad-count", "too-many-atoms", "count-mismatch", "line-too-long",
                    "malformed-line", "unknown-element", "non-finite", "out-of-range", "overlapping-atoms"])
    }

    @Test func aValidFileParsesExactly() {
        #expect(XYZParser.parse(Data(water.utf8)) == .success(ParsedXYZ(comment: "water test", atoms: waterAtoms)))
        #expect(XYZParser.parse(water) == .success(ParsedXYZ(comment: "water test", atoms: waterAtoms)))
        let single = "1\n\nI 1.5 -2.25 3e2\n"
        #expect(XYZParser.parse(single)
                == .success(ParsedXYZ(comment: "", atoms: [Atom(symbol: "I", x: 1.5, y: -2.25, z: 300)])))
    }

    @Test func lineEndingsSpacesFinalNewlineAndByteOrderMarkAreAccepted() {
        let expected = XYZParser.parse(water)
        let windows = "3\r\nwater test\r\nO 0.0000 0.0000 0.0000  \r\nH 0.2774 0.8929 0.2544\t\r\n"
            + "H 0.6068 -0.2383 -0.7169"
        #expect(XYZParser.parse(windows) == expected)
        let noFinalNewline = String(water.dropLast())
        #expect(XYZParser.parse(noFinalNewline) == expected)
        #expect(XYZParser.parse(water + "\n\n   \n\t\n") == expected, "trailing blank lines are ignored")
        let marked = Data([0xEF, 0xBB, 0xBF]) + Data(water.utf8)
        #expect(XYZParser.parse(marked) == expected)
        let spaced = "  3  \nwater test\n  O   0.0000\t0.0000 0.0000\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n"
        #expect(XYZParser.parse(spaced) == expected)
    }

    @Test func extraColumnsAreIgnoredAndSymbolsNormalised() {
        #expect(XYZParser.parse("1\nc\nH 1 2 3 0.5 charge\n")
                == .success(ParsedXYZ(comment: "c", atoms: [Atom(symbol: "H", x: 1, y: 2, z: 3)])))
        #expect(XYZParser.parse("2\nc\ncl 0 0 0\nBR 2 0 0\n")
                == .success(ParsedXYZ(comment: "c", atoms: [Atom(symbol: "Cl", x: 0, y: 0, z: 0),
                                                            Atom(symbol: "Br", x: 2, y: 0, z: 0)])))
    }

    @Test func theCommentIsCutTo256Characters() throws {
        let long = String(repeating: "a", count: 300)
        let parsed = try XYZParser.parse("1\n\(long)\nH 0 0 0\n").get()
        #expect(parsed.comment == String(repeating: "a", count: 256))
        let wide = String(repeating: "é", count: 300)
        let accented = try XYZParser.parse("1\n\(wide)\nH 0 0 0\n").get()
        #expect(accented.comment.count == 256 && accented.comment == String(repeating: "é", count: 256))
        let exact = String(repeating: "b", count: 256)
        #expect(try XYZParser.parse("1\n\(exact)\nH 0 0 0\n").get().comment == exact)
    }

    @Test func emptyTooLargeAndNotTextHaveNoLine() {
        #expect(refusal(Data()) == XYZRefusal(.empty))
        #expect(refusal(Data([0xEF, 0xBB, 0xBF])) == XYZRefusal(.empty))
        #expect(refusal(Data(repeating: 0x0A, count: 65_537)) == XYZRefusal(.tooLarge))
        #expect(refusal(Data(repeating: 0xFF, count: 65_537)) == XYZRefusal(.tooLarge), "size before decoding")
        #expect(refusal(Data([0x31, 0x0A, 0x63, 0x0A, 0x48, 0xFF, 0x0A])) == XYZRefusal(.notText))
        #expect(refusal(Data([0x31, 0x0A, 0xC3, 0x28, 0x0A])) == XYZRefusal(.notText))
        #expect(refusal(Data([0x31, 0x0A, 0xED, 0xA0, 0x80, 0x0A])) == XYZRefusal(.notText), "a surrogate")
    }

    @Test func badAndExcessiveCountsAreRefusedOnLineOne() {
        let bad: [String] = ["", " ", "-3", "0", "00", "2.5", "1.0", "three", "+1", "1 atom", "0x1", "١"]
        for count in bad {
            #expect(refusal("\(count)\nc\nH 0 0 0\n") == XYZRefusal(.badCount, line: 1), "count \(count)")
        }
        let excessive: [String] = ["501", "1000", "99999999999999999999999999"]
        for count in excessive {
            #expect(refusal("\(count)\nc\nH 0 0 0\n") == XYZRefusal(.tooManyAtoms, line: 1), "count \(count)")
        }
        #expect(refusal("01\nc\nH 0 0 0\n") == nil, "leading zeros are a whole number")
    }

    @Test func countMismatchIsRefusedNeverTruncatedOrPadded() {
        #expect(refusal("2\nc\nH 0 0 0\n") == XYZRefusal(.countMismatch, line: 1))
        #expect(refusal("1\nc\nH 0 0 0\nH 1 0 0\n") == XYZRefusal(.countMismatch, line: 1))
        #expect(refusal("1\n") == XYZRefusal(.countMismatch, line: 1))
        #expect(refusal("1") == XYZRefusal(.countMismatch, line: 1))
    }

    @Test func eachAtomLineRefusalNamesItsLine() {
        #expect(refusal("1\nc\nH 0 0\n") == XYZRefusal(.malformedLine, line: 3))
        #expect(refusal("1\nc\nH\n") == XYZRefusal(.malformedLine, line: 3))
        #expect(refusal("2\nc\nH 0 0 0\n\nH 1 1 1\n") == XYZRefusal(.malformedLine, line: 4), "a blank atom line")
        let malformed: [String] = ["abc", "0x10", "1,5", "1e", "--1", "∞"]
        for value in malformed {
            #expect(refusal(oneAtom(x: value)) == XYZRefusal(.malformedLine, line: 3), "\(value)")
        }
        #expect(refusal("2\nc\nH 0 0 0\nXx 1 1 1\n") == XYZRefusal(.unknownElement, line: 4))
        #expect(refusal("1\nc\nHe 0 0 0\n") == XYZRefusal(.unknownElement, line: 3))
        let nonFinite: [String] = ["nan", "NaN", "-nan", "inf", "-inf", "+INF", "Infinity", "-infinity"]
        for value in nonFinite {
            #expect(refusal(oneAtom(x: value)) == XYZRefusal(.nonFinite, line: 3), "\(value)")
        }
        let outOfRange: [String] = ["1000.001", "-1000.5", "1e4", "1e400"]
        for value in outOfRange {
            #expect(refusal(oneAtom(x: value)) == XYZRefusal(.outOfRange, line: 3), "\(value)")
        }
        #expect(refusal("1\nc\nH 0 0 1e-3 nan\n") == nil, "an extra column is never read")
        #expect(refusal("3\nc\nH 0 0 0\nH 2 0 0\nH 2.1 0 0\n") == XYZRefusal(.overlappingAtoms, line: 5))
        #expect(refusal("2\nc\nH 0 0 0\nH 0 0 0\n") == XYZRefusal(.overlappingAtoms, line: 4))
        #expect(refusal("2\nc\nH 0 0 0\nH 0.4 0 0\n") == nil, "0.4 Å is inside the limit")
        #expect(XYZRefusal(.nonFinite, line: 4).description == "non-finite on line 4")
        #expect(XYZRefusal(.tooLarge).description == "too-large")
    }

    @Test func theLineLimitIsInclusive() {
        let atomLine = "H 0 0 0"
        let fits = atomLine + String(repeating: " ", count: 256 - atomLine.utf8.count)
        #expect(fits.utf8.count == 256)
        #expect(refusal("1\nc\n\(fits)\n") == nil)
        #expect(refusal("1\nc\n\(fits) \n") == XYZRefusal(.lineTooLong, line: 3))
        #expect(refusal("1\nc\n\(fits)\r\n") == nil, "the line ending is not counted")
        let countLine = "1" + String(repeating: " ", count: 256)
        #expect(refusal("\(countLine)\nc\nH 0 0 0\n") == XYZRefusal(.lineTooLong, line: 1))
        #expect(refusal("1\n\(String(repeating: "x", count: 1_000))\nH 0 0 0\n") == nil, "the comment is cut")
    }

    @Test func theSizeLimitIsInclusive() {
        let base = "1\nc\nH 0 0 0\n"
        let padding = String(repeating: "\n", count: XYZParser.maxBytes - base.utf8.count)
        let fits = Data((base + padding).utf8)
        #expect(fits.count == 65_536)
        #expect(refusal(fits) == nil)
        #expect(refusal(fits + Data([0x0A])) == XYZRefusal(.tooLarge))
    }

    @Test func theAtomLimitIsInclusive() throws {
        var lines: [String] = ["500", "grid"]
        for index in 0..<500 {
            lines.append("H \(index % 10) \((index / 10) % 10) \(index / 100)")
        }
        let parsed = try XYZParser.parse(lines.joined(separator: "\n")).get()
        #expect(parsed.atoms.count == 500 && parsed.atoms[499] == Atom(symbol: "H", x: 9, y: 9, z: 4))
        lines[0] = "501"
        lines.append("H 0 0 5")
        #expect(refusal(lines.joined(separator: "\n")) == XYZRefusal(.tooManyAtoms, line: 1))
    }

    @Test func theCoordinateLimitIsInclusive() {
        #expect(XYZParser.parse("1\nc\nH 1000 -1000 1000.000\n")
                == .success(ParsedXYZ(comment: "c", atoms: [Atom(symbol: "H", x: 1_000, y: -1_000, z: 1_000)])))
        #expect(refusal(oneAtom(x: "1000.001")) == XYZRefusal(.outOfRange, line: 3))
        #expect(refusal(oneAtom(x: "-1000.001")) == XYZRefusal(.outOfRange, line: 3))
    }
}
