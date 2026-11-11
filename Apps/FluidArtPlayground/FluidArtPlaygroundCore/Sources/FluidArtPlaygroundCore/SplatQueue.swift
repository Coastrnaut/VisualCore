// SplatQueue.swift — touch samples and splash bursts become capped splats (feature 020 T-A02-208; FR-A02-204,
// FR-A02-208; research R5, R6). Samples come from VisualCore's PointerVelocityTracker; nothing is recorded or
// persisted, and the queue only holds splats until a frame drains them.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Pending splats for the next frames, with an even per-frame cap.
public struct SplatQueue: Sendable {
    /// Most splats kept between frames; older ones are dropped (and counted) beyond it.
    public static let maxPending = 1024
    /// Force of a splash burst, in cells per second.
    public static let splashForce: Float = 600
    /// Rotation between successive splash bursts (the golden angle, so bursts spread evenly).
    public static let splashAngleDegrees = 137.5

    /// The validated configuration (grid size, brush radius, force scale, cap).
    public let configuration: FluidConfiguration
    /// Splats dropped by the per-frame cap or the pending capacity.
    public private(set) var dropped = 0
    /// Splats ever queued.
    public private(set) var totalQueued = 0
    /// Splash bursts added.
    public private(set) var splashCount = 0
    private var pending: [Splat] = []
    private var colorIndex: [Int: Int] = [:]
    private var nextColor = 0

    /// A queue for `configuration` (validated again here).
    public init(configuration: FluidConfiguration) {
        self.configuration = configuration.validated().0
    }

    /// Splats waiting for a frame.
    public var pendingCount: Int { pending.count }
    /// Pointers that currently hold a color.
    public var trackedPointers: Int { colorIndex.count }

    /// Converts tracker samples (view points, top-left origin) into splats. Position is normalized with y flipped;
    /// force = velocity (points/s) × grid cells per point × `forceScale`; each pointer keeps one palette color.
    /// Nothing is queued for a non-positive or non-finite view size. An `ended` sample releases its pointer's color.
    public mutating func add(_ samples: [PointerVelocityTracker.Sample], viewSize: SIMD2<Double>) {
        guard viewSize.x.isFinite, viewSize.y.isFinite, viewSize.x > 0, viewSize.y > 0 else { return }
        let cellsPerPoint = SIMD2(Double(configuration.gridWidth) / viewSize.x, Double(configuration.gridHeight) / viewSize.y)
        for s in samples {
            let index = colorIndex[s.id] ?? {
                let i = nextColor % DyeSeed.palette.count
                nextColor += 1
                colorIndex[s.id] = i
                return i
            }()
            let rgb = DyeSeed.palette[index]
            let position = SIMD2(Float(s.position.x / viewSize.x), Float(1 - s.position.y / viewSize.y))
            let force = SIMD2(Float(s.velocity.x * cellsPerPoint.x), Float(-s.velocity.y * cellsPerPoint.y)) * Float(configuration.forceScale)
            if let splat = Splat(position: position, radius: Float(configuration.brushRadius), force: force,
                                 color: SIMD4(rgb, 1), timestamp: s.timestamp) {
                push(splat)
            }
            if s.phase == .ended { colorIndex[s.id] = nil }
        }
    }

    /// Forgets a pointer's color (call on cancelled touches, which produce no samples).
    public mutating func forget(pointer id: Int) { colorIndex[id] = nil }

    /// Queues splash burst k (k = splashes so far): at the center, direction `k × 137.5°`, force 600 cells/s,
    /// palette color `k mod 6`, the configured brush radius.
    public mutating func addSplash() {
        let k = splashCount
        let angle = Double(k) * Self.splashAngleDegrees * .pi / 180
        let force = SIMD2(Float(cos(angle)), Float(sin(angle))) * Self.splashForce
        let rgb = DyeSeed.palette[k % DyeSeed.palette.count]
        splashCount += 1
        if let splat = Splat(position: SIMD2(0.5, 0.5), radius: Float(configuration.brushRadius), force: force, color: SIMD4(rgb, 1)) {
            push(splat)
        }
    }

    /// Removes and returns at most `max` splats (default: the configured per-frame cap). Over the cap it keeps the
    /// evenly spaced indices `round(i·(n−1)/(max−1))`, which include the first and the newest, in order; with a cap
    /// of 1 only the newest. The rest are counted in `dropped`.
    public mutating func drain(max: Int? = nil) -> [Splat] {
        let cap = Swift.max(1, max ?? configuration.maxSplatsPerFrame)
        let all = pending
        pending.removeAll(keepingCapacity: true)
        guard all.count > cap else { return all }
        dropped += all.count - cap
        if cap == 1 { return [all[all.count - 1]] }
        let n = all.count
        return (0..<cap).map { i in all[Int((Double(i) * Double(n - 1) / Double(cap - 1)).rounded())] }
    }

    private mutating func push(_ splat: Splat) {
        pending.append(splat)
        totalQueued += 1
        if pending.count > Self.maxPending {
            pending.removeFirst(pending.count - Self.maxPending)
            dropped += 1
        }
    }
}
