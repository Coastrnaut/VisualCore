// LicenseAudit — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; SC-A11-106). The content license
// audit of the material catalog: one row per material (in catalog order) with its id, name, author and license; the
// problems (a missing author or license, or a license outside the allowed list); and the Markdown text of
// `docs/apps/physics-playground/content-licenses.md`, which a test compares with the bundled catalog. The text is
// deterministic (no dates), so regenerating it from an unchanged catalog gives the same bytes.
// Feature 085 (A11-P04) T-A11-402 (FR-A11-431): each row has a role — `material` (the catalog's materials, in catalog
// order), then `preset` (the four presets in `PresetID` order) and `tutorial` (one row per tutorial in id order, its
// step texts being the content); the problems cover every row, and the Markdown adds a second table of the presets and
// tutorials after the materials table, and a summary line counting each role.
import Foundation

/// One audited piece of content: a material, a preset or a tutorial.
public struct LicenseRow: Codable, Equatable, Sendable {
    /// The content id (kebab-case).
    public var id: String
    /// The display name.
    public var name: String
    /// The author.
    public var author: String
    /// The license.
    public var license: String
    /// The role: ``LicenseAudit/materialRole``, ``LicenseAudit/presetRole`` or ``LicenseAudit/tutorialRole``.
    public var role: String

    /// Creates an audit row (role `material` by default).
    public init(id: String, name: String, author: String, license: String, role: String = LicenseAudit.materialRole) {
        self.id = id; self.name = name; self.author = author; self.license = license; self.role = role
    }
}

/// The content license audit of a material catalog.
public enum LicenseAudit {
    /// The document title.
    public static let title = "Physics Playground — content licenses"
    /// The role of a material row.
    public static let materialRole = "material"
    /// The role of a preset row.
    public static let presetRole = "preset"
    /// The role of a tutorial row.
    public static let tutorialRole = "tutorial"

    /// One row per material in catalog order, then one per preset in ``PresetID`` order, then one per tutorial in id
    /// order.
    public static func rows(_ catalog: MaterialCatalog) -> [LicenseRow] {
        catalog.materials.map { LicenseRow(id: $0.id, name: $0.name, author: $0.author, license: $0.license) }
            + contentRows()
    }

    /// The preset and tutorial rows.
    public static func contentRows() -> [LicenseRow] {
        PresetID.allCases.map {
            LicenseRow(id: $0.contentId, name: $0.name, author: $0.author, license: $0.license, role: presetRole)
        } + Tutorials.all.map {
            LicenseRow(id: $0.contentId, name: $0.name, author: $0.author, license: $0.license, role: tutorialRole)
        }
    }

    /// The audit's problems, empty when every row has an author and an allowed license; one line per problem, such as
    /// "material rubber: missing-license" or "preset pendulum: unsupported-license".
    public static func problems(_ catalog: MaterialCatalog) -> [String] {
        problems(rows(catalog))
    }

    /// The problems of `rows`, one line per problem: "<role> <id>: <reason>".
    public static func problems(_ rows: [LicenseRow]) -> [String] {
        rows.compactMap { row in
            guard let error = MaterialCatalog.licenseError(author: row.author, license: row.license) else { return nil }
            return "\(row.role) \(row.id): \(error.rawValue)"
        }
    }

    /// The Markdown document: the title, a short provenance note, a table
    /// `Id | Name | Density (kg/m²) | Restitution | Friction | Author | License` with every material, a table
    /// `Id | Role | Name | Author | License` with every preset and tutorial, and a summary line
    /// "N materials, P presets, T tutorials; X problems.". Cell text has `|` escaped and line breaks replaced by spaces.
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
        lines += [
            "",
            "The presets and the tutorial texts are original content of this repository; each tutorial row covers all of",
            "its step texts.",
            "",
            "| Id | Role | Name | Author | License |",
            "|---|---|---|---|---|",
        ]
        let content = contentRows()
        for row in content {
            lines.append("| " + [row.id, row.role, row.name, row.author, row.license].map(cell).joined(separator: " | ")
                         + " |")
        }
        func counted(_ count: Int, _ noun: String) -> String { "\(count) \(noun)\(count == 1 ? "" : "s")" }
        let presets = content.filter { $0.role == presetRole }.count
        let tutorials = content.filter { $0.role == tutorialRole }.count
        lines.append("")
        lines.append("\(counted(catalog.materials.count, "material")), \(counted(presets, "preset")), "
                     + "\(counted(tutorials, "tutorial")); \(problems(catalog).count) problems.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
