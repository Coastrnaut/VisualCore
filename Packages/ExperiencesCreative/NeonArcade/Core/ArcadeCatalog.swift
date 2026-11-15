// ArcadeCatalog — feature 075 (A10-P01) T-A10-103 (FR-A10-113; clarification 5; data-model "ContentItem",
// "CatalogError"). The content Neon Arcade ships with, as Swift data: the player (shape `chevron`), the hazards
// (`spike-ball`, a circle, and `bar`, a horizontal capsule) and the orb (`glow-orb`, a circle worth 10 points). Every
// item carries its colours, its size limits (radius, and the half-length for the bar), its value, its author and its
// license; the allowed licenses are exactly ["MIT"] (the repository's license, author "VisualCore project"). Sizes are
// game units: the field is 9 × 16 (x 0…9, y 0…16, y up).
//
// The JSON codec writes the catalog with sorted keys (`{"items":[…]}`); the validating decoder reads the same layout
// item by item, keeps every valid item and refuses each invalid one with a named reason, so one damaged entry never
// hides the rest. Checks per item, in this order (the first failure names the reason):
// 1. `unknown-shape`: the item is not a JSON object with a non-empty string `id` and a string `name`, its `role` or
//    `shape` is missing or not one of the enumerations, the shape does not belong to the role (player: chevron;
//    hazard: spike-ball or bar; orb: glow-orb), or the id repeats an id already kept (an ambiguous record). An
//    unreadable document is refused as a whole with the id `catalog` and this reason.
// 2. `missing-license`: the `license` or the `author` is missing or empty.
// 3. `unsupported-license`: the license is not in `ArcadeCatalog.allowedLicenses` (["MIT"]).
// 4. `invalid-number`: a colour or size is missing, not a number, non-finite or out of range (colours 0…1; radius range
//    min ≤ max inside 0.1…1.0; half-length range for the bar only, min ≤ max inside 0.3…1.5, and absent otherwise;
//    value an integer ≥ 0, ≥ 1 for an orb).
import Foundation

/// A colour with red, green, blue and alpha components, each finite and in 0…1.
public struct RGBA: Codable, Equatable, Sendable {
    /// Red component, 0…1.
    public var r: Double
    /// Green component, 0…1.
    public var g: Double
    /// Blue component, 0…1.
    public var b: Double
    /// Alpha (opacity), 0…1.
    public var a: Double

    /// Creates a colour from its components (alpha defaults to opaque); validity is checked by ``isValid``.
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// True when every component is finite and in 0…1.
    public var isValid: Bool { [r, g, b, a].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } }
}

/// An inclusive size range in game units (`min ≤ max`); validity against a limit is checked by ``isValid(within:)``.
public struct SizeRange: Codable, Equatable, Sendable {
    /// The smallest size.
    public var min: Double
    /// The largest size.
    public var max: Double

    /// Creates a range from its bounds (no validation).
    public init(min: Double, max: Double) { self.min = min; self.max = max }

    /// A range holding exactly `value`.
    public init(exactly value: Double) { self.init(min: value, max: value) }

    /// True when both bounds are finite, `min ≤ max` and both lie inside `limit`.
    public func isValid(within limit: ClosedRange<Double>) -> Bool {
        min.isFinite && max.isFinite && min <= max && limit.contains(min) && limit.contains(max)
    }

    /// The bounds as a closed range (callers check ``isValid(within:)`` first; an inverted range gives `min…min`).
    public var closed: ClosedRange<Double> { min...Swift.max(min, max) }
}

/// What a catalog item is in the game.
public enum ContentRole: String, Codable, CaseIterable, Sendable {
    /// The steered player.
    case player
    /// A falling object that costs a life on contact.
    case hazard
    /// A falling object that adds its value to the score on contact.
    case orb
    /// A spawn pattern of the wave director (license audit rows only; no catalog item has this role, so a catalog
    /// item claiming it is refused as `unknown-shape`).
    case pattern
}

/// The form a catalog item is drawn and collided as.
public enum ContentShape: String, Codable, CaseIterable, Sendable {
    /// The player: a ring at the hit radius with a chevron inside (collides as a circle).
    case chevron
    /// A spiked ball hazard (collides as a circle).
    case spikeBall = "spike-ball"
    /// A horizontal bar hazard (collides as a capsule).
    case bar
    /// A glowing orb (collides as a circle).
    case glowOrb = "glow-orb"

    /// The role this shape belongs to.
    public var role: ContentRole {
        switch self {
        case .chevron: .player
        case .spikeBall, .bar: .hazard
        case .glowOrb: .orb
        }
    }

    /// True for the capsule shape (`bar`); every other shape collides as a circle.
    public var isCapsule: Bool { self == .bar }
}

