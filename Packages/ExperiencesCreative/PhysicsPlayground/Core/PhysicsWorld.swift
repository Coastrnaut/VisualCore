// PhysicsWorld — feature 082 (A11-P01) T-A11-103 (FR-A11-110, FR-A11-111; clarifications 1 and 4; data-model
// "WorldSettings", "PhysicsBody", "PhysicsWorld"), extended by feature 083 (A11-P02) T-A11-203 (FR-A11-210;
// clarifications 3 and 4; research D3, D4; data-model "Spring", "Force levels", "ContactCacheEntry", "PhysicsWorld
// schema 2"). The versioned world record (schema 2). Units are metres, kilograms (2D: density in kg/m²), seconds and
// radians; y is up and the origin is the stage's bottom-left corner. The stage is 10 m × 8 m, enclosed by four static
// walls 1 m thick just outside it (see `WorldSimulation.walls(for:)`).
//
// A body is a circle (radius) or a box (half-extents), each size 0.15…1.0 m, with a material id, a static flag, a
// position, an angle, a velocity and an angular velocity. Its mass is the material density × the shape area and its
// inertia comes from `Shape2D.inertia(mass:)`; a static body has mass 0, so its inverse mass and inverse inertia are 0
// and the solver never moves it. The world adds the settings, the tick count, the next body id, the pause flag, the
// time-scale index (0…3 for ¼, ½, 1 and 2) and the time-scale remainder (0…7 quarter ticks).
//
// Schema 2 adds: the springs (at most 16, ids unique and ascending below `nextSpringId`; end A is a body with a
// body-local point or a fixed world point inside the stage, end B a body with a body-local point; both bodies exist and
// differ; rest length 0.1…10 m), the gravity level 0…2, the drag level 0…2 and the stiffness level 0…3 (`ForceLevels`;
// the settings' gravity and drags equal the levels' values exactly), and the contact cache: the accumulated normal and
// tangent impulse of every contact point of the last tick, keyed by (body id A, body id B or a wall marker, point
// index), sorted by that key, used to warm-start the next tick and saved so a restore continues exactly.
//
// A schema-1 record is read with `PhysicsWorld.decode(_:)` (which reads the schema number first) or migrated explicitly
// with `PhysicsWorld.migrated(fromSchemaOne:)`: its bodies, tick, ids, pause and time scale are kept; it gets no springs,
// Earth gravity, low drag, stiffness level 1 and an empty cache.
//
// The record is plain Codable data, so `JSONEncoder` with `.sortedKeys` gives deterministic bytes. `validate(catalog:)`
// names every problem, one line each, and is empty for a sound world.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The fixed settings of a world.
public struct WorldSettings: Codable, Equatable, Sendable {
    /// Gravity in m/s² (default (0, −9.81)); finite and at most ``maxGravity`` in magnitude.
    public var gravity: Vec2
    /// Linear drag in s⁻¹ (default 0.05), applied as the velocity factor 1/(1 + k·dt); 0…5.
    public var linearDrag: Double
    /// Angular drag in s⁻¹ (default 0.05), applied as the angular-velocity factor 1/(1 + k·dt); 0…5.
    public var angularDrag: Double
    /// The fixed tick in seconds; exactly 1/120.
    public var tick: Double
    /// Solver velocity iterations per tick, 1…20 (default 10).
    public var iterations: Int
    /// The stage size in metres (default 10 × 8).
    public var stageSize: Vec2

    /// The default gravity, (0, −9.81) m/s².
    public static let defaultGravity = Vec2(0, -9.81)
    /// The largest allowed gravity magnitude in m/s².
    public static let maxGravity = 20.0
    /// The allowed drag coefficients in s⁻¹.
    public static let dragRange: ClosedRange<Double> = 0...5
    /// The allowed solver iteration counts.
    public static let iterationRange: ClosedRange<Int> = 1...20
    /// The one allowed tick, 1/120 s.
    public static let fixedTick = 1.0 / 120.0
    /// The default stage size, 10 m × 8 m.
    public static let defaultStage = Vec2(10, 8)

