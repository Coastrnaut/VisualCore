// WorldSimulation — feature 082 (A11-P01) T-A11-103 (FR-A11-111, FR-A11-112; clarifications 1 and 4; research D3,
// D4; SC-A11-101–104), extended by feature 083 (A11-P02) T-A11-203 (FR-A11-211; clarifications 1–4; research D1–D4).
// The fixed-tick rules of the playground world. One tick (1/120 s) does, in this order:
// 1. Solver states: the bodies in id order (static bodies with inverse mass and inverse inertia 0), then the four
//    walls (floor, ceiling, left, right; static, restitution 0, friction 0.5).
// 2. Springs through VisualCore's `Springs2D.apply`, in spring order, with the stiffness of the world's level (each
//    spring clamps it to its stable bound) and the damping ratio 0.1. Springs act before gravity so a spring's damper
//    never sees the gravity speed of the same tick (that would shorten a hanging body's rest stretch by 2ζ·ω·dt,
//    about 1.8 % at ζ = 0.1).
// 3. Every dynamic body: v += g·dt; v ·= 1/(1 + kₗ·dt); ω ·= 1/(1 + kₐ·dt); then the caps (40 m/s, 40 rad/s). Gravity
//    and drag come from the settings, which carry the world's gravity and drag levels.
// 4. Contacts through VisualCore's `Contacts2D.collide`: the body pairs i < j that `BroadPhase2D.pairs` reports over
//    each body's `Shape2D.bounds(at:)` (static–static skipped), in ascending (i, j) order, then every dynamic body
//    against each wall it can reach (a body whose bounding circle stays more than 1e-6 m inside a wall's stage edge is
//    not tested; this only saves work). ``ContactPairing/allPairs`` passes every pair instead (the reference the broad
//    phase is tested against; the result is identical).
// 5. Warm start: each contact's normal and tangent impulses are seeded from the contact cache entries of the same
//    (body id A, body id B or wall marker) when their count equals the manifold's point count (by point index);
//    `ImpulseSolver2D.solve(_:contacts:settings:)` with the world's iteration count then solves velocities and the
//    positional correction and writes the accumulated impulses back, which become the new cache, sorted by
//    (body id A, body id B, point index).
// 6. Dynamic bodies take the solved velocities and the corrected positions back; the correction of one body in one tick
//    is limited to 0.1 m so a deep overlap (a drop onto another body) separates over a few ticks and never pushes a
//    body through a 1 m wall. The caps apply again; static bodies are never written.
// 7. Semi-implicit Euler: x += v·dt, θ += ω·dt (θ kept in −π…π); the tick count increases.
//
// A world with a non-finite number, an unknown material, unsound settings, levels that do not match the settings or an
// unsound spring is refused (`tick` returns false and changes nothing). `advanceHostStep` turns host steps into ticks
// with the quarter-tick remainder (¼ runs one tick every fourth host step, 2 runs two ticks per host step), so the world
// after N ticks is the same at every time scale; `step` runs exactly one tick while paused; `drop` adds a seeded body at
// y = 7 m; `setGravityLevel`, `setDragLevel` and `setStiffnessLevel` change a level (and the settings it drives).
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

/// How a tick finds the body pairs it passes to contact generation.
public enum ContactPairing: Sendable, Equatable {
    /// The pairs whose bounds overlap, from VisualCore's broad phase (the default).
    case broadPhase
    /// Every pair i < j (the reference for tests; gives the identical world, more slowly).
    case allPairs
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

