// ParticleSystem.swift — fixed-capacity particle pool with emitters, forces and a NaN guard
// (feature 006 T-F512; FR-F507, FR-F511, FR-F512; research R6). Structure of arrays, swap-remove,
// semi-implicit Euler; advance it with fixed steps (FixedStepClock) for frame-rate independence.
// Feature 033 (A04-P01, G-EMITTERS): emitter shapes, burst emission and clamped emitters (EmitterShape.swift).
// Feature 034 (A04-P02, G-FIELDS): repulsor, gravity well, wind and vortex forces, clamped once per step
// (ParticleForceFields.swift).
import Foundation
import VisualCoreMath

/// A particle source: continuous emission rate plus per-particle lifetime, speed, direction cone, and size/color ramps.
public struct Emitter: Sendable, Equatable {
    /// Spawn point in world units.
    public var position: Vec2
    /// Particles per second (continuous emission; fractional rates accumulate).
    public var rate: Double
    /// Seconds each particle lives (uniform in the range).
    public var lifetime: ClosedRange<Double>
    /// Initial speed (world units per second, uniform in the range).
    public var speed: ClosedRange<Double>
    /// Emission direction, radians (counter-clockwise from +x).
    public var direction: Double
    /// Total cone angle, radians (2π = all directions).
    public var spread: Double
    /// Particle diameter (world units) at birth and at death, interpolated linearly over its life.
    public var startSize: Double, endSize: Double
    /// Particle RGBA at birth and at death, interpolated linearly over its life.
    public var startColor: Vec4, endColor: Vec4
    /// When false the emitter stops continuous and periodic burst emission (default true); `burst(_:from:)` still works.
    public var isEmitting = true
    /// Where new particles start, relative to `position` (default `.point`).
    public var shape: EmitterShape
    /// Periodic burst emission in addition to `rate` (default nil: none).
    public var burst: EmitterBurst?
    /// When true, `direction` is measured from the shape's outward direction at the spawn point: the radius for a ring,
    /// the line's angle for a line; no effect for a point (default false). Feature 033: rings that emit outward.
    public var radial: Bool

    /// Defaults: 100 particles/s, 1 s life, speed 50–100, pointing +y with a full 2π spread, size 4→0, opaque→transparent
    /// white, a point shape and no periodic bursts.
    public init(position: Vec2 = .zero, rate: Double = 100, lifetime: ClosedRange<Double> = 1...1,
                speed: ClosedRange<Double> = 50...100, direction: Double = .pi / 2, spread: Double = 2 * .pi,
                startSize: Double = 4, endSize: Double = 0, startColor: Vec4 = Vec4(1, 1, 1, 1), endColor: Vec4 = Vec4(1, 1, 1, 0),
                shape: EmitterShape = .point, burst: EmitterBurst? = nil, radial: Bool = false) {
        self.position = position; self.rate = rate; self.lifetime = lifetime; self.speed = speed
        self.direction = direction; self.spread = spread
        self.startSize = startSize; self.endSize = endSize; self.startColor = startColor; self.endColor = endColor
        self.shape = shape; self.burst = burst; self.radial = radial
    }
}

/// A force applied to every live particle each step (accelerations add up).
public enum ParticleForce: Sendable, Equatable {
    /// Constant acceleration.
    case gravity(Vec2)
    /// Velocity damping per second (k ≥ 0).
    case drag(Double)
    /// Pulls toward `point` with `strength` (units/s²), only within `radius`.
    case attractor(point: Vec2, strength: Double, radius: Double)
    /// Pushes away from `point` with `strength · (1 − distance/radius)` (units/s²) inside `radius`; 0 at the center
    /// (feature 034, G-FIELDS). A negative strength pulls.
    case repulsor(point: Vec2, strength: Double, radius: Double)
    /// Softened point gravity toward `point`: a = strength · d / (|d|² + softening²)^{3/2}. An artistic field, not
    /// a physical N-body force; finite everywhere and 0 at the center (feature 034, G-FIELDS).
    case gravityWell(point: Vec2, strength: Double, softening: Double)
    /// Pulls each particle's velocity toward `velocity` at `rate` per second: a = rate · (velocity − v)
    /// (feature 034, G-FIELDS).
    case wind(velocity: Vec2, rate: Double)
    /// Turns particles around `point`: a tangential push of `strength · (1 − distance/radius)` (units/s²) inside
    /// `radius`, counter-clockwise for a positive strength; 0 at the center (feature 034, G-FIELDS).
    case vortex(point: Vec2, strength: Double, radius: Double)
}