    /// Creates settings (defaults: gravity (0, −9.81), drags 0.05, tick 1/120 s, 10 iterations, stage 10 × 8 m).
    public init(gravity: Vec2 = WorldSettings.defaultGravity, linearDrag: Double = 0.05, angularDrag: Double = 0.05,
                tick: Double = WorldSettings.fixedTick, iterations: Int = 10,
                stageSize: Vec2 = WorldSettings.defaultStage) {
        self.gravity = gravity; self.linearDrag = linearDrag; self.angularDrag = angularDrag; self.tick = tick
        self.iterations = iterations; self.stageSize = stageSize
    }

    /// True when every number is finite.
    public var isFinite: Bool {
        gravity.isFinite && linearDrag.isFinite && angularDrag.isFinite && tick.isFinite && stageSize.isFinite
    }

    /// The problems of these settings, one line each (empty when they are sound).
    public func problems() -> [String] {
        var out: [String] = []
        if !gravity.isFinite { out.append("settings.gravity is not finite") }
        else if gravity.length > Self.maxGravity { out.append("settings.gravity exceeds \(Self.maxGravity) m/s²") }
        if !(linearDrag.isFinite && Self.dragRange.contains(linearDrag)) {
            out.append("settings.linearDrag \(linearDrag) is outside 0…5")
        }
        if !(angularDrag.isFinite && Self.dragRange.contains(angularDrag)) {
            out.append("settings.angularDrag \(angularDrag) is outside 0…5")
        }
        if tick != Self.fixedTick { out.append("settings.tick \(tick) is not 1/120 s") }
        if !Self.iterationRange.contains(iterations) { out.append("settings.iterations \(iterations) is outside 1…20") }
        if !(stageSize.isFinite && stageSize.x >= 2 && stageSize.x <= 50 && stageSize.y >= 2 && stageSize.y <= 50) {
            out.append("settings.stageSize is not finite or outside 2…50 m")
        }
        return out
    }
}

/// The two body kinds a person can drop.
public enum BodyKind: Int, Codable, CaseIterable, Sendable {
    /// A circle.
    case circle = 0
    /// A box.
    case box = 1
}

/// One rigid body of the world.
public struct PhysicsBody: Codable, Equatable, Sendable, Identifiable {
    /// The body id, unique and ascending in the world's body list.
    public var id: Int
    /// The shape: a circle (radius) or a box (half-extents), each size in ``PhysicsWorld/sizeRange``.
    public var shape: Shape2D
    /// The material id in the catalog.
    public var materialId: String
    /// True for a static body (mass 0, never moved by the simulation).
    public var isStatic: Bool
    /// The centre in metres.
    public var position: Vec2
    /// The rotation in radians (counter-clockwise).
    public var angle: Double
    /// The velocity in m/s.
    public var velocity: Vec2
    /// The angular velocity in rad/s.
    public var angularVelocity: Double

    /// Creates a body (no validation; ``PhysicsWorld/validate(catalog:)`` validates).
    public init(id: Int, shape: Shape2D, materialId: String, isStatic: Bool = false, position: Vec2,
                angle: Double = 0, velocity: Vec2 = .zero, angularVelocity: Double = 0) {
        self.id = id; self.shape = shape; self.materialId = materialId; self.isStatic = isStatic
        self.position = position; self.angle = angle; self.velocity = velocity; self.angularVelocity = angularVelocity
    }

    /// The pose (position and angle) used for contact generation.
    public var pose: Pose2D { Pose2D(position: position, angle: angle) }

    /// The mass in kg (density × area), 0 for a static body, nil when the material is not in `catalog`.
    public func mass(in catalog: MaterialCatalog) -> Double? {
        guard let material = catalog.material(id: materialId) else { return nil }
        return isStatic ? 0 : material.density * shape.area
    }

