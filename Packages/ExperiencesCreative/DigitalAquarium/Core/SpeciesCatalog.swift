// SpeciesCatalog — feature 068 (A09-P01) T-A09-102 (FR-A09-102, FR-A09-103; clarifications 2, 3 and 4; research
// D2, D3; data-model "FishSpecies", "PlantKind", "StarterHabitat"). The content the aquarium ships with, as Swift
// data: fish species (body shape, colours, length, cruise and maximum speed, turn rate), plant kinds (shape, colour,
// height) and the two starter habitats ("Reef", "Kelp") that combine them by id. Every item carries its author and
// license; the allowed licenses are exactly ["MIT"] (the repository's license, author "VisualCore project"). Names are
// descriptive, never brand or animal-care names. Coordinates are habitat units: the tank is 16 × 9 (x 0…16, y 0…9,
// y up).
// Feature 069 (A09-P02) T-A09-203 (FR-A09-212; clarification 4; research D4; data-model "DecorShape", "DecorKind",
// "DecorSpot"): decor kinds (rock and shell shapes, colour, size 0.3…2.0, author, license) and per-habitat starter
// decor spots (kind, position inside the tank, rotation −π…π, scale 0.5…2.0, at most 12). A catalog or habitat JSON
// without "decor" keys (written before this feature) decodes with no decor.
// The JSON codec and the validating decoder are in `CatalogDecoder.swift`; the license audit in `LicenseAudit.swift`.
import Foundation
import VisualCoreMath

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
    public var isValid: Bool {
        [r, g, b, a].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
    }
}

/// The outline a fish body is drawn from.
public enum FishShape: String, Codable, CaseIterable, Sendable {
    /// A rounded body tapering to the tail.
    case teardrop
    /// A long, narrow body.
    case slender
}

/// The form a plant is drawn as.
public enum PlantShape: String, Codable, CaseIterable, Sendable {
    /// A swaying ribbon (a polyline of a few segments).
    case ribbon
    /// A fan of stems from one base point.
    case fan
}

/// The form a decor piece is drawn as.
public enum DecorShape: String, Codable, CaseIterable, Sendable {
    /// A rounded stone (an irregular closed polygon).
    case rock
    /// A spiral shell.
    case shell
}

/// A fish species of the catalog.
public struct FishSpecies: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the catalog.
    public var id: String
    /// Descriptive display name ("Orange striped fish").
    public var name: String
    /// The body outline.
    public var shape: FishShape
    /// The body colour.
    public var bodyColor: RGBA
    /// The fin and tail colour.
    public var finColor: RGBA
    /// Body length in habitat units, in ``SpeciesCatalog/lengthRange``.
    public var length: Double
    /// The speed a fish eases toward, in units per second (> 0, ≤ ``maxSpeed``).
    public var cruiseSpeed: Double
    /// The highest speed, in units per second (≥ ``cruiseSpeed``, ≤ ``SpeciesCatalog/speedLimit``).
    public var maxSpeed: Double
    /// The largest random turn per second, in radians (> 0, ≤ ``SpeciesCatalog/turnRateLimit``).
    public var turnRate: Double
    /// Who made this item.
    public var author: String
    /// The license of this item; one of ``SpeciesCatalog/allowedLicenses``.
    public var license: String

    /// Creates a species from all of its fields; validity is checked by the catalog decoder.
    public init(id: String, name: String, shape: FishShape, bodyColor: RGBA, finColor: RGBA, length: Double,
                cruiseSpeed: Double, maxSpeed: Double, turnRate: Double, author: String, license: String) {
        self.id = id; self.name = name; self.shape = shape
        self.bodyColor = bodyColor; self.finColor = finColor
        self.length = length; self.cruiseSpeed = cruiseSpeed; self.maxSpeed = maxSpeed; self.turnRate = turnRate
        self.author = author; self.license = license
    }
}

/// A plant kind of the catalog.
public struct PlantKind: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the catalog.
    public var id: String
    /// Descriptive display name.
    public var name: String
    /// The drawn form.
    public var shape: PlantShape
    /// The plant colour.
    public var color: RGBA
    /// Height in habitat units, in ``SpeciesCatalog/heightRange``.
    public var height: Double
    /// Who made this item.
    public var author: String
    /// The license of this item; one of ``SpeciesCatalog/allowedLicenses``.
    public var license: String

    /// Creates a plant kind from all of its fields; validity is checked by the catalog decoder.
    public init(id: String, name: String, shape: PlantShape, color: RGBA, height: Double, author: String,
                license: String) {
        self.id = id; self.name = name; self.shape = shape; self.color = color; self.height = height
        self.author = author; self.license = license
    }
}

