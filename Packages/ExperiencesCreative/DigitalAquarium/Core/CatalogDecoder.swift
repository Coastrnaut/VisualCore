// CatalogDecoder — feature 068 (A09-P01) T-A09-102 (FR-A09-103; clarification 3; research D3; data-model
// "CatalogError"). The JSON codec of the species catalog and its validating decoder. `encoded()` writes the catalog as
// JSON with sorted keys (the synthesized `Codable` keys); `decode(_:)` reads the same layout item by item, keeps every
// valid item and refuses each invalid one with a named reason, so one damaged entry never hides the rest.
//
// Checks per item, in this order (the first failure names the reason):
// 1. `unknown-shape`: the item is not a JSON object with a string `id` and `name`, or its `shape` is missing or not one
//    of the enumeration (fish: teardrop, slender; plants: ribbon, fan). An unreadable document is refused as a whole
//    with the id `catalog` and this reason.
// 2. `missing-license`: the `license` or the `author` is missing or empty (a provenance record needs both).
// 3. `unsupported-license`: the license is not in `SpeciesCatalog.allowedLicenses` (["MIT"]).
// 4. `invalid-number`: a number or colour is missing, not a number, non-finite or out of range (fish length 0.3…1.5,
//    0 < cruise ≤ max ≤ 4, 0 < turn rate ≤ 2π; plant height 0.5…6; colours 0…1; habitat counts ≥ 1, total ≥ 1, at
//    most 12 plants, plant x inside the swim bounds' x range).
// 5. `too-many-fish`: a habitat's fish total exceeds `HabitatDocument.maxFish` (24).
// 6. `unknown-reference`: a habitat names a species or plant that is not among the kept items, or an item repeats an
//    id already kept (an ambiguous reference).
// Species and plants are decoded before habitats, so a habitat that names a refused species is itself refused.
//
// Feature 069 (A09-P02) T-A09-203 (FR-A09-212; research D4): decor kinds are decoded after plants and before habitats
// with the same checks (shape rock or shell; size 0.3…2.0; valid colour; author and allowed license; unique id), and a
// habitat's decor spots are checked too: at most `HabitatDocument.maxDecor` (12), each position finite inside the tank
// (x 0…16, y 0…9), rotation −π…π and scale 0.5…2.0 (`invalid-number`), and each kind among the kept decor kinds
// (`unknown-reference`). A catalog or habitat without a `decor` key has no decor.
import Foundation
import VisualCoreMath

/// Why a catalog item was refused; the raw values are the reason names used in documents and tests.
public enum CatalogError: String, Codable, CaseIterable, Error, Sendable {
    /// The item has no license or no author.
    case missingLicense = "missing-license"
    /// The item's license is not an allowed license.
    case unsupportedLicense = "unsupported-license"
    /// The item's shape (or its record layout) is not known.
    case unknownShape = "unknown-shape"
    /// The item names an unknown item, or repeats an id.
    case unknownReference = "unknown-reference"
    /// A number or colour is missing, non-finite or out of range.
    case invalidNumber = "invalid-number"
    /// A habitat asks for more fish than a habitat may hold.
    case tooManyFish = "too-many-fish"
}

/// The kind of a catalog item.
public enum CatalogItemKind: String, Codable, CaseIterable, Sendable {
    /// A fish species.
    case species
    /// A plant kind.
    case plant
    /// A decor kind.
    case decor
    /// A starter habitat.
    case habitat
    /// The catalog document as a whole (unreadable JSON).
    case catalog
}

/// One refused catalog item: its kind, its id (empty when it had none) and the reason.
public struct CatalogRefusal: Codable, Equatable, Sendable {
    /// The kind of the refused item.
    public var kind: CatalogItemKind
    /// The refused item's id, or "" when it had no readable id.
    public var id: String
    /// Why it was refused.
    public var error: CatalogError

    /// Creates a refusal record.
    public init(kind: CatalogItemKind, id: String, error: CatalogError) {
        self.kind = kind; self.id = id; self.error = error
    }
}

