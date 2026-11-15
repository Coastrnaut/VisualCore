// GameRun — feature 075 (A10-P01) T-A10-103 (FR-A10-110, FR-A10-112; clarifications 1, 3 and 4; research D4;
// data-model "PlayerState", "FallingObject", "CollisionEvent", "GameRun", schema 1). The versioned, validated record of
// one Neon Dodge run: the step count, the score (0…9,999,999), the lives (0…3), the paused and over flags, the held
// steering value (−1…1), the player (x on the line y 1.5 inside 0.5…8.5, velocity |v| ≤ 9, hit radius 0.4,
// invulnerability 0…90 steps), the falling objects (at most 24, ids increasing), the next object id, the last 256
// collision events and the total event count. Game units throughout: the field is 9 × 16 (x 0…9, y 0…16, y up).
// The seeded generator's state is saved beside the run by the experience (snapshot `ArcadeState`); the run alone
// is advanced by `GameSimulation`.
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

/// One Neon Dodge run (schema 1).
public struct GameRun: Codable, Equatable, Sendable {
    /// The only schema this build reads and writes.
    public static let currentSchema = 1
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

    /// The schema version (1).
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

    /// Creates a run from all of its fields (validity is checked by ``validate()``).
    public init(schema: Int = GameRun.currentSchema, step: Int, score: Int, lives: Int, paused: Bool, over: Bool,
                steering: Double, player: PlayerState, objects: [FallingObject], nextObjectId: Int,
                events: [CollisionEvent], eventCount: Int) {
        self.schema = schema; self.step = step; self.score = score; self.lives = lives; self.paused = paused
        self.over = over; self.steering = steering; self.player = player; self.objects = objects
        self.nextObjectId = nextObjectId; self.events = events; self.eventCount = eventCount
    }

    /// A fresh run: step 0, score 0, three lives, not paused, steering 0, the player at rest in the middle (x 4.5),
    /// no objects and no events.
    public static func new() -> GameRun {
        GameRun(step: 0, score: 0, lives: startLives, paused: false, over: false, steering: 0,
                player: PlayerState(x: fieldWidth / 2), objects: [], nextObjectId: 0, events: [], eventCount: 0)
    }

    /// The run's problems, empty when it is valid: schema, counts and limits, finite numbers, the player inside its
    /// range, objects in increasing id order below ``nextObjectId``, and over exactly when no lives are left.
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
        return problems
    }
}
