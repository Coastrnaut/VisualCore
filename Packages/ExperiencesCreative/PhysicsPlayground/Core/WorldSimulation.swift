// WorldSimulation — feature 082 (A11-P01) T-A11-103 (FR-A11-111, FR-A11-112; clarifications 1 and 4; research D3,
// D4; SC-A11-101–104). The fixed-tick rules of the playground world. One tick (1/120 s) does, in this order:
// 1. Every dynamic body: v += g·dt; v ·= 1/(1 + kₗ·dt); ω ·= 1/(1 + kₐ·dt); then the caps (40 m/s, 40 rad/s).
// 2. Solver states: the bodies in id order (static bodies with inverse mass and inverse inertia 0), then the four
//    walls (floor, ceiling, left, right; static, restitution 0, friction 0.5).
// 3. Contacts through VisualCore's `Contacts2D.collide`: every pair i < j in id order (static–static skipped), then
//    every dynamic body against each wall. A pair whose bounding circles are more than 1e-6 m apart, or a body whose
//    bounding circle stays more than 1e-6 m inside a wall's stage edge, cannot touch and is not passed to `collide`
//    (the result is the same; this only saves work, it is not a broad phase).
// 4. `ImpulseSolver2D.solve` with the world's iteration count: velocities first, then the positional correction.
// 5. Dynamic bodies take the solved velocities and the corrected positions back; the correction of one body in one tick
//    is limited to 0.1 m so a deep overlap (a drop onto another body) separates over a few ticks and never pushes a
//    body through a 1 m wall. The caps apply again; static bodies are never written.
// 6. Semi-implicit Euler: x += v·dt, θ += ω·dt (θ kept in −π…π); the tick count increases.
//
// A world with a non-finite number, an unknown material or unsound settings is refused (`tick` returns false and
// changes nothing). `advanceHostStep` turns host steps into ticks with the quarter-tick remainder (¼ runs one tick every
// fourth host step, 2 runs two ticks per host step), so the world after N ticks is the same at every time scale;
// `step` runs exactly one tick while paused; `drop` adds a seeded body at y = 7 m.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// A static wall of the stage: its shape and pose.
public struct StageWall: Equatable, Sendable {
    /// The wall's box shape.
    public var shape: Shape2D
    /// The wall's pose (angle 0).
    public var pose: Pose2D
}

/// The fixed-tick rules of a playground world.
public enum WorldSimulation {
    /// The wall thickness in metres.
    public static let wallThickness = 1.0
    /// The walls' coefficient of restitution (a body's own restitution decides its bounce through max(eA, eB)).
    public static let wallRestitution = 0.0
    /// The walls' coefficient of friction.
    public static let wallFriction = 0.5
    /// The largest positional correction applied to one body in one tick, in metres.
    public static let maxCorrectionPerTick = 0.1
    /// The height a dropped body starts at, in metres.
    public static let dropHeight = 7.0
    /// The range of x a dropped body starts at, in metres.
    public static let dropXRange: ClosedRange<Double> = 1...9
    /// The size range of a dropped body (radius or half-extent), in metres.
    public static let dropSizeRange: ClosedRange<Double> = 0.25...0.6

    /// The four walls just outside a stage of `settings.stageSize`, each 1 m thick and overlapping at the corners, in
    /// the order floor, ceiling, left, right.
    public static func walls(for settings: WorldSettings) -> [StageWall] {
        let w = settings.stageSize.x, h = settings.stageSize.y, t = wallThickness
        let across = Vec2(w / 2 + t, t / 2), upright = Vec2(t / 2, h / 2 + t)
        return [
            StageWall(shape: .box(halfExtents: across), pose: Pose2D(position: Vec2(w / 2, -t / 2), angle: 0)),
            StageWall(shape: .box(halfExtents: across), pose: Pose2D(position: Vec2(w / 2, h + t / 2), angle: 0)),
            StageWall(shape: .box(halfExtents: upright), pose: Pose2D(position: Vec2(-t / 2, h / 2), angle: 0)),
            StageWall(shape: .box(halfExtents: upright), pose: Pose2D(position: Vec2(w + t / 2, h / 2), angle: 0)),
        ]
    }

