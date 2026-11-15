// CitationAudit — feature 103 (A14-P01) T-A14-102 (FR-A14-110; clarification Q1; research "citation audit";
// SC-A14-103; contract row M20). The citation audit of the Solar System Explorer catalog: every stored value must have
// exactly one source record with a source (title, publisher, link text), an epoch, the units of its quantity and an
// allowed license (["public-domain", "CC0-1.0"]); a record must name a value the catalog stores. `problems(_:)` names
// each problem with the body id and the quantity, one line each, in this order: first the stored values in catalog
// and quantity order (per value: "no source record" or "duplicate source record", then per record "missing source",
// "missing epoch", "missing units", "wrong units <units>", "unsupported license <license>"), then the records that
// name no stored value in record order ("source record without a value").
//
// `markdown(_:)` is the text of `docs/apps/solar-system-explorer/data-sources.md`, which a test compares with the
// bundled catalog: the title "# Solar System Explorer — data sources", a provenance note, a table
// `Body | Quantity | Value | Units | Source | Epoch | License` with one row per stored value (the value exactly as
// stored, grouped by thousands), and the closing line "N values; X problems.". It is deterministic (no dates), uses LF
// line endings and ends with a newline, so regenerating it from an unchanged catalog gives the same bytes.
//
// Feature 104 (A14-P02) T-A14-205 (FR-A14-210): `elementProblems(_:sources:)` audits the orbital elements the same way
// (each element set has exactly one complete `orbital-elements` record with units "AU, degrees" and an allowed
// license; each record names an element set), and `markdown` adds the section "## Orbital elements" (a table
// `Body | a (AU) | e | i (deg) | L (deg) | ϖ (deg) | Ω (deg) | Source | Epoch | License`) before the closing line, whose
// problem count includes the element problems.
import Foundation

/// The citation audit of a body catalog.
public enum CitationAudit {
    /// The licenses a source record may carry.
    public static let allowedLicenses: [String] = ["public-domain", "CC0-1.0"]
    /// The document title.
    public static let title = "Solar System Explorer — data sources"

    /// The audit's problems, empty when every stored value has exactly one complete record with an allowed license and
    /// every record names a stored value; one line per problem, such as "earth mean-radius: no source record" or
    /// "mars axial-tilt: unsupported license CC-BY-4.0" (see the file header for the order).
    public static func problems(_ catalog: BodyCatalog) -> [String] {
        var lines: [String] = []
        var stored: Set<String> = []
        for body in catalog.bodies {
            for quantity in body.storedQuantities {
                let key = "\(body.id) \(quantity.rawValue)"
                stored.insert(key)
                let records = catalog.sources.filter { $0.bodyID == body.id && $0.quantity == quantity.rawValue }
                if records.isEmpty { lines.append("\(key): no source record") }
                if records.count > 1 { lines.append("\(key): duplicate source record") }
                for record in records {
                    lines += recordProblems(record, quantity: quantity).map { "\(key): \($0)" }
                }
            }
        }
        for record in catalog.sources where !stored.contains("\(record.bodyID) \(record.quantity)") {
            lines.append("\(record.bodyID) \(record.quantity): source record without a value")
        }
        return lines
    }

    /// The problems of one record of a stored `quantity`, in the order of the file header.
    private static func recordProblems(_ record: SourceRecord, quantity: BodyQuantity) -> [String] {
        var lines: [String] = []
        if blank(record.title) || blank(record.publisher) || blank(record.link) { lines.append("missing source") }
        if blank(record.epoch) { lines.append("missing epoch") }
        if blank(record.units) {
            lines.append("missing units")
        } else if record.units != quantity.units {
            lines.append("wrong units \(record.units)")
        }
        if !allowedLicenses.contains(record.license) {
            lines.append("unsupported license \(blank(record.license) ? "(none)" : record.license)")
        }
        return lines
    }

