// HabitatDocument — feature 068 (A09-P01) T-A09-102 (FR-A09-101, FR-A09-110; clarifications 1, 2 and 5; research D1,
// D2; data-model "SwimBounds", "FishAgent", "HabitatDocument", schema 1). The versioned document that describes one
// aquarium: which starter habitat it came from, the water colour, the swim bounds, the plants, the fish (species,
// position, velocity, heading, animation phase), the decor and the lighting level. Habitat units throughout: the tank
// is 16 × 9 (x 0…16, y 0…9, y up), fish swim inside x 0.5…15.5, y 1.5…8.5 (above the gravel band), plants stand on
// y 1.0.
// A habitat holds at most 24 fish, 12 plants and 12 decor items. Decor is a real, validated list that stays empty in
// this phase (placement comes in A09-P03).
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

    /// Creates a fish from all of its fields; validity is checked by ``HabitatDocument/validate(catalog:)``.
    public init(speciesId: String, position: Vec2, velocity: Vec2, heading: Double, animationPhase: Double) {
        self.speciesId = speciesId; self.position = position; self.velocity = velocity
        self.heading = heading; self.animationPhase = animationPhase
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

/// One decor item of a habitat (placement arrives in A09-P03; the list is empty in this phase).
public struct DecorPlacement: Codable, Equatable, Sendable {
    /// The decor kind id (non-empty).
    public var kindId: String
    /// The position in habitat units, inside the tank.
    public var position: Vec2

    /// Creates a decor placement of `kindId` at `position`.
    public init(kindId: String, position: Vec2) { self.kindId = kindId; self.position = position }
}

/// The versioned description of one aquarium (schema 1).
public struct HabitatDocument: Codable, Equatable, Sendable {
    /// The document schema written by this version.
    public static let currentSchema = 1
    /// The most fish a habitat may hold.
    public static let maxFish = 24
    /// The most plants a habitat may hold.
    public static let maxPlants = 12
    /// The most decor items a habitat may hold.
    public static let maxDecor = 12
    /// The lighting levels: 0 dim, 1 soft, 2 bright.
    public static let lightingRange: ClosedRange<Int> = 0...2
    /// The lighting level of a new starter document (soft).
    public static let defaultLighting = 1
    /// The y coordinate plants stand on, in habitat units.
    public static let plantBaseY = 1.0

    /// The document schema (1).
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
    /// The decor items (empty in this phase).
    public var decor: [DecorPlacement]
    /// The lighting level, in ``lightingRange``.
    public var lighting: Int

    /// Creates a document from all of its fields; validity is checked by ``validate(catalog:)``.
    public init(schema: Int = HabitatDocument.currentSchema, habitatIndex: Int, habitatId: String, waterColor: RGBA,
                bounds: SwimBounds = .standard, plants: [PlantPlacement], fish: [FishAgent],
                decor: [DecorPlacement] = [], lighting: Int = HabitatDocument.defaultLighting) {
        self.schema = schema; self.habitatIndex = habitatIndex; self.habitatId = habitatId
        self.waterColor = waterColor; self.bounds = bounds; self.plants = plants; self.fish = fish
        self.decor = decor; self.lighting = lighting
    }

    /// A new document of the catalog's starter habitat `index` (clamped to the catalog's habitats; an empty catalog
    /// gives an empty "none" document): plants at the habitat's x positions, and each fish at a random position inside
    /// the standard bounds with a random heading (mostly level, ±0.4 rad around left or right), moving at its
    /// species' cruise speed, with a random animation phase. Fish of species missing from the catalog are skipped.
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
        return HabitatDocument(habitatIndex: chosen, habitatId: habitat.id, waterColor: habitat.waterColor,
                               bounds: bounds, plants: plants, fish: fish)
    }

    /// The document's problems, empty when it is valid: the schema, the bounds, the water colour, the counts (≤ 24
    /// fish, ≤ 12 plants, ≤ 12 decor), every fish (non-empty species, finite numbers, position inside the bounds,
    /// phase in 0…2π), every plant (non-empty kind, x finite inside the tank), every decor item (non-empty kind,
    /// position inside the tank) and the lighting level (0…2). With a `catalog` it also checks that the habitat index,
    /// the species and the plant kinds exist and that no fish is faster than its species' maximum speed.
    public func validate(catalog: SpeciesCatalog? = nil) -> [String] {
        var problems: [String] = []
        if schema != Self.currentSchema { problems.append("schema \(schema) is not \(Self.currentSchema)") }
        if !bounds.isValid { problems.append("swim bounds are invalid") }
        if !waterColor.isValid { problems.append("water colour is invalid") }
        if habitatId.isEmpty { problems.append("habitat id is empty") }
        if fish.count > Self.maxFish { problems.append("\(fish.count) fish exceed \(Self.maxFish)") }
        if plants.count > Self.maxPlants { problems.append("\(plants.count) plants exceed \(Self.maxPlants)") }
        if decor.count > Self.maxDecor { problems.append("\(decor.count) decor items exceed \(Self.maxDecor)") }
        if !Self.lightingRange.contains(lighting) { problems.append("lighting \(lighting) is outside 0…2") }
        for (i, agent) in fish.enumerated() {
            if agent.speciesId.isEmpty { problems.append("fish \(i) has no species") }
            if !agent.position.isFinite || !agent.velocity.isFinite || !agent.heading.isFinite
                || !agent.animationPhase.isFinite {
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
        }
        return problems
    }
}
