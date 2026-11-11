// ParticleScene.swift — the versioned, validated scene description (feature 033 A04-P01 T-A04-111; FR-A04-105; US4;
// spec clarification 4; data model). Plain data: the simulation and any GPU state are rebuilt from it.
import VisualCoreMath
import VisualCoreSimulation

/// Why a scene was rejected.
public enum SceneError: Error, Equatable, Sendable {
    /// The schema version is not supported (only 1 is).
    case unsupportedVersion(Int)
    /// A number in the named field is NaN or infinite.
    case nonFinite(String)
    /// The particle limit is outside `ParticleScene.limitRange`.
    case limitOutOfRange(Int)
    /// The time scale is outside `ParticleScene.timeScaleRange`.
    case timeScaleOutOfRange(Double)
    /// The number of emitters is outside 1…`ParticleScene.maxEmitters`.
    case emitterCount(Int)
    /// More forces than `ParticleScene.maxForces`.
    case forceCount(Int)
    /// A force value is out of range (negative drag, non-positive attractor radius).
    case invalidForce(Int)
}

/// One emitter in a scene: a family, optionally moved.
public struct SceneEmitter: Codable, Equatable, Sendable {
    /// The family preset.
    public var family: EmitterFamily
    /// A position replacing the family's (world units), or nil for the family's own.
    public var position: Vec2?
    /// Creates an emitter of `family`, optionally at `position`.
    public init(family: EmitterFamily, position: Vec2? = nil) { self.family = family; self.position = position }

    /// The VisualCore emitter for this entry.
    public func emitter() -> Emitter {
        var e = family.emitter()
        if let position { e.position = position }
        return e
    }
}

/// A scene force, mirroring VisualCore's `ParticleForce` in a storable form.
public enum SceneForce: Codable, Equatable, Sendable {
    /// Constant acceleration (world units/s²).
    case gravity(x: Double, y: Double)
    /// Velocity damping per second, k ≥ 0.
    case drag(k: Double)
    /// Pull toward (x, y) with `strength` (units/s²) within `radius` > 0.
    case attractor(x: Double, y: Double, strength: Double, radius: Double)
    /// Push away from (x, y) with linear falloff; |strength| ≤ 10,000, radius 1…2,000 (feature 034).
    case repulsor(x: Double, y: Double, strength: Double, radius: Double)
    /// Softened point gravity toward (x, y); strength 0…1e9, softening 1…500 (feature 034).
    case gravityWell(x: Double, y: Double, strength: Double, softening: Double)
    /// Pull velocities toward (vx, vy), speed ≤ 2,000, at `rate` 0…10 per second (feature 034).
    case wind(vx: Double, vy: Double, rate: Double)
    /// Counter-clockwise swirl around (x, y) for a positive strength; |strength| ≤ 10,000, radius 1…2,000 (feature 034).
    case vortex(x: Double, y: Double, strength: Double, radius: Double)

    /// The VisualCore force.
    public var particleForce: ParticleForce {
        switch self {
        case .gravity(let x, let y): .gravity(Vec2(x, y))
        case .drag(let k): .drag(k)
        case .attractor(let x, let y, let s, let r): .attractor(point: Vec2(x, y), strength: s, radius: r)
        case .repulsor(let x, let y, let s, let r): .repulsor(point: Vec2(x, y), strength: s, radius: r)
        case .gravityWell(let x, let y, let s, let e): .gravityWell(point: Vec2(x, y), strength: s, softening: e)
        case .wind(let vx, let vy, let rate): .wind(velocity: Vec2(vx, vy), rate: rate)
        case .vortex(let x, let y, let s, let r): .vortex(point: Vec2(x, y), strength: s, radius: r)
        }
    }

    var values: [Double] {
        switch self {
        case .gravity(let x, let y): [x, y]
        case .drag(let k): [k]
        case .attractor(let x, let y, let s, let r), .repulsor(let x, let y, let s, let r), .vortex(let x, let y, let s, let r): [x, y, s, r]
        case .gravityWell(let x, let y, let s, let e): [x, y, s, e]
        case .wind(let vx, let vy, let rate): [vx, vy, rate]
        }
    }

