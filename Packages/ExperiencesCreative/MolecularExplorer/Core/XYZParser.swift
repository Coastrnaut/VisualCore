// XYZParser — feature 110 (A15-P01) T-A15-103 (FR-A15-120, FR-A15-121; clarification Q3; data-model "XYZRefusal";
// contracts/domain.md; research D3; SC-A15-102). The strict, bounded XYZ parser of Molecular Explorer: an atom count on
// the first line, a comment on the second, then one atom per line (symbol and x y z in ångström). It never throws and
// never traps; every input either becomes a `ParsedXYZ` or is refused with an `XYZRefusal` (a reason and, where one
// applies, the 1-based line), producing nothing.
//
// Limits (all inclusive): at most 65,536 bytes; an atom count 1…500; each line at most 256 bytes (the count line and
// the atom lines, measured without the line ending); the comment cut to 256 characters (the comment line is plain text,
// never refused and never interpreted); every coordinate finite with magnitude at most 1,000 Å; no two atoms closer
// than 0.4 Å.
//
// The checks, in order:
// 1. `empty` (no bytes, or only a byte-order mark), then `too-large` (more than 65,536 bytes) before any decoding;
// 2. a leading UTF-8 byte-order mark is dropped; `not-text` when the rest is not valid UTF-8;
// 3. the text is split on "\n" with one trailing "\r" stripped per line (Windows line endings); blank lines (spaces
//    and tabs only) after the last non-blank line are ignored, so a missing or doubled final newline is accepted;
// 4. line 1: `line-too-long`, then the count, trimmed of spaces and tabs, must be ASCII digits only — missing, negative,
//    zero, fractional or non-numeric is `bad-count`; a whole number above 500 is `too-many-atoms`;
// 5. line 2 is the comment (absent → ""), cut to 256 characters;
// 6. every following line, in order: `line-too-long`; fewer than four fields (separated by spaces or tabs) is
//    `malformed-line` (extra columns, such as charges, are ignored); a symbol outside `Elements` (matched
//    case-insensitively and stored normalised, `cl` → `Cl`) is `unknown-element`; then x, y, z in order: `nan`, `inf`
//    or `infinity` (any case or sign) is `non-finite`, a token that is not a decimal number is `malformed-line`, a
//    magnitude above 1,000 (or a decimal that overflows) is `out-of-range`;
// 7. `count-mismatch` (line 1) when the number of atom lines differs from the count — never truncated or padded;
// 8. `overlapping-atoms` when two atoms are closer than 0.4 Å, naming the line of the later atom.
import Foundation

/// Why an XYZ text was refused, with the 1-based line where one applies.
public struct XYZRefusal: Error, Equatable, Sendable, CustomStringConvertible {
    /// The refusal reasons of clarification Q3.
    public enum Reason: String, CaseIterable, Codable, Error, Sendable {
        /// No bytes.
        case empty = "empty"
        /// More than ``XYZParser/maxBytes`` bytes.
        case tooLarge = "too-large"
        /// Not valid UTF-8.
        case notText = "not-text"
        /// A missing, negative, zero, fractional or non-numeric atom count.
        case badCount = "bad-count"
        /// An atom count above ``XYZParser/maxAtoms``.
        case tooManyAtoms = "too-many-atoms"
        /// The number of atom lines differs from the count.
        case countMismatch = "count-mismatch"
        /// A line longer than ``XYZParser/maxLineBytes`` bytes.
        case lineTooLong = "line-too-long"
        /// An atom line without a symbol and three decimal coordinates.
        case malformedLine = "malformed-line"
        /// A symbol outside the element catalog.
        case unknownElement = "unknown-element"
        /// A NaN or infinite coordinate.
        case nonFinite = "non-finite"
        /// A coordinate magnitude above ``XYZParser/maxCoordinate``.
        case outOfRange = "out-of-range"
        /// Two atoms closer than ``XYZParser/minDistance``.
        case overlappingAtoms = "overlapping-atoms"
    }

    /// The reason.
    public let reason: Reason
    /// The 1-based line where the reason applies, nil for `empty`, `too-large` and `not-text`.
    public let line: Int?

    /// Creates a refusal.
    public init(_ reason: Reason, line: Int? = nil) {
        self.reason = reason; self.line = line
    }

    /// The reason's raw value, followed by the line when there is one (`non-finite on line 4`).
    public var description: String {
        line.map { "\(reason.rawValue) on line \($0)" } ?? reason.rawValue
    }
}

/// A parsed XYZ text: the comment (untrusted plain text) and the atoms in order, symbols normalised.
public struct ParsedXYZ: Equatable, Sendable {
    /// The comment line, cut to ``XYZParser/maxCommentCharacters`` characters.
    public let comment: String
    /// The atoms in file order, positions in ångström.
    public let atoms: [Atom]

    /// Creates a parse result.
    public init(comment: String, atoms: [Atom]) {
        self.comment = comment; self.atoms = atoms
    }
}

/// The strict XYZ parser (see the file header for the limits and the order of the checks).
public enum XYZParser {
    /// The most bytes an input may have.
    public static let maxBytes = 65_536
    /// The largest atom count.
    public static let maxAtoms = 500
    /// The most bytes of a count or atom line, without its line ending.
    public static let maxLineBytes = 256
    /// The most characters of the comment kept.
    public static let maxCommentCharacters = 256
    /// The largest coordinate magnitude, ångström.
    public static let maxCoordinate = 1_000.0
    /// The smallest distance between two atoms, ångström.
    public static let minDistance = 0.4

