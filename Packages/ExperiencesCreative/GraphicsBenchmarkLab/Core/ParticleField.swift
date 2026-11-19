// ParticleField — feature 174 (A24-P02) T-A24-203 (FR-A24-201; clarification Q1; data-model.md "ParticleField"). The
// particles workload's instances as a pure function of the particle index and the workload frame number n, never of
// the clock, so the same case draws the same picture on every run.
// Choices recorded here: a splitmix64 hash of the index seeds a small chain of 64-bit values; each gives a fraction in
// [0, 1) from its top 53 bits. The start position lies in [0, width) × [0, height); the velocity is up to ±2 points
// per frame on each axis; the size is 2…6 points; the colour is red 0.35…1, green 0.30…0.9, blue 0.55…1 and alpha
// 0.6…0.95. The position at frame n is start + velocity · n wrapped into the view with a true (never negative) modulo;
// a width or height of 0 or less (or not finite) gives position 0 on that axis. Integer and Double arithmetic only, no
// random generator. Pure Foundation; no UI, GPU or clock.
import Foundation

/// One particle's appearance in a frame, in view points.
public struct ParticleState: Sendable, Equatable {
    /// The horizontal position in points, within [0, width).
    public var x: Double
    /// The vertical position in points, within [0, height).
    public var y: Double
    /// The side of the particle's quad in points, 2…6.
    public var size: Double
    /// The red component, 0…1.
    public var red: Double
    /// The green component, 0…1.
    public var green: Double
    /// The blue component, 0…1.
    public var blue: Double
    /// The opacity, 0…1.
    public var alpha: Double

    /// A particle state with the given values (not checked).
    public init(x: Double, y: Double, size: Double, red: Double, green: Double, blue: Double, alpha: Double) {
        self.x = x
        self.y = y
        self.size = size
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// A deterministic field of `count` particles moving at fixed velocities and wrapping around the view.
public struct ParticleField: Sendable, Equatable {
    /// The number of particles; a negative value is treated as 0 by ``states(frame:width:height:)``.
    public let count: Int

    /// A field of `count` particles.
    public init(count: Int) {
        self.count = count
    }

    /// The largest speed on each axis, in points per frame.
    static let maxSpeed = 2.0

    /// One splitmix64 step: advances `state` and returns the mixed value.
    static func splitmix64(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A fraction in [0, 1) from the top 53 bits of `value`.
    static func unit(_ value: UInt64) -> Double {
        Double(value >> 11) * 0x1p-53
    }

    /// `value` wrapped into [0, extent) with a true modulo; 0 when `extent` is 0 or less or not finite.
    static func wrap(_ value: Double, into extent: Double) -> Double {
        guard extent.isFinite, extent > 0, value.isFinite else { return 0 }
        var wrapped = value.truncatingRemainder(dividingBy: extent)
        if wrapped < 0 { wrapped += extent }
        if wrapped >= extent { wrapped = 0 }
        return wrapped
    }

    /// The state of particle `index` at workload frame `frame` in a view of `width` × `height` points.
    public func state(index: Int, frame: Int, width: Double, height: Double) -> ParticleState {
        var seed = UInt64(bitPattern: Int64(index))
        let startX = Self.unit(Self.splitmix64(&seed))
        let startY = Self.unit(Self.splitmix64(&seed))
        let velocityX = (Self.unit(Self.splitmix64(&seed)) * 2 - 1) * Self.maxSpeed
        let velocityY = (Self.unit(Self.splitmix64(&seed)) * 2 - 1) * Self.maxSpeed
        let size = 2 + Self.unit(Self.splitmix64(&seed)) * 4
        let red = 0.35 + Self.unit(Self.splitmix64(&seed)) * 0.65
        let green = 0.30 + Self.unit(Self.splitmix64(&seed)) * 0.60
        let blue = 0.55 + Self.unit(Self.splitmix64(&seed)) * 0.45
        let alpha = 0.6 + Self.unit(Self.splitmix64(&seed)) * 0.35
        let n = Double(frame)
        let x = width > 0 ? Self.wrap(startX * width + velocityX * n, into: width) : 0
        let y = height > 0 ? Self.wrap(startY * height + velocityY * n, into: height) : 0
        return ParticleState(x: x, y: y, size: size, red: red, green: green, blue: blue, alpha: alpha)
    }

    /// The states of every particle, index 0 to `count` − 1, at workload frame `frame` in a view of `width` ×
    /// `height` points.
    public func states(frame: Int, width: Double, height: Double) -> [ParticleState] {
        let total = max(0, count)
        var result: [ParticleState] = []
        result.reserveCapacity(total)
        for index in 0..<total {
            result.append(state(index: index, frame: frame, width: width, height: height))
        }
        return result
    }
}
