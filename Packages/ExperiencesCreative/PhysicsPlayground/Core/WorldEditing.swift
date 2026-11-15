// WorldEditing — feature 084 (A11-P03) T-A11-302 (FR-A11-301, FR-A11-302; clarification 1; research D1; contract
// contracts/actions.md). The edits of the gesture editor and its native controls, as pure functions on a world. Each
// returns nil when it applied the edit and an `EditRefusal` when it refused it; a refused edit changes nothing (neither
// the world nor the generator). Coordinates are stage metres.
// - `add(kind:at:)`: a body of `kind` centred at the point, at rest. Four draws from the generator in the order
//   `WorldSimulation.drop` makes them after its x: the first and the second size (0.25…0.6 m; a circle's radius is the
//   first, a box uses both as half-extents), the material (uniform over the catalog) and the angle (−π…π). It gets
//   `nextId`. Refused with `bodyCap` at `PhysicsWorld.maxBodies` bodies (or when `nextId` cannot increase) and with
//   `noRoom` when its axis-aligned bounds leave the stage or overlap another body's bounds by more than half the new
//   body's bounds area; a non-finite point or an empty catalog is `invalidChoice`.
// - `select(id:)`: −1 clears the selection; another id must name a body (`unknownBody`).
// - `grab(id:at:)`: the body must exist (`unknownBody`) and be dynamic and unpinned (`notGrabbable`); the anchor is the
//   point in the body's frame, the target the point clamped into the stage. A new grab replaces an old one.
// - `move(to:)`: the target, clamped into the stage (`noGrab` without a grab).
// - `release()`: ends the grab (`noGrab` without one); the body keeps its own velocity.
// - `togglePin(id:)`: pins or unpins a dynamic body (`unknownBody`; `staticBody` for a static body). Pinning zeroes
//   the velocity and angular velocity and ends a grab of that body; unpinning keeps the material, so the mass returns
//   from it (mass is always derived from the material and shape).
// - `delete(id:)`: removes the body, every spring with an end on it, its contact-cache entries, and the grab and the
//   selection when they name it (`unknownBody`). `nextId` is kept.
// - `nudge(dx:dy:)`: adds 1 m/s × (dx, dy) (each clamped to −1…1) to the selected body's velocity, then the 40 m/s cap
//   (`noSelection` without a selection; `notGrabbable` for a static or pinned body; `invalidChoice` for a non-finite
//   value).
// Feature 086 (A11-P05) T-A11-502 (FR-A11-502; clarification 1; research D1): edits wake (Sleep.swift). `grab`, `nudge`
// and `togglePin` wake the body they name (a pinned body is never asleep); `delete` wakes every body whose bounds touch
// the deleted body's bounds and every body a removed spring joined to it; an added body starts awake; `select`, `move`
// and `release` wake nothing (a grabbed body is awake while grabbed).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Why an edit was refused. The raw value is the contract code without the experience prefix; ``code`` adds it.
public enum EditRefusal: String, CaseIterable, Error, Sendable {
    /// The world already holds the most bodies.
    case bodyCap = "body-cap"
    /// The new body would leave the stage or overlap another body too much.
    case noRoom = "no-room"
    /// No body has the id.
    case unknownBody = "unknown-body"
    /// The body is static or pinned and cannot be grabbed or nudged.
    case notGrabbable = "not-grabbable"
    /// There is no grab to move or release.
    case noGrab = "no-grab"
    /// A static body cannot be pinned or unpinned.
    case staticBody = "static-body"
    /// There is no selected body to nudge.
    case noSelection = "no-selection"
    /// A value is not finite (or nothing can be chosen, as with an empty catalog).
    case invalidChoice = "invalid-choice"

    /// The prefix of every Physics Playground refusal code.
    public static let prefix = "a11."

    /// The contract code, for example "a11.body-cap".
    public var code: String { Self.prefix + rawValue }
}

/// The edits of the playground's gesture editor.
public enum WorldEditing {
    /// The velocity in m/s one full nudge (value 1) adds.
    public static let nudgeSpeed = 1.0
    /// The share of the new body's bounds area another body's bounds may overlap before an add is refused.
    public static let maxAddOverlap = 0.5

    /// Adds a body of `kind` centred at `point` (see the file header for the draws and the refusals).
    public static func add(_ world: inout PhysicsWorld, kind: BodyKind, at point: Vec2, random: inout SeededRandom,
                           catalog: MaterialCatalog) -> EditRefusal? {
        guard point.isFinite, !catalog.materials.isEmpty else { return .invalidChoice }
        guard world.bodies.count < PhysicsWorld.maxBodies, world.nextId >= 0, world.nextId < Int.max,
              world.bodies.allSatisfy({ $0.id < world.nextId }) else { return .bodyCap }
        var draws = random
        let first = draws.range(WorldSimulation.dropSizeRange), second = draws.range(WorldSimulation.dropSizeRange)
        let material = catalog.materials[draws.index(below: catalog.materials.count)]
        let angle = draws.range(-Double.pi...Double.pi)
        let shape: Shape2D = kind == .circle ? .circle(radius: first) : .box(halfExtents: Vec2(first, second))
        let body = PhysicsBody(id: world.nextId, shape: shape, materialId: material.id, position: point, angle: angle)
        let bounds = shape.bounds(at: body.pose), stage = world.settings.stageSize
        guard bounds.isFinite, bounds.min.x >= 0, bounds.min.y >= 0, bounds.max.x <= stage.x,
              bounds.max.y <= stage.y else { return .noRoom }
        let area = (bounds.max.x - bounds.min.x) * (bounds.max.y - bounds.min.y)
        for other in world.bodies {
            let box = other.shape.bounds(at: other.pose)
            let w = min(bounds.max.x, box.max.x) - max(bounds.min.x, box.min.x)
            let h = min(bounds.max.y, box.max.y) - max(bounds.min.y, box.min.y)
            if w > 0, h > 0, w * h > maxAddOverlap * area { return .noRoom }
        }
        world.bodies.append(body)
        world.nextId += 1
        random = draws
        return nil
    }

