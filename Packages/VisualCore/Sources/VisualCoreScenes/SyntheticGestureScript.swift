// SyntheticGestureScript.swift — seeded, repeatable multi-pointer touch input for fixtures and automation runs
// (feature 023 T-A02-501; FR-A02-505, SC-A02-503; research R1). Pure: every frame's events are computed from the
// inputs alone, so any frame can be replayed without the frames before it.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Deterministic touch strokes for tests and device stress runs: the same inputs always give the same events.
///
/// Each pointer repeats strokes of `strokeSamples + 2` frames: one `began`, `strokeSamples` `moved` and one `ended`,
/// then a new stroke from a new seeded start point and direction. Pointer `i` (id `i`) starts at frame `i`. Moved
/// samples advance by `speed × frameInterval` points and are clamped inside `viewSize` (top-left origin).
/// Timestamps are `frame × frameInterval` plus a per-pointer offset below one interval, so they strictly increase per
/// pointer.
public struct SyntheticGestureScript: Sendable, Equatable {
    /// The seed (0 is replaced by 1).
    public let seed: UInt64
    /// Simultaneous pointers, 1…10 (`PointerTracker.maxPointers`).
    public let pointerCount: Int
    /// Moved samples per stroke, 1…240.
    public let strokeSamples: Int
    /// Stroke speed in points per second, 0…20,000 (non-finite values give 0).
    public let speed: Double
    /// The view size in points; non-finite or non-positive sizes give 1×1.
    public let viewSize: Vec2
    /// Seconds per frame (default 1/60; non-finite or non-positive values give 1/60).
    public let frameInterval: Double

    /// Creates a script; every input is clamped to its documented range.
    public init(seed: UInt64, pointerCount: Int = 1, strokeSamples: Int = 30, speed: Double = 600,
                viewSize: Vec2, frameInterval: Double = 1.0 / 60) {
        self.seed = seed == 0 ? 1 : seed
        self.pointerCount = min(max(pointerCount, 1), PointerTracker.maxPointers)
        self.strokeSamples = min(max(strokeSamples, 1), 240)
        self.speed = speed.isFinite ? min(max(speed, 0), 20_000) : 0
        let valid = viewSize.x.isFinite && viewSize.y.isFinite && viewSize.x > 0 && viewSize.y > 0
        self.viewSize = valid ? viewSize : Vec2(1, 1)
        self.frameInterval = frameInterval.isFinite && frameInterval > 0 ? frameInterval : 1.0 / 60
    }

    /// Frames per stroke: began, the moved samples, ended.
    private var strokeLength: Int { strokeSamples + 2 }

    /// The events of frame `frame` (at most one per pointer, ordered by pointer id); none for a negative frame.
    public func events(forFrame frame: Int) -> [PointerEvent] {
        guard frame >= 0 else { return [] }
        var out: [PointerEvent] = []
        for pointer in 0..<pointerCount {
            let local = frame - pointer
            guard local >= 0 else { continue }
            let stroke = local / strokeLength, step = local % strokeLength
            let phase: PointerPhase = step == 0 ? .began : (step == strokeLength - 1 ? .ended : .moved)
            let (start, direction) = strokeStart(pointer: pointer, stroke: stroke)
            let distance = speed * frameInterval * Double(min(step, strokeSamples))
            let location = clamp(Vec2(start.x + direction.x * distance, start.y + direction.y * distance))
            let timestamp = Double(frame) * frameInterval + Double(pointer) * frameInterval / 16
            out.append(PointerEvent(id: pointer, phase: phase, location: location, timestamp: timestamp))
        }
        return out
    }

    /// The seeded start point (inside the view) and unit direction of one stroke.
    private func strokeStart(pointer: Int, stroke: Int) -> (Vec2, Vec2) {
        let mixed = seed &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(pointer) &* 0xBF58_476D_1CE4_E5B9 ^ UInt64(stroke) &* 0x94D0_49BB_1331_11EB
        var rng = SeededRandom(seed: mixed)
        let start = Vec2(rng.double() * viewSize.x, rng.double() * viewSize.y)
        let angle = rng.double() * 2 * Double.pi
        return (start, Vec2(cos(angle), sin(angle)))
    }

    private func clamp(_ p: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 0), viewSize.x), min(max(p.y, 0), viewSize.y))
    }
}
