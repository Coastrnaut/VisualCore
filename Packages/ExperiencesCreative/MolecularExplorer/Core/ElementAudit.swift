// ElementAudit — feature 110 (A15-P01) T-A15-102, T-A15-105, T-A15-109 (FR-A15-101, FR-A15-130; clarifications Q1,
// Q2; data-model "Element", "SourceRecord"; SC-A15-101). The provenance audit of Molecular Explorer's data.
//
// `problems(elements:sources:)` names each problem of an element catalog, one line each, in this order: per element in
// catalog order — "<symbol>: duplicate symbol" (the same symbol, ignoring case, as an earlier element), "<symbol>:
// duplicate atomic number <n>", "<symbol> covalent-radius: non-finite radius" or "… radius <r> outside 0.1…3.0 Å"
// (the same for `van-der-waals-radius`), "<symbol> color: malformed colour hex <hex>" (not exactly six hex digits);
// then per stored quantity in `ElementQuantity` order "no source record" or "duplicate source record", and per record
// "missing source" (an empty title or publisher), "wrong units <units>" (radii "Å", others ""), "unsupported license
// <license>"; finally, in record order, "<key> <quantity>: source record without a value" for a record naming no
// element's quantity. The allowed licenses are `public-domain`, `CC0-1.0` and `factual-data`.
//
// `problems(molecules:)` audits each molecule's structure record: "<id> structure: source key <key>" when the record's
// key is not the molecule id, "missing source", "wrong units <units>" (must be "Å"), "unsupported license <license>".
//
// `markdown()` is the text of `docs/apps/molecular-explorer/data-sources.md`, which a test compares with the bundled
// data: the title "# Molecular Explorer — data sources", a provenance note, "## Elements" (a table of the ten elements
// with atomic number, symbol, name, both radii in Å and the colour), "## Element sources" (one row per distinct source
// of a quantity, with the units, the elements it covers, title, publisher, link and license), "## Molecules" (one row
// per library molecule: title, PubChem CID, formula, atom and bond counts, source, units and license) and the closing
// line "N elements, M element source records, K molecules; X problems.". It is deterministic (no dates, radii with two
// decimals in the POSIX format), uses LF line endings and ends with a newline.
import Foundation

/// The provenance audit of the element catalog and the library's structure records.
public enum ElementAudit {
    /// The licenses a source record may carry.
    public static let allowedLicenses: [String] = ["public-domain", "CC0-1.0", "factual-data"]
    /// The radius range a sound element has, ångström (inclusive).
    public static let radiusRange = 0.1...3.0
    /// The document title.
    public static let title = "Molecular Explorer — data sources"

    /// The problems of `elements` and their `sources`, empty when sound (see the file header for the lines and their
    /// order).
    public static func problems(elements: [Element], sources: [SourceRecord]) -> [String] {
        var lines: [String] = []
        var seenSymbols: Set<String> = []
        var seenNumbers: Set<Int> = []
        var stored: Set<String> = []
        for element in elements {
            let symbol = element.symbol
            if !seenSymbols.insert(symbol.lowercased()).inserted { lines.append("\(symbol): duplicate symbol") }
            if !seenNumbers.insert(element.atomicNumber).inserted {
                lines.append("\(symbol): duplicate atomic number \(element.atomicNumber)")
            }
            lines += radiusProblems(element.covalentRadius).map { "\(symbol) covalent-radius: \($0)" }
            lines += radiusProblems(element.vanDerWaalsRadius).map { "\(symbol) van-der-waals-radius: \($0)" }
            if !isColorHex(element.colorHex) {
                let hex = element.colorHex.isEmpty ? "(none)" : element.colorHex
                lines.append("\(symbol) color: malformed colour hex \(hex)")
            }
            for quantity in ElementQuantity.allCases {
                let key = "\(symbol) \(quantity.rawValue)"
                stored.insert(key)
                let records = sources.filter { $0.key == symbol && $0.quantity == quantity.rawValue }
                if records.isEmpty { lines.append("\(key): no source record") }
                if records.count > 1 { lines.append("\(key): duplicate source record") }
                for record in records {
                    lines += recordProblems(record, units: quantity.units).map { "\(key): \($0)" }
                }
            }
        }
        for record in sources where !stored.contains("\(record.key) \(record.quantity)") {
            lines.append("\(record.key) \(record.quantity): source record without a value")
        }
        return lines
    }

    /// The problems of the bundled data: the catalog (``Elements/all``, ``Elements/sources``) and the library's
    /// structure records (``MoleculeLibrary/molecules``).
    public static func problems() -> [String] {
        problems(elements: Elements.all, sources: Elements.sources) + problems(molecules: MoleculeLibrary.molecules)
    }

    /// The problems of each molecule's structure record, empty when every record names its molecule, has a title and
    /// publisher, the units "Å" and an allowed license.
    public static func problems(molecules: [Molecule]) -> [String] {
        var lines: [String] = []
        for molecule in molecules {
            let key = "\(molecule.id) \(SourceRecord.structureQuantity)"
            if molecule.source.key != molecule.id { lines.append("\(key): source key \(molecule.source.key)") }
            lines += recordProblems(molecule.source, units: SourceRecord.angstrom).map { "\(key): \($0)" }
        }
        return lines
    }

    /// The problems of one radius: non-finite, or outside ``radiusRange``.
    static func radiusProblems(_ radius: Double) -> [String] {
        if !radius.isFinite { return ["non-finite radius"] }
        if !radiusRange.contains(radius) { return ["radius \(radius) outside 0.1…3.0 Å"] }
        return []
    }

