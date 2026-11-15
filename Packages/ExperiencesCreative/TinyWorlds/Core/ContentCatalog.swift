// ContentCatalog — feature 089 (A12-P01) T-A12-103 (FR-A12-110, FR-A12-113; clarifications 3 and 5; data-model
// "ContentRecord", "Palette"; G-CONTENTLICENSES). The content Tiny Worlds ships with, as Swift data: three presets
// (island, asteroid-garden, miniature-city) and three palettes with the same ids. Every preset names its palette;
// every palette has exactly three colours (sea or void, low land, high land) as RGBA, each component 0…1. Every
// record carries its name, its author ("VisualCore project") and its license; the allowed licenses are exactly
// ["MIT"] (the repository's license). The terrain recipes themselves are code (`WorldPreset`).
//
// The JSON codec writes the catalog with sorted keys (`{"palettes":[…],"presets":[…]}`); the validating decoder reads
// the same layout record by record (palettes first, then presets, each in document order), keeps every valid record
// and refuses each invalid one with a named reason, so one damaged entry never hides the rest. Checks per record, in
// this order (the first failure names the reason):
// 1. `missing-license`: the `license` or the `author` is missing or empty.
// 2. `unsupported-license`: the license is not in `ContentCatalog.allowedLicenses` (["MIT"]).
// 3. `invalid-number`: the record is not a JSON object with a non-empty string `id` and a string `name` (and, for a
//    preset, a non-empty string `palette`), or a palette's `colors` is not a list of exactly three colour objects
//    whose r, g, b and a are finite numbers. An unreadable document is refused as a whole with the id `catalog` and
//    this reason.
// 4. `out-of-range`: a finite colour component lies outside 0…1.
// 5. `duplicate-id`: an otherwise valid record repeats the id of a record of the same kind already kept.
import Foundation

/// A colour with red, green, blue and alpha components, each finite and in 0…1.
public struct RGBA: Codable, Equatable, Sendable {
    /// Red component, 0…1.
    public var r: Double
    /// Green component, 0…1.
    public var g: Double
    /// Blue component, 0…1.
    public var b: Double
    /// Alpha (opacity) component, 0…1.
    public var a: Double

    /// Creates a colour from its components (alpha 1 by default); validity is checked by ``isFiniteColor`` and
    /// ``isInRange``.
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// True when every component is finite.
    public var isFiniteColor: Bool { [r, g, b, a].allSatisfy(\.isFinite) }
    /// True when every component is finite and in 0…1.
    public var isInRange: Bool { [r, g, b, a].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } }
}

/// The kind of a content record.
public enum ContentKind: String, Codable, CaseIterable, Sendable {
    /// A world preset (a terrain recipe with its palette).
    case preset
    /// A colour palette.
    case palette
}

/// One palette: three named colours of a world and its provenance.
public struct Palette: Codable, Equatable, Sendable, Identifiable {
    /// The index of the sea (or void) colour in ``colors``.
    public static let seaIndex = 0
    /// The index of the low-land colour in ``colors``.
    public static let lowLandIndex = 1
    /// The index of the high-land colour in ``colors``.
    public static let highLandIndex = 2

    /// Kebab-case identifier, unique among the palettes.
    public var id: String
    /// Display name ("Island").
    public var name: String
    /// Exactly three colours: sea or void, low land, high land.
    public var colors: [RGBA]
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``ContentCatalog/allowedLicenses``.
    public var license: String

    /// Creates a palette from all of its fields (no validation; `ContentCatalog.check(_:)` validates).
    public init(id: String, name: String, colors: [RGBA], author: String, license: String) {
        self.id = id; self.name = name; self.colors = colors; self.author = author; self.license = license
    }

    /// The sea (or void) colour; transparent black when the palette has no colours.
    public var sea: RGBA { color(Self.seaIndex) }
    /// The low-land colour; transparent black when missing.
    public var lowLand: RGBA { color(Self.lowLandIndex) }
    /// The high-land colour; transparent black when missing.
    public var highLand: RGBA { color(Self.highLandIndex) }

    /// The colour at `index`, or transparent black when there is none.
    private func color(_ index: Int) -> RGBA { colors.indices.contains(index) ? colors[index] : RGBA(0, 0, 0, 0) }
}

