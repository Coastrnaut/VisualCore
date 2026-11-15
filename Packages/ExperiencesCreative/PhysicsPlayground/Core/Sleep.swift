// Sleep — feature 086 (A11-P05) T-A11-502 (FR-A11-502; clarification 1; research D1; data-model "PhysicsBody (world
// schema 4)"; contract contracts/stability.md). Resting bodies fall asleep and cost nothing until something touches,
// pulls or edits them. Sleep is an optimisation: a sleeping body is drawn and described exactly like an awake one.
//
// - Thresholds: speed below 0.05 m/s and angular speed below 0.05 rad/s for 60 consecutive ticks (0.5 s).
// - Rest count (after integration, every tick, `settle`): a dynamic (not static), unpinned, ungrabbed, awake body whose
//   speed and angular speed are both below the thresholds adds 1 to `restTicks` (held at 60); any other awake body has
//   `restTicks` 0. A static, pinned or grabbed body is never asleep. An anchored body — one joined by a spring to a
//   world point or to a static or pinned body — also keeps `restTicks` 0: frozen bodies must be in balance, and resting
//   contacts and friction balance any load, but an anchored spring balances only at one stretch. With the damping ratio
//   0.1 a hanging body's speed stays below 0.05 m/s through whole swings of amplitude up to 0.05/ω (5 mm at 20 N/m),
//   so it would freeze up to that far from its rest stretch (more than the 2 % of the equilibrium fixtures). Springs
//   between two dynamic bodies do not anchor (their bodies sleep together, see below).
// - Falling asleep: bodies that touch rest on each other, so they sleep together. The awake dynamic bodies are grouped
//   by overlapping bounds (`Shape2D.bounds(at:)`, the broad phase's inclusive overlap) and by springs joining two of them;
//   static and pinned bodies and the walls never join a group. A group whose every body has 60 rest ticks (and none is
//   grabbed) falls asleep in that tick: `asleep` true and velocity and angular velocity 0. Without the grouping a body
//   that reached 60 first would be woken again by a touching neighbour that had not (the wake rule below), and a stack
//   would never settle.
// - Waking (`wake(_:id:)`: `asleep` false, `restTicks` 0). Before contacts, every tick (`applyWakeTriggers`): a sleeping
//   body whose bounds overlap an awake dynamic body's bounds, or that a spring joins to an awake dynamic body, wakes,
//   repeated until nothing changes (a woken body wakes its own sleeping neighbours in the same tick). A static or pinned
//   body never wakes another. Every level change wakes all bodies (`wakeAll`); the edits wake the body they name (grab,
//   nudge, pin and unpin) and a delete wakes every body whose bounds touch the deleted body's bounds and every body a
//   removed spring joined to it (WorldEditing.swift). Selecting a body does not wake it. Presets, the starting scene and
//   added or dropped bodies start awake.
// - While asleep (WorldSimulation.swift): no gravity, drag or integration, and the tick never writes the body; a pair in
//   which neither body is awake and dynamic, and a sleeping body against a wall, are not tested by the narrow phase.
//   After the wake triggers no sleeping body's bounds overlap an awake dynamic body's bounds, so a sleeping body is in
//   no contact at all.
//
// Everything here is pure and deterministic (id order, the broad phase's sorted pairs).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The sleep rules of the playground world.
public enum Sleep {
    /// The speed in m/s below which a body rests.
    public static let linearThreshold = 0.05
    /// The angular speed in rad/s below which a body rests.
    public static let angularThreshold = 0.05
    /// The consecutive resting ticks after which a body (with the bodies it touches) falls asleep.
    public static let ticksToSleep = 60

    /// True when `body` moves slower than both thresholds.
    public static func isResting(_ body: PhysicsBody) -> Bool {
        body.velocity.length < linearThreshold && abs(body.angularVelocity) < angularThreshold
    }

    /// Wakes body `id` (asleep false, rest ticks 0); nothing when no body has the id.
    public static func wake(_ world: inout PhysicsWorld, id: Int) {
        guard let index = world.index(ofBody: id) else { return }
        world.bodies[index].asleep = false
        world.bodies[index].restTicks = 0
    }

    /// Wakes every body of the world (a level change).
    public static func wakeAll(_ world: inout PhysicsWorld) {
        for index in world.bodies.indices {
            world.bodies[index].asleep = false
            world.bodies[index].restTicks = 0
        }
    }

    /// Wakes every body whose bounds touch `bounds` (inclusive, as the broad phase).
    public static func wakeTouching(_ world: inout PhysicsWorld, bounds: AABB2D) {
        for index in world.bodies.indices where world.bodies[index].shape.bounds(at: world.bodies[index].pose)
            .overlaps(bounds) {
            world.bodies[index].asleep = false
            world.bodies[index].restTicks = 0
        }
    }

