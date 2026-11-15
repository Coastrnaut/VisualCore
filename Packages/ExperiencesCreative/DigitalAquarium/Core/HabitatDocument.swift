// HabitatDocument — feature 068 (A09-P01) T-A09-102 (FR-A09-101, FR-A09-110; clarifications 1, 2 and 5; research D1,
// D2; data-model "SwimBounds", "FishAgent", "HabitatDocument", schema 1). The versioned document that describes one
// aquarium: which starter habitat it came from, the water colour, the swim bounds, the plants, the fish (species,
// position, velocity, heading, animation phase), the decor and the lighting level. Habitat units throughout: the tank
// is 16 × 9 (x 0…16, y 0…9, y up), fish swim inside x 0.5…15.5, y 1.5…8.5 (above the gravel band), plants stand on
// y 1.0.
// A habitat holds at most 24 fish, 12 plants and 12 decor items.
// Schema 2 — feature 069 (A09-P02) T-A09-203 (FR-A09-212; clarification 4; research D4; data-model "FishAgent",
// "DecorPlacement", "HabitatDocument"): each fish keeps its smoothed `turn` (radians per second, for drawing the bend);
// each decor piece has a rotation (−π…π) and a scale (0.5…2.0); starter documents carry the habitat's starter decor.
// A schema-1 document decodes with turn 0, rotation 0 and scale 1 and is brought to schema 2 by `migrated(catalog:)`
// (the habitat's starter decor is added when it has none).
// Schema 3 — feature 070 (A09-P03) T-A09-302 (FR-A09-320; clarification 4; research D3; data-model "FoodPellet",
// "HabitatDocument"): the document holds the food pellets in the water (`food`, at most 12, each finite and inside the
// swim bounds; a missing key decodes as none). `migrated(catalog:)` brings schemas 1 and 2 to 3 (schema 1 also gets
// the starter decor when it has none; schema 2 keeps its decor); starter documents have no food; validation accepts
// schema 3 only.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The rectangle fish stay inside, in habitat units (inclusive on every side).
public struct SwimBounds: Codable, Equatable, Sendable {
    /// The tank width in habitat units.
    public static let tankWidth = 16.0
    /// The tank height in habitat units.
    public static let tankHeight = 9.0
    /// The standard bounds: x 0.5…15.5, y 1.5…8.5.
    public static let standard = SwimBounds(minX: 0.5, maxX: 15.5, minY: 1.5, maxY: 8.5)

    /// Left edge.
    public var minX: Double
    /// Right edge.
    public var maxX: Double
    /// Bottom edge (above the gravel band).
    public var minY: Double
    /// Top edge (below the water surface).
    public var maxY: Double

    /// Creates bounds from their four edges; validity is checked by ``isValid``.
    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY
    }

    /// True when every edge is finite, each minimum is below its maximum and the rectangle lies inside the tank.
    public var isValid: Bool {
        [minX, maxX, minY, maxY].allSatisfy(\.isFinite) && minX < maxX && minY < maxY
            && minX >= 0 && maxX <= Self.tankWidth && minY >= 0 && maxY <= Self.tankHeight
    }

    /// True when `point` is finite and inside the bounds (edges included).
    public func contains(_ point: Vec2) -> Bool {
        point.isFinite && point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// One fish of a habitat.
public struct FishAgent: Codable, Equatable, Sendable {
    /// The catalog species id.
    public var speciesId: String
    /// Position in habitat units, inside the habitat's swim bounds.
    public var position: Vec2
    /// Velocity in units per second; its length never exceeds the species' maximum speed.
    public var velocity: Vec2
    /// Heading in radians (−π…π, 0 = swimming right, y up); follows the velocity.
    public var heading: Double
    /// Tail-swing phase in radians, 0 ≤ phase < 2π; advances with speed.
    public var animationPhase: Double
    /// The smoothed heading change in radians per second (positive = turning left, y up); finite. Used only for
    /// drawing the body bend; a schema-1 fish decodes with 0.
    public var turn: Double

    /// Creates a fish from all of its fields (`turn` defaults to 0); validity is checked by
    /// ``HabitatDocument/validate(catalog:)``.
    public init(speciesId: String, position: Vec2, velocity: Vec2, heading: Double, animationPhase: Double,
                turn: Double = 0) {
        self.speciesId = speciesId; self.position = position; self.velocity = velocity
        self.heading = heading; self.animationPhase = animationPhase; self.turn = turn
    }

    private enum CodingKeys: String, CodingKey { case speciesId, position, velocity, heading, animationPhase, turn }

    /// Decodes a fish; a missing `turn` (schema 1) decodes as 0.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speciesId = try c.decode(String.self, forKey: .speciesId)
        position = try c.decode(Vec2.self, forKey: .position)
        velocity = try c.decode(Vec2.self, forKey: .velocity)
        heading = try c.decode(Double.self, forKey: .heading)
        animationPhase = try c.decode(Double.self, forKey: .animationPhase)
        turn = try c.decodeIfPresent(Double.self, forKey: .turn) ?? 0
    }
}