/// A decor kind of the catalog: a rock or a shell drawn procedurally.
public struct DecorKind: Codable, Equatable, Sendable, Identifiable {
    /// Allowed decor sizes (the drawn width at scale 1) in habitat units.
    public static let sizeRange: ClosedRange<Double> = 0.3...2.0

    /// Kebab-case identifier, unique among the catalog's decor kinds.
    public var id: String
    /// Descriptive display name ("Round rock").
    public var name: String
    /// The drawn form.
    public var shape: DecorShape
    /// The decor colour.
    public var color: RGBA
    /// The drawn width at scale 1 in habitat units, in ``sizeRange``.
    public var size: Double
    /// Who made this item.
    public var author: String
    /// The license of this item; one of ``SpeciesCatalog/allowedLicenses``.
    public var license: String

    /// Creates a decor kind from all of its fields; validity is checked by the catalog decoder.
    public init(id: String, name: String, shape: DecorShape, color: RGBA, size: Double, author: String,
                license: String) {
        self.id = id; self.name = name; self.shape = shape; self.color = color; self.size = size
        self.author = author; self.license = license
    }
}

/// A decor piece of one kind placed in a starter habitat.
public struct DecorSpot: Codable, Equatable, Sendable {
    /// Allowed rotations in radians.
    public static let rotationRange: ClosedRange<Double> = -Double.pi...Double.pi
    /// Allowed scales.
    public static let scaleRange: ClosedRange<Double> = 0.5...2.0

    /// The decor kind id (must name a catalog decor kind).
    public var decorId: String
    /// The position in habitat units, inside the tank (x 0…16, y 0…9).
    public var position: Vec2
    /// The rotation in radians, in ``rotationRange``.
    public var rotation: Double
    /// The scale, in ``scaleRange``.
    public var scale: Double

    /// Creates a decor spot of `decorId` at `position` with `rotation` (radians) and `scale`.
    public init(decorId: String, position: Vec2, rotation: Double = 0, scale: Double = 1) {
        self.decorId = decorId; self.position = position; self.rotation = rotation; self.scale = scale
    }
}

/// A number of fish of one species in a starter habitat.
public struct SpeciesCount: Codable, Equatable, Sendable {
    /// The species id (must name a catalog species).
    public var speciesId: String
    /// How many fish of that species, at least 1.
    public var count: Int

    /// Creates an entry naming `speciesId` `count` times.
    public init(speciesId: String, count: Int) { self.speciesId = speciesId; self.count = count }
}

/// A plant of one kind at a position along the gravel in a starter habitat.
public struct PlantSpot: Codable, Equatable, Sendable {
    /// The plant kind id (must name a catalog plant).
    public var plantId: String
    /// The x position in habitat units, inside the swim bounds' x range.
    public var x: Double

    /// Creates a plant spot of `plantId` at `x`.
    public init(plantId: String, x: Double) { self.plantId = plantId; self.x = x }
}

/// A starter habitat: a water colour, fish by species, plants by kind and position, and starter decor.
public struct StarterHabitat: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the catalog.
    public var id: String
    /// Display name ("Reef").
    public var name: String
    /// The water colour.
    public var waterColor: RGBA
    /// The fish, by species; the total is 1…``HabitatDocument/maxFish``.
    public var species: [SpeciesCount]
    /// The plants, by kind and x position; at most ``HabitatDocument/maxPlants``.
    public var plants: [PlantSpot]
    /// The starter decor pieces; at most ``HabitatDocument/maxDecor``.
    public var decor: [DecorSpot]
    /// Who made this item.
    public var author: String
    /// The license of this item; one of ``SpeciesCatalog/allowedLicenses``.
    public var license: String

    /// Creates a starter habitat from all of its fields (`decor` defaults to none); validity is checked by the
    /// catalog decoder.
    public init(id: String, name: String, waterColor: RGBA, species: [SpeciesCount], plants: [PlantSpot],
                author: String, license: String, decor: [DecorSpot] = []) {
        self.id = id; self.name = name; self.waterColor = waterColor; self.species = species; self.plants = plants
        self.decor = decor; self.author = author; self.license = license
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, waterColor, species, plants, decor, author, license
    }

    /// Decodes a habitat; a missing `decor` key (a habitat written before decor existed) gives no decor.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        waterColor = try c.decode(RGBA.self, forKey: .waterColor)
        species = try c.decode([SpeciesCount].self, forKey: .species)
        plants = try c.decode([PlantSpot].self, forKey: .plants)
        decor = try c.decodeIfPresent([DecorSpot].self, forKey: .decor) ?? []
        author = try c.decode(String.self, forKey: .author)
        license = try c.decode(String.self, forKey: .license)
    }

    /// The total number of fish over all species entries; each entry counts at most ``HabitatDocument/maxFish`` + 1
    /// and a negative count as 0, so the sum never overflows and any total above the maximum still reads as too many.
    public var fishCount: Int {
        species.reduce(0) { $0 + min(max($1.count, 0), HabitatDocument.maxFish + 1) }
    }
}