    /// The orbital elements' audit problems, empty when every element set has exactly one complete record with the
    /// units "AU, degrees" and an allowed license and every record names an element set; one line per problem, such
    /// as "mars orbital-elements: no source record" (element order, then the records without an element set).
    public static func elementProblems(_ elements: [OrbitElements],
                                       sources: [SourceRecord] = SourceRecord.orbitalElements) -> [String] {
        let quantity = SourceRecord.orbitalElementsQuantity
        var lines: [String] = []
        for element in elements {
            let key = "\(element.bodyID) \(quantity)"
            let records = sources.filter { $0.bodyID == element.bodyID && $0.quantity == quantity }
            if records.isEmpty { lines.append("\(key): no source record") }
            if records.count > 1 { lines.append("\(key): duplicate source record") }
            for record in records {
                if blank(record.title) || blank(record.publisher) || blank(record.link) {
                    lines.append("\(key): missing source")
                }
                if blank(record.epoch) { lines.append("\(key): missing epoch") }
                if blank(record.units) {
                    lines.append("\(key): missing units")
                } else if record.units != SourceRecord.orbitalElementsUnits {
                    lines.append("\(key): wrong units \(record.units)")
                }
                if !allowedLicenses.contains(record.license) {
                    lines.append("\(key): unsupported license \(record.license)")
                }
            }
        }
        let ids = Set(elements.map(\.bodyID))
        for record in sources where record.quantity != quantity || !ids.contains(record.bodyID) {
            lines.append("\(record.bodyID) \(record.quantity): source record without an element set")
        }
        return lines
    }

    /// True when `text` is empty or only white space.
    private static func blank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The Markdown document (see the file header).
    public static func markdown(_ catalog: BodyCatalog, elements: [OrbitElements] = OrbitElements.bundled,
                                elementSources: [SourceRecord] = SourceRecord.orbitalElements) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Every number Solar System Explorer shows comes from this table. It is generated from "
                + "`BodyCatalog.bundled` by `CitationAudit.markdown(_:)`, and a test checks that it matches it. "
                + "Distances are stored in kilometres and times in days; astronomical units are derived through 1 AU = "
                + "\(Units.storedText(Units.kmPerAU)) km and years through "
                + "\(Units.storedText(Units.daysPerJulianYear)) days per Julian year, never stored. Axial tilts above "
                + "90 degrees mean retrograde rotation. Allowed "
                + "licenses: \(allowedLicenses.joined(separator: ", ")).",
            "",
            "| Body | Quantity | Value | Units | Source | Epoch | License |",
            "|---|---|---|---|---|---|---|",
        ]
        var count = 0
        for body in catalog.bodies {
            for quantity in body.storedQuantities {
                guard let value = body.value(of: quantity) else { continue }
                count += 1
                let record = catalog.source(bodyID: body.id, quantity: quantity)
                let source = record.map { "\($0.title), \($0.publisher) (\($0.link))" } ?? ""
                let cells: [String] = [body.name, quantity.rawValue, Units.storedText(value), record?.units ?? "",
                                       source, record?.epoch ?? "", record?.license ?? ""]
                lines.append("| " + cells.map(cell).joined(separator: " | ") + " |")
            }
        }
        if !elements.isEmpty {
            lines += [
                "",
                "## Orbital elements",
                "",
                "Mean elements at epoch J2000.0, held fixed (no secular rates): positions are approximate and valid "
                    + "only as a labelled model. The argument of perihelion is ϖ − Ω and the mean anomaly at epoch "
                    + "L − ϖ; the mean motion is 2π divided by the catalog's sidereal period.",
                "",
                "| Body | a (AU) | e | i (deg) | L (deg) | ϖ (deg) | Ω (deg) | Source | Epoch | License |",
                "|---|---|---|---|---|---|---|---|---|---|",
            ]
            for element in elements {
                let record = elementSources.first {
                    $0.bodyID == element.bodyID && $0.quantity == SourceRecord.orbitalElementsQuantity
                }
                let name = catalog.bodies.first { $0.id == element.bodyID }?.name ?? element.bodyID
                let source = record.map { "\($0.title), \($0.publisher) (\($0.link))" } ?? ""
                let numbers: [Double] = [element.semiMajorAxisAU, element.eccentricity, element.inclinationDeg,
                                         element.meanLongitudeDeg, element.perihelionLongitudeDeg,
                                         element.ascendingNodeDeg]
                var cells: [String] = [name]
                for number in numbers { cells.append("\(number)") }
                cells += [source, record?.epoch ?? "", record?.license ?? ""]
                lines.append("| " + cells.map(cell).joined(separator: " | ") + " |")
            }
        }
        let problemCount = problems(catalog).count
            + (elements.isEmpty ? 0 : elementProblems(elements, sources: elementSources).count)
        lines.append("")
        lines.append("\(count) value\(count == 1 ? "" : "s"); \(problemCount) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell: `|` escaped, line breaks replaced by spaces, "—" when empty.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
