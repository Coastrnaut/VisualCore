// ScreenCare — feature 134 T-A18-403 (FR-A18-406; SC-A18-404; clarification Q3). Screen care for a clock left on for
// hours: a slow bounded drift of the overlay and scene, and an idle dim after ten minutes without an action. Pure
// functions of the instant in seconds; nothing here reads a clock.
import Foundation

/// The drift and idle-dim rules of screen care.
public enum ScreenCare {
    /// The largest drift on either axis, in points.
    public static let amplitude = 8.0
    /// The period of the horizontal drift, in seconds.
    public static let periodX = 600.0
    /// The period of the vertical drift, in seconds.
    public static let periodY = 840.0
    /// The time without an action after which the screen dims, in seconds.
    public static let idleInterval = 600.0
    /// The dim factor applied to the scene and the text opacity once idle.
    public static let idleDim = 0.6

    /// The drift offset in points at instant `seconds`: `8 × (sin 2πt/600, sin 2πt/840)`, or (0, 0) under reduced
    /// motion. At most 8 points per axis and at most 2π·8/600 × 60 ≈ 5 points per minute.
    public static func drift(at seconds: Double, reduceMotion: Bool) -> SIMD2<Double> {
        guard !reduceMotion, seconds.isFinite else { return .zero }
        let twoPi = 2 * Double.pi
        return SIMD2(amplitude * sin(twoPi * seconds / periodX), amplitude * sin(twoPi * seconds / periodY))
    }

    /// The idle dim factor: ``idleDim`` once `now − lastAction` reaches ``idleInterval`` seconds, otherwise 1.
    public static func dimFactor(now: Double, lastAction: Double) -> Double {
        (now - lastAction) >= idleInterval ? idleDim : 1
    }
}