    /// True when `world` can be simulated: finite numbers, sound settings, every material known in `catalog`, levels
    /// in range that match the settings and sound springs.
    public static func canSimulate(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Bool {
        world.isFinite && world.settings.problems().isEmpty
            && world.bodies.allSatisfy { catalog.material(id: $0.materialId) != nil }
            && world.levelProblems().isEmpty && world.springProblems().isEmpty
    }

    /// The stiffness in N/m the world's springs use before each spring's stable clamp (from the stiffness level; the
    /// default level's value when the level is out of range).
    public static func springStiffness(_ world: PhysicsWorld) -> Double {
        ForceLevels.stiffnessValue(level: world.stiffnessLevel)
            ?? ForceLevels.stiffness[ForceLevels.defaultStiffnessLevel]
    }

    /// Runs one tick with the broad phase (see the file header). Returns false and changes nothing when the world
    /// cannot be simulated. A paused world is ticked too; pausing is handled by ``advanceHostStep(_:catalog:)`` and
    /// ``step(_:catalog:)``.
    @discardableResult
    public static func tick(_ world: inout PhysicsWorld, catalog: MaterialCatalog) -> Bool {
        tick(&world, catalog: catalog, pairing: .broadPhase)
    }

    /// Runs one tick, finding body pairs with `pairing` (see the file header). Returns false and changes nothing when
    /// the world cannot be simulated.
    @discardableResult
    public static func tick(_ world: inout PhysicsWorld, catalog: MaterialCatalog, pairing: ContactPairing) -> Bool {
        guard canSimulate(world, catalog: catalog) else { return false }
        let settings = world.settings, dt = settings.tick
        let linear = 1 / (1 + settings.linearDrag * dt), angular = 1 / (1 + settings.angularDrag * dt)
        var bodies = world.bodies

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

        // Springs.
        if !world.springs.isEmpty {
            var indexOfId: [Int: Int] = [:]
            for (index, body) in bodies.enumerated() { indexOfId[body.id] = index }
            func anchor(_ end: WorldSpringEnd) -> SpringAnchor2D {
                if let id = end.bodyId, let index = indexOfId[id] { return .body(index: index, local: end.point) }
                return .world(end.point)
            }
            let stiffness = springStiffness(world)
            let springs = world.springs.map {
                Spring2D(a: anchor($0.a), b: anchor($0.b), restLength: $0.restLength, stiffness: stiffness,
                         dampingRatio: ForceLevels.springDampingRatio)
            }
            Springs2D.apply(&states, springs: springs, dt: dt)
        }

        // Gravity and drag (after the springs, so a spring's damper never sees this tick's gravity speed), then caps.
        for index in bodies.indices where !bodies[index].isStatic {
            states[index].velocity = (states[index].velocity + settings.gravity * dt) * linear
            states[index].angularVelocity *= angular
            cap(&states[index])
        }

        // Contacts.
        var contacts: [Contact2D] = []
        let count = bodies.count
        let fixed = bodies.map(\.isStatic)
        var pairs: [(Int, Int)] = []
        switch pairing {
        case .broadPhase:
            pairs = BroadPhase2D.pairs(bodies.map { $0.shape.bounds(at: $0.pose) }).map { ($0.a, $0.b) }
        case .allPairs:
            for i in 0..<count { for j in (i + 1)..<max(count, i + 1) { pairs.append((i, j)) } }
        }
        for (i, j) in pairs where !(fixed[i] && fixed[j]) {
            let a = bodies[i], b = bodies[j]
            if let manifold = Contacts2D.collide(a.shape, a.pose, b.shape, b.pose) {
                contacts.append(Contact2D(a: i, b: j, manifold: manifold))
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

        // Warm start from the cache.
        func key(_ contact: Contact2D) -> (Int, Int) {
            (bodies[contact.a].id,
             contact.b < count ? bodies[contact.b].id : ContactCacheEntry.wallMarker(contact.b - count))
        }
        var cached: [CachePair: [ContactCacheEntry]] = [:]
        for entry in world.contactCache {
            cached[CachePair(a: entry.bodyA, b: entry.bodyB), default: []].append(entry)
        }
        for index in contacts.indices where !cached.isEmpty {
            let (idA, idB) = key(contacts[index])
            guard let entries = cached[CachePair(a: idA, b: idB)],
                  entries.count == contacts[index].manifold.points.count else {
                continue
            }
            let ordered = entries.sorted { $0.pointIndex < $1.pointIndex }
            guard ordered.map(\.pointIndex) == Array(0..<ordered.count) else { continue }
            contacts[index].normalImpulses = ordered.map(\.normalImpulse)
            contacts[index].tangentImpulses = ordered.map(\.tangentImpulse)
        }

        var solver = ImpulseSolver2D.Settings()
        solver.iterations = settings.iterations
        ImpulseSolver2D.solve(&states, contacts: &contacts, settings: solver)

        var cache: [ContactCacheEntry] = []
        for contact in contacts {
            let points = contact.manifold.points.count
            guard points > 0, contact.normalImpulses.count == points, contact.tangentImpulses.count == points else {
                continue
            }
            let (idA, idB) = key(contact)
            for point in 0..<points {
                let entry = ContactCacheEntry(bodyA: idA, bodyB: idB, pointIndex: point,
                                              normalImpulse: contact.normalImpulses[point],
                                              tangentImpulse: contact.tangentImpulses[point])
                if entry.isFinite { cache.append(entry) }
            }
        }
        cache.sort { ($0.bodyA, $0.bodyB, $0.pointIndex) < ($1.bodyA, $1.bodyB, $1.pointIndex) }

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
        world.contactCache = cache
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

    /// Sets the gravity level (0 off, 1 Moon, 2 Earth) and the settings' gravity to its vector. Refused (false,
    /// nothing changes) outside 0…2.
    @discardableResult
    public static func setGravityLevel(_ world: inout PhysicsWorld, _ level: Int) -> Bool {
        guard let gravity = ForceLevels.gravityVector(level: level) else { return false }
        world.gravityLevel = level
        world.settings.gravity = gravity
        return true
    }

    /// Sets the drag level (0 none, 1 low, 2 high) and the settings' linear and angular drag to its value. Refused
    /// (false, nothing changes) outside 0…2.
    @discardableResult
    public static func setDragLevel(_ world: inout PhysicsWorld, _ level: Int) -> Bool {
        guard let drag = ForceLevels.dragValue(level: level) else { return false }
        world.dragLevel = level
        world.settings.linearDrag = drag
        world.settings.angularDrag = drag
        return true
    }

    /// Sets the stiffness level (0…3: 20, 60, 150, 400 N/m) every spring uses. Refused (false, nothing changes)
    /// outside 0…3.
    @discardableResult
    public static func setStiffnessLevel(_ world: inout PhysicsWorld, _ level: Int) -> Bool {
        guard ForceLevels.stiffnessLevels.contains(level) else { return false }
        world.stiffnessLevel = level
        return true
    }

    /// The (body id A, body id B or wall marker) of a contact in the cache.
    private struct CachePair: Hashable {
        var a: Int
        var b: Int
    }

    /// Applies the speed caps (40 m/s, 40 rad/s) to `body`.
    private static func cap(_ body: inout PhysicsBody) {
        let speed = body.velocity.length
        if speed > PhysicsWorld.speedCap { body.velocity = body.velocity * (PhysicsWorld.speedCap / speed) }
        body.angularVelocity = min(max(body.angularVelocity, -PhysicsWorld.angularSpeedCap),
                                   PhysicsWorld.angularSpeedCap)
    }

    /// Applies the speed caps (40 m/s, 40 rad/s) to a solver state.
    private static func cap(_ state: inout RigidBodyState2D) {
        let speed = state.velocity.length
        if speed > PhysicsWorld.speedCap { state.velocity = state.velocity * (PhysicsWorld.speedCap / speed) }
        state.angularVelocity = min(max(state.angularVelocity, -PhysicsWorld.angularSpeedCap),
                                    PhysicsWorld.angularSpeedCap)
    }
}
