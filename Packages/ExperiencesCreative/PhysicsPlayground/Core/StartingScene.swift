// StartingScene — feature 082 (A11-P01) T-A11-103 (FR-A11-112; clarification 4). The seeded starting scene: one
// static steel ledge (id 0, mass 0) at the fixed place centre (2.0, 2.5) m with half-extents (1.0, 0.15) m on the left,
// then three circles and three boxes (ids 1…6), at rest, in the upper half of the stage.
//
// Non-overlap holds by construction: the upper half (y 4…8 m) of the 10 m stage is cut into six slots, three across
// (each 10/3 m wide) and two high (each 2 m high), filled in slot order (bottom row left to right, then the top row).
// The seeded generator first shuffles the six kinds (three circles, three boxes) over the slots, then draws for each
// body, always in the same order and number (six draws): the first size and the second size (0.25…0.6 m each; a circle
// uses the first as its radius, a box both as half-extents), the material (uniform over the catalog), the angle
// (−π…π) and the offset of the centre from the slot centre in x and in y, chosen so the body's bounding circle (the
// radius, or the half-diagonal ≤ 0.85 m) stays 0.05 m inside its slot. Separate slots therefore never overlap, and the
// ledge (y ≤ 2.65 m) lies below every slot. An empty catalog gives the same scene with the material id "steel".
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The seeded starting scene of a world.
public enum StartingScene {
    /// The ledge centre in metres.
    public static let ledgeCenter = Vec2(2.0, 2.5)
    /// The ledge half-extents in metres.
    public static let ledgeHalfExtents = Vec2(1.0, 0.15)
    /// The material the ledge is made of.
    public static let ledgeMaterialId = "steel"
    /// The size range of the starting bodies (radius or half-extent) in metres.
    public static let sizeRange: ClosedRange<Double> = 0.25...0.6

    /// The starting world: the static ledge and three circles and three boxes at rest in the upper half, drawn from
    /// `random` (see the file header for the draw order), with default settings, tick 0, running at normal speed.
    public static func make(random: inout SeededRandom, catalog: MaterialCatalog) -> PhysicsWorld {
        let stage = WorldSettings.defaultStage
        let ledgeMaterial = catalog.material(id: ledgeMaterialId)?.id ?? catalog.materials.first?.id ?? ledgeMaterialId
        var bodies = [PhysicsBody(id: 0, shape: .box(halfExtents: ledgeHalfExtents), materialId: ledgeMaterial,
                                  isStatic: true, position: ledgeCenter)]
        var kinds: [BodyKind] = [.circle, .circle, .circle, .box, .box, .box]
        random.shuffle(&kinds)
        let slotWidth = stage.x / 3, slotHeight = stage.y / 4, margin = 0.05
        for (slot, kind) in kinds.enumerated() {
            let column = Double(slot % 3), row = Double(slot / 3)
            let center = Vec2(slotWidth * (column + 0.5), stage.y / 2 + slotHeight * (row + 0.5))
            let first = random.range(sizeRange), second = random.range(sizeRange)
            let materialIndex = random.index(below: max(catalog.materials.count, 1))
            let angle = random.range(-Double.pi...Double.pi)
            let shape: Shape2D = kind == .circle ? .circle(radius: first) : .box(halfExtents: Vec2(first, second))
            let bound = kind == .circle ? first : Vec2(first, second).length
            let spanX = slotWidth / 2 - bound - margin, spanY = slotHeight / 2 - bound - margin
            let offset = Vec2(random.range(-spanX...spanX), random.range(-spanY...spanY))
            let material = catalog.materials.isEmpty ? ledgeMaterialId : catalog.materials[materialIndex].id
            bodies.append(PhysicsBody(id: slot + 1, shape: shape, materialId: material, position: center + offset,
                                      angle: angle))
        }
        return PhysicsWorld(bodies: bodies, nextId: bodies.count)
    }
}
