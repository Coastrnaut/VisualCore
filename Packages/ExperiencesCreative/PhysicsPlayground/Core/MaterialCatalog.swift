// MaterialCatalog — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; data-model "Material"; SC-A11-106).
// The materials Physics Playground ships with, as Swift data: rubber (density 1.2 kg/m², restitution 0.8, friction
// 0.9), wood (0.6, 0.4, 0.5), steel (7.8, 0.25, 0.4) and ice (0.9, 0.1, 0.05). Every material carries its name, its
// fill and edge colours (RGB, each component 0…1), its author ("VisualCore project") and its license; the allowed
// licenses are exactly ["MIT"] (the repository's license). Densities are 2D (kg per square metre).
//
// The JSON codec writes the catalog with sorted keys (`{"materials":[…]}`); the validating decoder reads the same
// layout material by material, keeps every valid material and refuses each invalid one with a named reason, so one
// damaged entry never hides the rest. Checks per material, in this order (the first failure names the reason):
// 1. `missing-license`: the `license` or the `author` is missing or empty.
// 2. `unsupported-license`: the license is not in `MaterialCatalog.allowedLicenses` (["MIT"]).
// 3. `invalid-number`: the record is not a JSON object with a non-empty string `id` and a string `name`, or a colour
//    component, the density, the restitution or the friction is missing, not a number or non-finite. An unreadable
//    document is refused as a whole with the id `catalog` and this reason (no number in it can be read).
// 4. `out-of-range`: a finite number lies outside its range (density 0.1…10, restitution 0…1, friction 0…1, colour
//    components 0…1).
// 5. `duplicate-id`: an otherwise valid material repeats the id of a material already kept.
import Foundation

/// A colour with red, green and blue components, each finite and in 0…1.
public struct RGB: Codable, Equatable, Sendable {
    /// Red component, 0…1.
    public var r: Double
    /// Green component, 0…1.
    public var g: Double
    /// Blue component, 0…1.
    public var b: Double

    /// Creates a colour from its components; validity is checked by ``isFiniteColor`` and ``isInRange``.
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    /// True when every component is finite.
    public var isFiniteColor: Bool { [r, g, b].allSatisfy(\.isFinite) }
    /// True when every component is finite and in 0…1.
    public var isInRange: Bool { [r, g, b].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } }
}

/// One material: its look, its physical constants and its provenance.
public struct Material: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the catalog.
    public var id: String
    /// Display name ("Rubber").
    public var name: String
    /// The fill colour.
    public var fill: RGB
    /// The edge (outline) colour.
    public var edge: RGB
    /// Area density in kg/m² (``MaterialCatalog/densityRange``); a body's mass is density × area.
    public var density: Double
    /// Coefficient of restitution, 0…1; a contact uses the larger of the two bodies' values.
    public var restitution: Double
    /// Coefficient of friction, 0…1; a contact uses the geometric mean of the two bodies' values.
    public var friction: Double
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``MaterialCatalog/allowedLicenses``.
    public var license: String

    /// Creates a material from all of its fields (no validation; ``MaterialCatalog/check(_:)`` validates).
    public init(id: String, name: String, fill: RGB, edge: RGB, density: Double, restitution: Double,
                friction: Double, author: String, license: String) {
        self.id = id; self.name = name; self.fill = fill; self.edge = edge; self.density = density
        self.restitution = restitution; self.friction = friction; self.author = author; self.license = license
    }
}

/// Why a material was refused; the raw values are the reason names used in documents and tests.
public enum CatalogRefusalReason: String, Codable, CaseIterable, Error, Sendable {
    /// The material has no license or no author.
    case missingLicense = "missing-license"
    /// The material's license is not an allowed license.
    case unsupportedLicense = "unsupported-license"
    /// A finite number lies outside its range.
    case outOfRange = "out-of-range"
    /// A number (or the record layout) is missing, not a number or non-finite.
    case invalidNumber = "invalid-number"
    /// The id repeats the id of a material already kept.
    case duplicateId = "duplicate-id"
}

/// One refused material: its id (empty when it had none; `catalog` for an unreadable document) and the reason.
public struct CatalogRefusal: Codable, Equatable, Sendable {
    /// The refused material's id, or "" when it had no readable id.
    public var id: String
    /// Why it was refused.
    public var reason: CatalogRefusalReason

    /// Creates a refusal record.
    public init(id: String, reason: CatalogRefusalReason) { self.id = id; self.reason = reason }
}

/// The material catalog of Physics Playground.
public struct MaterialCatalog: Codable, Equatable, Sendable {
    /// The only licenses a material may carry.
    public static let allowedLicenses = ["MIT"]
    /// The author of every bundled material.
    public static let projectAuthor = "VisualCore project"
    /// The allowed area densities in kg/m².
    public static let densityRange: ClosedRange<Double> = 0.1...10
    /// The allowed coefficients of restitution.
    public static let restitutionRange: ClosedRange<Double> = 0...1
    /// The allowed coefficients of friction.
    public static let frictionRange: ClosedRange<Double> = 0...1

    /// The materials in catalog order.
    public var materials: [Material]

