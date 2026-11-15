// GameRun — feature 075 (A10-P01) T-A10-103 (FR-A10-110, FR-A10-112; clarifications 1, 3 and 4; research D4;
// data-model "PlayerState", "FallingObject", "CollisionEvent", "GameRun", schema 1). The versioned, validated record of
// one Neon Dodge run: the step count, the score (0…9,999,999), the lives (0…3), the paused and over flags, the held
// steering value (−1…1), the player (x on the line y 1.5 inside 0.5…8.5, velocity |v| ≤ 9, hit radius 0.4,
// invulnerability 0…90 steps), the falling objects (at most 24, ids increasing), the next object id, the last 256
// collision events and the total event count. Game units throughout: the field is 9 × 16 (x 0…9, y 0…16, y up).
// The seeded generator's state is saved beside the run by the experience (snapshot `ArcadeState`); the run alone
// is advanced by `GameSimulation`.
//
// Schema 2 — feature 076 (A10-P02) T-A10-202 (FR-A10-210; clarification 4; research D4; data-model "GameRun"): adds
// the wave state `wave` (≥ 1), `waveStep` (0…599), `patternId` (a `PatternTable` id), `freeLane` (the last wall's free
// lane, −1 for none) and `patternCursor` (0…7: the zigzag position or the trail lane). The decoder also reads schema 1
// JSON, which has none of these fields: they take the defaults (wave 1, step 0, `rain`, −1, 0) and the run keeps
// schema 1 until `migrated()` lifts it to schema 2 keeping every other field. A schema 2 document must carry them.
import Foundation
import VisualCoreMath

/// The player: a circle on the line ``GameRun/playerY`` steered left and right.
public struct PlayerState: Codable, Equatable, Sendable {
    /// The hit radius every run uses.
    public static let hitRadius = 0.4
    /// The longest invulnerability after a hit, in steps (1.5 s at 60 Hz).
    public static let invulnerabilitySteps = 90
    /// The x range the player stays inside.
    public static let xRange: ClosedRange<Double> = 0.5...8.5
    /// The maximum speed in units per second.
    public static let maxSpeed = 9.0
    /// How fast the velocity eases toward the target, in units per second squared.
    public static let acceleration = 60.0

    /// The x position, in ``xRange``.
    public var x: Double
    /// The horizontal velocity in units per second, |v| ≤ ``maxSpeed``.
    public var velocity: Double
    /// The hit radius (always ``PlayerState/hitRadius``).
    public var hitRadius: Double
    /// Steps of invulnerability left, 0…``invulnerabilitySteps``.
    public var invulnerableSteps: Int

    /// Creates a player from all of its fields (validity is checked by ``GameRun/validate()``).
    public init(x: Double, velocity: Double = 0, hitRadius: Double = PlayerState.hitRadius,
                invulnerableSteps: Int = 0) {
        self.x = x; self.velocity = velocity; self.hitRadius = hitRadius; self.invulnerableSteps = invulnerableSteps
    }

    /// The player's centre on the field.
    public var center: Vec2 { Vec2(x, GameRun.playerY) }
}

/// What a falling object does on contact.
public enum ObjectKind: String, Codable, CaseIterable, Sendable {
    /// Costs a life (unless the player is invulnerable).
    case hazard
    /// Adds its value to the score.
    case orb
}

/// One falling object: a circle (`halfLength` 0) or a horizontal capsule (`halfLength` > 0).
public struct FallingObject: Codable, Equatable, Sendable, Identifiable {
    /// The spawn-order id (increasing within a run).
    public var id: Int
    /// The catalog item this object was spawned from.
    public var contentId: String
    /// Hazard or orb.
    public var kind: ObjectKind
    /// The centre in game units.
    public var position: Vec2
    /// The velocity in units per second (x 0, y −3…−5 when spawned).
    public var velocity: Vec2
    /// The circle radius, or the capsule's radius around its segment.
    public var radius: Double
    /// The capsule's horizontal half-length; 0 for a circle.
    public var halfLength: Double
    /// Points added on pickup (orbs); 0 for hazards.
    public var value: Int

    /// Creates an object from all of its fields (validity is checked by ``GameRun/validate()``).
    public init(id: Int, contentId: String, kind: ObjectKind, position: Vec2, velocity: Vec2, radius: Double,
                halfLength: Double = 0, value: Int = 0) {
        self.id = id; self.contentId = contentId; self.kind = kind; self.position = position
        self.velocity = velocity; self.radius = radius; self.halfLength = halfLength; self.value = value
    }

    /// True when the object collides as a capsule.
    public var isCapsule: Bool { halfLength > 0 }
}

/// One resolved contact.
public struct CollisionEvent: Codable, Equatable, Sendable {
    /// What happened.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// A hazard cost a life.
        case hit
        /// An orb was collected.
        case pickup
    }

    /// The step at which the contact happened (the run's step count before that step).
    public var step: Int
    /// The object's id.
    public var objectId: Int
    /// Hit or pickup.
    public var kind: Kind

    /// Creates an event.
    public init(step: Int, objectId: Int, kind: Kind) { self.step = step; self.objectId = objectId; self.kind = kind }
}

