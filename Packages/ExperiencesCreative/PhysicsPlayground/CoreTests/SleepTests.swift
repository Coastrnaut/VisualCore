// SleepTests — feature 086 (A11-P05) T-A11-502 (FR-A11-502, FR-A11-510; clarification 1; research D1; SC-A11-502,
// SC-A11-503). Sleep, host-free and short:
// - The stacked-objects preset is fully asleep within 360 ticks (3 s); from then on a tick tests no pair and finds no
//   contact, and the sleeping world stays exactly as it is.
// - Each wake trigger wakes in that tick: a dropped body whose bounds reach the sleeping stack; a spring to an awake
//   dynamic body; each level change (gravity, drag, stiffness); a grab, a nudge (a selection alone does not wake), a pin;
//   a delete wakes the bodies touching the deleted one. A static or pinned body and a world-point spring wake nothing.
// - Validation names a moving, static, pinned or grabbed sleeping body and rest ticks outside 0…60.
// - A session over every action kind (drops, adds, select, grab, move, release, nudge, pin, unpin, delete, the three
//   levels, pause, single steps, time scales) in which bodies fall asleep and wake replays to the identical encoded
//   world, and saving and restoring halfway continues to the same world.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct SleepTests {
    private let catalog = MaterialCatalog.bundled

    /// The stacked-objects preset ticked until every box sleeps (at most 360 ticks), and the ticks it took.
    private func settledStack() -> (PhysicsWorld, Int) {
        var random = SeededRandom(seed: 1)
        var world = Presets.make(.stackedObjects, random: &random, catalog: catalog)
        #expect(world.bodies.allSatisfy { !$0.asleep && $0.restTicks == 0 })
        var ticks = 0
        while ticks < 360, !world.bodies.allSatisfy(\.asleep) {
            WorldSimulation.tick(&world, catalog: catalog)
            ticks += 1
        }
        return (world, ticks)
    }

    @Test func theStackFallsAsleepWithinThreeSecondsAndThenTestsNothing() {
        let (settled, ticks) = settledStack()
        print("stacked objects fully asleep after \(ticks) ticks")
        #expect(settled.bodies.allSatisfy { $0.asleep && $0.velocity == .zero && $0.angularVelocity == 0 })
        #expect(ticks <= 360 && settled.validate(catalog: catalog).isEmpty)
        // Settled positions are still a stack on the floor.
        for (index, body) in settled.bodies.enumerated() {
            #expect(abs(body.position.y - 0.25 * Double(2 * index + 1)) < 0.02 && abs(body.position.x - 5) < 0.02)
        }
        var world = settled
        var work = WorkCount(narrowPhaseTests: -1)
        for _ in 0..<60 {
            #expect(WorldSimulation.tick(&world, catalog: catalog, work: &work))
            #expect(work == WorkCount())
        }
        var unchanged = world
        unchanged.tick = settled.tick
        unchanged.contactCache = settled.contactCache
        #expect(unchanged == settled && world.contactCache.isEmpty)
        // The preset itself starts awake, before any work: five boxes and the floor.
        var random = SeededRandom(seed: 1)
        var fresh = Presets.make(.stackedObjects, random: &random, catalog: catalog)
        #expect(WorldSimulation.tick(&fresh, catalog: catalog, work: &work))
        #expect(work.narrowPhaseTests > 0 && work.contacts >= 5)
    }

    @Test func aBodyDroppedOntoTheSleepingStackWakesItInTheTickItsBoundsReachIt() throws {
        var (world, _) = settledStack()
        var random = SeededRandom(seed: 5)
        #expect(WorldSimulation.drop(&world, kind: .circle, random: &random, catalog: catalog))
        let dropped = world.bodies.count - 1
        world.bodies[dropped].position.x = 5
        var woke = false
        for _ in 0..<240 {
            let top = world.bodies[4], ball = world.bodies[dropped]
            let touching = top.shape.bounds(at: top.pose).overlaps(ball.shape.bounds(at: ball.pose))
            #expect(world.bodies[4].asleep == !woke)
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            if touching {
                #expect(world.bodies.prefix(5).allSatisfy { !$0.asleep })
                woke = true
                break
            }
            #expect(world.bodies.prefix(5).allSatisfy { $0.asleep })
        }
        #expect(woke)
    }

    @Test func aSpringToAnAwakeBodyWakesButAWorldPointStaticOrPinnedBodyDoesNot() {
        let sleeping = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood",
                                   position: Vec2(2, 0.3), asleep: true, restTicks: 60)
        let mover = PhysicsBody(id: 1, shape: .circle(radius: 0.3), materialId: "rubber", position: Vec2(6, 4),
                                velocity: Vec2(1, 0))
        let spring = WorldSpring(id: 0, a: .body(0), b: .body(1), restLength: 4)
        var world = PhysicsWorld(bodies: [sleeping, mover], springs: [spring])
        #expect(world.validate(catalog: catalog).isEmpty)
        #expect(WorldSimulation.tick(&world, catalog: catalog))
        #expect(!world.bodies[0].asleep)
        // A world-point spring, a static ledge and a pinned box touching it leave a sleeping body asleep.
        let anchored = WorldSpring(id: 0, a: .world(Vec2(2, 3)), b: .body(0), restLength: 2.4)
        let ledge = PhysicsBody(id: 1, shape: .box(halfExtents: Vec2(1, 0.15)), materialId: "steel", isStatic: true,
                                position: Vec2(2, 0.75))
        let pinned = PhysicsBody(id: 2, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "steel",
                                 position: Vec2(2.6, 0.3), pinned: true)
        var quiet = PhysicsWorld(bodies: [sleeping, ledge, pinned], springs: [anchored])
        #expect(quiet.validate(catalog: catalog).isEmpty)
        for _ in 0..<30 { #expect(WorldSimulation.tick(&quiet, catalog: catalog)) }
        #expect(quiet.bodies[0] == sleeping)
    }

    @Test func everyLevelChangeWakesEveryBody() {
        let (settled, _) = settledStack()
        let changes: [(inout PhysicsWorld) -> Bool] = [
            { WorldSimulation.setGravityLevel(&$0, 1) }, { WorldSimulation.setGravityLevel(&$0, 2) },
            { WorldSimulation.setDragLevel(&$0, 2) }, { WorldSimulation.setStiffnessLevel(&$0, 3) },
        ]
        for change in changes {
            var world = settled
            #expect(change(&world))
            #expect(world.bodies.allSatisfy { !$0.asleep && $0.restTicks == 0 })
        }
        // A refused level wakes nothing.
        var world = settled
        #expect(!WorldSimulation.setGravityLevel(&world, 7) && world == settled)
    }

    @Test func grabNudgePinAndDeleteWakeInTheSameEdit() {
        let (settled, _) = settledStack()
        var grabbed = settled
        #expect(WorldEditing.grab(&grabbed, id: 2, at: grabbed.bodies[2].position) == nil)
        #expect(!grabbed.bodies[2].asleep && grabbed.bodies[0].asleep && grabbed.validate(catalog: catalog).isEmpty)
        #expect(WorldSimulation.tick(&grabbed, catalog: catalog))
        #expect(grabbed.bodies.allSatisfy { !$0.asleep })

        var nudged = settled
        #expect(WorldEditing.select(&nudged, id: 4) == nil)
        #expect(nudged.bodies[4].asleep)
        #expect(WorldEditing.nudge(&nudged, dx: 1, dy: 0) == nil)
        #expect(!nudged.bodies[4].asleep && nudged.bodies[4].velocity == Vec2(1, 0))
        #expect(nudged.validate(catalog: catalog).isEmpty)

        var pinned = settled
        #expect(WorldEditing.togglePin(&pinned, id: 1) == nil)
        #expect(pinned.bodies[1].pinned && !pinned.bodies[1].asleep && pinned.validate(catalog: catalog).isEmpty)
        #expect(WorldEditing.togglePin(&pinned, id: 1) == nil)
        #expect(!pinned.bodies[1].pinned && !pinned.bodies[1].asleep)

        var deleted = settled
        #expect(WorldEditing.delete(&deleted, id: 4) == nil)
        #expect(!deleted.bodies[3].asleep && deleted.bodies[0].asleep && deleted.bodies[2].asleep)
        #expect(WorldSimulation.tick(&deleted, catalog: catalog))
        #expect(deleted.bodies.allSatisfy { !$0.asleep })

        // An added body starts awake; the add itself wakes nothing.
        var added = settled
        var random = SeededRandom(seed: 3)
        #expect(WorldEditing.add(&added, kind: .box, at: Vec2(5, 3.4), random: &random, catalog: catalog) == nil)
        #expect(!added.bodies[5].asleep && added.bodies[4].asleep)
    }

    @Test func validationNamesUnsoundSleepStates() {
        let (settled, _) = settledStack()
        func problems(_ change: (inout PhysicsWorld) -> Void) -> [String] {
            var world = settled
            change(&world)
            return world.validate(catalog: catalog)
        }
        #expect(problems { $0.bodies[1].velocity = Vec2(0.01, 0) } == ["body 1: sleeping body is moving"])
        #expect(problems { $0.bodies[1].angularVelocity = 0.01 } == ["body 1: sleeping body is moving"])
        #expect(problems { $0.bodies[1].pinned = true } == ["body 1: pinned body is asleep"])
        #expect(problems { $0.bodies[1].isStatic = true } == ["body 1: static body is asleep"])
        #expect(problems { $0.grab = Grab(bodyId: 1, localAnchor: .zero, target: Vec2(5, 1)) }
                == ["body 1: grabbed body is asleep"])
        #expect(problems { $0.bodies[1].restTicks = 61 } == ["body 1: restTicks 61 is outside 0…60"])
        #expect(problems { $0.bodies[1].restTicks = -1 } == ["body 1: restTicks -1 is outside 0…60"])
    }

    /// One recorded input of the replay session.
    private enum Action {
        case drop(BodyKind), add(BodyKind, Vec2), select(Int), grab(Int), move(Vec2), release, nudge(Double, Double)
        case pin(Int), delete(Int), gravity(Int), drag(Int), stiffness(Int), pause, step, resume, timeScale(Int)
    }

    /// The session: (host step, action), over every action kind, with quiet stretches in which bodies fall asleep.
    private static let session: [(step: Int, action: Action)] = [
        (0, .drop(.circle)), (20, .add(.box, Vec2(8.5, 6))), (40, .timeScale(3)), (90, .timeScale(2)),
        (300, .select(4)), (301, .nudge(1, 0.5)), (330, .grab(5)), (335, .move(Vec2(3, 5))), (360, .release),
        (420, .pin(6)), (480, .gravity(1)), (500, .pause), (501, .step), (502, .step), (505, .resume),
        (520, .drag(2)), (540, .stiffness(3)), (560, .pin(6)), (620, .delete(3)), (700, .timeScale(0)),
        (760, .timeScale(2)), (800, .gravity(2)),
    ]

    /// Plays the session over host `steps`; counts the ticks that end with a sleeping body.
    private func play(_ steps: Range<Int>, world start: PhysicsWorld, random startRandom: SeededRandom)
        -> (PhysicsWorld, SeededRandom, Int) {
        var world = start, random = startRandom, sleepyTicks = 0
        for step in steps {
            for input in Self.session where input.step == step {
                switch input.action {
                case .drop(let kind): WorldSimulation.drop(&world, kind: kind, random: &random, catalog: catalog)
                case .add(let kind, let point):
                    _ = WorldEditing.add(&world, kind: kind, at: point, random: &random, catalog: catalog)
                case .select(let id): _ = WorldEditing.select(&world, id: id)
                case .grab(let id):
                    if let body = world.bodies.first(where: { $0.id == id }) {
                        _ = WorldEditing.grab(&world, id: id, at: body.position)
                    }
                case .move(let point): _ = WorldEditing.move(&world, to: point)
                case .release: _ = WorldEditing.release(&world)
                case .nudge(let dx, let dy): _ = WorldEditing.nudge(&world, dx: dx, dy: dy)
                case .pin(let id): _ = WorldEditing.togglePin(&world, id: id)
                case .delete(let id): _ = WorldEditing.delete(&world, id: id)
                case .gravity(let level): WorldSimulation.setGravityLevel(&world, level)
                case .drag(let level): WorldSimulation.setDragLevel(&world, level)
                case .stiffness(let level): WorldSimulation.setStiffnessLevel(&world, level)
                case .pause: world.paused = true
                case .step: WorldSimulation.step(&world, catalog: catalog)
                case .resume: world.paused = false
                case .timeScale(let index): world.timeScaleIndex = index
                }
            }
            WorldSimulation.advanceHostStep(&world, catalog: catalog)
            if world.bodies.contains(where: \.asleep) { sleepyTicks += 1 }
        }
        return (world, random, sleepyTicks)
    }

    @Test func aSessionWithSleepingBodiesReplaysIdenticallyAndRestoresExactly() throws {
        var random = SeededRandom(seed: 2026)
        let start = Presets.make(.freePlay, random: &random, catalog: catalog)
        let (a, randomA, sleepy) = play(0..<900, world: start, random: random)
        let (b, randomB, _) = play(0..<900, world: start, random: random)
        print("replay session: \(a.tick) ticks, \(sleepy) host steps ending with a sleeping body, "
              + "\(a.bodies.filter(\.asleep).count) asleep at the end")
        #expect(a.encoded() == b.encoded() && !a.encoded().isEmpty && randomA == randomB)
        #expect(sleepy > 0 && a.validate(catalog: catalog).isEmpty)
        // Save halfway (sleep state included) and continue.
        let (half, halfRandom, _) = play(0..<450, world: start, random: random)
        let restored = try PhysicsWorld.decode(half.encoded())
        #expect(restored == half)
        let (continued, continuedRandom, _) = play(450..<900, world: restored, random: halfRandom)
        #expect(continued.encoded() == a.encoded() && continuedRandom == randomA)
    }
}