extension SpeciesCatalog {
    /// The catalog as JSON with sorted keys (deterministic bytes for equal catalogs).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Every value of a catalog is a string, an integer, a finite double or a list of them, so encoding succeeds;
        // a non-finite number (only possible in a hand-built catalog) gives empty data rather than a crash.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Decodes a catalog from `data`, keeping every valid item and naming every refused one (see the file header for
    /// the checks and their order). Unreadable JSON gives an empty catalog and one `catalog` refusal.
    public static func decode(_ data: Data) -> (catalog: SpeciesCatalog, refused: [CatalogRefusal]) {
        var refused: [CatalogRefusal] = []
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return (SpeciesCatalog(species: [], plants: [], habitats: [], decor: []),
                    [CatalogRefusal(kind: .catalog, id: "catalog", error: .unknownShape)])
        }
        var species: [FishSpecies] = []
        for item in CatalogDecoder.items(root["species"]) {
            switch CatalogDecoder.parseSpecies(item) {
            case .success(let value) where species.contains(where: { $0.id == value.id }):
                refused.append(CatalogRefusal(kind: .species, id: value.id, error: .unknownReference))
            case .success(let value): species.append(value)
            case .failure(let error): refused.append(CatalogRefusal(kind: .species, id: CatalogDecoder.id(item),
                                                                    error: error))
            }
        }
        var plants: [PlantKind] = []
        for item in CatalogDecoder.items(root["plants"]) {
            switch CatalogDecoder.parsePlant(item) {
            case .success(let value) where plants.contains(where: { $0.id == value.id }):
                refused.append(CatalogRefusal(kind: .plant, id: value.id, error: .unknownReference))
            case .success(let value): plants.append(value)
            case .failure(let error): refused.append(CatalogRefusal(kind: .plant, id: CatalogDecoder.id(item),
                                                                    error: error))
            }
        }
        var decor: [DecorKind] = []
        for item in CatalogDecoder.items(root["decor"]) {
            switch CatalogDecoder.parseDecor(item) {
            case .success(let value) where decor.contains(where: { $0.id == value.id }):
                refused.append(CatalogRefusal(kind: .decor, id: value.id, error: .unknownReference))
            case .success(let value): decor.append(value)
            case .failure(let error): refused.append(CatalogRefusal(kind: .decor, id: CatalogDecoder.id(item),
                                                                    error: error))
            }
        }
        var habitats: [StarterHabitat] = []
        let speciesIds = Set(species.map(\.id)), plantIds = Set(plants.map(\.id)), decorIds = Set(decor.map(\.id))
        for item in CatalogDecoder.items(root["habitats"]) {
            switch CatalogDecoder.parseHabitat(item, speciesIds: speciesIds, plantIds: plantIds,
                                               decorIds: decorIds) {
            case .success(let value) where habitats.contains(where: { $0.id == value.id }):
                refused.append(CatalogRefusal(kind: .habitat, id: value.id, error: .unknownReference))
            case .success(let value): habitats.append(value)
            case .failure(let error): refused.append(CatalogRefusal(kind: .habitat, id: CatalogDecoder.id(item),
                                                                    error: error))
            }
        }
        return (SpeciesCatalog(species: species, plants: plants, habitats: habitats, decor: decor), refused)
    }
}

/// The validation rules of catalog items, shared by the decoder and usable on hand-built items.
public enum CatalogDecoder {
    /// The license problem of an item with `author` and `license`, or nil when both are present and allowed.
    public static func licenseError(author: String, license: String) -> CatalogError? {
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty || license.isEmpty { return .missingLicense }
        return SpeciesCatalog.allowedLicenses.contains(license) ? nil : .unsupportedLicense
    }

    /// The first problem of `species` (license, then numbers), or nil when it is valid.
    public static func check(_ species: FishSpecies) -> CatalogError? {
        if let error = licenseError(author: species.author, license: species.license) { return error }
        let numbers = [species.length, species.cruiseSpeed, species.maxSpeed, species.turnRate]
        guard numbers.allSatisfy(\.isFinite), species.bodyColor.isValid, species.finColor.isValid,
              SpeciesCatalog.lengthRange.contains(species.length),
              species.cruiseSpeed > 0, species.cruiseSpeed <= species.maxSpeed,
              species.maxSpeed <= SpeciesCatalog.speedLimit,
              species.turnRate > 0, species.turnRate <= SpeciesCatalog.turnRateLimit else { return .invalidNumber }
        return nil
    }

    /// The first problem of `plant` (license, then numbers), or nil when it is valid.
    public static func check(_ plant: PlantKind) -> CatalogError? {
        if let error = licenseError(author: plant.author, license: plant.license) { return error }
        guard plant.height.isFinite, SpeciesCatalog.heightRange.contains(plant.height), plant.color.isValid else {
            return .invalidNumber
        }
        return nil
    }