/// What a renderer needs per particle.
public struct ParticleInstance: Sendable, Equatable {
    /// Center in world units.
    public var position: Vec2
    /// Diameter in world units.
    public var size: Double
    /// RGBA color.
    public var color: Vec4
    /// Creates an instance from a position, diameter and RGBA color.
    public init(position: Vec2, size: Double, color: Vec4) { self.position = position; self.size = size; self.color = color }
}

/// Deterministic fixed-capacity particle simulation: same seed, emitters, forces and steps give the same state (see `checksum()`).
public struct ParticleSystem: Sendable {
    /// Default pool size: 10,000 particles.
    public static let defaultCapacity = 10_000
    /// Hard cap on the pool size: 100,000 particles (larger requests are clamped).
    public static let maxCapacity = 100_000

    /// Pool size, clamped to 1…`maxCapacity`; emission beyond it is dropped and counted in `droppedCount`.
    public let capacity: Int
    /// Particle sources; a particle's size and color come from the emitter that spawned it.
    public var emitters: [Emitter] = []
    /// Forces applied to every live particle on each step.
    public var forces: [ParticleForce] = []
    /// Live particles (0…`capacity`).
    public private(set) var aliveCount = 0
    /// The current emission ceiling (feature 034, G-PQUALITY): clamped to 1…`capacity`, default `capacity`. While
    /// `aliveCount ≥ liveLimit` new particles are refused and counted in `droppedCount`; lowering it removes nobody.
    /// Configuration, not state: it is not part of `checksum()`.
    public var liveLimit: Int {
        get { storedLiveLimit ?? capacity }
        set { storedLiveLimit = min(max(newValue, 1), capacity) }
    }
    private var storedLiveLimit: Int?
    /// Particles not emitted because the pool was full or the live limit was reached.
    public private(set) var droppedCount = 0
    /// Particles removed because their state became NaN or infinite.
    public private(set) var nanRemoved = 0
    /// The seeded generator used for emission; its state advances with every spawn.
    public private(set) var random: SeededRandom

    // Structure of arrays, valid in 0..<aliveCount (internal for tests).
    var px: [Double], py: [Double], vx: [Double], vy: [Double], age: [Double], life: [Double], source: [Int]
    private var accumulators: [Double] = []
    // Seconds since each emitter's last periodic burst; negative means "burst on the next step" (research R3).
    private var burstClocks: [Double] = []
    private var pendingBursts: [(emitter: Int, count: Int)] = []

    /// Creates an empty pool of `capacity` particles (clamped to 1…100,000) seeded with `seed` (default 0).
    public init(capacity: Int = ParticleSystem.defaultCapacity, seed: UInt64 = 0) {
        let c = min(max(capacity, 1), Self.maxCapacity)
        self.capacity = c
        random = SeededRandom(seed: seed)
        px = .init(repeating: 0, count: c); py = px; vx = px; vy = px; age = px; life = px
        source = .init(repeating: 0, count: c)
    }

    /// Emits `count` particles from emitter `index` on the next step.
    public mutating func burst(_ count: Int, from index: Int = 0) {
        guard emitters.indices.contains(index), count > 0 else { return }
        pendingBursts.append((index, count))
    }