    /// The moment of inertia in kg·m² from ``Shape2D/inertia(mass:)``, 0 for a static body, nil when the material is
    /// not in `catalog`.
    public func inertia(in catalog: MaterialCatalog) -> Double? {
        guard let mass = mass(in: catalog) else { return nil }
        return isStatic ? 0 : shape.inertia(mass: mass)
    }

    /// The shape's sizes (the radius, or both half-extents).
    public var sizes: [Double] {
        switch shape {
        case .circle(let radius): [radius]
        case .box(let half): [half.x, half.y]
        }
    }

    /// The radius of the smallest circle about the centre that holds the shape at any angle.
    public var boundingRadius: Double {
        switch shape {
        case .circle(let radius): radius
        case .box(let half): half.length
        }
    }

    /// True when every number of the body is finite.
    public var isFinite: Bool {
        sizes.allSatisfy(\.isFinite) && position.isFinite && angle.isFinite && velocity.isFinite
            && angularVelocity.isFinite
    }
}


/// One end of a world spring: a body (by id) with a point in its local frame, or a fixed world point.
public struct WorldSpringEnd: Codable, Equatable, Sendable {
    /// The body id, or nil for a fixed world point.
    public var bodyId: Int?
    /// The point: body-local when ``bodyId`` is set, otherwise in world coordinates (metres).
    public var point: Vec2

    /// Creates an end (no validation; ``PhysicsWorld/validate(catalog:)`` validates).
    public init(bodyId: Int?, point: Vec2) { self.bodyId = bodyId; self.point = point }

    /// An end on body `id` at the body-local point `local` (default its centre).
    public static func body(_ id: Int, local: Vec2 = .zero) -> WorldSpringEnd {
        WorldSpringEnd(bodyId: id, point: local)
    }

    /// An end at the fixed world point `point`.
    public static func world(_ point: Vec2) -> WorldSpringEnd { WorldSpringEnd(bodyId: nil, point: point) }
}

/// A spring of the world: end A (a body or a world point), end B (a body) and a rest length. Its stiffness comes from
/// the world's stiffness level and its damping ratio is ``ForceLevels/springDampingRatio``.
public struct WorldSpring: Codable, Equatable, Sendable, Identifiable {
    /// The spring id, unique and ascending in the world's spring list.
    public var id: Int
    /// End A: a body with a body-local point, or a fixed world point inside the stage.
    public var a: WorldSpringEnd
    /// End B: a body with a body-local point.
    public var b: WorldSpringEnd
    /// The rest length in metres, ``PhysicsWorld/restLengthRange``.
    public var restLength: Double

    /// Creates a spring (no validation; ``PhysicsWorld/validate(catalog:)`` validates).
    public init(id: Int, a: WorldSpringEnd, b: WorldSpringEnd, restLength: Double) {
        self.id = id; self.a = a; self.b = b; self.restLength = restLength
    }

    /// True when every number of the spring is finite.
    public var isFinite: Bool { a.point.isFinite && b.point.isFinite && restLength.isFinite }
}

/// The accumulated impulses of one contact point of the last tick, used to warm-start the next tick.
public struct ContactCacheEntry: Codable, Equatable, Sendable {
    /// The id of the first body of the contact.
    public var bodyA: Int
    /// The id of the second body (greater than ``bodyA``), or a wall marker ``wallMarker(_:)`` (−1…−4).
    public var bodyB: Int
    /// The index of the point in the contact's manifold (0 or 1).
    public var pointIndex: Int
    /// The accumulated normal impulse in N·s (finite, ≥ 0).
    public var normalImpulse: Double
    /// The accumulated friction impulse in N·s (finite).
    public var tangentImpulse: Double

    /// Creates an entry (no validation).
    public init(bodyA: Int, bodyB: Int, pointIndex: Int, normalImpulse: Double, tangentImpulse: Double) {
        self.bodyA = bodyA; self.bodyB = bodyB; self.pointIndex = pointIndex
        self.normalImpulse = normalImpulse; self.tangentImpulse = tangentImpulse
    }

