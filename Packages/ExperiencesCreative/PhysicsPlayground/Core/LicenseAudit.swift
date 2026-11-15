// LicenseAudit — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; SC-A11-106). The content license
// audit of the material catalog: one row per material (in catalog order) with its id, name, author and license; the
// problems (a missing author or license, or a license outside the allowed list); and the Markdown text of
// `docs/apps/physics-playground/content-licenses.md`, which a test compares with the bundled catalog. The text is
// deterministic (no dates), so regenerating it from an unchanged catalog gives the same bytes.
import Foundation

/// One audited material.
public struct LicenseRow: Codable, Equatable, Sendable {
    /// The material id.
    public var id: String
    /// The material's display name.
    public var name: String
    /// The material's author.
    public var author: String
    /// The material's license.
    public var license: String

    /// Creates an audit row.
    public init(id: String, name: String, author: String, license: String) {
        self.id = id; self.name = name; self.author = author; self.license = license
    }
}

/// The content license audit of a material catalog.
public enum LicenseAudit {
    /// The document title.
    public static let title = "Physics Playground — content licenses"

    /// One row per material, in catalog order.
    public static func rows(_ catalog: MaterialCatalog) -> [LicenseRow] {
        catalog.materials.map { LicenseRow(id: $0.id, name: $0.name, author: $0.author, license: $0.license) }
    }

    /// The audit's problems, empty when every material has an author and an allowed license; one line per problem,
    /// such as "material rubber: missing-license".
    public static func problems(_ catalog: MaterialCatalog) -> [String] {
        rows(catalog).compactMap { row in
            guard let error = MaterialCatalog.licenseError(author: row.author, license: row.license) else { return nil }
            return "material \(row.id): \(error.rawValue)"
        }
    }

    /// The Markdown document: the title, a short provenance note, a table
    /// `Id | Name | Density (kg/m²) | Restitution | Friction | Author | License` with every material, and a summary
    /// line. Cell text has `|` escaped and line breaks replaced by spaces.
    public static func markdown(_ catalog: MaterialCatalog) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Every material of Physics Playground is data in this repository, and every body is drawn by code. This",
            "table is generated from `MaterialCatalog.bundled` by `LicenseAudit.markdown(_:)`, and a test checks that it",
            "matches it. Allowed licenses: \(MaterialCatalog.allowedLicenses.joined(separator: ", ")). The physical",
            "constants are educational approximations, not engineering data.",
            "",
            "| Id | Name | Density (kg/m²) | Restitution | Friction | Author | License |",
            "|---|---|---|---|---|---|---|",
        ]
        for material in catalog.materials {
            let cells = [material.id, material.name, "\(material.density)", "\(material.restitution)",
                         "\(material.friction)", material.author, material.license].map(cell)
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        let count = catalog.materials.count
        lines.append("")
        lines.append("\(count) material\(count == 1 ? "" : "s"); \(problems(catalog).count) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