/// One item of the content catalog.
public struct ContentItem: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the catalog.
    public var id: String
    /// Descriptive display name ("Spike ball").
    public var name: String
    /// The item's role in the game.
    public var role: ContentRole
    /// The drawn and collided shape; it must belong to ``role``.
    public var shape: ContentShape
    /// The fill colour.
    public var color: RGBA
    /// The glow colour.
    public var glowColor: RGBA
    /// The radius range in game units (min ≤ max, inside ``ArcadeCatalog/radiusLimit``); a spawned object draws its
    /// radius uniformly from it.
    public var radiusRange: SizeRange
    /// The half-length range of a bar (min ≤ max, inside ``ArcadeCatalog/halfLengthLimit``); nil for every other shape.
    public var halfLengthRange: SizeRange?
    /// Points added on contact (≥ 1 for an orb; 0 for the player and hazards by convention).
    public var value: Int
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``ArcadeCatalog/allowedLicenses``.
    public var license: String

    /// Creates an item from all of its fields (no validation; ``ArcadeCatalog/check(_:)`` validates).
    public init(id: String, name: String, role: ContentRole, shape: ContentShape, color: RGBA, glowColor: RGBA,
                radiusRange: SizeRange, halfLengthRange: SizeRange? = nil, value: Int, author: String,
                license: String) {
        self.id = id; self.name = name; self.role = role; self.shape = shape; self.color = color
        self.glowColor = glowColor; self.radiusRange = radiusRange; self.halfLengthRange = halfLengthRange
        self.value = value; self.author = author; self.license = license
    }
}

/// Why a catalog item was refused; the raw values are the reason names used in documents and tests.
public enum CatalogError: String, Codable, CaseIterable, Error, Sendable {
    /// The item has no license or no author.
    case missingLicense = "missing-license"
    /// The item's license is not an allowed license.
    case unsupportedLicense = "unsupported-license"
    /// The item's role or shape (or its record layout, or a repeated id) is not known.
    case unknownShape = "unknown-shape"
    /// A colour, size or value is missing, non-finite or out of range.
    case invalidNumber = "invalid-number"
}

/// One refused catalog item: its id (empty when it had none; `catalog` for an unreadable document) and the reason.
public struct CatalogRefusal: Codable, Equatable, Sendable {
    /// The refused item's id, or "" when it had no readable id.
    public var id: String
    /// Why it was refused.
    public var error: CatalogError

    /// Creates a refusal record.
    public init(id: String, error: CatalogError) { self.id = id; self.error = error }
}

/// The content catalog of Neon Arcade: every drawable item with its sizes, colours, value and provenance.
public struct ArcadeCatalog: Codable, Equatable, Sendable {
    /// The only licenses content may carry.
    public static let allowedLicenses = ["MIT"]
    /// The author of all bundled content.
    public static let projectAuthor = "VisualCore project"
    /// The limit every radius range lies inside.
    public static let radiusLimit: ClosedRange<Double> = 0.1...1.0
    /// The limit every bar half-length range lies inside.
    public static let halfLengthLimit: ClosedRange<Double> = 0.3...1.5

    /// The items in catalog order.
    public var items: [ContentItem]

    /// Creates a catalog from its items (no validation; ``decode(_:)`` validates).
    public init(items: [ContentItem]) { self.items = items }

    /// The item with `id`, if any.
    public func item(id: String) -> ContentItem? { items.first { $0.id == id } }
    /// The first player item, if any.
    public var player: ContentItem? { items.first { $0.role == .player } }
    /// The hazard items in catalog order.
    public var hazards: [ContentItem] { items.filter { $0.role == .hazard } }
    /// The orb items in catalog order.
    public var orbs: [ContentItem] { items.filter { $0.role == .orb } }

    /// The bundled content: the player "Chevron" (radius 0.4), the hazards "Spike ball" (radius 0.35…0.6) and "Bar"
    /// (radius 0.2, half-length 0.6…1.0) and the orb "Glow orb" (radius 0.25, worth 10); every item is by
    /// "VisualCore project" under "MIT".
    public static let bundled: ArcadeCatalog = {
        let author = projectAuthor, license = "MIT"
        return ArcadeCatalog(items: [
            ContentItem(id: "chevron", name: "Chevron", role: .player, shape: .chevron,
                        color: RGBA(0.2, 0.95, 1.0), glowColor: RGBA(0.1, 0.7, 1.0, 0.6),
                        radiusRange: SizeRange(exactly: 0.4), value: 0, author: author, license: license),
            ContentItem(id: "spike-ball", name: "Spike ball", role: .hazard, shape: .spikeBall,
                        color: RGBA(1.0, 0.2, 0.45), glowColor: RGBA(1.0, 0.1, 0.35, 0.6),
                        radiusRange: SizeRange(min: 0.35, max: 0.6), value: 0, author: author, license: license),
            ContentItem(id: "bar", name: "Bar", role: .hazard, shape: .bar,
                        color: RGBA(1.0, 0.55, 0.1), glowColor: RGBA(1.0, 0.4, 0.05, 0.6),
                        radiusRange: SizeRange(exactly: 0.2), halfLengthRange: SizeRange(min: 0.6, max: 1.0),
                        value: 0, author: author, license: license),
            ContentItem(id: "glow-orb", name: "Glow orb", role: .orb, shape: .glowOrb,
                        color: RGBA(0.75, 1.0, 0.3), glowColor: RGBA(0.6, 1.0, 0.2, 0.7),
                        radiusRange: SizeRange(exactly: 0.25), value: 10, author: author, license: license),
        ])
    }()