    /// The wake triggers applied before contacts (see the file header): a static, pinned or grabbed body is never
    /// asleep; then sleeping bodies overlapping an awake dynamic body or joined by a spring to one wake, until nothing
    /// changes.
    static func applyWakeTriggers(_ bodies: inout [PhysicsBody], springs: [WorldSpring], grabbedId: Int?) {
        for index in bodies.indices where bodies[index].asleep
            && (bodies[index].isFixed || bodies[index].id == grabbedId) {
            bodies[index].asleep = false
            bodies[index].restTicks = 0
        }
        guard bodies.contains(where: \.isSleeping), bodies.contains(where: \.isAwakeDynamic) else { return }
        let links = links(bodies, springs: springs)
        var changed = true
        while changed {
            changed = false
            for (a, b) in links {
                let sleepA = bodies[a].isSleeping, sleepB = bodies[b].isSleeping
                if sleepA, bodies[b].isAwakeDynamic {
                    bodies[a].asleep = false; bodies[a].restTicks = 0; changed = true
                } else if sleepB, bodies[a].isAwakeDynamic {
                    bodies[b].asleep = false; bodies[b].restTicks = 0; changed = true
                }
            }
        }
    }

    /// The rest count and falling asleep after integration (see the file header).
    static func settle(_ bodies: inout [PhysicsBody], springs: [WorldSpring], grabbedId: Int?) {
        let anchored = anchoredIds(bodies, springs: springs)
        var ready = false
        for index in bodies.indices {
            if bodies[index].isFixed || bodies[index].id == grabbedId {
                bodies[index].asleep = false
                bodies[index].restTicks = 0
                continue
            }
            guard !bodies[index].asleep else { continue }
            if isResting(bodies[index]), !anchored.contains(bodies[index].id) {
                bodies[index].restTicks = min(bodies[index].restTicks + 1, ticksToSleep)
                if bodies[index].restTicks == ticksToSleep { ready = true }
            } else {
                bodies[index].restTicks = 0
            }
        }
        guard ready else { return }
        // Groups of awake dynamic bodies joined by overlapping bounds or springs (union–find, smallest index as root).
        var parent = Array(bodies.indices)
        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        for (a, b) in links(bodies, springs: springs) where bodies[a].isAwakeDynamic && bodies[b].isAwakeDynamic {
            let ra = root(a), rb = root(b)
            if ra != rb { parent[max(ra, rb)] = min(ra, rb) }
        }
        var groupReady: [Int: Bool] = [:]
        for index in bodies.indices where bodies[index].isAwakeDynamic {
            let r = root(index)
            groupReady[r] = (groupReady[r] ?? true) && bodies[index].restTicks >= ticksToSleep
                && bodies[index].id != grabbedId
        }
        for index in bodies.indices where bodies[index].isAwakeDynamic && groupReady[root(index)] == true {
            bodies[index].asleep = true
            bodies[index].velocity = .zero
            bodies[index].angularVelocity = 0
        }
    }

    /// The ids of the anchored bodies: joined by a spring to a world point or to a static or pinned body.
    static func anchoredIds(_ bodies: [PhysicsBody], springs: [WorldSpring]) -> Set<Int> {
        guard !springs.isEmpty else { return [] }
        var fixedIds = Set<Int>()
        for body in bodies where body.isFixed { fixedIds.insert(body.id) }
        var out = Set<Int>()
        for spring in springs {
            let aFixed = spring.a.bodyId.map(fixedIds.contains) ?? true
            let bFixed = spring.b.bodyId.map(fixedIds.contains) ?? true
            if aFixed, let b = spring.b.bodyId { out.insert(b) }
            if bFixed, let a = spring.a.bodyId { out.insert(a) }
        }
        return out
    }

    /// The body index pairs (a < b) joined by overlapping bounds (the broad phase) or by a spring between two bodies,
    /// in a fixed order: the overlap pairs as the broad phase sorts them, then the springs in spring order.
    static func links(_ bodies: [PhysicsBody], springs: [WorldSpring]) -> [(Int, Int)] {
        var out = BroadPhase2D.pairs(bodies.map { $0.shape.bounds(at: $0.pose) }).map { ($0.a, $0.b) }
        guard !springs.isEmpty else { return out }
        var indexOfId: [Int: Int] = [:]
        for (index, body) in bodies.enumerated() { indexOfId[body.id] = index }
        for spring in springs {
            guard let idA = spring.a.bodyId, let idB = spring.b.bodyId, let a = indexOfId[idA], let b = indexOfId[idB],
                  a != b else { continue }
            out.append((min(a, b), max(a, b)))
        }
        return out
    }
}