    /// The marker of wall `index` (0 floor, 1 ceiling, 2 left, 3 right) in ``bodyB``: −1 − index.
    public static func wallMarker(_ index: Int) -> Int { -1 - index }

    /// True when both impulses are finite.
    public var isFinite: Bool { normalImpulse.isFinite && tangentImpulse.isFinite }
}

/// The world record, schema 2.
public struct PhysicsWorld: Codable, Equatable, Sendable {
    /// The schema this code writes and reads.
    public static let schemaVersion = 2
    /// The most bodies a world holds (including static ones).
    public static let maxBodies = 48
    /// The allowed radius and half-extent sizes in metres.
    public static let sizeRange: ClosedRange<Double> = 0.15...1.0
    /// The speed cap in m/s (at most 0.33 m per tick, under the 1 m wall thickness).
    public static let speedCap = 40.0
    /// The angular speed cap in rad/s.
    public static let angularSpeedCap = 40.0
    /// The four time scales by index: ¼, ½, 1 and 2.
    public static let timeScales: [Double] = [0.25, 0.5, 1, 2]
    /// The quarter ticks each host step adds to the remainder, by time-scale index.
    public static let quarterTicks: [Int] = [1, 2, 4, 8]
    /// The time-scale index of normal speed.
    public static let normalTimeScaleIndex = 2
    /// The allowed spring rest lengths in metres.
    public static let restLengthRange: ClosedRange<Double> = 0.1...10
    /// The most contact cache entries: two points for every body pair and every body–wall pair of a full world.
    public static let maxContactCache = 2 * (maxBodies * (maxBodies - 1) / 2 + 4 * maxBodies)

    /// The schema version (2).
    public var schema: Int
    /// The fixed settings (their gravity and drags equal the levels' values).
    public var settings: WorldSettings
    /// The bodies, ids unique and ascending.
    public var bodies: [PhysicsBody]
    /// Ticks run so far (≥ 0).
    public var tick: Int
    /// The id the next added body receives (greater than every id).
    public var nextId: Int
    /// True while the world is paused (host steps do nothing; a single step runs one tick).
    public var paused: Bool
    /// The time-scale index, 0…3 (``timeScales``).
    public var timeScaleIndex: Int
    /// Quarter ticks carried to the next host step, 0…7.
    public var remainder: Int
    /// The springs, at most ``ForceLevels/maxSprings``, ids unique and ascending.
    public var springs: [WorldSpring]
    /// The id the next added spring receives (greater than every spring id).
    public var nextSpringId: Int
    /// The gravity level 0…2 (``ForceLevels/gravity``).
    public var gravityLevel: Int
    /// The drag level 0…2 (``ForceLevels/drag``).
    public var dragLevel: Int
    /// The stiffness level 0…3 (``ForceLevels/stiffness``).
    public var stiffnessLevel: Int
    /// The accumulated contact impulses of the last tick, sorted by (bodyA, bodyB, pointIndex).
    public var contactCache: [ContactCacheEntry]

    /// Creates a world (defaults: schema 2, default settings, no bodies, tick 0, running at normal speed, no springs,
    /// stiffness level 1, an empty cache). A nil gravity or drag level is the level whose value the settings carry, or
    /// the default level when none matches (``validate(catalog:)`` then reports the mismatch).
    public init(settings: WorldSettings = WorldSettings(), bodies: [PhysicsBody] = [], tick: Int = 0,
                nextId: Int? = nil, paused: Bool = false, timeScaleIndex: Int = PhysicsWorld.normalTimeScaleIndex,
                remainder: Int = 0, springs: [WorldSpring] = [], nextSpringId: Int? = nil, gravityLevel: Int? = nil,
                dragLevel: Int? = nil, stiffnessLevel: Int = ForceLevels.defaultStiffnessLevel,
                contactCache: [ContactCacheEntry] = []) {
        self.schema = Self.schemaVersion; self.settings = settings; self.bodies = bodies; self.tick = tick
        self.nextId = nextId ?? ((bodies.map(\.id).max() ?? -1) + 1)
        self.paused = paused; self.timeScaleIndex = timeScaleIndex; self.remainder = remainder
        self.springs = springs
        self.nextSpringId = nextSpringId ?? ((springs.map(\.id).max() ?? -1) + 1)
        self.gravityLevel = gravityLevel ?? ForceLevels.gravityLevel(matching: settings.gravity)
            ?? ForceLevels.defaultGravityLevel
        self.dragLevel = dragLevel ?? ForceLevels.dragLevel(linear: settings.linearDrag, angular: settings.angularDrag)
            ?? ForceLevels.defaultDragLevel
        self.stiffnessLevel = stiffnessLevel
        self.contactCache = contactCache
    }

