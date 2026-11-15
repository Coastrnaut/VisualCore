// LicenseAudit — feature 075 (A10-P01) T-A10-103 (FR-A10-113; clarification 5; SC-A10-104). The content license
// audit: one row per catalog item (in catalog order) with its role, id, name, author and license; the problems (a
// missing author or license, or a license outside the allowed list); and the Markdown text of
// `docs/apps/neon-arcade/content-licenses.md`, which a test compares with the bundled catalog. The text is
// deterministic (no dates), so regenerating it from an unchanged catalog gives the same bytes.
import Foundation

/// One audited catalog item.
public struct LicenseRow: Codable, Equatable, Sendable {
    /// The item's role (`player`, `hazard` or `orb`).
    public var role: ContentRole
    /// The item id.
    public var id: String
    /// The item's display name.
    public var name: String
    /// The item's author.
    public var author: String
    /// The item's license.
    public var license: String

    /// Creates an audit row.
    public init(role: ContentRole, id: String, name: String, author: String, license: String) {
        self.role = role; self.id = id; self.name = name; self.author = author; self.license = license
    }
}

/// The content license audit of an arcade catalog.
public enum LicenseAudit {
    /// The document title.
    public static let title = "Neon Arcade — content licenses"

    /// One row per item, in catalog order.
    public static func rows(_ catalog: ArcadeCatalog) -> [LicenseRow] {
        catalog.items.map { LicenseRow(role: $0.role, id: $0.id, name: $0.name, author: $0.author,
                                       license: $0.license) }
    }

    /// The audit's problems, empty when every item has an author and an allowed license; one line per problem, such
    /// as "hazard spike-ball: missing-license".
    public static func problems(_ catalog: ArcadeCatalog) -> [String] {
        rows(catalog).compactMap { row in
            guard let error = ArcadeCatalog.licenseError(author: row.author, license: row.license) else { return nil }
            return "\(row.role.rawValue) \(row.id): \(error.rawValue)"
        }
    }

    /// The Markdown document: the title, a short provenance note, a table `Role | Id | Name | Author | License` with
    /// every item, and a summary line. Cell text has `|` escaped and line breaks replaced by spaces.
    public static func markdown(_ catalog: ArcadeCatalog) -> String {
        let items = rows(catalog)
        var lines: [String] = [
            "# \(title)",
            "",
            "The player, every hazard and every orb of Neon Arcade is drawn by code in this repository. This table is",
            "generated from `ArcadeCatalog.bundled` by `LicenseAudit.markdown(_:)`, and a test checks that it matches",
            "the catalog. Allowed licenses: \(ArcadeCatalog.allowedLicenses.joined(separator: ", ")).",
            "",
            "| Role | Id | Name | Author | License |",
            "|---|---|---|---|---|",
        ]
        for row in items {
            let cells = [row.role.rawValue, row.id, row.name, row.author, row.license].map(cell)
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        let count = { (role: ContentRole, noun: String) -> String in
            let n = items.filter { $0.role == role }.count
            return "\(n) \(noun)\(n == 1 ? "" : "s")"
        }
        lines.append("")
        lines.append("\(items.count) items (\(count(.player, "player")), \(count(.hazard, "hazard")), "
                     + "\(count(.orb, "orb"))); \(problems(catalog).count) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
