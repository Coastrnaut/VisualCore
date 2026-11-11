// ParticleSystem.swift — fixed-capacity particle pool with emitters, forces and a NaN guard
// (feature 006 T-F512; FR-F507, FR-F511, FR-F512; research R6). Structure of arrays, swap-remove,
// semi-implicit Euler; advance it with fixed steps (FixedStepClock) for frame-rate independence.
import Foundation
import VisualCoreMath

public struct Emitter: Sendable, Equatable {
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
    public var startSize: Double, endSize: Double
    public var startColor: Vec4, endColor: Vec4
    public var isEmitting = true

    public init(position: Vec2 = .zero, rate: Double = 100, lifetime: ClosedRange<Double> = 1...1,
                speed: ClosedRange<Double> = 50...100, direction: Double = .pi / 2, spread: Double = 2 * .pi,
                startSize: Double = 4, endSize: Double = 0, startColor: Vec4 = Vec4(1, 1, 1, 1), endColor: Vec4 = Vec4(1, 1, 1, 0)) {
        self.position = position; self.rate = rate; self.lifetime = lifetime; self.speed = speed
        self.direction = direction; self.spread = spread
        self.startSize = startSize; self.endSize = endSize; self.startColor = startColor; self.endColor = endColor
    }
}

public enum ParticleForce: Sendable, Equatable {
    /// Constant acceleration.
    case gravity(Vec2)
    /// Velocity damping per second (k ≥ 0).
    case drag(Double)
    /// Pulls toward `point` with `strength` (units/s²), only within `radius`.
    case attractor(point: Vec2, strength: Double, radius: Double)
}

/// What a renderer needs per particle.
public struct ParticleInstance: Sendable, Equatable {
    public var position: Vec2
    /// Diameter in world units.
    public var size: Double
    public var color: Vec4
    public init(position: Vec2, size: Double, color: Vec4) { self.position = position; self.size = size; self.color = color }
}

public struct ParticleSystem: Sendable {
    public static let defaultCapacity = 10_000
    public static let maxCapacity = 100_000

    public let capacity: Int
    public var emitters: [Emitter] = []
    public var forces: [ParticleForce] = []
    public private(set) var aliveCount = 0
    /// Particles not emitted because the pool was full.
    public private(set) var droppedCount = 0
    /// Particles removed because their state became NaN or infinite.
    public private(set) var nanRemoved = 0
    public private(set) var random: SeededRandom

    // Structure of arrays, valid in 0..<aliveCount (internal for tests).
    var px: [Double], py: [Double], vx: [Double], vy: [Double], age: [Double], life: [Double], source: [Int]
    private var accumulators: [Double] = []
    private var pendingBursts: [(emitter: Int, count: Int)] = []

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

    public mutating func step(_ dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        // 1. Age and expire.
        var i = 0
        while i < aliveCount {
            age[i] += dt
            if age[i] >= life[i] { remove(i) } else { i += 1 }
        }
        // 2. Forces, integration, NaN guard.
        i = 0
        while i < aliveCount {
            var ax = 0.0, ay = 0.0
            for f in forces {
                switch f {
                case .gravity(let g): ax += g.x; ay += g.y
                case .drag(let k): ax -= k * vx[i]; ay -= k * vy[i]
                case .attractor(let p, let s, let r):
                    let dx = p.x - px[i], dy = p.y - py[i], d = (dx * dx + dy * dy).squareRoot()
                    if d > 1e-9 && d <= r { ax += s * dx / d; ay += s * dy / d }
                }
            }
            vx[i] += ax * dt; vy[i] += ay * dt
            px[i] += vx[i] * dt; py[i] += vy[i] * dt
            if !(px[i].isFinite && py[i].isFinite && vx[i].isFinite && vy[i].isFinite) {
                nanRemoved += 1
                remove(i)
            } else { i += 1 }
        }
        // 3. Emit.
        if accumulators.count != emitters.count { accumulators = Array(accumulators.prefix(emitters.count)) + Array(repeating: 0, count: max(0, emitters.count - accumulators.count)) }
        for (e, emitter) in emitters.enumerated() where emitter.isEmitting && emitter.rate.isFinite && emitter.rate > 0 {
            accumulators[e] += emitter.rate * dt
            let n = Int((accumulators[e] + 1e-9).rounded(.down))
            accumulators[e] = max(0, accumulators[e] - Double(n))
            for _ in 0..<n { spawn(from: e) }
        }
        for b in pendingBursts where emitters.indices.contains(b.emitter) { for _ in 0..<b.count { spawn(from: b.emitter) } }
        pendingBursts.removeAll()
    }

    private mutating func spawn(from e: Int) {
        guard aliveCount < capacity else { droppedCount += 1; return }
        let em = emitters[e]
        let angle = em.direction + (random.double() - 0.5) * em.spread
        let speed = random.range(em.speed)
        let i = aliveCount
        px[i] = em.position.x; py[i] = em.position.y
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

    /// Position, size and color of each live particle (size and color interpolated over life).
    public func instances() -> [ParticleInstance] {
        (0..<aliveCount).map { i in
            let em = emitters.indices.contains(source[i]) ? emitters[source[i]] : Emitter()
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