    /// The ranges equal VisualCore's `ParticleForce.clamped()` ranges, so a valid scene is never altered by clamping.
    var isInRange: Bool {
        let strength = -ParticleForce.strengthLimit...ParticleForce.strengthLimit
        switch self {
        case .gravity: return true
        case .drag(let k): return k >= 0
        case .attractor(_, _, _, let r): return r > 0
        case .repulsor(_, _, let s, let r), .vortex(_, _, let s, let r):
            return strength.contains(s) && ParticleForce.radiusRange.contains(r)
        case .gravityWell(_, _, let s, let e):
            return (0...ParticleForce.gravityWellStrengthLimit).contains(s) && ParticleForce.softeningRange.contains(e)
        case .wind(let vx, let vy, let rate):
            return Vec2(vx, vy).length <= ParticleForce.maxWindSpeed && ParticleForce.rateRange.contains(rate)
        }
    }
}

/// A particle scene, schema version 1: seed, particle limit, time scale, emitters and forces. Decoding validates.
public struct ParticleScene: Codable, Equatable, Sendable {
    /// Supported particle limits.
    public static let limitRange = 100...20_000
    /// Default particle limit.
    public static let defaultLimit = 4_000
    /// Supported time scales.
    public static let timeScaleRange = 0.25...2.0
    /// Most emitters in a scene.
    public static let maxEmitters = 8
    /// Most scene forces in a scene.
    public static let maxForces = 8

    /// Schema version (1).
    public var version: Int
    /// Seed of the particle generator.
    public var seed: UInt64
    /// Largest number of live particles.
    public var particleLimit: Int
    /// Simulation speed relative to real time.
    public var timeScale: Double
    /// Particle sources (1…8).
    public var emitters: [SceneEmitter]
    /// Scene forces in addition to each family's own (≤ 8).
    public var forces: [SceneForce]

    /// Creates a version-1 scene.
    public init(seed: UInt64 = 0, particleLimit: Int = ParticleScene.defaultLimit, timeScale: Double = 1,
                emitters: [SceneEmitter], forces: [SceneForce] = []) {
        version = ParticleUniverseCore.schemaVersion
        self.seed = seed; self.particleLimit = particleLimit; self.timeScale = timeScale
        self.emitters = emitters; self.forces = forces
    }

    /// A one-family scene.
    public static func single(_ family: EmitterFamily, seed: UInt64 = 0) -> ParticleScene {
        ParticleScene(seed: seed, emitters: [SceneEmitter(family: family)])
    }

    /// Throws the first problem found, in field order.
    public func validate() throws(SceneError) {
        guard version == ParticleUniverseCore.schemaVersion else { throw .unsupportedVersion(version) }
        guard Self.limitRange.contains(particleLimit) else { throw .limitOutOfRange(particleLimit) }
        guard timeScale.isFinite else { throw .nonFinite("timeScale") }
        guard Self.timeScaleRange.contains(timeScale) else { throw .timeScaleOutOfRange(timeScale) }
        guard (1...Self.maxEmitters).contains(emitters.count) else { throw .emitterCount(emitters.count) }
        for (i, e) in emitters.enumerated() {
            if let p = e.position, !(p.x.isFinite && p.y.isFinite) { throw .nonFinite("emitters[\(i)].position") }
        }
        guard forces.count <= Self.maxForces else { throw .forceCount(forces.count) }
        for (i, f) in forces.enumerated() {
            guard f.values.allSatisfy(\.isFinite) else { throw .nonFinite("forces[\(i)]") }
            guard f.isInRange else { throw .invalidForce(i) }
        }
    }

    private enum CodingKeys: String, CodingKey { case version, seed, particleLimit, timeScale, emitters, forces }

    /// Decodes and validates; a `SceneError` is thrown for valid JSON describing an invalid scene.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        guard version == ParticleUniverseCore.schemaVersion else { throw SceneError.unsupportedVersion(version) }
        seed = try c.decode(UInt64.self, forKey: .seed)
        particleLimit = try c.decode(Int.self, forKey: .particleLimit)
        timeScale = try c.decode(Double.self, forKey: .timeScale)
        emitters = try c.decode([SceneEmitter].self, forKey: .emitters)
        forces = try c.decode([SceneForce].self, forKey: .forces)
        try validate()
    }
}