    /// Advances by `dt` seconds: ages and expires, applies forces (semi-implicit Euler), removes NaN/infinite particles, then emits; ignores non-finite or non-positive `dt`.
    public mutating func step(_ dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        // 1. Age and expire.
        var i = 0
        while i < aliveCount {
            age[i] += dt
            if age[i] >= life[i] { remove(i) } else { i += 1 }
        }
        // 2. Forces (clamped once per step, feature 034 research R1), integration, NaN guard.
        let active = forces.map { $0.clamped() }
        i = 0
        while i < aliveCount {
            var ax = 0.0, ay = 0.0
            for f in active {
                switch f {
                case .gravity(let g): ax += g.x; ay += g.y
                case .drag(let k): ax -= k * vx[i]; ay -= k * vy[i]
                case .attractor(let p, let s, let r):
                    let dx = p.x - px[i], dy = p.y - py[i], d = (dx * dx + dy * dy).squareRoot()
                    if d > 1e-9 && d <= r { ax += s * dx / d; ay += s * dy / d }
                case .repulsor, .gravityWell, .wind, .vortex:
                    let a = f.acceleration(at: Vec2(px[i], py[i]), velocity: Vec2(vx[i], vy[i]))
                    ax += a.x; ay += a.y
                }
            }
            vx[i] += ax * dt; vy[i] += ay * dt
            px[i] += vx[i] * dt; py[i] += vy[i] * dt
            if !(px[i].isFinite && py[i].isFinite && vx[i].isFinite && vy[i].isFinite) {
                nanRemoved += 1
                remove(i)
            } else { i += 1 }
        }
        // 3. Emit from clamped emitters (FR-A04-102): continuous rate, then periodic bursts, then requested bursts.
        if accumulators.count != emitters.count { accumulators = Array(accumulators.prefix(emitters.count)) + Array(repeating: 0, count: max(0, emitters.count - accumulators.count)) }
        if burstClocks.count != emitters.count { burstClocks = Array(burstClocks.prefix(emitters.count)) + Array(repeating: -1, count: max(0, emitters.count - burstClocks.count)) }
        let sources = emitters.map { $0.clamped() }
        for (e, emitter) in sources.enumerated() where emitter.isEmitting && emitter.rate > 0 {
            accumulators[e] += emitter.rate * dt
            let n = Int((accumulators[e] + 1e-9).rounded(.down))
            accumulators[e] = max(0, accumulators[e] - Double(n))
            for _ in 0..<n { spawn(from: e, sources[e]) }
        }
        for (e, emitter) in sources.enumerated() {
            guard emitter.isEmitting, let b = emitter.burst else { continue }
            if burstClocks[e] < 0 {
                burstClocks[e] = 0
            } else {
                burstClocks[e] += dt
                guard burstClocks[e] + 1e-9 >= b.interval else { continue }
                // At most one burst per step; the leftover stays below one interval, so a stall cannot cause a storm.
                burstClocks[e] = min(burstClocks[e] - b.interval, b.interval * 0.999_999)
            }
            for _ in 0..<b.count { spawn(from: e, emitter) }
        }
        for b in pendingBursts where emitters.indices.contains(b.emitter) { for _ in 0..<b.count { spawn(from: b.emitter, sources[b.emitter]) } }
        pendingBursts.removeAll()
    }

    private mutating func spawn(from e: Int, _ em: Emitter) {
        guard aliveCount < capacity, aliveCount < liveLimit else { droppedCount += 1; return }
        var angle = em.direction + (random.double() - 0.5) * em.spread
        let speed = random.range(em.speed)
        // Shape offset after angle and speed: a point draws nothing, keeping earlier seeded results identical (R2).
        let i = aliveCount
        if em.shape == .point {
            px[i] = em.position.x; py[i] = em.position.y
        } else {
            let offset = em.shape.sampleOffset(&random)
            px[i] = em.position.x + offset.x; py[i] = em.position.y + offset.y
            if em.radial {
                switch em.shape {
                case .point: break
                case .line(_, let a): angle += a
                case .ring: if offset.x != 0 || offset.y != 0 { angle += atan2(offset.y, offset.x) }
                }
            }
        }
        vx[i] = cos(angle) * speed; vy[i] = sin(angle) * speed
        age[i] = 0
        life[i] = max(1e-6, random.range(em.lifetime))
        source[i] = e
        aliveCount += 1
    }

    private mutating func remove(_ i: Int) {
        let last = aliveCount - 1
        if i != last {
            px[i] = px[last]; py[i] = py[last]; vx[i] = vx[last]; vy[i] = vy[last]
            age[i] = age[last]; life[i] = life[last]; source[i] = source[last]
        }
        aliveCount -= 1
    }

    /// Live particles spawned by emitter `source` (0 for an index with none). Feature 035: apps retire an emitter
    /// slot and reuse it only once its particles are gone, so no live particle changes look (research R4).
    public func liveCount(source index: Int) -> Int {
        var n = 0
        for i in 0..<aliveCount where source[i] == index { n += 1 }
        return n
    }

    /// Position, size and color of each live particle (size and color interpolated over life).
    public func instances() -> [ParticleInstance] {
        (0..<aliveCount).map { i in
            let em = (emitters.indices.contains(source[i]) ? emitters[source[i]] : Emitter()).clamped()
            let t = min(max(age[i] / life[i], 0), 1)
            return ParticleInstance(position: Vec2(px[i], py[i]), size: em.startSize + (em.endSize - em.startSize) * t,
                                    color: em.startColor.mix(em.endColor, t))
        }
    }

    /// FNV-1a over the live state's bit patterns (determinism checks, SC-F502).
    public func checksum() -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ v: UInt64) { h = (h ^ v) &* 0x100_0000_01B3 }
        mix(UInt64(aliveCount))
        for i in 0..<aliveCount {
            mix(px[i].bitPattern); mix(py[i].bitPattern); mix(vx[i].bitPattern); mix(vy[i].bitPattern); mix(age[i].bitPattern)
        }
        return h
    }
}