    /// The world as JSON with sorted keys (deterministic bytes for equal worlds); a non-finite number gives empty
    /// data rather than a crash.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// True when every number of the settings, the bodies, the springs and the contact cache is finite.
    public var isFinite: Bool {
        settings.isFinite && bodies.allSatisfy(\.isFinite) && springs.allSatisfy(\.isFinite)
            && contactCache.allSatisfy(\.isFinite)
    }

    /// The world position of spring end `end`: the world point, or the body's local point through its pose; nil when
    /// the body does not exist.
    public func anchorPosition(_ end: WorldSpringEnd) -> Vec2? {
        guard let id = end.bodyId else { return end.point }
        return bodies.first { $0.id == id }?.pose.toWorld(end.point)
    }

    /// Every problem of the world, one line each, empty when it is sound: the schema, the settings, the body count,
    /// ids (≥ 0, unique and ascending, below ``nextId``), each body's numbers (finite), sizes (0.15…1.0 m), material
    /// (known in `catalog`), speeds (within the caps), a moving static body, a centre outside the stage, a negative
    /// tick, the time-scale index (0…3) and the remainder (0…7); then ``levelProblems()``, ``springProblems()`` and
    /// ``contactCacheProblems()``.
    public func validate(catalog: MaterialCatalog = .bundled) -> [String] {
        var out: [String] = []
        if schema != Self.schemaVersion { out.append("schema \(schema) is not \(Self.schemaVersion)") }
        out += settings.problems()
        if bodies.count > Self.maxBodies { out.append("body count \(bodies.count) exceeds \(Self.maxBodies)") }
        let tolerance = 1e-9
        var previous: Int?
        for body in bodies {
            let label = "body \(body.id)"
            if body.id < 0 { out.append("\(label): id is negative") }
            if let previous, body.id <= previous { out.append("\(label): id is not above the previous id \(previous)") }
            previous = body.id
            if body.id >= nextId { out.append("\(label): id is not below nextId \(nextId)") }
            guard body.isFinite else { out.append("\(label): non-finite value"); continue }
            if !body.sizes.allSatisfy(Self.sizeRange.contains) { out.append("\(label): size outside 0.15…1.0 m") }
            if catalog.material(id: body.materialId) == nil {
                out.append("\(label): unknown material '\(body.materialId)'")
            }
            if body.velocity.length > Self.speedCap + tolerance { out.append("\(label): speed exceeds 40 m/s") }
            if abs(body.angularVelocity) > Self.angularSpeedCap + tolerance {
                out.append("\(label): angular speed exceeds 40 rad/s")
            }
            if body.isStatic && (body.velocity != .zero || body.angularVelocity != 0) {
                out.append("\(label): static body is moving")
            }
            if !isInsideStage(body.position) { out.append("\(label): centre outside the stage") }
        }
        if tick < 0 { out.append("tick \(tick) is negative") }
        if !(0...3).contains(timeScaleIndex) { out.append("timeScaleIndex \(timeScaleIndex) is outside 0…3") }
        if !(0...7).contains(remainder) { out.append("remainder \(remainder) is outside 0…7") }
        out += levelProblems()
        out += springProblems()
        out += contactCacheProblems()
        return out
    }

