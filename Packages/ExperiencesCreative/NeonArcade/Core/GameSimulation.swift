// GameSimulation — feature 075 (A10-P01) T-A10-103 (FR-A10-111, FR-A10-112; clarifications 1–3; research D2–D4). The
// fixed-step rules of Neon Dodge. One step is 1/60 s; `advance` does, in this order (research D2):
// 1. Steering: the target velocity is the held steering value × 9; the velocity eases toward it at 60 units/s² (at
//    most 1 unit/s per step); x moves by velocity × step and is clamped to 0.5…8.5, zeroing the velocity at a wall.
// 2. Spawning: at step 30, then every 40 steps, the seeded generator draws, always in the same order and number, the
//    kind (hazard 70 %, orb 30 %), the catalog item of that kind, x uniform in 0.5…8.5, the fall speed 3…5 units/s,
//    the radius from the item's radius range and the half-length from its half-length range (bars only; the draw is
//    made for every spawn). The object starts at y 16.5. A spawn beyond 24 objects (or with no item of the kind) is
//    skipped after the same draws, so the generator stays in step either way.
// 3. Objects in id order: an object spawned in this step is only moved (it can touch the player from the next step
//    on). Every other object is tested against the player: circles with VisualCore's swept circle–circle test using
//    both this step's displacements (the player's from step 1 and the object's), capsules with the end-of-step
//    circle–capsule overlap (sound because a capsule falls ≤ 5 × 1/60 = 0.083 units per step, below the smallest summed
//    radius 0.2 + 0.4 = 0.6; research D3). A touching hazard costs a life, starts 90 steps of invulnerability, is
//    removed and records a `hit` event, unless the player is already invulnerable, when it passes without effect (no
//    event, not removed). A touching orb adds its value (score capped at 9,999,999), is removed and records a `pickup`
//    event. Objects not removed move by their displacement and are removed once below y −1.
// 4. Invulnerability counts down by one.
// 5. Lives 0 → the run is over. The step count increases.
// A paused or over run is not changed at all. A non-finite steering value is ignored; others are clamped to −1…1.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The fixed-step rules of a Neon Dodge run.
public enum GameSimulation {
    /// The fixed step in seconds (1/60 s).
    public static let step = 1.0 / 60
    /// The step of the first spawn.
    public static let firstSpawnStep = 30
    /// Steps between spawns after the first.
    public static let spawnInterval = 40
    /// The chance that a spawn is a hazard (else an orb).
    public static let hazardChance = 0.7
    /// The x range objects spawn in.
    public static let spawnXRange: ClosedRange<Double> = 0.5...8.5
    /// The y objects spawn at (above the field).
    public static let spawnY = 16.5
    /// The fall speed range in units per second.
    public static let fallSpeedRange: ClosedRange<Double> = 3.0...5.0
    /// Objects below this y are removed.
    public static let removalY = -1.0

    /// Sets the held steering value: a non-finite value is ignored, others are clamped to −1…1. It holds until the
    /// next call and also applies while paused (it takes effect on the next advanced step).
    public static func steer(_ run: inout GameRun, value: Double) {
        guard value.isFinite else { return }
        run.steering = min(max(value, -1), 1)
    }

    /// Replaces `run` with a fresh run (steering 0, score 0, lives 3; see ``GameRun/new()``).
    public static func restart(_ run: inout GameRun) { run = .new() }

    /// True when a spawn is due at `step` (30, 70, 110, …).
    public static func isSpawnStep(_ step: Int) -> Bool {
        step >= firstSpawnStep && (step - firstSpawnStep) % spawnInterval == 0
    }