    /// True when `world` can be simulated: finite numbers, sound settings and every material known in `catalog`.
    public static func canSimulate(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Bool {
        world.isFinite && world.settings.problems().isEmpty
            && world.bodies.allSatisfy { catalog.material(id: $0.materialId) != nil }
    }

    /// Runs one tick (see the file header). Returns false and changes nothing when the world cannot be simulated.
    /// A paused world is ticked too; pausing is handled by ``advanceHostStep(_:catalog:)`` and ``step(_:catalog:)``.
    @discardableResult
    public static func tick(_ world: inout PhysicsWorld, catalog: MaterialCatalog) -> Bool {
        guard canSimulate(world, catalog: catalog) else { return false }
        let settings = world.settings, dt = settings.tick
        let linear = 1 / (1 + settings.linearDrag * dt), angular = 1 / (1 + settings.angularDrag * dt)
        var bodies = world.bodies
        for index in bodies.indices where !bodies[index].isStatic {
            var body = bodies[index]
            body.velocity = (body.velocity + settings.gravity * dt) * linear
            body.angularVelocity *= angular
            cap(&body)
            bodies[index] = body
        }

        var states: [RigidBodyState2D] = bodies.map { body in
            let material = catalog.material(id: body.materialId)!
            let mass = body.mass(in: catalog) ?? 0, inertia = body.inertia(in: catalog) ?? 0
            return RigidBodyState2D(position: body.position, angle: body.angle, velocity: body.velocity,
                                    angularVelocity: body.angularVelocity,
                                    inverseMass: body.isStatic || mass <= 0 ? 0 : 1 / mass,
                                    inverseInertia: body.isStatic || inertia <= 0 ? 0 : 1 / inertia,
                                    restitution: material.restitution, friction: material.friction)
        }
        let walls = walls(for: settings)
        for wall in walls {
            states.append(RigidBodyState2D(position: wall.pose.position, angle: 0, velocity: .zero, angularVelocity: 0,
                                           inverseMass: 0, inverseInertia: 0, restitution: wallRestitution,
                                           friction: wallFriction))
        }

        var contacts: [Contact2D] = []
        let count = bodies.count
        let xs = bodies.map(\.position.x), ys = bodies.map(\.position.y), bounds = bodies.map(\.boundingRadius)
        let fixed = bodies.map(\.isStatic)
        for i in 0..<count {
            for j in (i + 1)..<max(count, i + 1) {
                if fixed[i] && fixed[j] { continue }
                let dx = xs[j] - xs[i], dy = ys[j] - ys[i], reach = bounds[i] + bounds[j] + 1e-6
                if dx * dx + dy * dy > reach * reach { continue }
                let a = bodies[i], b = bodies[j]
                if let manifold = Contacts2D.collide(a.shape, a.pose, b.shape, b.pose) {
                    contacts.append(Contact2D(a: i, b: j, manifold: manifold))
                }
            }
        }
        for i in 0..<count where !bodies[i].isStatic {
            let body = bodies[i]
            let bound = body.boundingRadius + 1e-6, stage = settings.stageSize
            let reaches = [body.position.y - bound <= 0, body.position.y + bound >= stage.y,
                           body.position.x - bound <= 0, body.position.x + bound >= stage.x]
            for (k, wall) in walls.enumerated() where reaches[k] {
                if let manifold = Contacts2D.collide(body.shape, body.pose, wall.shape, wall.pose) {
                    contacts.append(Contact2D(a: i, b: count + k, manifold: manifold))
                }
            }
        }

        var solver = ImpulseSolver2D.Settings()
        solver.iterations = settings.iterations
        ImpulseSolver2D.solve(&states, contacts: contacts, settings: solver)

        for index in bodies.indices where !bodies[index].isStatic {
            var body = bodies[index]
            let state = states[index]
            body.velocity = state.velocity
            body.angularVelocity = state.angularVelocity
            var correction = state.position - body.position
            let length = correction.length
            if length > maxCorrectionPerTick { correction = correction * (maxCorrectionPerTick / length) }
            body.position += correction
            cap(&body)
            body.position += body.velocity * dt
            body.angle += body.angularVelocity * dt
            if abs(body.angle) > Double.pi { body.angle = remainder(body.angle, 2 * Double.pi) }
            bodies[index] = body
        }
        guard bodies.allSatisfy(\.isFinite) else { return false }
        world.bodies = bodies
        world.tick += 1
        return true
    }

    /// One host step: nothing while paused; otherwise the time scale's quarter ticks (1, 2, 4 or 8) are added to the
    /// remainder, its whole ticks run and the rest (0…3 quarter ticks) is kept. Returns the ticks run; a world that
    /// cannot be simulated, or has a time-scale index outside 0…3 or a remainder outside 0…7, is left unchanged (0).
    @discardableResult
    public static func advanceHostStep(_ world: inout PhysicsWorld, catalog: MaterialCatalog) -> Int {
        guard !world.paused, (0...3).contains(world.timeScaleIndex), (0...7).contains(world.remainder),
              canSimulate(world, catalog: catalog) else { return 0 }
        var next = world
        let quarters = next.remainder + PhysicsWorld.quarterTicks[next.timeScaleIndex]
        next.remainder = quarters % 4
        for _ in 0..<(quarters / 4) {
            guard tick(&next, catalog: catalog) else { return 0 }
        }
        world = next
        return quarters / 4
    }

    /// The single step: exactly one tick while paused (the remainder is kept); refused (false, nothing changes) while
    /// running or when the world cannot be simulated.
    @discardableResult
    public static func step(_ world: inout PhysicsWorld, catalog: MaterialCatalog) -> Bool {
        guard world.paused else { return false }
        return tick(&world, catalog: catalog)
    }

    /// Drops a body of `kind` at rest at y = 7 m. Five draws from `random`, always in this order: x (1…9 m), the first
    /// and the second size (0.25…0.6 m; a circle's radius is the first, a box uses both as half-extents), the material
    /// (uniform over the catalog) and the angle (−π…π). The body gets ``PhysicsWorld/nextId``, which then increases.
    /// Refused (false; the world and the generator unchanged) at ``PhysicsWorld/maxBodies`` bodies, with an empty
    /// catalog, or when `nextId` cannot increase.
    @discardableResult
    public static func drop(_ world: inout PhysicsWorld, kind: BodyKind, random: inout SeededRandom,
                            catalog: MaterialCatalog) -> Bool {
        guard world.bodies.count < PhysicsWorld.maxBodies, !catalog.materials.isEmpty, world.nextId >= 0,
              world.nextId < Int.max, world.bodies.allSatisfy({ $0.id < world.nextId }) else { return false }
        let x = random.range(dropXRange)
        let first = random.range(dropSizeRange), second = random.range(dropSizeRange)
        let material = catalog.materials[random.index(below: catalog.materials.count)]
        let angle = random.range(-Double.pi...Double.pi)
        let shape: Shape2D = kind == .circle ? .circle(radius: first) : .box(halfExtents: Vec2(first, second))
        world.bodies.append(PhysicsBody(id: world.nextId, shape: shape, materialId: material.id,
                                        position: Vec2(x, dropHeight), angle: angle))
        world.nextId += 1
        return true
    }

    /// Applies the speed caps (40 m/s, 40 rad/s) to `body`.
    private static func cap(_ body: inout PhysicsBody) {
        let speed = body.velocity.length
        if speed > PhysicsWorld.speedCap { body.velocity = body.velocity * (PhysicsWorld.speedCap / speed) }
        body.angularVelocity = min(max(body.angularVelocity, -PhysicsWorld.angularSpeedCap),
                                   PhysicsWorld.angularSpeedCap)
    }
}