    /// The problems of the force levels, one line each: a level outside its range, and settings whose gravity or drags
    /// differ from the levels' values (only checked when the level is in range and the setting is finite).
    public func levelProblems() -> [String] {
        var out: [String] = []
        if let gravity = ForceLevels.gravityVector(level: gravityLevel) {
            if settings.gravity.isFinite, settings.gravity != gravity {
                out.append("settings.gravity does not match gravityLevel \(gravityLevel)")
            }
        } else {
            out.append("gravityLevel \(gravityLevel) is outside 0…2")
        }
        if let drag = ForceLevels.dragValue(level: dragLevel) {
            if settings.linearDrag.isFinite, settings.linearDrag != drag {
                out.append("settings.linearDrag does not match dragLevel \(dragLevel)")
            }
            if settings.angularDrag.isFinite, settings.angularDrag != drag {
                out.append("settings.angularDrag does not match dragLevel \(dragLevel)")
            }
        } else {
            out.append("dragLevel \(dragLevel) is outside 0…2")
        }
        if !ForceLevels.stiffnessLevels.contains(stiffnessLevel) {
            out.append("stiffnessLevel \(stiffnessLevel) is outside 0…3")
        }
        return out
    }

    /// The problems of the springs, one line each: more than ``ForceLevels/maxSprings``; per spring an id that is
    /// negative, not above the previous id or not below ``nextSpringId``; a non-finite number; a rest length outside
    /// 0.1…10 m; an end B that is not a body; an end on a body that does not exist; both ends on the same body; a world
    /// end outside the stage.
    public func springProblems() -> [String] {
        var out: [String] = []
        if springs.count > ForceLevels.maxSprings {
            out.append("spring count \(springs.count) exceeds \(ForceLevels.maxSprings)")
        }
        let ids = Set(bodies.map(\.id))
        var previous: Int?
        for spring in springs {
            let label = "spring \(spring.id)"
            if spring.id < 0 { out.append("\(label): id is negative") }
            if let previous, spring.id <= previous { out.append("\(label): id is not above the previous id \(previous)") }
            previous = spring.id
            if spring.id >= nextSpringId { out.append("\(label): id is not below nextSpringId \(nextSpringId)") }
            guard spring.isFinite else { out.append("\(label): non-finite value"); continue }
            if !Self.restLengthRange.contains(spring.restLength) {
                out.append("\(label): rest length \(spring.restLength) is outside 0.1…10 m")
            }
            if spring.b.bodyId == nil { out.append("\(label): end b is not a body") }
            for (name, end) in [("a", spring.a), ("b", spring.b)] {
                if let id = end.bodyId {
                    if !ids.contains(id) { out.append("\(label): end \(name) body \(id) does not exist") }
                } else if !isInsideStage(end.point) {
                    out.append("\(label): end \(name) world point outside the stage")
                }
            }
            if let a = spring.a.bodyId, a == spring.b.bodyId { out.append("\(label): both ends on body \(a)") }
        }
        return out
    }

    /// The problems of the contact cache, one line each: more than ``maxContactCache`` entries; an entry whose body
    /// A is negative, whose body B is neither above body A nor a wall marker (−1…−4), whose point index is outside
    /// 0…1, whose impulses are not finite or whose normal impulse is negative; keys not strictly ascending.
    public func contactCacheProblems() -> [String] {
        var out: [String] = []
        if contactCache.count > Self.maxContactCache {
            out.append("contact cache count \(contactCache.count) exceeds \(Self.maxContactCache)")
        }
        var previous: (Int, Int, Int)?
        for (index, entry) in contactCache.enumerated() {
            let label = "contact cache \(index)"
            if entry.bodyA < 0 { out.append("\(label): bodyA is negative") }
            if !(entry.bodyB > entry.bodyA || (-4 ... -1).contains(entry.bodyB)) {
                out.append("\(label): bodyB \(entry.bodyB) is neither above bodyA nor a wall marker")
            }
            if !(0...1).contains(entry.pointIndex) { out.append("\(label): point index outside 0…1") }
            if !entry.isFinite { out.append("\(label): non-finite value") }
            else if entry.normalImpulse < 0 { out.append("\(label): normal impulse is negative") }
            let key = (entry.bodyA, entry.bodyB, entry.pointIndex)
            if let previous, !(previous < key) { out.append("\(label): key is not above the previous key") }
            previous = key
        }
        return out
    }

