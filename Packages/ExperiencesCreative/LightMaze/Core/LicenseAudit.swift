// LicenseAudit — feature 096 (A13-P01) T-A13-103 (FR-A13-114; clarification Q4; SC-A13-104). The content license
// audit of the Light Maze level catalog: one row per level (in catalog order) with its id, name, size, tile count,
// author and license; the problems (a missing author or license, or a license outside the allowed list ["MIT"]); and
// the Markdown text of `docs/apps/light-maze/content-licenses.md`, which a test compares with the bundled catalog. The
// text is deterministic (no dates), so regenerating it from an unchanged catalog gives the same bytes.
import Foundation

/// One audited level.
public struct LicenseRow: Codable, Equatable, Sendable {
    /// The level id (`lm-01` …).
    public var id: String
    /// The display name.
    public var name: String
    /// The board size as "W×H".
    public var size: String
    /// The number of tiles.
    public var tiles: Int
    /// The author.
    public var author: String
    /// The license.
    public var license: String

    /// Creates an audit row.
    public init(id: String, name: String, size: String, tiles: Int, author: String, license: String) {
        self.id = id; self.name = name; self.size = size; self.tiles = tiles; self.author = author
        self.license = license
    }
}

/// The content license audit of a Light Maze level catalog.
public enum LicenseAudit {
    /// The document title.
    public static let title = "Light Maze — content licenses"

    /// One row per level in catalog order.
    public static func rows(_ catalog: LevelCatalog) -> [LicenseRow] {
        catalog.levels.map {
            LicenseRow(id: $0.id, name: $0.name, size: "\($0.board.width)×\($0.board.height)",
                       tiles: $0.board.tiles.count, author: $0.author, license: $0.license)
        }
    }

    /// The audit's problems, empty when every level has an author and an allowed license; one line per problem, such
    /// as "level lm-01: missing-license" or "level lm-02: unsupported-license".
    public static func problems(_ catalog: LevelCatalog) -> [String] { problems(rows(catalog)) }

    /// The problems of `rows`, one line per problem: "level <id>: <reason>".
    public static func problems(_ rows: [LicenseRow]) -> [String] {
        rows.compactMap { row in
            guard let error = LevelCatalog.licenseError(author: row.author, license: row.license) else { return nil }
            return "level \(row.id): \(error.rawValue)"
        }
    }

    /// The Markdown document: the title, a short provenance note, a table `Id | Name | Size | Tiles | Author | License`
    /// with every level and a summary line "N levels; X problems.". Cell text has `|` escaped and line breaks replaced
    /// by spaces; an empty cell shows "—".
    public static func markdown(_ catalog: LevelCatalog) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Every Light Maze level is original data in this repository, drawn by code (no artwork). This table is",
            "generated from `LevelCatalog.bundled` by `LicenseAudit.markdown(_:)`, and a test checks that it matches "
                + "it. Allowed licenses: \(LevelCatalog.allowedLicenses.joined(separator: ", ")).",
            "",
            "| Id | Name | Size | Tiles | Author | License |",
            "|---|---|---|---|---|---|",
        ]
        for row in rows(catalog) {
            let cells = [row.id, row.name, row.size, String(row.tiles), row.author, row.license].map(cell)
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        let count = catalog.levels.count
        lines.append("")
        lines.append("\(count) level\(count == 1 ? "" : "s"); \(problems(catalog).count) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