/// One plant of a habitat: a catalog plant kind standing on the gravel at `x`.
public struct PlantPlacement: Codable, Equatable, Sendable {
    /// The catalog plant kind id.
    public var kindId: String
    /// The x position of the plant's base in habitat units (its base is at ``HabitatDocument/plantBaseY``).
    public var x: Double

    /// Creates a plant placement of `kindId` at `x`.
    public init(kindId: String, x: Double) { self.kindId = kindId; self.x = x }
}

/// One decor piece of a habitat: a catalog decor kind at a position, rotated and scaled.
public struct DecorPlacement: Codable, Equatable, Sendable {
    /// The decor kind id (non-empty; with a catalog it must name a catalog decor kind).
    public var kindId: String
    /// The position in habitat units, inside the tank (x 0…16, y 0…9).
    public var position: Vec2
    /// The rotation in radians, in ``DecorSpot/rotationRange`` (−π…π); a schema-1 piece decodes with 0.
    public var rotation: Double
    /// The scale, in ``DecorSpot/scaleRange`` (0.5…2.0); a schema-1 piece decodes with 1.
    public var scale: Double

    /// Creates a decor placement of `kindId` at `position` with `rotation` (radians, default 0) and `scale`
    /// (default 1).
    public init(kindId: String, position: Vec2, rotation: Double = 0, scale: Double = 1) {
        self.kindId = kindId; self.position = position; self.rotation = rotation; self.scale = scale
    }

    /// The placement of a catalog starter decor spot (same kind, position, rotation and scale).
    public init(_ spot: DecorSpot) {
        self.init(kindId: spot.decorId, position: spot.position, rotation: spot.rotation, scale: spot.scale)
    }

    private enum CodingKeys: String, CodingKey { case kindId, position, rotation, scale }

    /// Decodes a decor piece; a missing `rotation` decodes as 0 and a missing `scale` as 1 (schema 1).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kindId = try c.decode(String.self, forKey: .kindId)
        position = try c.decode(Vec2.self, forKey: .position)
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1
    }
}

/// One food pellet in the water (schema 3).
public struct FoodPellet: Codable, Equatable, Sendable {
    /// The pellet's centre in habitat units; finite and inside the habitat's swim bounds.
    public var position: Vec2

    /// Creates a pellet at `position`; validity is checked by ``HabitatDocument/validate(catalog:)``.
    public init(position: Vec2) { self.position = position }
}

/// The versioned description of one aquarium (schema 3).
public struct HabitatDocument: Codable, Equatable, Sendable {
    /// The document schema written by this version (3: food pellets; 2: fish `turn`, decor rotation and scale,
    /// starter decor).
    public static let currentSchema = 3
    /// The most fish a habitat may hold.
    public static let maxFish = 24
    /// The most plants a habitat may hold.
    public static let maxPlants = 12
    /// The most decor items a habitat may hold.
    public static let maxDecor = 12
    /// The most food pellets a habitat may hold in the water (``Feeding/maxPellets`` is this value).
    public static let maxFood = 12
    /// The lighting levels: 0 dim, 1 soft, 2 bright.
    public static let lightingRange: ClosedRange<Int> = 0...2
    /// The lighting level of a new starter document (soft).
    public static let defaultLighting = 1
    /// The y coordinate plants stand on, in habitat units.
    public static let plantBaseY = 1.0

    /// The document schema (3; a decoded schema-1 or schema-2 document is brought to 3 by ``migrated(catalog:)``).
    public var schema: Int
    /// The index of the starter habitat in the catalog's `habitats`.
    public var habitatIndex: Int
    /// The starter habitat's id.
    public var habitatId: String
    /// The water colour.
    public var waterColor: RGBA
    /// The rectangle fish stay inside.
    public var bounds: SwimBounds
    /// The plants.
    public var plants: [PlantPlacement]
    /// The fish.
    public var fish: [FishAgent]
    /// The decor pieces; at most ``maxDecor``.
    public var decor: [DecorPlacement]
    /// The lighting level, in ``lightingRange``.
    public var lighting: Int
    /// The food pellets in the water; at most ``maxFood``, each inside ``bounds``.
    public var food: [FoodPellet]

