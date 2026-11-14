// ScopeZoom — feature 064 (A08-P04) T-A08-402 (FR-A08-403; SC-A08-403; clarification 2; research D2; data-model
// "ScopeZoom"). Pinch zoom as discrete timebase steps, host-free: each time the pinch scale crosses a doubling of the
// scale at the last step (the anchor), the timebase moves one index — down (a shorter span, zoom in) when the fingers
// spread to at least twice the anchor, up (zoom out) when they close to at most half of it. The caller re-anchors at
// the scale of every step, so a continuous pinch by 4 gives two steps and by 0.25 two steps the other way. The index is
// clamped to the offered timebases; the step is sent as the `timebase.select` action like the timebase control.
import Foundation

/// Pinch scale to timebase steps.
public enum ScopeZoom {
    /// The factor of the pinch scale against the anchor that makes one step.
    public static let stepFactor = 2.0

    /// The timebase step for a pinch at `scale` since the last step at `anchorScale`.
    /// - Returns: −1 (one index down, zoom in) when `scale` ≥ 2 × `anchorScale`; +1 (one index up, zoom out) when
    ///   `scale` ≤ `anchorScale` ÷ 2; otherwise 0. 0 also when either scale is not finite or not positive.
    public static func step(scale: Double, anchorScale: Double) -> Int {
        guard scale.isFinite, anchorScale.isFinite, scale > 0, anchorScale > 0 else { return 0 }
        if scale >= anchorScale * stepFactor { return -1 }
        if scale <= anchorScale / stepFactor { return 1 }
        return 0
    }

    /// The timebase index after `step` from `current`, clamped to 0…`count` − 1 (0 when `count` is not positive).
    public static func index(after current: Int, step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let (sum, overflow) = current.addingReportingOverflow(step)
        let target = overflow ? (step < 0 ? 0 : count - 1) : sum
        return min(max(target, 0), count - 1)
    }
}
