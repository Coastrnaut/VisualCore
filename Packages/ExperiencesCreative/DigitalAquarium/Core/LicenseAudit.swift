// LicenseAudit — feature 068 (A09-P01) T-A09-102 (FR-A09-104; clarification 3; SC-A09-103). The content license audit:
// one row per catalog item (species, then plants, then habitats, each in catalog order) with its kind, id, name, author
// and license; the problems (a missing author or license, or a license outside the allowed list); and the Markdown text
// of `docs/apps/digital-aquarium/content-licenses.md`, which a test compares with the bundled catalog. The text is
// deterministic (no dates), so regenerating it from an unchanged catalog gives the same bytes.
import Foundation

/// One audited catalog item.
public struct LicenseRow: Codable, Equatable, Sendable {
    /// The item kind (`species`, `plant` or `habitat`).
    public var kind: CatalogItemKind
    /// The item id.
    public var id: String
    /// The item's display name.
    public var name: String
    /// The item's author.
    public var author: String
    /// The item's license.
    public var license: String

    /// Creates an audit row.
    public init(kind: CatalogItemKind, id: String, name: String, author: String, license: String) {
        self.kind = kind; self.id = id; self.name = name; self.author = author; self.license = license
    }
}

/// The content license audit of a species catalog.
public enum LicenseAudit {
    /// The document title.
    public static let title = "Digital Aquarium — content licenses"

    /// One row per item: species, then plants, then habitats, each in catalog order.
    public static func rows(_ catalog: SpeciesCatalog) -> [LicenseRow] {
        catalog.species.map { LicenseRow(kind: .species, id: $0.id, name: $0.name, author: $0.author,
                                         license: $0.license) }
            + catalog.plants.map { LicenseRow(kind: .plant, id: $0.id, name: $0.name, author: $0.author,
                                              license: $0.license) }
            + catalog.habitats.map { LicenseRow(kind: .habitat, id: $0.id, name: $0.name, author: $0.author,
                                                license: $0.license) }
    }

    /// The audit's problems, empty when every item has an author and an allowed license; one line per problem, such
    /// as "species orange-striped-fish: missing-license".
    public static func problems(_ catalog: SpeciesCatalog) -> [String] {
        rows(catalog).compactMap { row in
            guard let error = CatalogDecoder.licenseError(author: row.author, license: row.license) else { return nil }
            return "\(row.kind.rawValue) \(row.id): \(error.rawValue)"
        }
    }

    /// The Markdown document: the title, a short provenance note, a table `Kind | Id | Name | Author | License` with
    /// every item, and a summary line. Cell text has `|` escaped and line breaks replaced by spaces.
    public static func markdown(_ catalog: SpeciesCatalog) -> String {
        let items = Self.rows(catalog)
        var lines: [String] = [
            "# \(title)",
            "",
            "Every species, plant and starter habitat of Digital Aquarium is drawn by code in this repository. This",
            "table is generated from `SpeciesCatalog.bundled` by `LicenseAudit.markdown(_:)`, and a test checks that",
            "it matches the catalog. Allowed licenses: \(SpeciesCatalog.allowedLicenses.joined(separator: ", ")).",
            "",
            "| Kind | Id | Name | Author | License |",
            "|---|---|---|---|---|",
        ]
        for row in items {
            let cells = [row.kind.rawValue, row.id, row.name, row.author, row.license].map(cell)
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        let problemCount = Self.problems(catalog).count
        lines.append("")
        lines.append("\(items.count) items (\(catalog.species.count) species, \(catalog.plants.count) plants, "
                     + "\(catalog.habitats.count) habitats); \(problemCount) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