    // MARK: - Validation

    /// The license problem of an item with `author` and `license`, or nil when both are present and allowed.
    public static func licenseError(author: String, license: String) -> CatalogError? {
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty || license.isEmpty { return .missingLicense }
        return allowedLicenses.contains(license) ? nil : .unsupportedLicense
    }

    /// The first problem of `item` (shape against role, license, then numbers), or nil when it is valid.
    public static func check(_ item: ContentItem) -> CatalogError? {
        if item.id.isEmpty || item.shape.role != item.role { return .unknownShape }
        if let error = licenseError(author: item.author, license: item.license) { return error }
        guard item.color.isValid, item.glowColor.isValid, item.radiusRange.isValid(within: radiusLimit),
              item.value >= 0, item.role != .orb || item.value >= 1 else { return .invalidNumber }
        if item.shape.isCapsule {
            guard let half = item.halfLengthRange, half.isValid(within: halfLengthLimit) else { return .invalidNumber }
        } else if item.halfLengthRange != nil {
            return .invalidNumber
        }
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

    /// Decodes a catalog from `data`, keeping every valid item and naming every refused one (see the file header for
    /// the checks and their order). Unreadable JSON gives an empty catalog and one `catalog` refusal.
    public static func decode(_ data: Data) -> (catalog: ArcadeCatalog, refused: [CatalogRefusal]) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["items"] as? [Any] else {
            return (ArcadeCatalog(items: []), [CatalogRefusal(id: "catalog", error: .unknownShape)])
        }
        var items: [ContentItem] = []
        var refused: [CatalogRefusal] = []
        for element in list {
            let object = (element as? [String: Any]) ?? [:]
            switch parse(object) {
            case .success(let item) where items.contains(where: { $0.id == item.id }):
                refused.append(CatalogRefusal(id: item.id, error: .unknownShape))
            case .success(let item): items.append(item)
            case .failure(let error): refused.append(CatalogRefusal(id: (object["id"] as? String) ?? "", error: error))
            }
        }
        return (ArcadeCatalog(items: items), refused)
    }

    /// A finite JSON number, or nil (booleans are not numbers).
    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    /// A colour object with r, g, b and a, or nil.
    private static func color(_ value: Any?) -> RGBA? {
        guard let object = value as? [String: Any], let r = number(object["r"]), let g = number(object["g"]),
              let b = number(object["b"]), let a = number(object["a"]) else { return nil }
        return RGBA(r, g, b, a)
    }

    /// A size range object with min and max, or nil.
    private static func range(_ value: Any?) -> SizeRange? {
        guard let object = value as? [String: Any], let min = number(object["min"]),
              let max = number(object["max"]) else { return nil }
        return SizeRange(min: min, max: max)
    }

    /// One JSON object to a checked item, or the first reason it is refused.
    private static func parse(_ object: [String: Any]) -> Result<ContentItem, CatalogError> {
        guard let id = object["id"] as? String, !id.isEmpty, let name = object["name"] as? String,
              let roleText = object["role"] as? String, let role = ContentRole(rawValue: roleText),
              let shapeText = object["shape"] as? String, let shape = ContentShape(rawValue: shapeText),
              shape.role == role else { return .failure(.unknownShape) }
        let author = (object["author"] as? String) ?? "", license = (object["license"] as? String) ?? ""
        if let error = licenseError(author: author, license: license) { return .failure(error) }
        guard let fill = color(object["color"]), let glow = color(object["glowColor"]),
              let radius = range(object["radiusRange"]), let rawValue = number(object["value"]),
              rawValue == rawValue.rounded(), abs(rawValue) <= 1e9 else { return .failure(.invalidNumber) }
        var halfLength: SizeRange?
        if let raw = object["halfLengthRange"], !(raw is NSNull) {
            guard let parsed = range(raw) else { return .failure(.invalidNumber) }
            halfLength = parsed
        }
        let item = ContentItem(id: id, name: name, role: role, shape: shape, color: fill, glowColor: glow,
                               radiusRange: radius, halfLengthRange: halfLength, value: Int(rawValue),
                               author: author, license: license)
        if let error = check(item) { return .failure(error) }
        return .success(item)
    }
}
