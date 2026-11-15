// PhysicsWorld — feature 082 (A11-P01) T-A11-103 (FR-A11-110, FR-A11-111; clarifications 1 and 4; data-model
// "WorldSettings", "PhysicsBody", "PhysicsWorld"). The versioned world record (schema 1). Units are metres, kilograms
// (2D: density in kg/m²), seconds and radians; y is up and the origin is the stage's bottom-left corner. The stage is
// 10 m × 8 m, enclosed by four static walls 1 m thick just outside it (see `WorldSimulation.walls(for:)`).
//
// A body is a circle (radius) or a box (half-extents), each size 0.15…1.0 m, with a material id, a static flag, a
// position, an angle, a velocity and an angular velocity. Its mass is the material density × the shape area and its
// inertia comes from `Shape2D.inertia(mass:)`; a static body has mass 0, so its inverse mass and inverse inertia are 0
// and the solver never moves it. The world adds the settings, the tick count, the next body id, the pause flag, the
// time-scale index (0…3 for ¼, ½, 1 and 2) and the time-scale remainder (0…7 quarter ticks).
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

/// The world record, schema 1.
public struct PhysicsWorld: Codable, Equatable, Sendable {
    /// The schema this code writes and reads.
    public static let schemaVersion = 1
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

    /// The schema version (1).
    public var schema: Int
    /// The fixed settings.
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

    /// Creates a world (defaults: schema 1, default settings, no bodies, tick 0, running at normal speed).
    public init(settings: WorldSettings = WorldSettings(), bodies: [PhysicsBody] = [], tick: Int = 0,
                nextId: Int? = nil, paused: Bool = false, timeScaleIndex: Int = PhysicsWorld.normalTimeScaleIndex,
                remainder: Int = 0) {
        self.schema = Self.schemaVersion; self.settings = settings; self.bodies = bodies; self.tick = tick
        self.nextId = nextId ?? ((bodies.map(\.id).max() ?? -1) + 1)
        self.paused = paused; self.timeScaleIndex = timeScaleIndex; self.remainder = remainder
    }

    /// The world as JSON with sorted keys (deterministic bytes for equal worlds); a non-finite number gives empty
    /// data rather than a crash.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// True when every number of the settings and the bodies is finite.
    public var isFinite: Bool { settings.isFinite && bodies.allSatisfy(\.isFinite) }

    /// Every problem of the world, one line each, empty when it is sound: the schema, the settings, the body count,
    /// ids (≥ 0, unique and ascending, below ``nextId``), each body's numbers (finite), sizes (0.15…1.0 m), material
    /// (known in `catalog`), speeds (within the caps), a moving static body, a centre outside the stage, a negative
    /// tick, the time-scale index (0…3) and the remainder (0…7).
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
            let stage = settings.stageSize
            if stage.isFinite, stage.x >= 0, stage.y >= 0,
               !(0...stage.x).contains(body.position.x) || !(0...stage.y).contains(body.position.y) {
                out.append("\(label): centre outside the stage")
            }
        }
        if tick < 0 { out.append("tick \(tick) is negative") }
        if !(0...3).contains(timeScaleIndex) { out.append("timeScaleIndex \(timeScaleIndex) is outside 0…3") }
        if !(0...7).contains(remainder) { out.append("remainder \(remainder) is outside 0…7") }
        return out
    }
}