    /// The UTF-8 byte-order mark.
    static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// The atoms of `data`, or the first refusal in the order of the file header.
    public static func parse(_ data: Data) -> Result<ParsedXYZ, XYZRefusal> {
        if data.isEmpty { return .failure(XYZRefusal(.empty)) }
        if data.count > maxBytes { return .failure(XYZRefusal(.tooLarge)) }
        var bytes = [UInt8](data)
        if bytes.starts(with: byteOrderMark) { bytes.removeFirst(byteOrderMark.count) }
        if bytes.isEmpty { return .failure(XYZRefusal(.empty)) }
        guard isValidUTF8(bytes) else { return .failure(XYZRefusal(.notText)) }

        var lines = splitLines(bytes)
        while lines.count > 1, let last = lines.last, isBlank(last) { lines.removeLast() }

        guard lines[0].count <= maxLineBytes else { return .failure(XYZRefusal(.lineTooLong, line: 1)) }
        let count: Int
        switch atomCount(text(lines[0])) {
        case .success(let value): count = value
        case .failure(let reason): return .failure(XYZRefusal(reason, line: 1))
        }

        let comment = lines.count > 1 ? String(text(lines[1]).prefix(maxCommentCharacters)) : ""

        var atoms: [Atom] = []
        atoms.reserveCapacity(count)
        var index = 2
        while index < lines.count {
            let lineNumber = index + 1
            guard lines[index].count <= maxLineBytes else {
                return .failure(XYZRefusal(.lineTooLong, line: lineNumber))
            }
            switch atom(text(lines[index])) {
            case .success(let atom): atoms.append(atom)
            case .failure(let reason): return .failure(XYZRefusal(reason, line: lineNumber))
            }
            index += 1
        }

        guard atoms.count == count else { return .failure(XYZRefusal(.countMismatch, line: 1)) }
        if let later = Molecule.firstOverlap(atoms) {
            return .failure(XYZRefusal(.overlappingAtoms, line: later + 3))
        }
        return .success(ParsedXYZ(comment: comment, atoms: atoms))
    }

    /// The parse of `text` (UTF-8), for callers holding a string.
    public static func parse(_ text: String) -> Result<ParsedXYZ, XYZRefusal> {
        parse(Data(text.utf8))
    }

    /// True when `bytes` is valid UTF-8 (no ill-formed, overlong or surrogate sequences).
    static func isValidUTF8(_ bytes: [UInt8]) -> Bool {
        let failed = transcode(bytes.makeIterator(), from: UTF8.self, to: UTF32.self, stoppingOnError: true) { _ in }
        return !failed
    }

    /// The lines of `bytes` split on "\n", each without one trailing "\r".
    static func splitLines(_ bytes: [UInt8]) -> [[UInt8]] {
        var lines: [[UInt8]] = []
        for slice in bytes.split(separator: 0x0A, omittingEmptySubsequences: false) {
            var line = Array(slice)
            if line.last == 0x0D { line.removeLast() }
            lines.append(line)
        }
        return lines
    }

    /// True when `line` holds only spaces and tabs.
    static func isBlank(_ line: [UInt8]) -> Bool {
        line.allSatisfy { $0 == 0x20 || $0 == 0x09 }
    }

    /// The UTF-8 text of one line (already validated, so nothing is replaced).
    static func text(_ line: [UInt8]) -> String {
        String(decoding: line, as: UTF8.self)
    }

    /// True for a field separator (space or tab).
    static func isSeparator(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    /// The atom count of the count line: ASCII digits only after trimming spaces and tabs, 1…500.
    static func atomCount(_ line: String) -> Result<Int, XYZRefusal.Reason> {
        let fields = line.split(whereSeparator: isSeparator)
        guard fields.count == 1, let field = fields.first else { return .failure(.badCount) }
        guard field.unicodeScalars.allSatisfy({ $0.value >= 0x30 && $0.value <= 0x39 }) else {
            return .failure(.badCount)
        }
        guard let count = Int(field) else { return .failure(.tooManyAtoms) }   // all digits, beyond Int
        if count == 0 { return .failure(.badCount) }
        if count > maxAtoms { return .failure(.tooManyAtoms) }
        return .success(count)
    }

    /// One atom line: a symbol and three coordinates, extra columns ignored.
    static func atom(_ line: String) -> Result<Atom, XYZRefusal.Reason> {
        let fields = line.split(whereSeparator: isSeparator)
        guard fields.count >= 4 else { return .failure(.malformedLine) }
        guard let element = Elements.element(symbol: String(fields[0])) else { return .failure(.unknownElement) }
        var values: [Double] = []
        for field in fields[1...3] {
            switch coordinate(field) {
            case .success(let value): values.append(value)
            case .failure(let reason): return .failure(reason)
            }
        }
        return .success(Atom(symbol: element.symbol, x: values[0], y: values[1], z: values[2]))
    }

    /// The characters a decimal coordinate may contain.
    static let decimalScalars = Set("0123456789+-.eE".unicodeScalars)

    /// One coordinate: `nan`/`inf`/`infinity` (any case or sign) is non-finite; anything but a decimal number is
    /// malformed; a magnitude above 1,000 Å, or a decimal that overflows a `Double`, is out of range.
    static func coordinate(_ field: Substring) -> Result<Double, XYZRefusal.Reason> {
        var word = field.lowercased()
        if word.hasPrefix("+") || word.hasPrefix("-") { word.removeFirst() }
        if word == "inf" || word == "infinity" || word.hasPrefix("nan") || word.hasPrefix("snan") {
            return .failure(.nonFinite)
        }
        guard field.unicodeScalars.allSatisfy({ decimalScalars.contains($0) }), let value = Double(field) else {
            return .failure(.malformedLine)
        }
        guard value.isFinite, abs(value) <= maxCoordinate else { return .failure(.outOfRange) }
        return .success(value)
    }
}