/// One preset record: the content side of a world preset (its name, palette and provenance).
public struct PresetRecord: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique among the presets (one of ``WorldPresetID``'s ids for the bundled catalog).
    public var id: String
    /// Display name ("Island").
    public var name: String
    /// The id of the preset's palette.
    public var palette: String
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``ContentCatalog/allowedLicenses``.
    public var license: String

    /// Creates a preset record from all of its fields (no validation).
    public init(id: String, name: String, palette: String, author: String, license: String) {
        self.id = id; self.name = name; self.palette = palette; self.author = author; self.license = license
    }
}

/// Why a record was refused; the raw values are the reason names used in documents and tests.
public enum CatalogRefusalReason: String, Codable, CaseIterable, Error, Sendable {
    /// The record has no license or no author.
    case missingLicense = "missing-license"
    /// The record's license is not an allowed license.
    case unsupportedLicense = "unsupported-license"
    /// A finite number lies outside its range.
    case outOfRange = "out-of-range"
    /// A number (or the record layout) is missing, not a number or non-finite.
    case invalidNumber = "invalid-number"
    /// The id repeats the id of a record of the same kind already kept.
    case duplicateId = "duplicate-id"
}

/// One refused record: its kind, its id (empty when it had none; `catalog` for an unreadable document) and the reason.
public struct CatalogRefusal: Codable, Equatable, Sendable {
    /// The refused record's kind (`palette` for an unreadable document).
    public var kind: ContentKind
    /// The refused record's id, or "" when it had no readable id.
    public var id: String
    /// Why it was refused.
    public var reason: CatalogRefusalReason

    /// Creates a refusal record.
    public init(kind: ContentKind, id: String, reason: CatalogRefusalReason) {
        self.kind = kind; self.id = id; self.reason = reason
    }
}

/// The content catalog of Tiny Worlds: presets and palettes.
public struct ContentCatalog: Codable, Equatable, Sendable {
    /// The only licenses a record may carry.
    public static let allowedLicenses = ["MIT"]
    /// The author of every bundled record.
    public static let projectAuthor = "VisualCore project"
    /// The number of colours of every palette.
    public static let colorCount = 3

    /// The palettes in catalog order.
    public var palettes: [Palette]
    /// The presets in catalog order.
    public var presets: [PresetRecord]

    /// Creates a catalog from its records (no validation; ``decode(_:)`` validates).
    public init(palettes: [Palette], presets: [PresetRecord]) {
        self.palettes = palettes
        self.presets = presets
    }

    /// The palette with `id`, if any.
    public func palette(id: String) -> Palette? { palettes.first { $0.id == id } }
    /// The preset record with `id`, if any.
    public func preset(id: String) -> PresetRecord? { presets.first { $0.id == id } }

    /// The bundled content: the palettes and presets island, asteroid-garden and miniature-city, each by
    /// "VisualCore project" under "MIT"; each preset uses the palette of the same id.
    public static let bundled: ContentCatalog = {
        let author = projectAuthor, license = "MIT"
        return ContentCatalog(
            palettes: [
                Palette(id: "island", name: "Island",
                        colors: [RGBA(0.16, 0.42, 0.62), RGBA(0.36, 0.62, 0.30), RGBA(0.72, 0.66, 0.50)],
                        author: author, license: license),
                Palette(id: "asteroid-garden", name: "Asteroid garden",
                        colors: [RGBA(0.03, 0.03, 0.08), RGBA(0.46, 0.42, 0.40), RGBA(0.70, 0.64, 0.58)],
                        author: author, license: license),
                Palette(id: "miniature-city", name: "Miniature city",
                        colors: [RGBA(0.20, 0.46, 0.58), RGBA(0.62, 0.60, 0.56), RGBA(0.86, 0.80, 0.70)],
                        author: author, license: license),
            ],
            presets: [
                PresetRecord(id: "island", name: "Island", palette: "island", author: author, license: license),
                PresetRecord(id: "asteroid-garden", name: "Asteroid garden", palette: "asteroid-garden",
                             author: author, license: license),
                PresetRecord(id: "miniature-city", name: "Miniature city", palette: "miniature-city",
                             author: author, license: license),
            ])
    }()

    // MARK: - Validation

    /// The license problem of a record with `author` and `license`, or nil when both are present and allowed.
    public static func licenseError(author: String, license: String) -> CatalogRefusalReason? {
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty || license.isEmpty { return .missingLicense }
        return allowedLicenses.contains(license) ? nil : .unsupportedLicense
    }