/// The aquarium's content: fish species, plant kinds, decor kinds and starter habitats, each with author and license.
public struct SpeciesCatalog: Codable, Equatable, Sendable {
    /// The only licenses a catalog item may carry.
    public static let allowedLicenses: [String] = ["MIT"]
    /// The author of every bundled item.
    public static let projectAuthor = "VisualCore project"
    /// Allowed fish body lengths in habitat units.
    public static let lengthRange: ClosedRange<Double> = 0.3...1.5
    /// The highest allowed maximum speed in units per second.
    public static let speedLimit = 4.0
    /// The highest allowed turn rate in radians per second.
    public static let turnRateLimit = 2 * Double.pi
    /// Allowed plant heights in habitat units.
    public static let heightRange: ClosedRange<Double> = 0.5...6

    /// The fish species.
    public var species: [FishSpecies]
    /// The plant kinds.
    public var plants: [PlantKind]
    /// The decor kinds.
    public var decor: [DecorKind]
    /// The starter habitats; ``HabitatDocument/starter(_:catalog:random:)`` indexes into this list.
    public var habitats: [StarterHabitat]

    /// Creates a catalog from its lists (`decor` defaults to none; no validation; ``decode(_:)`` validates).
    public init(species: [FishSpecies], plants: [PlantKind], habitats: [StarterHabitat], decor: [DecorKind] = []) {
        self.species = species; self.plants = plants; self.decor = decor; self.habitats = habitats
    }

    private enum CodingKeys: String, CodingKey { case species, plants, decor, habitats }

