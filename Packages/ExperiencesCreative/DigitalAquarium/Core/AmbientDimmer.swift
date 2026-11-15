// AmbientDimmer — feature 072 (A09-P05) T-A09-502 (FR-A09-511; clarification 3; research D3). The in-scene dimming of
// ambient drawing: the idle clock counts frame time while ambient drawing is active (pausing does not stop it); after
// ``idleInterval`` seconds without a canvas touch the brightness fades linearly over ``fadeDuration`` seconds to
// ``dimLevel``; a touch restores full brightness at once. While ambient drawing is not active the clock is held at 0,
// so the brightness is 1 and a later ambient period starts a fresh minute. The system screen brightness and idle timer
// are never touched; the caller multiplies its colours by ``brightness``.
import Foundation

/// The idle clock and colour scale of ambient dimming.
public struct AmbientDimmer: Equatable, Sendable {
    /// Seconds of frame time without a touch before the fade starts.
    public static let idleInterval = 60.0
    /// Seconds the fade to ``dimLevel`` takes.
    public static let fadeDuration = 2.0
    /// The brightness after the fade.
    public static let dimLevel = 0.6

    /// Seconds of active frame time since the last touch (0 while ambient drawing is off).
    public private(set) var idle: Double = 0

    /// Creates a dimmer at full brightness.
    public init() {}

    /// The colour scale: 1 while ``idle`` ≤ ``idleInterval``, then linear to ``dimLevel`` at ``idleInterval`` +
    /// ``fadeDuration``, then ``dimLevel``.
    public var brightness: Double {
        let t = (idle - Self.idleInterval) / Self.fadeDuration
        guard t > 0 else { return 1 }
        return 1 - (1 - Self.dimLevel) * min(t, 1)
    }

    /// Advances the idle clock by `seconds` of frame time while `active` (ambient drawing on); a non-finite or
    /// non-positive `seconds` changes nothing. While not `active` the clock is reset to 0.
    public mutating func advance(by seconds: Double, active: Bool) {
        guard active else { idle = 0; return }
        guard seconds.isFinite, seconds > 0 else { return }
        idle += seconds
    }

    /// A canvas touch: the idle clock restarts and the brightness is 1 at once.
    public mutating func touch() { idle = 0 }
}
