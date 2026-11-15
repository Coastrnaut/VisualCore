// ForceMeasurement — feature 084 (A11-P03) T-A11-302 (FR-A11-310 inputs; clarification 4; research D3). The measured
// forces the force arrows draw, derived during a tick and never saved:
// - The net spring force on each non-static body (pinned bodies included): the sum, over the world's springs (never the
//   grab pull), of the impulse each spring applied to the body in the tick, divided by the tick. End A of a spring
//   receives +J·n and end B −J·n, exactly the impulse `Springs2D.apply` computes (J = (k'·(L − L₀) + c·vₙ)·dt along
//   n = (pB − pA)/L). The tick applies each spring on its own, in spring order, which gives the same states as applying
//   the list at once, and computes J from the same states with the same formula, so the measured value is what was
//   applied; a spring that `Springs2D` skipped (the states did not change) adds nothing.
// - The weight m·g of a body (its material mass; zero for a static body or an unknown material).
//
// A measurement is a separate value returned by `WorldSimulation.tick(_:catalog:forces:)`,
// `advanceHostStep(_:catalog:forces:)` and `step(_:catalog:forces:)`; it is not part of `PhysicsWorld`, so it is not
// encoded, not validated and not in any digest. A restored world has no measurement until its next tick runs (the
// arrows then show no spring force). `tick` names the world tick count right after the measured tick, so a reader can
// tell whether a measurement belongs to the world it draws (`isCurrent(for:)`).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The spring forces measured during one tick (derived; never saved).
public struct ForceMeasurement: Equatable, Sendable {
    /// The world's tick count right after the measured tick (0 for an empty measurement).
    public var tick: Int
    /// The net spring force in newtons on each non-static body of the measured tick, by body id.
    public var springForces: [Int: Vec2]

    /// Creates a measurement (default: empty, tick 0).
    public init(tick: Int = 0, springForces: [Int: Vec2] = [:]) {
        self.tick = tick; self.springForces = springForces
    }

    /// The net spring force in newtons on body `id`, zero when the body was not measured.
    public func springForce(on id: Int) -> Vec2 { springForces[id] ?? .zero }

    /// True when this measurement was taken by the tick that produced `world`'s current tick count.
    public func isCurrent(for world: PhysicsWorld) -> Bool { tick == world.tick && tick > 0 }

    /// The weight m·g in newtons of `body` in `world` (its material mass times the world's gravity); zero for a static
    /// body or a material not in `catalog`. A pinned body keeps its material mass.
    public static func weight(of body: PhysicsBody, in world: PhysicsWorld, catalog: MaterialCatalog) -> Vec2 {
        guard !body.isStatic, let mass = body.mass(in: catalog) else { return .zero }
        return world.settings.gravity * mass
    }

    /// Adds `force` to `body`'s entry (non-static bodies only).
    mutating func add(_ force: Vec2, to body: PhysicsBody) {
        guard !body.isStatic else { return }
        springForces[body.id, default: .zero] += force
    }

    /// The impulse `Springs2D.apply` gives `spring` on `states` for a step `dt`: the body indices of end A and end B
    /// (nil for a world end) and the impulse J·n that end A receives (end B receives its negative). Nil when the spring
    /// would be skipped. Mirrors `Springs2D.apply` operation by operation so the value is bit-identical.
    static func appliedImpulse(_ spring: Spring2D, _ states: [RigidBodyState2D], dt: Double)
        -> (indexA: Int?, indexB: Int?, impulse: Vec2)? {
        struct End { var index: Int?; var point: Vec2; var velocity: Vec2; var inverseMass: Double }
        func resolve(_ anchor: SpringAnchor2D) -> End? {
            switch anchor {
            case .world(let p):
                guard p.isFinite else { return nil }
                return End(index: nil, point: p, velocity: .zero, inverseMass: 0)
            case let .body(index, local):
                guard states.indices.contains(index), local.isFinite else { return nil }
                let body = states[index]
                let point = Pose2D(position: body.position, angle: body.angle).toWorld(local)
                let r = point - body.position
                let velocity = body.velocity + Vec2(-body.angularVelocity * r.y, body.angularVelocity * r.x)
                guard point.isFinite, r.isFinite, velocity.isFinite else { return nil }
                return End(index: index, point: point, velocity: velocity, inverseMass: body.inverseMass)
            }
        }
        guard dt.isFinite, dt > 0, let endA = resolve(spring.a), let endB = resolve(spring.b) else { return nil }
        if let ia = endA.index, let ib = endB.index, ia == ib { return nil }
        let inverseMassSum = endA.inverseMass + endB.inverseMass
        guard inverseMassSum.isFinite, inverseMassSum > 0 else { return nil }
        let d = endB.point - endA.point
        let length = d.length
        guard length.isFinite, length >= Springs2D.minimumLength else { return nil }
        let n = d / length
        let vn = (endB.velocity - endA.velocity).dot(n)
        let m = 1 / inverseMassSum
        let k = min(spring.stiffness, Springs2D.stableStiffness(effectiveMass: m, dt: dt))
        let c = min(2 * spring.dampingRatio * (k * m).squareRoot(), Springs2D.stableDamping(effectiveMass: m, dt: dt))
        let j = (k * (length - spring.restLength) + c * vn) * dt
        let impulse = n * j
        guard j.isFinite, impulse.isFinite else { return nil }
        return (endA.index, endB.index, impulse)
    }
}