    /// True when `hex` is exactly six hex digits (either case), without `#`.
    static func isColorHex(_ hex: String) -> Bool {
        let digits: ClosedRange<UInt32> = 0x30...0x39
        let upper: ClosedRange<UInt32> = 0x41...0x46
        let lower: ClosedRange<UInt32> = 0x61...0x66
        return hex.unicodeScalars.count == 6 && hex.unicodeScalars.allSatisfy { scalar in
            digits.contains(scalar.value) || upper.contains(scalar.value) || lower.contains(scalar.value)
        }
    }

    /// The problems of one record whose quantity has the units `units`, in the order of the file header.
    static func recordProblems(_ record: SourceRecord, units: String) -> [String] {
        var lines: [String] = []
        if blank(record.title) || blank(record.publisher) { lines.append("missing source") }
        if record.units != units { lines.append("wrong units \(blank(record.units) ? "(none)" : record.units)") }
        if !allowedLicenses.contains(record.license) {
            lines.append("unsupported license \(blank(record.license) ? "(none)" : record.license)")
        }
        return lines
    }

    /// True when `text` is empty or only white space.
    static func blank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A radius with two decimals in the POSIX format (`0.31`).
    static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// The text of `docs/apps/molecular-explorer/data-sources.md` for the bundled data (see the file header).
    public static func markdown() -> String {
        let elements = Elements.all
        let sources = Elements.sources
        let molecules = MoleculeLibrary.molecules
        var lines: [String] = [
            "# \(title)",
            "",
            "Generated by `ElementAudit.markdown()` from the element catalog (`Elements`) and the curated library "
                + "(`MoleculeLibrary`) of Molecular Explorer (feature 110, A15-P01). A test compares this file with "
                + "the data; regenerate it with `UPDATE_DATA_SOURCES=1` (or `TEST_RUNNER_UPDATE_DATA_SOURCES=1` "
                + "through xcodebuild). Every stored value has exactly one source record; the allowed licenses are "
                + allowedLicenses.map { "`\($0)`" }.joined(separator: ", ") + ".",
            "",
            "## Elements",
            "",
            "| Z | Symbol | Name | Covalent radius (Å) | van der Waals radius (Å) | Colour |",
            "|---:|---|---|---:|---:|---|",
        ]
        for element in elements {
            lines.append("| \(element.atomicNumber) | \(element.symbol) | \(element.name) | "
                         + "\(format(element.covalentRadius)) | \(format(element.vanDerWaalsRadius)) | "
                         + "`\(element.colorHex)` |")
        }
        lines += ["", "## Element sources", "",
                  "| Quantity | Units | Elements | Source | Publisher | Link | License |",
                  "|---|---|---|---|---|---|---|"]
        for group in sourceGroups(sources) {
            let units = group.record.units.isEmpty ? "—" : group.record.units
            lines.append("| \(group.record.quantity) | \(units) | \(group.symbols.joined(separator: ", ")) | "
                         + "\(group.record.title) | \(group.record.publisher) | \(group.record.link) | "
                         + "\(group.record.license) |")
        }
        lines += ["", "## Molecules", "",
                  "| Molecule | PubChem CID | Formula | Atoms | Bonds | Source | Publisher | Link | Units | License |",
                  "|---|---:|---|---:|---:|---|---|---|---|---|"]
        for molecule in molecules {
            let cid = MoleculeLibrary.pubChemCID(id: molecule.id).map { String($0) } ?? "—"
            let source = molecule.source
            lines.append("| \(molecule.title) | \(cid) | \(molecule.formula) | \(molecule.atoms.count) | "
                         + "\(molecule.bonds.count) | \(source.title) | \(source.publisher) | \(source.link) | "
                         + "\(source.units) | \(source.license) |")
        }
        let problemCount = problems(elements: elements, sources: sources).count
            + problems(molecules: molecules).count
        lines += ["", "\(elements.count) elements, \(sources.count) element source records, \(molecules.count) "
                  + "molecules; \(problemCount) problems."]
        return lines.joined(separator: "\n") + "\n"
    }

    /// One distinct source of a quantity and the element symbols whose value it covers.
    struct SourceGroup {
        /// A representative record (its key is the first symbol).
        let record: SourceRecord
        /// The symbols covered, in record order.
        var symbols: [String]
    }

    /// The records grouped by (quantity, units, title, publisher, link, license), in first-appearance order within
    /// ``ElementQuantity`` order.
    static func sourceGroups(_ sources: [SourceRecord]) -> [SourceGroup] {
        var groups: [SourceGroup] = []
        for quantity in ElementQuantity.allCases {
            for record in sources where record.quantity == quantity.rawValue {
                if let index = groups.firstIndex(where: { sameSource($0.record, record) }) {
                    groups[index].symbols.append(record.key)
                } else {
                    groups.append(SourceGroup(record: record, symbols: [record.key]))
                }
            }
        }
        return groups
    }

    /// True when two records cite the same source for the same quantity.
    static func sameSource(_ lhs: SourceRecord, _ rhs: SourceRecord) -> Bool {
        lhs.quantity == rhs.quantity && lhs.units == rhs.units && lhs.title == rhs.title
            && lhs.publisher == rhs.publisher && lhs.link == rhs.link && lhs.license == rhs.license
    }
}