    /// Selects body `id`, or clears the selection for −1.
    public static func select(_ world: inout PhysicsWorld, id: Int) -> EditRefusal? {
        if id == -1 { world.selectedId = nil; return nil }
        guard world.index(ofBody: id) != nil else { return .unknownBody }
        world.selectedId = id
        return nil
    }

    /// Grabs body `id` at the world point `point` (the anchor in the body's frame; the target clamped into the stage).
    public static func grab(_ world: inout PhysicsWorld, id: Int, at point: Vec2) -> EditRefusal? {
        guard let index = world.index(ofBody: id) else { return .unknownBody }
        guard !world.bodies[index].isFixed else { return .notGrabbable }
        guard point.isFinite else { return .invalidChoice }
        let anchor = world.bodies[index].pose.toLocal(point)
        guard anchor.isFinite else { return .invalidChoice }
        world.grab = Grab(bodyId: id, localAnchor: anchor, target: clampedIntoStage(point, world))
        Sleep.wake(&world, id: id)
        return nil
    }

    /// Moves the grab's target to `point`, clamped into the stage.
    public static func move(_ world: inout PhysicsWorld, to point: Vec2) -> EditRefusal? {
        guard world.grab != nil else { return .noGrab }
        guard point.isFinite else { return .invalidChoice }
        let target = clampedIntoStage(point, world)
        world.grab?.target = target
        return nil
    }

    /// Ends the grab; the body keeps its velocity.
    public static func release(_ world: inout PhysicsWorld) -> EditRefusal? {
        guard world.grab != nil else { return .noGrab }
        world.grab = nil
        return nil
    }

    /// Pins or unpins body `id` (see the file header).
    public static func togglePin(_ world: inout PhysicsWorld, id: Int) -> EditRefusal? {
        guard let index = world.index(ofBody: id) else { return .unknownBody }
        guard !world.bodies[index].isStatic else { return .staticBody }
        if world.bodies[index].pinned {
            world.bodies[index].pinned = false
        } else {
            world.bodies[index].pinned = true
            world.bodies[index].velocity = .zero
            world.bodies[index].angularVelocity = 0
            if world.grab?.bodyId == id { world.grab = nil }
        }
        Sleep.wake(&world, id: id)
        return nil
    }

    /// Deletes body `id` with its springs, contact-cache entries, grab and selection.
    public static func delete(_ world: inout PhysicsWorld, id: Int) -> EditRefusal? {
        guard let index = world.index(ofBody: id) else { return .unknownBody }
        let deleted = world.bodies[index]
        Sleep.wakeTouching(&world, bounds: deleted.shape.bounds(at: deleted.pose))
        for spring in world.springs where spring.a.bodyId == id || spring.b.bodyId == id {
            for other in [spring.a.bodyId, spring.b.bodyId] { if let other, other != id { Sleep.wake(&world, id: other) } }
        }
        world.bodies.remove(at: index)
        world.springs.removeAll { $0.a.bodyId == id || $0.b.bodyId == id }
        world.contactCache.removeAll { $0.bodyA == id || $0.bodyB == id }
        if world.grab?.bodyId == id { world.grab = nil }
        if world.selectedId == id { world.selectedId = nil }
        return nil
    }

    /// Adds 1 m/s × (dx, dy) to the selected body's velocity (each value clamped to −1…1), then the speed cap.
    public static func nudge(_ world: inout PhysicsWorld, dx: Double, dy: Double) -> EditRefusal? {
        guard let id = world.selectedId, let index = world.index(ofBody: id) else { return .noSelection }
        guard !world.bodies[index].isFixed else { return .notGrabbable }
        guard dx.isFinite, dy.isFinite else { return .invalidChoice }
        let delta = Vec2(min(max(dx, -1), 1), min(max(dy, -1), 1)) * nudgeSpeed
        var velocity = world.bodies[index].velocity + delta
        let speed = velocity.length
        if speed > PhysicsWorld.speedCap { velocity = velocity * (PhysicsWorld.speedCap / speed) }
        world.bodies[index].velocity = velocity
        Sleep.wake(&world, id: id)
        return nil
    }

    /// `point` clamped into the world's stage.
    public static func clampedIntoStage(_ point: Vec2, _ world: PhysicsWorld) -> Vec2 {
        let stage = world.settings.stageSize
        return Vec2(min(max(point.x, 0), stage.x), min(max(point.y, 0), stage.y))
    }
}