    /// The first problem of `palette` (license, then layout and non-finite numbers, then ranges), or nil when valid.
    public static func check(_ palette: Palette) -> CatalogRefusalReason? {
        if let error = licenseError(author: palette.author, license: palette.license) { return error }
        guard !palette.id.isEmpty, palette.colors.count == colorCount, palette.colors.allSatisfy(\.isFiniteColor)
        else { return .invalidNumber }
        guard palette.colors.allSatisfy(\.isInRange) else { return .outOfRange }
        return nil
    }

    /// The first problem of `preset` (license, then layout), or nil when valid.
    public static func check(_ preset: PresetRecord) -> CatalogRefusalReason? {
        if let error = licenseError(author: preset.author, license: preset.license) { return error }
        guard !preset.id.isEmpty, !preset.palette.isEmpty else { return .invalidNumber }
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

    /// Decodes a catalog from `data`, keeping every valid record and naming every refused one (see the file header
    /// for the checks and their order). Unreadable JSON, or a document without both lists, gives an empty catalog and
    /// one `catalog` refusal.
    public static func decode(_ data: Data) -> (catalog: ContentCatalog, refused: [CatalogRefusal]) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let paletteList = root["palettes"] as? [Any], let presetList = root["presets"] as? [Any] else {
            return (ContentCatalog(palettes: [], presets: []),
                    [CatalogRefusal(kind: .palette, id: "catalog", reason: .invalidNumber)])
        }
        var palettes: [Palette] = []
        var presets: [PresetRecord] = []
        var refused: [CatalogRefusal] = []
        for element in paletteList {
            let object = (element as? [String: Any]) ?? [:]
            switch parsePalette(object) {
            case .success(let palette) where palettes.contains(where: { $0.id == palette.id }):
                refused.append(CatalogRefusal(kind: .palette, id: palette.id, reason: .duplicateId))
            case .success(let palette): palettes.append(palette)
            case .failure(let reason):
                refused.append(CatalogRefusal(kind: .palette, id: (object["id"] as? String) ?? "", reason: reason))
            }
        }
        for element in presetList {
            let object = (element as? [String: Any]) ?? [:]
            switch parsePreset(object) {
            case .success(let preset) where presets.contains(where: { $0.id == preset.id }):
                refused.append(CatalogRefusal(kind: .preset, id: preset.id, reason: .duplicateId))
            case .success(let preset): presets.append(preset)
            case .failure(let reason):
                refused.append(CatalogRefusal(kind: .preset, id: (object["id"] as? String) ?? "", reason: reason))
            }
        }
        return (ContentCatalog(palettes: palettes, presets: presets), refused)
    }

    /// A finite JSON number, or nil (booleans and strings are not numbers).
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

    /// The license problem of a JSON record, or nil.
    private static func licenseError(_ object: [String: Any]) -> CatalogRefusalReason? {
        licenseError(author: (object["author"] as? String) ?? "", license: (object["license"] as? String) ?? "")
    }

    /// One JSON object to a checked palette, or the first reason it is refused.
    private static func parsePalette(_ object: [String: Any]) -> Result<Palette, CatalogRefusalReason> {
        if let error = licenseError(object) { return .failure(error) }
        guard let id = object["id"] as? String, !id.isEmpty, let name = object["name"] as? String,
              let list = object["colors"] as? [Any], list.count == colorCount else { return .failure(.invalidNumber) }
        let colors = list.compactMap(color)
        guard colors.count == colorCount else { return .failure(.invalidNumber) }
        let palette = Palette(id: id, name: name, colors: colors, author: object["author"] as? String ?? "",
                              license: object["license"] as? String ?? "")
        if let error = check(palette) { return .failure(error) }
        return .success(palette)
    }

    /// One JSON object to a checked preset record, or the first reason it is refused.
    private static func parsePreset(_ object: [String: Any]) -> Result<PresetRecord, CatalogRefusalReason> {
        if let error = licenseError(object) { return .failure(error) }
        guard let id = object["id"] as? String, !id.isEmpty, let name = object["name"] as? String,
              let palette = object["palette"] as? String, !palette.isEmpty else { return .failure(.invalidNumber) }
        let preset = PresetRecord(id: id, name: name, palette: palette, author: object["author"] as? String ?? "",
                                  license: object["license"] as? String ?? "")
        if let error = check(preset) { return .failure(error) }
        return .success(preset)
    }
}
