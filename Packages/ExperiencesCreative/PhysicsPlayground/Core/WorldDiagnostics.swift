// WorldDiagnostics — feature 082 (A11-P01) T-A11-103 (FR-A11-113; data-model "Diagnostics"). Pure read-only measures
// of a world for tests and later overlays, over dynamic bodies only (a static body has mass 0): the kinetic energy
// Σ ½·m·|v|² + ½·I·ω², the potential energy Σ m·|g|·y (y measured from the stage floor, which is the origin) and the
// momentum Σ m·v. Bodies whose material is not in the catalog count as mass 0. These are educational approximations.
import Foundation
import VisualCoreMath

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
}