    /// True when `point` lies inside the stage (inclusive); false for an unusable stage size.
    private func isInsideStage(_ point: Vec2) -> Bool {
        let stage = settings.stageSize
        guard stage.isFinite, stage.x >= 0, stage.y >= 0 else { return true }
        return (0...stage.x).contains(point.x) && (0...stage.y).contains(point.y)
    }
}

// MARK: - Schema 1 and the migration 1 → 2

extension PhysicsWorld {
    /// A world record of schema 1 (feature 082), exactly the fields it was saved with.
    public struct SchemaOne: Codable, Equatable, Sendable {
        /// The schema version (1).
        public var schema: Int
        /// The settings.
        public var settings: WorldSettings
        /// The bodies.
        public var bodies: [PhysicsBody]
        /// Ticks run so far.
        public var tick: Int
        /// The next body id.
        public var nextId: Int
        /// The pause flag.
        public var paused: Bool
        /// The time-scale index.
        public var timeScaleIndex: Int
        /// The time-scale remainder.
        public var remainder: Int

        /// Creates a schema-1 record (no validation).
        public init(schema: Int = 1, settings: WorldSettings = WorldSettings(), bodies: [PhysicsBody] = [],
                    tick: Int = 0, nextId: Int, paused: Bool = false,
                    timeScaleIndex: Int = PhysicsWorld.normalTimeScaleIndex, remainder: Int = 0) {
            self.schema = schema; self.settings = settings; self.bodies = bodies; self.tick = tick
            self.nextId = nextId; self.paused = paused; self.timeScaleIndex = timeScaleIndex
            self.remainder = remainder
        }
    }

    /// Errors of ``decode(_:)``.
    public enum DecodeError: Error, Equatable {
        /// The record's schema is neither 1 nor 2.
        case unsupportedSchema(Int)
    }

    /// The schema-2 world of a schema-1 record: its bodies, tick, ids, pause flag, time-scale index and remainder,
    /// its stage, tick and iterations; no springs (next spring id 0), Earth gravity (level 2), low drag (level 1)
    /// written into the settings, stiffness level 1 and an empty contact cache. Not validated (the caller validates).
    public static func migrated(fromSchemaOne old: SchemaOne) -> PhysicsWorld {
        var settings = old.settings
        settings.gravity = ForceLevels.gravityVector(level: ForceLevels.defaultGravityLevel)!
        settings.linearDrag = ForceLevels.drag[ForceLevels.defaultDragLevel]
        settings.angularDrag = ForceLevels.drag[ForceLevels.defaultDragLevel]
        return PhysicsWorld(settings: settings, bodies: old.bodies, tick: old.tick, nextId: old.nextId,
                            paused: old.paused, timeScaleIndex: old.timeScaleIndex, remainder: old.remainder,
                            springs: [], nextSpringId: 0, gravityLevel: ForceLevels.defaultGravityLevel,
                            dragLevel: ForceLevels.defaultDragLevel,
                            stiffnessLevel: ForceLevels.defaultStiffnessLevel, contactCache: [])
    }

    /// Decodes a world record of schema 1 or 2 from JSON: it reads the `schema` number first, decodes a schema-2
    /// record as it is and migrates a schema-1 record with ``migrated(fromSchemaOne:)``. Throws the decoder's error for
    /// malformed data and ``DecodeError/unsupportedSchema(_:)`` for another schema. Not validated.
    public static func decode(_ data: Data) throws -> PhysicsWorld {
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: data)
        switch header.schema {
        case 1: return migrated(fromSchemaOne: try decoder.decode(SchemaOne.self, from: data))
        case schemaVersion: return try decoder.decode(PhysicsWorld.self, from: data)
        default: throw DecodeError.unsupportedSchema(header.schema)
        }
    }
}
