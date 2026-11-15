// WorldEditingTests — feature 084 (A11-P03) T-A11-302 (FR-A11-301, FR-A11-302, FR-A11-320; clarification 1; research
// D1; contracts/actions.md; SC-A11-303, SC-A11-305). The editor's edits on the world, host-free and short:
// - every edit applies as stated and every refusal names its contract code and changes nothing (world and generator);
// - add: centred at the point with the seeded sizes, material and angle; refused at the body cap, without room at a wall
//   or on another body, allowed with a small overlap;
// - grab: the pull brings the grabbed point within 5 cm of a still target within 1 s (120 ticks); release keeps the
//   body's velocity; the target is clamped into the stage; pinning a grabbed body ends the grab;
// - delete removes the body, its springs, its contact-cache entries, the grab and the selection naming it;
// - nudge adds 1 m/s × value within the caps; validation names unsound pins, selections and grabs;
// - a recorded editing session replays to identical bytes.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct WorldEditingTests {
    private let catalog = MaterialCatalog.bundled

    /// The seeded starting scene (ids 0…9: the static ledge, six bodies, the hanging box 7 and the circles 8 and 9).
    private func scene(_ seed: UInt64 = 5) -> PhysicsWorld {
        var random = SeededRandom(seed: seed)
        return StartingScene.make(random: &random, catalog: catalog)
    }

    /// The body `add` would create from `random` (same draws), centred at `point`, and its bounds.
    private func drawn(_ kind: BodyKind, at point: Vec2, random: SeededRandom) -> (Shape2D, String, Double, AABB2D) {
        let result = drawnWithGenerator(kind, at: point, random: random)
        return (result.0, result.1, result.2, result.3)
    }

    /// Like `drawn`, plus the generator after the four draws.
    private func drawnWithGenerator(_ kind: BodyKind, at point: Vec2, random: SeededRandom)
        -> (Shape2D, String, Double, AABB2D, SeededRandom) {
        var r = random
        let first = r.range(WorldSimulation.dropSizeRange), second = r.range(WorldSimulation.dropSizeRange)
        let material = catalog.materials[r.index(below: catalog.materials.count)].id
        let angle = r.range(-Double.pi...Double.pi)
        let shape: Shape2D = kind == .circle ? .circle(radius: first) : .box(halfExtents: Vec2(first, second))
        return (shape, material, angle, shape.bounds(at: Pose2D(position: point, angle: angle)), r)
    }

    /// Applies `edit` and expects `refusal` with the world unchanged.
    private func expectRefused(_ world: PhysicsWorld, _ refusal: EditRefusal,
                               _ edit: (inout PhysicsWorld) -> EditRefusal?, sourceLocation: SourceLocation = #_sourceLocation) {
        var copy = world
        #expect(edit(&copy) == refusal, sourceLocation: sourceLocation)
        #expect(copy == world, sourceLocation: sourceLocation)
    }

    @Test func refusalCodesAreTheContractCodes() {
        #expect(EditRefusal.allCases.map(\.code) == ["a11.body-cap", "a11.no-room", "a11.unknown-body",
                                                     "a11.not-grabbable", "a11.no-grab", "a11.static-body",
                                                     "a11.no-selection", "a11.invalid-choice"])
    }

    @Test(arguments: [BodyKind.circle, .box])
    func addPlacesTheSeededBodyCentredAtThePoint(kind: BodyKind) throws {
        var world = PhysicsWorld()
        var random = SeededRandom(seed: 9)
        let point = Vec2(5, 4)
        let (shape, material, angle, _, expected) = drawnWithGenerator(kind, at: point, random: random)
        #expect(WorldEditing.add(&world, kind: kind, at: point, random: &random, catalog: catalog) == nil)
        let body = try #require(world.bodies.first)
        #expect(body.id == 0 && world.nextId == 1 && body.position == point && body.angle == angle)
        #expect(body.shape == shape && body.materialId == material && body.velocity == .zero && !body.pinned)
        #expect(random == expected)
        #expect(world.validate(catalog: catalog).isEmpty)
    }

    @Test func addIsRefusedAtTheCapAndWithoutRoomAndChangesNothing() {
        // The cap: 48 bodies in a row of small circles.
        var full = PhysicsWorld()
        for id in 0..<PhysicsWorld.maxBodies {
            full.bodies.append(PhysicsBody(id: id, shape: .circle(radius: 0.15), materialId: "wood",
                                           position: Vec2(0.2 + Double(id % 24) * 0.4, id < 24 ? 0.5 : 1.5)))
        }
        full.nextId = PhysicsWorld.maxBodies
        let random = SeededRandom(seed: 3)
        for (world, point, refusal) in [(full, Vec2(5, 6), EditRefusal.bodyCap),
                                        (PhysicsWorld(), Vec2(0.1, 4), .noRoom),
                                        (PhysicsWorld(), Vec2(5, 7.95), .noRoom),
                                        (PhysicsWorld(), Vec2(-1, 4), .noRoom),
                                        (PhysicsWorld(), Vec2(.nan, 4), .invalidChoice)] {
            var copy = world, r = random
            #expect(WorldEditing.add(&copy, kind: .box, at: point, random: &r, catalog: catalog) == refusal)
            #expect(copy == world && r == random)
        }
        var empty = PhysicsWorld(), r = random
        #expect(WorldEditing.add(&empty, kind: .box, at: Vec2(5, 4), random: &r,
                                 catalog: MaterialCatalog(materials: [])) == .invalidChoice)
        #expect(r == random && empty == PhysicsWorld())
    }

    @Test func addAllowsASmallOverlapAndRefusesMoreThanHalf() {
        let other = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(1, 1)), materialId: "steel", isStatic: true,
                                position: Vec2(3, 4))
        let world = PhysicsWorld(bodies: [other])
        let random = SeededRandom(seed: 21)
        let (_, _, _, probe) = drawn(.circle, at: .zero, random: random)
        let width = probe.max.x - probe.min.x, half = width / 2
        // The new body's bounds overlap the box (right edge x = 4) by 10 % and by 60 % of its width (full height).
        for (share, refusal) in [(0.1, nil as EditRefusal?), (0.6, .noRoom)] {
            var copy = world, r = random
            let point = Vec2(4 + half - share * width, 4)
            #expect(WorldEditing.add(&copy, kind: .circle, at: point, random: &r, catalog: catalog) == refusal)
            #expect((copy.bodies.count == 2) == (refusal == nil))
        }
        // Directly on another body.
        var copy = world, r = random
        #expect(WorldEditing.add(&copy, kind: .circle, at: Vec2(3, 4), random: &r, catalog: catalog) == .noRoom)
    }

    @Test func selectSetsAndClearsAndRefusesAnUnknownId() {
        var world = scene()
        #expect(WorldEditing.select(&world, id: 4) == nil && world.selectedId == 4)
        expectRefused(world, .unknownBody) { WorldEditing.select(&$0, id: 99) }
        expectRefused(world, .unknownBody) { WorldEditing.select(&$0, id: -2) }
        #expect(WorldEditing.select(&world, id: -1) == nil && world.selectedId == nil)
        #expect(WorldEditing.select(&world, id: -1) == nil)
    }

    @Test func grabMoveAndReleaseFollowTheRulesAndRefuse() throws {
        var world = scene()
        let body = world.bodies[2]
        let point = body.position + Vec2(0.1, -0.05)
        #expect(WorldEditing.grab(&world, id: 2, at: point) == nil)
        let grab = try #require(world.grab)
        #expect(grab.bodyId == 2 && grab.target == point)
        #expect((body.pose.toWorld(grab.localAnchor) - point).length < 1e-12)
        #expect(WorldEditing.move(&world, to: Vec2(20, -5)) == nil && world.grab?.target == Vec2(10, 0))
        #expect(WorldEditing.move(&world, to: Vec2(4, 5)) == nil && world.grab?.target == Vec2(4, 5))
        expectRefused(world, .invalidChoice) { WorldEditing.move(&$0, to: Vec2(.infinity, 1)) }
        #expect(world.validate(catalog: catalog).isEmpty)
        #expect(WorldEditing.release(&world) == nil && world.grab == nil)
        expectRefused(world, .noGrab) { WorldEditing.release(&$0) }
        expectRefused(world, .noGrab) { WorldEditing.move(&$0, to: Vec2(1, 1)) }
        expectRefused(world, .unknownBody) { WorldEditing.grab(&$0, id: 77, at: Vec2(1, 1)) }
        expectRefused(world, .notGrabbable) { WorldEditing.grab(&$0, id: 0, at: Vec2(2, 2.5)) }   // static ledge
        #expect(WorldEditing.togglePin(&world, id: 3) == nil)
        expectRefused(world, .notGrabbable) { WorldEditing.grab(&$0, id: 3, at: world.bodies[3].position) }
        // A grab outside the stage gets a clamped target.
        #expect(WorldEditing.grab(&world, id: 2, at: Vec2(-3, 9)) == nil && world.grab?.target == Vec2(0, 8))
    }

    @Test func aGrabReachesAStillTargetWithinOneSecondAndReleaseKeepsTheVelocity() throws {
        // A wood box resting on the floor, grabbed off-centre and pulled to a still target in mid-air.
        let box = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood",
                              position: Vec2(2, 0.3))
        var world = PhysicsWorld(bodies: [box])
        let target = Vec2(6, 5)
        #expect(WorldEditing.grab(&world, id: 0, at: Vec2(2.1, 0.5)) == nil)
        #expect(WorldEditing.move(&world, to: target) == nil)
        for _ in 0..<120 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
        let grab = try #require(world.grab)
        let anchor = world.bodies[0].pose.toWorld(grab.localAnchor)
        #expect((anchor - target).length <= 0.05, "distance \((anchor - target).length)")
        #expect(world.springs.isEmpty && world.validate(catalog: catalog).isEmpty)
        // Throw: move the target, run a few ticks, release; the body keeps exactly its velocity.
        #expect(WorldEditing.move(&world, to: Vec2(9, 7)) == nil)
        for _ in 0..<6 { WorldSimulation.tick(&world, catalog: catalog) }
        let before = world.bodies[0]
        #expect(before.velocity.length > 1)
        #expect(WorldEditing.release(&world) == nil)
        #expect(world.bodies[0] == before)
        // The next tick has no pull: only gravity and drag change the velocity.
        WorldSimulation.tick(&world, catalog: catalog)
        let dt = world.settings.tick, linear = 1 / (1 + world.settings.linearDrag * dt)
        let expected = (before.velocity + world.settings.gravity * dt) * linear
        #expect((world.bodies[0].velocity - expected).length < 1e-12)
    }

    @Test func pinTogglesZeroesTheVelocityEndsAGrabAndRefusesStaticBodies() throws {
        var world = scene()
        world.bodies[4].velocity = Vec2(2, -1)
        world.bodies[4].angularVelocity = 3
        #expect(WorldEditing.grab(&world, id: 4, at: world.bodies[4].position) == nil)
        let mass = try #require(world.bodies[4].mass(in: catalog))
        #expect(WorldEditing.togglePin(&world, id: 4) == nil)
        #expect(world.bodies[4].pinned && world.bodies[4].velocity == .zero && world.bodies[4].angularVelocity == 0)
        #expect(world.grab == nil && world.bodies[4].mass(in: catalog) == mass)
        #expect(world.validate(catalog: catalog).isEmpty)
        #expect(WorldEditing.togglePin(&world, id: 4) == nil)
        #expect(!world.bodies[4].pinned && world.bodies[4].mass(in: catalog) == mass)
        expectRefused(world, .staticBody) { WorldEditing.togglePin(&$0, id: 0) }
        expectRefused(world, .unknownBody) { WorldEditing.togglePin(&$0, id: 50) }
        // Pinning a grabbed body ends its grab.
        #expect(WorldEditing.grab(&world, id: 5, at: world.bodies[5].position) == nil)
        #expect(WorldEditing.togglePin(&world, id: 5) == nil && world.grab == nil)
    }

    @Test func deleteRemovesTheBodyItsSpringsCacheEntriesGrabAndSelection() {
        var world = scene()
        // Run until circle 8 (on spring 1, bouncing on the floor) has a contact-cache entry (at most 600 ticks).
        for _ in 0..<600 where !world.contactCache.contains(where: { $0.bodyA == 8 || $0.bodyB == 8 }) {
            WorldSimulation.tick(&world, catalog: catalog)
        }
        #expect(world.contactCache.contains { $0.bodyA == 8 || $0.bodyB == 8 })
        #expect(WorldEditing.select(&world, id: 8) == nil)
        #expect(WorldEditing.grab(&world, id: 8, at: world.bodies[8].position) == nil)
        let nextId = world.nextId
        #expect(WorldEditing.delete(&world, id: 8) == nil)
        #expect(!world.bodies.contains { $0.id == 8 } && world.bodies.count == 9 && world.nextId == nextId)
        #expect(world.springs.map(\.id) == [0])
        #expect(!world.contactCache.contains { $0.bodyA == 8 || $0.bodyB == 8 })
        #expect(world.grab == nil && world.selectedId == nil)
        #expect(world.validate(catalog: catalog).isEmpty)
        #expect(WorldEditing.select(&world, id: 2) == nil)
        #expect(WorldEditing.delete(&world, id: 7) == nil)
        #expect(world.springs.isEmpty && world.selectedId == 2)
        expectRefused(world, .unknownBody) { WorldEditing.delete(&$0, id: 7) }
        // A static body can be deleted too.
        #expect(WorldEditing.delete(&world, id: 0) == nil && world.validate(catalog: catalog).isEmpty)
        #expect(WorldSimulation.tick(&world, catalog: catalog))
    }

    @Test func nudgeAddsOneMetrePerSecondPerUnitWithinTheCaps() {
        var world = scene()
        expectRefused(world, .noSelection) { WorldEditing.nudge(&$0, dx: 1, dy: 0) }
        #expect(WorldEditing.select(&world, id: 0) == nil)
        expectRefused(world, .notGrabbable) { WorldEditing.nudge(&$0, dx: 1, dy: 0) }
        #expect(WorldEditing.select(&world, id: 3) == nil)
        #expect(WorldEditing.nudge(&world, dx: 0.5, dy: -1) == nil && world.bodies[3].velocity == Vec2(0.5, -1))
        #expect(WorldEditing.nudge(&world, dx: 3, dy: 0) == nil && world.bodies[3].velocity == Vec2(1.5, -1))
        expectRefused(world, .invalidChoice) { WorldEditing.nudge(&$0, dx: .nan, dy: 0) }
        world.bodies[3].velocity = Vec2(39.9, 0)
        #expect(WorldEditing.nudge(&world, dx: 1, dy: 0) == nil)
        #expect(abs(world.bodies[3].velocity.length - PhysicsWorld.speedCap) < 1e-9)
        #expect(WorldEditing.togglePin(&world, id: 3) == nil)
        expectRefused(world, .notGrabbable) { WorldEditing.nudge(&$0, dx: 1, dy: 0) }
    }

    @Test func validationNamesUnsoundPinsSelectionsAndGrabs() {
        let good = scene()
        func problems(_ change: (inout PhysicsWorld) -> Void) -> [String] {
            var world = good
            change(&world)
            return world.validate(catalog: catalog)
        }
        #expect(problems { $0.bodies[0].pinned = true } == ["body 0: static body is pinned"])
        #expect(problems { $0.bodies[2].pinned = true; $0.bodies[2].velocity = Vec2(1, 0) }
            == ["body 2: pinned body is moving"])
        #expect(problems { $0.selectedId = 40 } == ["selectedId 40 names no body"])
        #expect(problems { $0.grab = Grab(bodyId: 0, localAnchor: .zero, target: Vec2(1, 1)) }
            == ["grab of body 0: body is static"])
        #expect(problems { $0.bodies[2].pinned = true; $0.grab = Grab(bodyId: 2, localAnchor: .zero, target: Vec2(1, 1)) }
            == ["grab of body 2: body is pinned"])
        #expect(problems { $0.grab = Grab(bodyId: 30, localAnchor: .zero, target: Vec2(1, 1)) }
            == ["grab of body 30: body does not exist"])
        #expect(problems { $0.grab = Grab(bodyId: 2, localAnchor: .zero, target: Vec2(11, 1)) }
            == ["grab of body 2: target outside the stage"])
        #expect(problems { $0.grab = Grab(bodyId: 2, localAnchor: Vec2(.nan, 0), target: Vec2(1, 1)) }
            == ["grab of body 2: non-finite value"])
        // Overlay choices never make a world unsound.
        #expect(problems { $0.showVelocity = true; $0.showForces = true } == [])
    }

    @Test func aRecordedEditingSessionReplaysIdentically() {
        enum Edit { case add(BodyKind, Vec2), select(Int), grab(Int), move(Vec2), release, pin(Int), delete(Int),
                    nudge(Double, Double) }
        let session: [(tick: Int, edit: Edit)] = [
            (0, .add(.circle, Vec2(5, 5))), (10, .select(10)), (12, .nudge(1, 0.5)), (30, .grab(2)),
            (31, .move(Vec2(4, 6))), (60, .move(Vec2(8, 7))), (80, .release), (90, .pin(4)), (120, .delete(8)),
            (150, .add(.box, Vec2(8, 4))), (170, .pin(4)), (200, .delete(10)),
        ]
        func play() -> (Data, SeededRandom) {
            var random = SeededRandom(seed: 77)
            var world = StartingScene.make(random: &random, catalog: catalog)
            for tick in 0..<240 {
                for entry in session where entry.tick == tick {
                    switch entry.edit {
                    case let .add(kind, p): _ = WorldEditing.add(&world, kind: kind, at: p, random: &random, catalog: catalog)
                    case .select(let id): _ = WorldEditing.select(&world, id: id)
                    case .grab(let id):
                        if let body = world.bodies.first(where: { $0.id == id }) {
                            _ = WorldEditing.grab(&world, id: id, at: body.position)
                        }
                    case .move(let p): _ = WorldEditing.move(&world, to: p)
                    case .release: _ = WorldEditing.release(&world)
                    case .pin(let id): _ = WorldEditing.togglePin(&world, id: id)
                    case .delete(let id): _ = WorldEditing.delete(&world, id: id)
                    case let .nudge(dx, dy): _ = WorldEditing.nudge(&world, dx: dx, dy: dy)
                    }
                }
                #expect(WorldSimulation.tick(&world, catalog: catalog))
            }
            #expect(world.validate(catalog: catalog).isEmpty)
            return (world.encoded(), random)
        }
        let first = play(), second = play()
        #expect(first.0 == second.0 && first.1 == second.1 && !first.0.isEmpty)
    }
}