/// One Neon Dodge run (schema 2).
public struct GameRun: Codable, Equatable, Sendable {
    /// The schema this build writes (it also reads schema 1, see ``migrated()``).
    public static let currentSchema = 2
    /// The Phase 01 schema, read and migrated.
    public static let schemaOne = 1
    /// The field width in game units.
    public static let fieldWidth = 9.0
    /// The field height in game units.
    public static let fieldHeight = 16.0
    /// The y of the player's line.
    public static let playerY = 1.5
    /// The highest score; reaching it is not an error.
    public static let maxScore = 9_999_999
    /// Lives at the start of a run.
    public static let startLives = 3
    /// The most falling objects at once; a spawn beyond it is skipped.
    public static let maxObjects = 24
    /// The most events kept (the oldest are dropped; ``eventCount`` keeps the total).
    public static let maxEvents = 256

    /// The schema version (2; 1 for a decoded Phase 01 run before ``migrated()``).
    public var schema: Int
    /// Steps advanced so far (paused and over steps are not counted).
    public var step: Int
    /// The score, 0…``maxScore``.
    public var score: Int
    /// The lives left, 0…``startLives``.
    public var lives: Int
    /// True while paused (advancing changes nothing).
    public var paused: Bool
    /// True once the lives reach 0 (advancing changes nothing).
    public var over: Bool
    /// The held steering value, −1…1 (target velocity = value × ``PlayerState/maxSpeed``).
    public var steering: Double
    /// The player.
    public var player: PlayerState
    /// The falling objects in id order (at most ``maxObjects``).
    public var objects: [FallingObject]
    /// The id the next spawned object gets.
    public var nextObjectId: Int
    /// The last ``maxEvents`` collision events, oldest first.
    public var events: [CollisionEvent]
    /// The number of events ever recorded in this run.
    public var eventCount: Int
    /// The wave number, ≥ 1.
    public var wave: Int
    /// The step within the wave, 0…599 (``WaveDirector/waveLength`` − 1).
    public var waveStep: Int
    /// The id of the wave's pattern (one of ``PatternTable/ids``).
    public var patternId: String
    /// The free lane of the last wall row, −1…4 (−1: none yet).
    public var freeLane: Int
    /// The pattern's position, 0…7: the zigzag cursor or the orb trail's lane.
    public var patternCursor: Int

    /// Creates a run from all of its fields (validity is checked by ``validate()``); the wave fields default to the
    /// start of wave 1.
    public init(schema: Int = GameRun.currentSchema, step: Int, score: Int, lives: Int, paused: Bool, over: Bool,
                steering: Double, player: PlayerState, objects: [FallingObject], nextObjectId: Int,
                events: [CollisionEvent], eventCount: Int, wave: Int = 1, waveStep: Int = 0,
                patternId: String = PatternTable.firstPatternId, freeLane: Int = -1, patternCursor: Int = 0) {
        self.schema = schema; self.step = step; self.score = score; self.lives = lives; self.paused = paused
        self.over = over; self.steering = steering; self.player = player; self.objects = objects
        self.nextObjectId = nextObjectId; self.events = events; self.eventCount = eventCount
        self.wave = wave; self.waveStep = waveStep; self.patternId = patternId; self.freeLane = freeLane
        self.patternCursor = patternCursor
    }

    /// A fresh run: step 0, score 0, three lives, not paused, steering 0, the player at rest in the middle (x 4.5),
    /// no objects and no events, wave 1 at wave step 0 with `rain`, no free lane, cursor 0.
    public static func new() -> GameRun {
        GameRun(step: 0, score: 0, lives: startLives, paused: false, over: false, steering: 0,
                player: PlayerState(x: fieldWidth / 2), objects: [], nextObjectId: 0, events: [], eventCount: 0)
    }

    private enum CodingKeys: String, CodingKey {
        case schema, step, score, lives, paused, over, steering, player, objects, nextObjectId, events, eventCount
        case wave, waveStep, patternId, freeLane, patternCursor
    }