    /// The first problem of `decor` (license, then numbers: size in ``DecorKind/sizeRange``, valid colour), or nil
    /// when it is valid.
    public static func check(_ decor: DecorKind) -> CatalogError? {
        if let error = licenseError(author: decor.author, license: decor.license) { return error }
        guard decor.size.isFinite, DecorKind.sizeRange.contains(decor.size), decor.color.isValid else {
            return .invalidNumber
        }
        return nil
    }

    /// True when `spot`'s numbers are valid: a finite position inside the tank (x 0…16, y 0…9), a finite rotation in
    /// ``DecorSpot/rotationRange`` and a finite scale in ``DecorSpot/scaleRange``. The kind is not checked here.
    public static func isValid(_ spot: DecorSpot) -> Bool {
        let p = spot.position
        return p.isFinite && p.x >= 0 && p.x <= SwimBounds.tankWidth && p.y >= 0 && p.y <= SwimBounds.tankHeight
            && spot.rotation.isFinite && DecorSpot.rotationRange.contains(spot.rotation)
            && spot.scale.isFinite && DecorSpot.scaleRange.contains(spot.scale)
    }

    /// The first problem of `habitat` against the known species, plant and decor ids (license, numbers, fish total,
    /// references), or nil when it is valid. Decor spots are always checked for count (≤ 12) and numbers; their kinds
    /// are checked against `decorIds` when it is given (nil skips that reference check).
    public static func check(_ habitat: StarterHabitat, speciesIds: Set<String>, plantIds: Set<String>,
                             decorIds: Set<String>? = nil) -> CatalogError? {
        if let error = licenseError(author: habitat.author, license: habitat.license) { return error }
        let bounds = SwimBounds.standard
        guard habitat.waterColor.isValid, !habitat.species.isEmpty,
              habitat.species.allSatisfy({ $0.count >= 1 }),
              habitat.plants.count <= HabitatDocument.maxPlants,
              habitat.plants.allSatisfy({ $0.x.isFinite && $0.x >= bounds.minX && $0.x <= bounds.maxX }),
              habitat.decor.count <= HabitatDocument.maxDecor,
              habitat.decor.allSatisfy(isValid) else {
            return .invalidNumber
        }
        if habitat.fishCount > HabitatDocument.maxFish { return .tooManyFish }
        guard habitat.species.allSatisfy({ speciesIds.contains($0.speciesId) }),
              habitat.plants.allSatisfy({ plantIds.contains($0.plantId) }) else { return .unknownReference }
        if let decorIds, !habitat.decor.allSatisfy({ decorIds.contains($0.decorId) }) { return .unknownReference }
        return nil
    }

    // MARK: - Parsing (JSON objects to typed items)

    /// The JSON objects of a list value; a missing list is empty, and a non-object element becomes an empty object
    /// (refused as `unknown-shape`).
    static func items(_ value: Any?) -> [[String: Any]] {
        guard let list = value as? [Any] else { return [] }
        return list.map { ($0 as? [String: Any]) ?? [:] }
    }

    /// The item's string id, or "".
    static func id(_ item: [String: Any]) -> String { (item["id"] as? String) ?? "" }

    /// A finite double, or nil.
    static func number(_ value: Any?) -> Double? {
        guard let number = value as? Double, number.isFinite else { return nil }
        return number
    }

    /// An integer, or nil (fractional numbers are not integers).
    static func integer(_ value: Any?) -> Int? { value as? Int }

    /// A colour object with r, g, b and a, or nil.
    static func color(_ value: Any?) -> RGBA? {
        guard let object = value as? [String: Any], let r = number(object["r"]), let g = number(object["g"]),
              let b = number(object["b"]), let a = number(object["a"]) else { return nil }
        return RGBA(r, g, b, a)
    }

    /// The id, name, author and license of an item, or `unknown-shape` / a license error.
    private static func header(_ item: [String: Any]) -> Result<(id: String, name: String, author: String,
                                                                  license: String), CatalogError> {
        guard let id = item["id"] as? String, !id.isEmpty, let name = item["name"] as? String else {
            return .failure(.unknownShape)
        }
        return .success((id, name, (item["author"] as? String) ?? "", (item["license"] as? String) ?? ""))
    }

