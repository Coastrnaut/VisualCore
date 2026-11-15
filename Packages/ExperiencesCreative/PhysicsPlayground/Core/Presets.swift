// Presets — feature 085 (A11-P04) T-A11-402 (FR-A11-401, FR-A11-420, FR-A11-431; clarification 1; research D1;
// data-model "PresetID"). The four ready-made experiments a person opens, each a schema-3 world that validates against
// the bundled catalog, at tick 0, running at normal speed, with no pins other than the stated ones, no selection, no
// grab and both overlays off. Each preset is original content: author "VisualCore project", license "MIT", listed by
// `LicenseAudit` with the role `preset`.
//
// - 0 free play: the seeded starting scene, `StartingScene.make(random:catalog:)` with exactly its draws (the only
//   preset that consumes the generator).
// - 1 pendulum: a pinned steel pivot circle (id 0, radius 0.15 m) at (5, 7) and a steel bob (id 1, radius 0.3 m) whose
//   centre is 2.5 m from the pivot's centre, 30° to the right of straight down, at rest; spring 0 joins the two centres
//   (end A the pivot body, end B the bob body) with rest length 2.5 m. Earth gravity, drag none (level 0), stiffness
//   level 3 (400 N/m, under the bob's stable bound 0.1·m/dt² ≈ 3,175 N/m).
// - 2 spring chain: five rubber circles (ids 0…4, radius 0.2 m) straight down from the world anchor (5, 8) on the
//   ceiling, each at rest length below the one above: centres at y = 7.2, 6.4, 5.6, 4.8 and 4.0 m, x = 5. Spring 0 joins
//   the anchor to circle 0, springs 1…4 join circle i − 1 to circle i, all at centres, rest length 0.8 m. Earth gravity,
//   drag low (level 1), stiffness level 2 (150 N/m; each spring clamps it to its stable bound).
// - 3 stacked objects: five wood boxes (ids 0…4, half-size 0.25 m) stacked on the floor at x = 5 m, each resting
//   exactly on the one below (centres at y = 0.25, 0.75, 1.25, 1.75 and 2.25 m). Default levels (Earth, low drag,
//   stiffness level 1), no springs.
//
// Presets 1–3 are fixed data: they never draw from the generator, so they are deterministic without randomness and the
// generator is left exactly as it was. Materials are looked up in the catalog; a material missing from it falls back to
// the catalog's first material (or "steel" for an empty catalog), as the starting scene does.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The four presets, by their stable number (the value of the `experiment.preset` action and of
/// ``ExperimentOrigin/preset(_:)``).
public enum PresetID: Int, CaseIterable, Codable, Sendable {
    /// The seeded starting scene.
    case freePlay = 0
    /// A bob on a stiff spring from a pinned pivot, released 30° from vertical.
    case pendulum
    /// Five balls joined by springs hanging from the ceiling.
    case springChain
    /// Five wood boxes stacked on the floor.
    case stackedObjects

    /// The display name.
    public var name: String {
        switch self {
        case .freePlay: "Free play"
        case .pendulum: "Pendulum"
        case .springChain: "Spring chain"
        case .stackedObjects: "Stacked objects"
        }
    }

    /// The kebab-case content id used in the license audit.
    public var contentId: String {
        switch self {
        case .freePlay: "free-play"
        case .pendulum: "pendulum"
        case .springChain: "spring-chain"
        case .stackedObjects: "stacked-objects"
        }
    }

    /// The author of the preset ("VisualCore project").
    public var author: String { MaterialCatalog.projectAuthor }
    /// The license of the preset ("MIT").
    public var license: String { "MIT" }
}

/// The builder of the presets.
public enum Presets {
    /// The pendulum's pivot centre in metres.
    public static let pendulumPivot = Vec2(5, 7)
    /// The pendulum's pivot radius in metres.
    public static let pendulumPivotRadius = 0.15
    /// The pendulum's bob radius in metres.
    public static let pendulumBobRadius = 0.3
    /// The pendulum's spring rest length in metres.
    public static let pendulumLength = 2.5
    /// The pendulum's release angle from straight down in radians (30°, to the right).
    public static let pendulumReleaseAngle = Double.pi / 6
    /// The spring chain's ceiling anchor in metres.
    public static let chainAnchor = Vec2(5, 8)
    /// The number of circles in the spring chain.
    public static let chainCount = 5
    /// The radius of each chain circle in metres.
    public static let chainRadius = 0.2
    /// The rest length of each chain spring in metres.
    public static let chainRestLength = 0.8
    /// The number of boxes in the stack.
    public static let stackCount = 5
    /// The half-size of each stacked box in metres.
    public static let stackHalfSize = 0.25
    /// The x of the stack in metres.
    public static let stackX = 5.0

