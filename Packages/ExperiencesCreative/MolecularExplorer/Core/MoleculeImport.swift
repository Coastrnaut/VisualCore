// MoleculeImport — feature 114 (A15-P05) T-A15-503 (FR-A15-502, FR-A15-503; clarifications Q1, Q2, Q3; data-model
// "ImportRefusal", "Stored import"; contracts/import.md; SC-A15-502). The words and actions of an XYZ import, host-free:
// - the size check before reading: above 65,536 bytes (`XYZParser.maxBytes`) the file is refused with "This file is
//   larger than 64 KB, the limit for a molecule file.";
// - one sentence per parser refusal: "This file could not be opened: <reason>." with " (line N)" before the period
//   where the refusal names a line, and one fixed reason phrase per `XYZRefusal.Reason`;
// - "The file could not be read." for a file that cannot be read;
// - the title from the file name: the extension (from the last ".") dropped, only letters, digits, spaces and
//   `-_.()` kept, trimmed, cut to 40 characters and trimmed again; "Imported molecule" when nothing is left (the comment
//   line of the file is never a title);
// - the engine actions of a parsed file: `import.begin [n]`, one `import.atom [Z, x, y, z]` per atom in file order,
//   `import.end []` and `molecule.select [5]`.
import Foundation

/// The words and engine actions of importing an XYZ file.
public enum MoleculeImport {
    /// The largest file accepted, bytes (65,536, the parser's limit).
    public static let maxBytes = XYZParser.maxBytes
    /// The most characters of a title.
    public static let titleLimit = 40
    /// The title when the file name leaves nothing.
    public static let fallbackTitle = "Imported molecule"
    /// The sentence of a file larger than ``maxBytes``.
    public static let tooLargeSentence = "This file is larger than 64 KB, the limit for a molecule file."
    /// The sentence of a file that cannot be read (no access, removed meanwhile).
    public static let unreadableSentence = "The file could not be read."
    /// The punctuation a title keeps besides letters, digits and spaces.
    static let titlePunctuation: Set<Character> = ["-", "_", ".", "(", ")"]

    /// The size refusal of a file of `byteCount` bytes: ``tooLargeSentence`` above ``maxBytes``, nil otherwise.
    public static func sizeRefusal(byteCount: Int) -> String? {
        byteCount > maxBytes ? tooLargeSentence : nil
    }

    /// The fixed phrase of a parser reason ("two atoms closer than 0.4 Å").
    public static func phrase(_ reason: XYZRefusal.Reason) -> String {
        switch reason {
        case .empty: return "the file is empty"
        case .tooLarge: return "the file is larger than 64 KB"
        case .notText: return "the file is not plain text"
        case .badCount: return "the first line is not a whole atom count"
        case .tooManyAtoms: return "more atoms than this explorer can show (at most 500)"
        case .countMismatch: return "the number of atom lines differs from the atom count"
        case .lineTooLong: return "a line longer than 256 bytes"
        case .malformedLine: return "a line that is not an element and three coordinates"
        case .unknownElement: return "an element this explorer does not know"
        case .nonFinite: return "a coordinate that is not a number"
        case .outOfRange: return "a coordinate beyond 1,000 Å"
        case .overlappingAtoms: return "two atoms closer than 0.4 Å"
        }
    }

    /// The sentence of a parser refusal: "This file could not be opened: <phrase> (line N)." (without the line part
    /// when the refusal names no line).
    public static func sentence(_ refusal: XYZRefusal) -> String {
        let line = refusal.line.map { " (line \($0))" } ?? ""
        return "This file could not be opened: \(phrase(refusal.reason))\(line)."
    }

    /// The title of the file named `fileName` (see the file header); never empty, at most ``titleLimit`` characters.
    public static func title(fileName: String) -> String {
        var base = Substring(fileName)
        if let dot = base.lastIndex(of: ".") { base = base[base.startIndex..<dot] }
        var kept = ""
        for character in base where isTitleCharacter(character) { kept.append(character) }
        let cut = String(trimmed(kept).prefix(titleLimit))
        let title = trimmed(cut)
        return title.isEmpty ? fallbackTitle : title
    }

    /// True for a letter, a digit, a space or one of `-_.()`.
    static func isTitleCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isWholeNumber || character == " " || titlePunctuation.contains(character)
    }

    /// `text` without leading and trailing spaces.
    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: " "))
    }

    /// The engine actions of `parsed`: `import.begin [n]`, `import.atom [Z, x, y, z]` per atom in file order,
    /// `import.end []`, then `molecule.select [5]`. An atom outside the catalog (never in a parse result) gets Z 0,
    /// which the engine refuses.
    public static func actions(_ parsed: ParsedXYZ) -> [(control: String, values: [Double])] {
        var list: [(control: String, values: [Double])] = []
        list.reserveCapacity(parsed.atoms.count + 3)
        list.append((control: "import.begin", values: [Double(parsed.atoms.count)]))
        for atom in parsed.atoms {
            let number = Elements.element(symbol: atom.symbol)?.atomicNumber ?? 0
            list.append((control: "import.atom", values: [Double(number), atom.x, atom.y, atom.z]))
        }
        list.append((control: "import.end", values: []))
        list.append((control: "molecule.select", values: [Double(MoleculeState.importedSelection)]))
        return list
    }
}
