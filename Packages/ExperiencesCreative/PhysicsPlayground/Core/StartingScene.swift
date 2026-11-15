// StartingScene — feature 082 (A11-P01) T-A11-103 (FR-A11-112; clarification 4), extended by feature 083 (A11-P02)
// T-A11-203 (FR-A11-212; clarification 5). The seeded starting scene: one static steel ledge (id 0, mass 0) at the fixed
// place centre (2.0, 2.5) m with half-extents (1.0, 0.15) m on the left, then three circles and three boxes (ids 1…6),
// at rest, in the upper left of the stage; then the spring bodies at fixed places: a wood box (id 7, half-size 0.3 m)
// hanging from the world anchor (7.5, 8.0) on the ceiling by spring 0 (rest length 1.5 m, attached at the box's top
// centre, so the box starts at rest length below the anchor with its centre at (7.5, 6.2)), and two rubber circles
// (ids 8 and 9, radius 0.3 m) at (7.0, 1.5) and (8.0, 1.5) joined at their centres by spring 1 (rest length 1.0 m).
//
// Non-overlap holds by construction: the upper half (y 4…8 m) of the left 6.6 m of the stage is cut into six slots,
// three across (each 2.2 m wide) and two high (each 2 m high), filled in slot order (bottom row left to right, then the
// top row). The seeded generator first shuffles the six kinds (three circles, three boxes) over the slots, then draws
// for each body, always in the same order and number (six draws): the first size and the second size (0.25…0.6 m each;
// a circle uses the first as its radius, a box both as half-extents), the material (uniform over the catalog), the
// angle (−π…π) and the offset of the centre from the slot centre in x and in y, chosen so the body's bounding circle
// (the radius, or the half-diagonal ≤ 0.85 m) stays 0.05 m inside its slot. Separate slots therefore never overlap,
// the ledge (y ≤ 2.65 m) lies below every slot, and the spring bodies lie right of x = 6.6 m (the box spans x 7.2…7.8,
// the circles x 6.7…8.3 below y 1.8 m). The world has the default levels (Earth gravity, low drag, stiffness level 1)
// and an empty contact cache. An empty catalog gives the same scene with the material id "steel" for every body.
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
    /// The width of the region the six seeded bodies occupy, from x = 0, in metres.
    public static let slotRegionWidth = 6.6
    /// The ceiling anchor of the hanging box's spring in metres.
    public static let hangingAnchor = Vec2(7.5, 8.0)
    /// The rest length of the hanging box's spring in metres.
    public static let hangingRestLength = 1.5
    /// The half-size of the hanging wood box in metres.
    public static let hangingHalfSize = 0.3
    /// The material of the hanging box.
    public static let hangingMaterialId = "wood"
    /// The centres of the two joined circles in metres.
    public static let pairCenters = (Vec2(7.0, 1.5), Vec2(8.0, 1.5))
    /// The radius of the two joined circles in metres.
    public static let pairRadius = 0.3
    /// The rest length of the spring joining the circles in metres.
    public static let pairRestLength = 1.0
    /// The material of the joined circles.
    public static let pairMaterialId = "rubber"

    /// The starting world: the static ledge, three circles and three boxes at rest drawn from `random` (see the file
    /// header for the draw order), the hanging box and the joined circles with their two springs, with default
    /// settings and levels, an empty contact cache, tick 0, running at normal speed.
    public static func make(random: inout SeededRandom, catalog: MaterialCatalog) -> PhysicsWorld {
        let stage = WorldSettings.defaultStage
        func known(_ id: String) -> String {
            catalog.material(id: id)?.id ?? catalog.materials.first?.id ?? ledgeMaterialId
        }
        var bodies = [PhysicsBody(id: 0, shape: .box(halfExtents: ledgeHalfExtents), materialId: known(ledgeMaterialId),
                                  isStatic: true, position: ledgeCenter)]
        var kinds: [BodyKind] = [.circle, .circle, .circle, .box, .box, .box]
        random.shuffle(&kinds)
        let slotWidth = slotRegionWidth / 3, slotHeight = stage.y / 4, margin = 0.05
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
        let boxId = bodies.count, firstCircle = boxId + 1, secondCircle = boxId + 2
        let attach = Vec2(0, hangingHalfSize)
        bodies.append(PhysicsBody(id: boxId, shape: .box(halfExtents: Vec2(hangingHalfSize, hangingHalfSize)),
                                  materialId: known(hangingMaterialId),
                                  position: hangingAnchor - Vec2(0, hangingRestLength) - attach))
        bodies.append(PhysicsBody(id: firstCircle, shape: .circle(radius: pairRadius), materialId: known(pairMaterialId),
                                  position: pairCenters.0))
        bodies.append(PhysicsBody(id: secondCircle, shape: .circle(radius: pairRadius),
                                  materialId: known(pairMaterialId), position: pairCenters.1))
        let springs = [
            WorldSpring(id: 0, a: .world(hangingAnchor), b: .body(boxId, local: attach), restLength: hangingRestLength),
            WorldSpring(id: 1, a: .body(firstCircle), b: .body(secondCircle), restLength: pairRestLength),
        ]
        return PhysicsWorld(bodies: bodies, nextId: bodies.count, springs: springs, nextSpringId: springs.count,
                            gravityLevel: ForceLevels.defaultGravityLevel, dragLevel: ForceLevels.defaultDragLevel,
                            stiffnessLevel: ForceLevels.defaultStiffnessLevel, contactCache: [])
    }
}