    /// The world of preset `id` (see the file header). Only ``PresetID/freePlay`` draws from `random`; the other
    /// presets leave it unchanged.
    public static func make(_ id: PresetID, random: inout SeededRandom, catalog: MaterialCatalog) -> PhysicsWorld {
        switch id {
        case .freePlay: StartingScene.make(random: &random, catalog: catalog)
        case .pendulum: pendulum(catalog: catalog)
        case .springChain: springChain(catalog: catalog)
        case .stackedObjects: stackedObjects(catalog: catalog)
        }
    }

    /// The world of the preset numbered `number`, nil outside 0…3.
    public static func make(number: Int, random: inout SeededRandom, catalog: MaterialCatalog) -> PhysicsWorld? {
        guard let id = PresetID(rawValue: number) else { return nil }
        return make(id, random: &random, catalog: catalog)
    }

    /// `id` when the catalog has it, otherwise its first material, or "steel" for an empty catalog.
    private static func known(_ id: String, _ catalog: MaterialCatalog) -> String {
        catalog.material(id: id)?.id ?? catalog.materials.first?.id ?? "steel"
    }

    /// A world of `bodies` and `springs` with the given levels (the settings carry the levels' values).
    private static func world(bodies: [PhysicsBody], springs: [WorldSpring], gravityLevel: Int, dragLevel: Int,
                              stiffnessLevel: Int) -> PhysicsWorld {
        let drag = ForceLevels.drag[dragLevel]
        let settings = WorldSettings(gravity: ForceLevels.gravityVector(level: gravityLevel)!, linearDrag: drag,
                                     angularDrag: drag)
        return PhysicsWorld(settings: settings, bodies: bodies, springs: springs, gravityLevel: gravityLevel,
                            dragLevel: dragLevel, stiffnessLevel: stiffnessLevel)
    }

    /// The pendulum preset.
    private static func pendulum(catalog: MaterialCatalog) -> PhysicsWorld {
        let steel = known("steel", catalog)
        let offset = Vec2(sin(pendulumReleaseAngle), -cos(pendulumReleaseAngle)) * pendulumLength
        let bodies = [
            PhysicsBody(id: 0, shape: .circle(radius: pendulumPivotRadius), materialId: steel, position: pendulumPivot,
                        pinned: true),
            PhysicsBody(id: 1, shape: .circle(radius: pendulumBobRadius), materialId: steel,
                        position: pendulumPivot + offset),
        ]
        let springs = [WorldSpring(id: 0, a: .body(0), b: .body(1), restLength: pendulumLength)]
        return world(bodies: bodies, springs: springs, gravityLevel: 2, dragLevel: 0, stiffnessLevel: 3)
    }

    /// The spring chain preset.
    private static func springChain(catalog: MaterialCatalog) -> PhysicsWorld {
        let rubber = known("rubber", catalog)
        let bodies = (0..<chainCount).map { index in
            PhysicsBody(id: index, shape: .circle(radius: chainRadius), materialId: rubber,
                        position: chainAnchor - Vec2(0, chainRestLength * Double(index + 1)))
        }
        let springs = (0..<chainCount).map { index in
            WorldSpring(id: index, a: index == 0 ? .world(chainAnchor) : .body(index - 1), b: .body(index),
                        restLength: chainRestLength)
        }
        return world(bodies: bodies, springs: springs, gravityLevel: 2, dragLevel: 1, stiffnessLevel: 2)
    }

    /// The stacked objects preset.
    private static func stackedObjects(catalog: MaterialCatalog) -> PhysicsWorld {
        let wood = known("wood", catalog)
        let bodies = (0..<stackCount).map { index in
            PhysicsBody(id: index, shape: .box(halfExtents: Vec2(stackHalfSize, stackHalfSize)), materialId: wood,
                        position: Vec2(stackX, stackHalfSize * Double(2 * index + 1)))
        }
        return world(bodies: bodies, springs: [], gravityLevel: ForceLevels.defaultGravityLevel,
                     dragLevel: ForceLevels.defaultDragLevel, stiffnessLevel: ForceLevels.defaultStiffnessLevel)
    }
}
