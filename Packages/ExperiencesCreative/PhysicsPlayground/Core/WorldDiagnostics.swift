// WorldDiagnostics — feature 082 (A11-P01) T-A11-103 (FR-A11-113; data-model "Diagnostics"). Pure read-only measures
// of a world for tests and later overlays, over dynamic bodies only (a static body has mass 0): the kinetic energy
// Σ ½·m·|v|² + ½·I·ω², the potential energy Σ m·|g|·y (y measured from the stage floor, which is the origin) and the
// momentum Σ m·v. Bodies whose material is not in the catalog count as mass 0. These are educational approximations.
// Feature 083 (A11-P02) T-A11-203 adds the spring potential energy Σ ½·k'·(L − L₀)² over the springs, where k' is the
// world's stiffness clamped to each spring's stable bound `Springs2D.stableStiffness(effectiveMass:dt:)` (effective mass
// 1/(Σ inverse masses of the ends); a spring between two static ends or a missing body counts 0), and the total energy
// kinetic + gravitational + spring potential.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Read-only energy and momentum measures of a world.
public enum WorldDiagnostics {
    /// The kinetic energy in joules: Σ ½·m·|v|² + ½·I·ω² over the dynamic bodies.
    public static func kineticEnergy(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Double {
        world.bodies.reduce(0) { total, body in
            guard !body.isStatic, let mass = body.mass(in: catalog), let inertia = body.inertia(in: catalog) else {
                return total
            }
            let v = body.velocity.length
            return total + 0.5 * mass * v * v + 0.5 * inertia * body.angularVelocity * body.angularVelocity
        }
    }

    /// The potential energy in joules: Σ m·|g|·y over the dynamic bodies, y from the stage floor.
    public static func potentialEnergy(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Double {
        let g = world.settings.gravity.length
        return world.bodies.reduce(0) { total, body in
            guard !body.isStatic, let mass = body.mass(in: catalog) else { return total }
            return total + mass * g * body.position.y
        }
    }

    /// The momentum in kg·m/s: Σ m·v over the dynamic bodies.
    public static func momentum(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Vec2 {
        world.bodies.reduce(Vec2.zero) { total, body in
            guard !body.isStatic, let mass = body.mass(in: catalog) else { return total }
            return total + body.velocity * mass
        }
    }

    /// The spring potential energy in joules: Σ ½·k'·(L − L₀)² over the springs, k' the world's stiffness clamped to
    /// the spring's stable bound for its effective mass and the tick; a spring with a missing body or two static ends
    /// counts 0.
    public static func springPotentialEnergy(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Double {
        let stiffness = WorldSimulation.springStiffness(world)
        func inverseMass(_ end: WorldSpringEnd) -> Double? {
            guard let id = end.bodyId else { return 0 }
            guard let body = world.bodies.first(where: { $0.id == id }), let mass = body.mass(in: catalog) else {
                return nil
            }
            return mass > 0 ? 1 / mass : 0
        }
        return world.springs.reduce(0) { total, spring in
            guard let pa = world.anchorPosition(spring.a), let pb = world.anchorPosition(spring.b),
                  let ia = inverseMass(spring.a), let ib = inverseMass(spring.b), ia + ib > 0 else { return total }
            let k = min(stiffness, Springs2D.stableStiffness(effectiveMass: 1 / (ia + ib), dt: world.settings.tick))
            let stretch = (pb - pa).length - spring.restLength
            return total + 0.5 * k * stretch * stretch
        }
    }

    /// The total energy in joules: kinetic + gravitational potential + spring potential.
    public static func totalEnergy(_ world: PhysicsWorld, catalog: MaterialCatalog) -> Double {
        kineticEnergy(world, catalog: catalog) + potentialEnergy(world, catalog: catalog)
            + springPotentialEnergy(world, catalog: catalog)
    }
}