    /// Creates a catalog from its materials (no validation; ``decode(_:)`` validates).
    public init(materials: [Material]) { self.materials = materials }

    /// The material with `id`, if any.
    public func material(id: String) -> Material? { materials.first { $0.id == id } }

    /// The bundled materials: rubber (1.2, 0.8, 0.9), wood (0.6, 0.4, 0.5), steel (7.8, 0.25, 0.4) and ice (0.9, 0.1,
    /// 0.05) as (density, restitution, friction), each by "VisualCore project" under "MIT".
    public static let bundled: MaterialCatalog = {
        let author = projectAuthor, license = "MIT"
        return MaterialCatalog(materials: [
            Material(id: "rubber", name: "Rubber", fill: RGB(0.86, 0.27, 0.32), edge: RGB(0.52, 0.10, 0.15),
                     density: 1.2, restitution: 0.8, friction: 0.9, author: author, license: license),
            Material(id: "wood", name: "Wood", fill: RGB(0.74, 0.54, 0.31), edge: RGB(0.45, 0.30, 0.15),
                     density: 0.6, restitution: 0.4, friction: 0.5, author: author, license: license),
            Material(id: "steel", name: "Steel", fill: RGB(0.62, 0.66, 0.72), edge: RGB(0.33, 0.36, 0.41),
                     density: 7.8, restitution: 0.25, friction: 0.4, author: author, license: license),
            Material(id: "ice", name: "Ice", fill: RGB(0.72, 0.90, 1.00), edge: RGB(0.40, 0.64, 0.85),
                     density: 0.9, restitution: 0.1, friction: 0.05, author: author, license: license),
        ])
    }()

    // MARK: - Validation

    /// The license problem of a material with `author` and `license`, or nil when both are present and allowed.
    public static func licenseError(author: String, license: String) -> CatalogRefusalReason? {
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty || license.isEmpty { return .missingLicense }
        return allowedLicenses.contains(license) ? nil : .unsupportedLicense
    }

    /// The first problem of `material` (license, then non-finite numbers, then ranges), or nil when it is valid.
    public static func check(_ material: Material) -> CatalogRefusalReason? {
        if let error = licenseError(author: material.author, license: material.license) { return error }
        guard !material.id.isEmpty, material.fill.isFiniteColor, material.edge.isFiniteColor,
              material.density.isFinite, material.restitution.isFinite, material.friction.isFinite
        else { return .invalidNumber }
        guard material.fill.isInRange, material.edge.isInRange, densityRange.contains(material.density),
              restitutionRange.contains(material.restitution), frictionRange.contains(material.friction)
        else { return .outOfRange }
        return nil
    }

    // MARK: - JSON

    /// The catalog as JSON with sorted keys (deterministic bytes for equal catalogs); a non-finite number (only
    /// possible in a hand-built catalog) gives empty data rather than a crash.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Decodes a catalog from `data`, keeping every valid material and naming every refused one (see the file header
    /// for the checks and their order). Unreadable JSON gives an empty catalog and one `catalog` refusal.
    public static func decode(_ data: Data) -> (catalog: MaterialCatalog, refused: [CatalogRefusal]) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["materials"] as? [Any] else {
            return (MaterialCatalog(materials: []), [CatalogRefusal(id: "catalog", reason: .invalidNumber)])
        }
        var kept: [Material] = []
        var refused: [CatalogRefusal] = []
        for element in list {
            let object = (element as? [String: Any]) ?? [:]
            switch parse(object) {
            case .success(let material) where kept.contains(where: { $0.id == material.id }):
                refused.append(CatalogRefusal(id: material.id, reason: .duplicateId))
            case .success(let material): kept.append(material)
            case .failure(let reason):
                refused.append(CatalogRefusal(id: (object["id"] as? String) ?? "", reason: reason))
            }
        }
        return (MaterialCatalog(materials: kept), refused)
    }

    /// A finite JSON number, or nil (booleans and strings are not numbers).
    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    /// A colour object with r, g and b, or nil.
    private static func color(_ value: Any?) -> RGB? {
        guard let object = value as? [String: Any], let r = number(object["r"]), let g = number(object["g"]),
              let b = number(object["b"]) else { return nil }
        return RGB(r, g, b)
    }

    /// One JSON object to a checked material, or the first reason it is refused.
    private static func parse(_ object: [String: Any]) -> Result<Material, CatalogRefusalReason> {
        let author = (object["author"] as? String) ?? "", license = (object["license"] as? String) ?? ""
        if let error = licenseError(author: author, license: license) { return .failure(error) }
        guard let id = object["id"] as? String, !id.isEmpty, let name = object["name"] as? String,
              let fill = color(object["fill"]), let edge = color(object["edge"]),
              let density = number(object["density"]), let restitution = number(object["restitution"]),
              let friction = number(object["friction"]) else { return .failure(.invalidNumber) }
        let material = Material(id: id, name: name, fill: fill, edge: edge, density: density,
                                restitution: restitution, friction: friction, author: author, license: license)
        if let error = check(material) { return .failure(error) }
        return .success(material)
    }
}