    /// Advances `run` by one fixed step (see the file header for the order); a paused or over run is unchanged.
    public static func advance(_ run: inout GameRun, catalog: ArcadeCatalog, random: inout SeededRandom) {
        guard !run.paused, !run.over else { return }
        let current = run.step

        // 1. Steering.
        let start = run.player.center
        let target = run.steering * PlayerState.maxSpeed
        let maxChange = PlayerState.acceleration * step
        var velocity = run.player.velocity + min(max(target - run.player.velocity, -maxChange), maxChange)
        velocity = min(max(velocity, -PlayerState.maxSpeed), PlayerState.maxSpeed)
        var x = run.player.x + velocity * step
        if x <= PlayerState.xRange.lowerBound || x >= PlayerState.xRange.upperBound {
            x = min(max(x, PlayerState.xRange.lowerBound), PlayerState.xRange.upperBound)
            velocity = 0
        }
        run.player.x = x
        run.player.velocity = velocity
        let end = run.player.center
        let playerMove = end - start

        // 2. Spawning.
        let firstNewId = run.nextObjectId
        if isSpawnStep(current) { spawn(&run, catalog: catalog, random: &random) }

        // 3. Objects in id order.
        var kept: [FallingObject] = []
        kept.reserveCapacity(run.objects.count)
        for var object in run.objects {
            let move = object.velocity * step
            if object.id < firstNewId && touches(object, move: move, playerStart: start, playerMove: playerMove,
                                                 playerEnd: end, radius: run.player.hitRadius) {
                switch object.kind {
                case .hazard where run.player.invulnerableSteps == 0:
                    run.lives = max(run.lives - 1, 0)
                    run.player.invulnerableSteps = PlayerState.invulnerabilitySteps
                    record(&run, CollisionEvent(step: current, objectId: object.id, kind: .hit))
                    continue
                case .hazard:
                    break   // Invulnerable: passes without effect.
                case .orb:
                    run.score = min(run.score + max(object.value, 0), GameRun.maxScore)
                    record(&run, CollisionEvent(step: current, objectId: object.id, kind: .pickup))
                    continue
                }
            }
            object.position += move
            if object.position.y >= removalY { kept.append(object) }
        }
        run.objects = kept

        // 4. Invulnerability.
        if run.player.invulnerableSteps > 0 { run.player.invulnerableSteps -= 1 }

        // 5. Over.
        if run.lives <= 0 { run.lives = 0; run.over = true }
        run.step = current + 1
    }

    /// True when `object` moving by `move` touches the player moving from `playerStart` by `playerMove` (circles:
    /// swept test) or touches it at `playerEnd` after the move (capsules: end-of-step overlap).
    static func touches(_ object: FallingObject, move: Vec2, playerStart: Vec2, playerMove: Vec2, playerEnd: Vec2,
                        radius: Double) -> Bool {
        if object.isCapsule {
            let c = object.position + move
            let capsule = CollisionCapsule(a: Vec2(c.x - object.halfLength, c.y), b: Vec2(c.x + object.halfLength, c.y),
                                           radius: object.radius)
            return Collision2D.overlaps(CollisionCircle(center: playerEnd, radius: radius), capsule)
        }
        return Collision2D.sweep(CollisionCircle(center: object.position, radius: object.radius), moving: move,
                                 CollisionCircle(center: playerStart, radius: radius), moving: playerMove) != nil
    }

    /// Appends `event`, keeping the last ``GameRun/maxEvents`` and counting every event.
    static func record(_ run: inout GameRun, _ event: CollisionEvent) {
        run.events.append(event)
        if run.events.count > GameRun.maxEvents { run.events.removeFirst(run.events.count - GameRun.maxEvents) }
        run.eventCount += 1
    }

    /// Draws one spawn (always six generator values) and appends the object unless the cap is reached or the
    /// catalog has no item of the drawn kind.
    static func spawn(_ run: inout GameRun, catalog: ArcadeCatalog, random: inout SeededRandom) {
        let kindDraw = random.double()
        let itemDraw = random.double()
        let x = random.range(spawnXRange)
        let speed = random.range(fallSpeedRange)
        let radiusDraw = random.double()
        let halfLengthDraw = random.double()
        let kind: ObjectKind = kindDraw < hazardChance ? .hazard : .orb
        let candidates = kind == .hazard ? catalog.hazards : catalog.orbs
        guard run.objects.count < GameRun.maxObjects, !candidates.isEmpty else { return }
        let item = candidates[min(Int(itemDraw * Double(candidates.count)), candidates.count - 1)]
        let radius = item.radiusRange.min + (item.radiusRange.max - item.radiusRange.min) * radiusDraw
        var halfLength = 0.0
        if item.shape.isCapsule, let range = item.halfLengthRange {
            halfLength = range.min + (range.max - range.min) * halfLengthDraw
        }
        run.objects.append(FallingObject(id: run.nextObjectId, contentId: item.id, kind: kind,
                                         position: Vec2(x, spawnY), velocity: Vec2(0, -speed), radius: radius,
                                         halfLength: halfLength, value: kind == .orb ? item.value : 0))
        run.nextObjectId += 1
    }
}