    /// Decodes schema 2, or schema 1 with the wave fields at their defaults (the schema stays 1; see ``migrated()``).
    /// A schema 2 (or later) document without the wave fields is refused.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        step = try c.decode(Int.self, forKey: .step)
        score = try c.decode(Int.self, forKey: .score)
        lives = try c.decode(Int.self, forKey: .lives)
        paused = try c.decode(Bool.self, forKey: .paused)
        over = try c.decode(Bool.self, forKey: .over)
        steering = try c.decode(Double.self, forKey: .steering)
        player = try c.decode(PlayerState.self, forKey: .player)
        objects = try c.decode([FallingObject].self, forKey: .objects)
        nextObjectId = try c.decode(Int.self, forKey: .nextObjectId)
        events = try c.decode([CollisionEvent].self, forKey: .events)
        eventCount = try c.decode(Int.self, forKey: .eventCount)
        if schema <= Self.schemaOne {
            wave = try c.decodeIfPresent(Int.self, forKey: .wave) ?? 1
            waveStep = try c.decodeIfPresent(Int.self, forKey: .waveStep) ?? 0
            patternId = try c.decodeIfPresent(String.self, forKey: .patternId) ?? PatternTable.firstPatternId
            freeLane = try c.decodeIfPresent(Int.self, forKey: .freeLane) ?? -1
            patternCursor = try c.decodeIfPresent(Int.self, forKey: .patternCursor) ?? 0
        } else {
            wave = try c.decode(Int.self, forKey: .wave)
            waveStep = try c.decode(Int.self, forKey: .waveStep)
            patternId = try c.decode(String.self, forKey: .patternId)
            freeLane = try c.decode(Int.self, forKey: .freeLane)
            patternCursor = try c.decode(Int.self, forKey: .patternCursor)
        }
    }

    /// The run in the current schema: a schema 1 run becomes schema 2 at the start of wave 1 (wave step 0, `rain`,
    /// no free lane, cursor 0) with every other field kept; any other run is returned unchanged.
    public func migrated() -> GameRun {
        guard schema == Self.schemaOne else { return self }
        var run = self
        run.schema = Self.currentSchema
        run.wave = 1
        run.waveStep = 0
        run.patternId = PatternTable.firstPatternId
        run.freeLane = -1
        run.patternCursor = 0
        return run
    }

    /// The run's problems, empty when it is valid: schema, counts and limits, finite numbers, the player inside its
    /// range, objects in increasing id order below ``nextObjectId``, over exactly when no lives are left, and the
    /// wave state (wave ≥ 1, wave step 0…599, a known pattern, free lane −1…4, cursor 0…7).
    public func validate() -> [String] {
        var problems: [String] = []
        if schema != Self.currentSchema { problems.append("schema \(schema) is not \(Self.currentSchema)") }
        if step < 0 { problems.append("step \(step) is negative") }
        if score < 0 || score > Self.maxScore { problems.append("score \(score) is outside 0…\(Self.maxScore)") }
        if lives < 0 || lives > Self.startLives { problems.append("lives \(lives) are outside 0…\(Self.startLives)") }
        if over != (lives == 0) { problems.append("over is \(over) with \(lives) lives") }
        if !steering.isFinite || abs(steering) > 1 { problems.append("steering is outside −1…1") }
        if !player.x.isFinite || !PlayerState.xRange.contains(player.x) {
            problems.append("player x is outside 0.5…8.5")
        }
        if !player.velocity.isFinite || abs(player.velocity) > PlayerState.maxSpeed {
            problems.append("player velocity exceeds 9")
        }
        if player.hitRadius != PlayerState.hitRadius { problems.append("player hit radius is not 0.4") }
        if player.invulnerableSteps < 0 || player.invulnerableSteps > PlayerState.invulnerabilitySteps {
            problems.append("invulnerability \(player.invulnerableSteps) is outside 0…90")
        }
        if objects.count > Self.maxObjects { problems.append("\(objects.count) objects exceed \(Self.maxObjects)") }
        var previousId = -1
        for object in objects {
            if object.id <= previousId || object.id >= nextObjectId {
                problems.append("object \(object.id) is out of id order")
            }
            previousId = object.id
            if object.contentId.isEmpty { problems.append("object \(object.id) has no content") }
            if !object.position.isFinite || !object.velocity.isFinite || !object.radius.isFinite
                || !object.halfLength.isFinite || object.radius <= 0 || object.halfLength < 0 || object.value < 0 {
                problems.append("object \(object.id) has an invalid number")
            }
        }
        if nextObjectId < 0 { problems.append("next object id is negative") }
        if events.count > Self.maxEvents { problems.append("\(events.count) events exceed \(Self.maxEvents)") }
        if eventCount < events.count { problems.append("event count \(eventCount) is below the kept events") }
        if events.contains(where: { $0.step < 0 || $0.step >= step || $0.objectId < 0 }) {
            problems.append("an event has an invalid step or object id")
        }
        if wave < 1 { problems.append("wave \(wave) is below 1") }
        if waveStep < 0 || waveStep >= WaveDirector.waveLength {
            problems.append("wave step \(waveStep) is outside 0…\(WaveDirector.waveLength - 1)")
        }
        if PatternTable.pattern(id: patternId) == nil { problems.append("pattern \(patternId) is not in the table") }
        if freeLane < -1 || freeLane >= Lanes.count { problems.append("free lane \(freeLane) is outside −1…4") }
        if patternCursor < 0 || patternCursor >= WaveDirector.zigzagCycle {
            problems.append("pattern cursor \(patternCursor) is outside 0…7")
        }
        return problems
    }
}
