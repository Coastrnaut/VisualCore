// WorkCount — feature 086 (A11-P05) T-A11-502 (FR-A11-503; clarification 2; research D2; data-model "WorkCount";
// contract contracts/stability.md). The work one tick did, counted while it runs and returned by
// `WorldSimulation.tick(_:catalog:work:)`; derived, never saved, never validated and never part of a digest.
//
// - `narrowPhaseTests`: the calls to `Contacts2D.collide` — the body pairs the broad phase reported that were not
//   skipped (a pair in which neither body is awake and dynamic is skipped), plus the body–wall tests of awake dynamic
//   bodies that can reach a wall.
// - `contacts`: the manifolds found (each body pair or body–wall pair in contact).
// - `contactPoints`: the points of those manifolds (one or two each).
// - `solverPointUpdates`: the point updates of the impulse solver, the world's iterations × `contactPoints`.
//
// The stated budget at 48 bodies and 16 springs (clarification 2): narrow-phase tests ≤ 48·47/2 + 48·4 = 1,320, contact
// points ≤ 2 × contacts, solver point updates ≤ iterations × contact points.
import Foundation

/// The counted work of one tick (derived; never saved).
public struct WorkCount: Equatable, Sendable {
    /// The narrow-phase tests (`Contacts2D.collide` calls) of the tick.
    public var narrowPhaseTests: Int
    /// The contact manifolds found.
    public var contacts: Int
    /// The contact points of those manifolds.
    public var contactPoints: Int
    /// The solver's point updates: iterations × contact points.
    public var solverPointUpdates: Int

    /// Creates a count (default: no work).
    public init(narrowPhaseTests: Int = 0, contacts: Int = 0, contactPoints: Int = 0, solverPointUpdates: Int = 0) {
        self.narrowPhaseTests = narrowPhaseTests; self.contacts = contacts; self.contactPoints = contactPoints
        self.solverPointUpdates = solverPointUpdates
    }

    /// The most narrow-phase tests of one tick at the body cap: every body pair and every body against four walls,
    /// 48·47/2 + 48·4 = 1,320.
    public static let maxNarrowPhaseTests = PhysicsWorld.maxBodies * (PhysicsWorld.maxBodies - 1) / 2
        + 4 * PhysicsWorld.maxBodies

    /// The problems of this count against the stated budget for `iterations` solver iterations, one line each (empty
    /// when it holds): more than ``maxNarrowPhaseTests`` tests, more than two points per contact, more point updates
    /// than iterations × points.
    public func budgetProblems(iterations: Int) -> [String] {
        var out: [String] = []
        if narrowPhaseTests > Self.maxNarrowPhaseTests {
            out.append("narrowPhaseTests \(narrowPhaseTests) exceeds \(Self.maxNarrowPhaseTests)")
        }
        if contactPoints > 2 * contacts { out.append("contactPoints \(contactPoints) exceeds 2 × \(contacts)") }
        if solverPointUpdates > iterations * contactPoints {
            out.append("solverPointUpdates \(solverPointUpdates) exceeds \(iterations) × \(contactPoints)")
        }
        return out
    }
}
