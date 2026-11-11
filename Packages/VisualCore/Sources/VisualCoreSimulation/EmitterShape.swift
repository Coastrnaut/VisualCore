// EmitterShape.swift — emitter shapes, burst emission and parameter clamping for `ParticleSystem`
// (feature 033 A04-P01 T-A04-102; G-EMITTERS; FR-A04-101, FR-A04-102; research R2–R4).
import Foundation
import VisualCoreMath

/// Where an emitter places new particles, as an offset from `Emitter.position` (world units).
public enum EmitterShape: Sendable, Equatable, Codable {
    /// Every particle starts at the emitter position; draws no random number.
    case point
    /// A segment centered on the emitter: `halfLength` each way along `angle` (radians, counter-clockwise from +x);
    /// draws one random number per particle.
    case line(halfLength: Double, angle: Double)
    /// A circle of `radius` around the emitter; draws one random number per particle (the angle on the circle).
    case ring(radius: Double)

    /// Largest half length or radius after clamping (world units).
    public static let extentRange: ClosedRange<Double> = 0...10_000

    /// The shape with a non-finite or out-of-range extent or angle replaced: non-finite values become 0, extents are
    /// clamped to `extentRange`.
    public func clamped() -> EmitterShape {
        switch self {
        case .point: return .point
        case .line(let h, let a):
            return .line(halfLength: Emitter.clamp(h, Self.extentRange, fallback: 0), angle: a.isFinite ? a : 0)
        case .ring(let r): return .ring(radius: Emitter.clamp(r, Self.extentRange, fallback: 0))
        }
    }

    /// The spawn offset for this shape, drawing from `random` only for line and ring (research R2).
    func sampleOffset(_ random: inout SeededRandom) -> Vec2 {
        switch self {
        case .point: return .zero
        case .line(let h, let a):
            let s = (2 * random.double() - 1) * h
            return Vec2(cos(a) * s, sin(a) * s)
        case .ring(let r):
            let t = 2 * Double.pi * random.double()
            return Vec2(cos(t) * r, sin(t) * r)
        }
    }
}

/// Periodic burst emission: `count` particles at once, every `interval` seconds of simulated time, the first burst on
/// the first step after the emitter is added.
public struct EmitterBurst: Sendable, Equatable, Codable {
    /// Particles per burst, 1…5,000 after clamping.
    public var count: Int
    /// Seconds between bursts, 1/60…60 after clamping.
    public var interval: Double

    /// Allowed burst sizes.
    public static let countRange: ClosedRange<Int> = 1...5_000
    /// Allowed intervals in seconds.
    public static let intervalRange: ClosedRange<Double> = (1.0 / 60)...60

    /// Creates a burst of `count` particles every `interval` seconds.
    public init(count: Int, interval: Double) { self.count = count; self.interval = interval }

    /// The burst with its count and interval clamped (a non-finite interval becomes 1 s).
    public func clamped() -> EmitterBurst {
        EmitterBurst(count: min(max(count, Self.countRange.lowerBound), Self.countRange.upperBound),
                     interval: Emitter.clamp(interval, Self.intervalRange, fallback: 1))
    }
}

extension Emitter {
    /// Allowed continuous emission rates (particles per second).
    public static let rateRange: ClosedRange<Double> = 0...20_000
    /// Allowed particle lifetimes (seconds).
    public static let lifetimeRange: ClosedRange<Double> = 0.01...3_600
    /// Allowed initial speeds (world units per second).
    public static let speedRange: ClosedRange<Double> = 0...10_000
    /// Allowed particle diameters (world units).
    public static let sizeRange: ClosedRange<Double> = 0...512
    /// Allowed cone angles (radians).
    public static let spreadRange: ClosedRange<Double> = 0...(2 * Double.pi)

    /// The emitter with every value finite and in range (FR-A04-102). In-range values are returned unchanged, so valid
    /// emitters behave exactly as before. A non-finite rate becomes 0 (no emission); other non-finite values become the
    /// defaults of `Emitter()`; ranges are ordered after clamping; color components are clamped to 0…1.
    public func clamped() -> Emitter {
        let d = Emitter()
        var e = self
        e.position = Vec2(position.x.isFinite ? position.x : 0, position.y.isFinite ? position.y : 0)
        e.rate = Self.clamp(rate, Self.rateRange, fallback: 0)
        e.lifetime = Self.clampRange(lifetime, Self.lifetimeRange, fallback: d.lifetime)
        e.speed = Self.clampRange(speed, Self.speedRange, fallback: d.speed)
        e.direction = direction.isFinite ? direction : d.direction
        e.spread = Self.clamp(spread, Self.spreadRange, fallback: d.spread)
        e.startSize = Self.clamp(startSize, Self.sizeRange, fallback: d.startSize)
        e.endSize = Self.clamp(endSize, Self.sizeRange, fallback: d.endSize)
        e.startColor = Self.clampColor(startColor, fallback: d.startColor)
        e.endColor = Self.clampColor(endColor, fallback: d.endColor)
        e.shape = shape.clamped()
        e.burst = burst?.clamped()
        return e
    }

    static func clamp(_ v: Double, _ r: ClosedRange<Double>, fallback: Double) -> Double {
        v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : fallback
    }

    static func clampRange(_ v: ClosedRange<Double>, _ r: ClosedRange<Double>, fallback: ClosedRange<Double>) -> ClosedRange<Double> {
        guard v.lowerBound.isFinite, v.upperBound.isFinite else { return fallback }
        let lo = clamp(v.lowerBound, r, fallback: r.lowerBound), hi = clamp(v.upperBound, r, fallback: r.lowerBound)
        return min(lo, hi)...max(lo, hi)
    }

    static func clampColor(_ c: Vec4, fallback: Vec4) -> Vec4 {
        guard c.x.isFinite, c.y.isFinite, c.z.isFinite, c.w.isFinite else { return fallback }
        func u(_ v: Double) -> Double { min(max(v, 0), 1) }
        return Vec4(u(c.x), u(c.y), u(c.z), u(c.w))
    }
}