    /// Creates a document from all of its fields (`food` defaults to none); validity is checked by
    /// ``validate(catalog:)``.
    public init(schema: Int = HabitatDocument.currentSchema, habitatIndex: Int, habitatId: String, waterColor: RGBA,
                bounds: SwimBounds = .standard, plants: [PlantPlacement], fish: [FishAgent],
                decor: [DecorPlacement] = [], lighting: Int = HabitatDocument.defaultLighting,
                food: [FoodPellet] = []) {
        self.schema = schema; self.habitatIndex = habitatIndex; self.habitatId = habitatId
        self.waterColor = waterColor; self.bounds = bounds; self.plants = plants; self.fish = fish
        self.decor = decor; self.lighting = lighting; self.food = food
    }

    private enum CodingKeys: String, CodingKey {
        case schema, habitatIndex, habitatId, waterColor, bounds, plants, fish, decor, lighting, food
    }

    /// Decodes a document; a missing `food` (schemas 1 and 2) decodes as none.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        habitatIndex = try c.decode(Int.self, forKey: .habitatIndex)
        habitatId = try c.decode(String.self, forKey: .habitatId)
        waterColor = try c.decode(RGBA.self, forKey: .waterColor)
        bounds = try c.decode(SwimBounds.self, forKey: .bounds)
        plants = try c.decode([PlantPlacement].self, forKey: .plants)
        fish = try c.decode([FishAgent].self, forKey: .fish)
        decor = try c.decode([DecorPlacement].self, forKey: .decor)
        lighting = try c.decode(Int.self, forKey: .lighting)
        food = try c.decodeIfPresent([FoodPellet].self, forKey: .food) ?? []
    }

    /// A new document of the catalog's starter habitat `index` (clamped to the catalog's habitats; an empty catalog
    /// gives an empty "none" document): plants at the habitat's x positions, and each fish at a random position inside
    /// the standard bounds with a random heading (mostly level, ±0.4 rad around left or right), moving at its
    /// species' cruise speed, with a random animation phase and `turn` 0. Fish of species missing from the catalog
    /// are skipped. The habitat's starter decor (at most ``maxDecor``) is copied as it is, drawing no random numbers,
    /// so the generator sequence is the same as in schema 1. A starter document has no food.
    public static func starter(_ index: Int, catalog: SpeciesCatalog, random: inout SeededRandom) -> HabitatDocument {
        guard !catalog.habitats.isEmpty else {
            return HabitatDocument(habitatIndex: 0, habitatId: "none", waterColor: RGBA(0.05, 0.3, 0.5),
                                   plants: [], fish: [])
        }
        let chosen = min(max(index, 0), catalog.habitats.count - 1)
        let habitat = catalog.habitats[chosen]
        let bounds = SwimBounds.standard
        var fish: [FishAgent] = []
        for entry in habitat.species {
            guard let species = catalog.species(id: entry.speciesId) else { continue }
            for _ in 0..<max(0, min(entry.count, maxFish - fish.count)) {
                let position = Vec2(random.range(bounds.minX...bounds.maxX), random.range(bounds.minY...bounds.maxY))
                let level = random.range(-0.4...0.4)
                let heading = AquariumSimulation.wrappedAngle(random.double() < 0.5 ? level : Double.pi + level)
                let velocity = Vec2(cos(heading), sin(heading)) * species.cruiseSpeed
                let phase = random.range(0...(2 * Double.pi))
                fish.append(FishAgent(speciesId: species.id, position: position, velocity: velocity,
                                      heading: heading, animationPhase: phase))
            }
        }
        let plants = habitat.plants.prefix(maxPlants).map { PlantPlacement(kindId: $0.plantId, x: $0.x) }
        let decor = habitat.decor.prefix(maxDecor).map { DecorPlacement($0) }
        return HabitatDocument(habitatIndex: chosen, habitatId: habitat.id, waterColor: habitat.waterColor,
                               bounds: bounds, plants: plants, fish: fish, decor: decor)
    }

    /// This document brought to schema 3. A schema-1 document (decoded with turn 0, rotation 0 and scale 1) gets
    /// schema 3, and when it has no decor, the starter decor (at most ``maxDecor``) of the catalog habitat at
    /// `habitatIndex`, if that habitat exists. A schema-2 document gets schema 3 and keeps its decor. Both keep their
    /// fish, plants, lighting, food (decoded as none when the key is missing) and other fields. A document of any
    /// other schema (3, or one this version does not know) is returned unchanged, so validation still judges it.
    public func migrated(catalog: SpeciesCatalog) -> HabitatDocument {
        guard schema == 1 || schema == 2 else { return self }
        var copy = self
        copy.schema = Self.currentSchema
        if schema == 1, copy.decor.isEmpty, catalog.habitats.indices.contains(habitatIndex) {
            copy.decor = catalog.habitats[habitatIndex].decor.prefix(Self.maxDecor).map { DecorPlacement($0) }
        }
        return copy
    }

    /// The document's problems, empty when it is valid: the schema (exactly 3; a schema-1 or schema-2 document must
    /// be ``migrated(catalog:)`` first), the bounds, the water colour, the counts (≤ 24 fish, ≤ 12 plants, ≤ 12 decor,
    /// ≤ 12 food pellets), every food pellet (finite, inside the swim bounds),
    /// every fish (non-empty species, finite numbers including `turn`, position inside the bounds, phase in 0…2π),
    /// every plant (non-empty kind, x finite inside the tank), every decor piece (non-empty kind, position inside the
    /// tank, finite rotation in −π…π, finite scale in 0.5…2.0) and the lighting level (0…2). With a `catalog` it also
    /// checks that the habitat index, the species, the plant kinds and the decor kinds exist and that no fish is
    /// faster than its species' maximum speed.
    public func validate(catalog: SpeciesCatalog? = nil) -> [String] {
        var problems: [String] = []
        if schema != Self.currentSchema { problems.append("schema \(schema) is not \(Self.currentSchema)") }
        if !bounds.isValid { problems.append("swim bounds are invalid") }
        if !waterColor.isValid { problems.append("water colour is invalid") }
        if habitatId.isEmpty { problems.append("habitat id is empty") }
        if fish.count > Self.maxFish { problems.append("\(fish.count) fish exceed \(Self.maxFish)") }
        if plants.count > Self.maxPlants { problems.append("\(plants.count) plants exceed \(Self.maxPlants)") }
        if decor.count > Self.maxDecor { problems.append("\(decor.count) decor items exceed \(Self.maxDecor)") }
        if food.count > Self.maxFood { problems.append("\(food.count) food pellets exceed \(Self.maxFood)") }
        for (i, pellet) in food.enumerated() where !bounds.contains(pellet.position) {
            problems.append("food \(i) is outside the swim bounds")
        }
        if !Self.lightingRange.contains(lighting) { problems.append("lighting \(lighting) is outside 0…2") }
        for (i, agent) in fish.enumerated() {
            if agent.speciesId.isEmpty { problems.append("fish \(i) has no species") }
            if !agent.position.isFinite || !agent.velocity.isFinite || !agent.heading.isFinite
                || !agent.animationPhase.isFinite || !agent.turn.isFinite {
                problems.append("fish \(i) has a non-finite number")
                continue
            }
            if !bounds.contains(agent.position) { problems.append("fish \(i) is outside the swim bounds") }
            if agent.animationPhase < 0 || agent.animationPhase > 2 * Double.pi {
                problems.append("fish \(i) animation phase is outside 0…2π")
            }
        }
        for (i, plant) in plants.enumerated() {
            if plant.kindId.isEmpty { problems.append("plant \(i) has no kind") }
            if !plant.x.isFinite || plant.x < 0 || plant.x > SwimBounds.tankWidth {
                problems.append("plant \(i) is outside the tank")
            }
        }
        for (i, item) in decor.enumerated() {
            if item.kindId.isEmpty { problems.append("decor \(i) has no kind") }
            let p = item.position
            if !p.isFinite || p.x < 0 || p.x > SwimBounds.tankWidth || p.y < 0 || p.y > SwimBounds.tankHeight {
                problems.append("decor \(i) is outside the tank")
            }
            if !item.rotation.isFinite || !DecorSpot.rotationRange.contains(item.rotation) {
                problems.append("decor \(i) rotation is outside −π…π")
            }
            if !item.scale.isFinite || !DecorSpot.scaleRange.contains(item.scale) {
                problems.append("decor \(i) scale is outside 0.5…2.0")
            }
        }
        if let catalog {
            if !catalog.habitats.indices.contains(habitatIndex) {
                problems.append("habitat index \(habitatIndex) is not in the catalog")
            }
            for (i, agent) in fish.enumerated() {
                guard let species = catalog.species(id: agent.speciesId) else {
                    problems.append("fish \(i) species \(agent.speciesId) is not in the catalog")
                    continue
                }
                if agent.velocity.isFinite && agent.velocity.length > species.maxSpeed * (1 + 1e-9) {
                    problems.append("fish \(i) is faster than its species' maximum speed")
                }
            }
            for (i, plant) in plants.enumerated() where catalog.plant(id: plant.kindId) == nil {
                problems.append("plant \(i) kind \(plant.kindId) is not in the catalog")
            }
            for (i, item) in decor.enumerated() where catalog.decor(id: item.kindId) == nil {
                problems.append("decor \(i) kind \(item.kindId) is not in the catalog")
            }
        }
        return problems
    }
}
