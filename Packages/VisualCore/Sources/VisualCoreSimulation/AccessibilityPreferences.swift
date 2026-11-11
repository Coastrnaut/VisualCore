// AccessibilityPreferences.swift — the app's motion and flashing choices combined with the system settings
// (feature 016 T-A01-501; gap G-UI; FR-A01-501, FR-A01-502, FR-A01-506; research R1, R2). Pure, host-testable logic
// shared by every animated app; VisualCoreUI.SystemAccessibilityObserver supplies the system values on iOS.

/// One accessibility choice in an app's settings: follow the system, or force on or off.
public enum AccessibilityChoice: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Follow the system setting (the default).
    case system
    /// Always on, whatever the system says.
    case on
    /// Always off, whatever the system says (the user's explicit choice).
    case off

    /// Stable identifier (the raw value).
    public var id: String { rawValue }
    /// Display title: "System", "On" or "Off".
    public var title: String {
        switch self {
        case .system: return "System"
        case .on: return "On"
        case .off: return "Off"
        }
    }

    /// Reads a stored raw value; nil or an unknown value becomes `.system`.
    public init(storedValue: String?) {
        self = storedValue.flatMap(AccessibilityChoice.init(rawValue:)) ?? .system
    }

    /// Decodes a raw string; an unknown value becomes `.system` instead of failing.
    public init(from decoder: Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }

    func resolve(_ systemValue: Bool) -> Bool {
        switch self {
        case .system: return systemValue
        case .on: return true
        case .off: return false
        }
    }
}

/// The system's accessibility flags relevant to animated scenes.
public struct SystemAccessibility: Sendable, Equatable {
    /// System Reduce Motion.
    public var reduceMotion: Bool
    /// System "Dim Flashing Lights".
    public var dimFlashingLights: Bool

    /// Creates system values (both off by default).
    public init(reduceMotion: Bool = false, dimFlashingLights: Bool = false) {
        self.reduceMotion = reduceMotion
        self.dimFlashingLights = dimFlashingLights
    }
}

/// The settings actually applied to a scene after combining system values and app choices.
public struct EffectiveAccessibility: Sendable, Equatable {
    /// Slow scene playback.
    public let reduceMotion: Bool
    /// Limit sudden brightness changes (VisualCoreEffects' flash limiter).
    public let reduceFlashing: Bool

    /// Creates effective values.
    public init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
    }

    /// Playback-rate factor: `SceneClock.reducedMotionFactor` (0.5) under Reduce Motion, else 1.
    public var playbackRate: Double { reduceMotion ? SceneClock.reducedMotionFactor : 1 }
}

/// An app's accessibility choices for animated content; each defaults to following the system.
public struct AccessibilityPreferences: Sendable, Equatable, Codable {
    /// Reduce Motion choice.
    public var reduceMotion: AccessibilityChoice
    /// Reduce Flashing choice.
    public var reduceFlashing: AccessibilityChoice

    /// Creates preferences; both default to `.system`.
    public init(reduceMotion: AccessibilityChoice = .system, reduceFlashing: AccessibilityChoice = .system) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
    }

    /// Combines the choices with the system values: `.system` takes the system flag, `.on`/`.off` override it.
    public func resolve(_ system: SystemAccessibility) -> EffectiveAccessibility {
        EffectiveAccessibility(reduceMotion: reduceMotion.resolve(system.reduceMotion),
                               reduceFlashing: reduceFlashing.resolve(system.dimFlashingLights))
    }
}