    static func parseSpecies(_ item: [String: Any]) -> Result<FishSpecies, CatalogError> {
        let head: (id: String, name: String, author: String, license: String)
        switch header(item) { case .success(let h): head = h; case .failure(let e): return .failure(e) }
        guard let raw = item["shape"] as? String, let shape = FishShape(rawValue: raw) else {
            return .failure(.unknownShape)
        }
        if let error = licenseError(author: head.author, license: head.license) { return .failure(error) }
        guard let body = color(item["bodyColor"]), let fin = color(item["finColor"]),
              let length = number(item["length"]), let cruise = number(item["cruiseSpeed"]),
              let maxSpeed = number(item["maxSpeed"]), let turn = number(item["turnRate"]) else {
            return .failure(.invalidNumber)
        }
        let species = FishSpecies(id: head.id, name: head.name, shape: shape, bodyColor: body, finColor: fin,
                                  length: length, cruiseSpeed: cruise, maxSpeed: maxSpeed, turnRate: turn,
                                  author: head.author, license: head.license)
        if let error = check(species) { return .failure(error) }
        return .success(species)
    }

    static func parsePlant(_ item: [String: Any]) -> Result<PlantKind, CatalogError> {
        let head: (id: String, name: String, author: String, license: String)
        switch header(item) { case .success(let h): head = h; case .failure(let e): return .failure(e) }
        guard let raw = item["shape"] as? String, let shape = PlantShape(rawValue: raw) else {
            return .failure(.unknownShape)
        }
        if let error = licenseError(author: head.author, license: head.license) { return .failure(error) }
        guard let tint = color(item["color"]), let height = number(item["height"]) else {
            return .failure(.invalidNumber)
        }
        let plant = PlantKind(id: head.id, name: head.name, shape: shape, color: tint, height: height,
                              author: head.author, license: head.license)
        if let error = check(plant) { return .failure(error) }
        return .success(plant)
    }

    static func parseDecor(_ item: [String: Any]) -> Result<DecorKind, CatalogError> {
        let head: (id: String, name: String, author: String, license: String)
        switch header(item) { case .success(let h): head = h; case .failure(let e): return .failure(e) }
        guard let raw = item["shape"] as? String, let shape = DecorShape(rawValue: raw) else {
            return .failure(.unknownShape)
        }
        if let error = licenseError(author: head.author, license: head.license) { return .failure(error) }
        guard let tint = color(item["color"]), let size = number(item["size"]) else {
            return .failure(.invalidNumber)
        }
        let decor = DecorKind(id: head.id, name: head.name, shape: shape, color: tint, size: size,
                              author: head.author, license: head.license)
        if let error = check(decor) { return .failure(error) }
        return .success(decor)
    }

    static func parseHabitat(_ item: [String: Any], speciesIds: Set<String>, plantIds: Set<String>,
                             decorIds: Set<String>) -> Result<StarterHabitat, CatalogError> {
        let head: (id: String, name: String, author: String, license: String)
        switch header(item) { case .success(let h): head = h; case .failure(let e): return .failure(e) }
        guard let speciesList = item["species"] as? [Any], let plantList = item["plants"] as? [Any] else {
            return .failure(.unknownShape)
        }
        if let error = licenseError(author: head.author, license: head.license) { return .failure(error) }
        guard let water = color(item["waterColor"]) else { return .failure(.invalidNumber) }
        var species: [SpeciesCount] = []
        for entry in speciesList {
            guard let object = entry as? [String: Any], let id = object["speciesId"] as? String else {
                return .failure(.unknownShape)
            }
            guard let count = integer(object["count"]) else { return .failure(.invalidNumber) }
            species.append(SpeciesCount(speciesId: id, count: count))
        }
        var plants: [PlantSpot] = []
        for entry in plantList {
            guard let object = entry as? [String: Any], let id = object["plantId"] as? String else {
                return .failure(.unknownShape)
            }
            guard let x = number(object["x"]) else { return .failure(.invalidNumber) }
            plants.append(PlantSpot(plantId: id, x: x))
        }
        var decor: [DecorSpot] = []
        if let raw = item["decor"] {
            guard let decorList = raw as? [Any] else { return .failure(.unknownShape) }
            for entry in decorList {
                guard let object = entry as? [String: Any], let id = object["decorId"] as? String else {
                    return .failure(.unknownShape)
                }
                guard let position = object["position"] as? [String: Any], let x = number(position["x"]),
                      let y = number(position["y"]), let rotation = number(object["rotation"]),
                      let scale = number(object["scale"]) else { return .failure(.invalidNumber) }
                decor.append(DecorSpot(decorId: id, position: Vec2(x, y), rotation: rotation, scale: scale))
            }
        }
        let habitat = StarterHabitat(id: head.id, name: head.name, waterColor: water, species: species,
                                     plants: plants, author: head.author, license: head.license, decor: decor)
        if let error = check(habitat, speciesIds: speciesIds, plantIds: plantIds, decorIds: decorIds) {
            return .failure(error)
        }
        return .success(habitat)
    }
}