    /// Decodes a catalog; a missing `decor` key (a catalog written before decor existed) gives no decor kinds.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decode([FishSpecies].self, forKey: .species)
        plants = try c.decode([PlantKind].self, forKey: .plants)
        decor = try c.decodeIfPresent([DecorKind].self, forKey: .decor) ?? []
        habitats = try c.decode([StarterHabitat].self, forKey: .habitats)
    }

    /// The species with `id`, if any.
    public func species(id: String) -> FishSpecies? { species.first { $0.id == id } }
    /// The plant kind with `id`, if any.
    public func plant(id: String) -> PlantKind? { plants.first { $0.id == id } }
    /// The decor kind with `id`, if any.
    public func decor(id: String) -> DecorKind? { decor.first { $0.id == id } }

    /// The bundled content: four fish species, four plant kinds and the two starter habitats "Reef" (orange striped
    /// fish and blue fish with yellow tails) and "Kelp" (silver fish and gold fish), each with two species, 6…10 fish
    /// and 4…6 plants; three decor kinds ("Round rock", "Flat rock", "Spiral shell") with three starter pieces in
    /// Reef and two in Kelp, resting on the gravel; every item is by "VisualCore project" under "MIT".
    public static let bundled: SpeciesCatalog = {
        let author = projectAuthor, license = "MIT"
        let species = [
            FishSpecies(id: "orange-striped-fish", name: "Orange striped fish", shape: .teardrop,
                        bodyColor: RGBA(1.0, 0.55, 0.15), finColor: RGBA(0.98, 0.96, 0.92), length: 0.7,
                        cruiseSpeed: 1.0, maxSpeed: 1.8, turnRate: 1.2, author: author, license: license),
            FishSpecies(id: "blue-yellowtail-fish", name: "Blue fish with yellow tail", shape: .teardrop,
                        bodyColor: RGBA(0.15, 0.35, 0.9), finColor: RGBA(1.0, 0.85, 0.2), length: 0.9,
                        cruiseSpeed: 1.2, maxSpeed: 2.2, turnRate: 1.0, author: author, license: license),
            FishSpecies(id: "silver-slender-fish", name: "Silver slender fish", shape: .slender,
                        bodyColor: RGBA(0.78, 0.8, 0.85), finColor: RGBA(0.6, 0.65, 0.72), length: 1.0,
                        cruiseSpeed: 1.4, maxSpeed: 2.6, turnRate: 0.9, author: author, license: license),
            FishSpecies(id: "gold-round-fish", name: "Gold round fish", shape: .teardrop,
                        bodyColor: RGBA(1.0, 0.78, 0.2), finColor: RGBA(1.0, 0.6, 0.15), length: 0.6,
                        cruiseSpeed: 0.8, maxSpeed: 1.5, turnRate: 1.4, author: author, license: license),
        ]
        let plants = [
            PlantKind(id: "green-ribbon-weed", name: "Green ribbon weed", shape: .ribbon,
                      color: RGBA(0.2, 0.65, 0.3), height: 3.0, author: author, license: license),
            PlantKind(id: "red-fan-plant", name: "Red fan plant", shape: .fan,
                      color: RGBA(0.75, 0.25, 0.3), height: 1.6, author: author, license: license),
            PlantKind(id: "tall-brown-ribbon", name: "Tall brown ribbon", shape: .ribbon,
                      color: RGBA(0.55, 0.5, 0.2), height: 5.5, author: author, license: license),
            PlantKind(id: "purple-fan-plant", name: "Purple fan plant", shape: .fan,
                      color: RGBA(0.55, 0.3, 0.7), height: 2.2, author: author, license: license),
        ]
        let decor = [
            DecorKind(id: "round-rock", name: "Round rock", shape: .rock, color: RGBA(0.52, 0.5, 0.47), size: 0.9,
                      author: author, license: license),
            DecorKind(id: "flat-rock", name: "Flat rock", shape: .rock, color: RGBA(0.42, 0.4, 0.36), size: 1.2,
                      author: author, license: license),
            DecorKind(id: "spiral-shell", name: "Spiral shell", shape: .shell, color: RGBA(0.93, 0.85, 0.74),
                      size: 0.4, author: author, license: license),
        ]
        let habitats = [
            StarterHabitat(id: "reef", name: "Reef", waterColor: RGBA(0.05, 0.45, 0.65),
                           species: [SpeciesCount(speciesId: "orange-striped-fish", count: 4),
                                     SpeciesCount(speciesId: "blue-yellowtail-fish", count: 3)],
                           plants: [PlantSpot(plantId: "green-ribbon-weed", x: 2.0),
                                    PlantSpot(plantId: "red-fan-plant", x: 4.5),
                                    PlantSpot(plantId: "purple-fan-plant", x: 8.0),
                                    PlantSpot(plantId: "green-ribbon-weed", x: 11.0),
                                    PlantSpot(plantId: "red-fan-plant", x: 13.5)],
                           author: author, license: license,
                           decor: [DecorSpot(decorId: "round-rock", position: Vec2(3.2, 1.2), rotation: 0.3,
                                             scale: 1.2),
                                   DecorSpot(decorId: "spiral-shell", position: Vec2(9.5, 1.05), rotation: -0.6,
                                             scale: 0.8),
                                   DecorSpot(decorId: "flat-rock", position: Vec2(12.3, 1.3), rotation: 0.15,
                                             scale: 1.5)]),
            StarterHabitat(id: "kelp", name: "Kelp", waterColor: RGBA(0.08, 0.3, 0.32),
                           species: [SpeciesCount(speciesId: "silver-slender-fish", count: 5),
                                     SpeciesCount(speciesId: "gold-round-fish", count: 3)],
                           plants: [PlantSpot(plantId: "tall-brown-ribbon", x: 1.5),
                                    PlantSpot(plantId: "tall-brown-ribbon", x: 4.0),
                                    PlantSpot(plantId: "tall-brown-ribbon", x: 7.5),
                                    PlantSpot(plantId: "green-ribbon-weed", x: 10.0),
                                    PlantSpot(plantId: "tall-brown-ribbon", x: 12.5),
                                    PlantSpot(plantId: "purple-fan-plant", x: 14.5)],
                           author: author, license: license,
                           decor: [DecorSpot(decorId: "flat-rock", position: Vec2(5.8, 1.25), rotation: -0.2,
                                             scale: 1.3),
                                   DecorSpot(decorId: "round-rock", position: Vec2(11.2, 1.4), rotation: 0.9,
                                             scale: 0.9)]),
        ]
        return SpeciesCatalog(species: species, plants: plants, habitats: habitats, decor: decor)
    }()
}
