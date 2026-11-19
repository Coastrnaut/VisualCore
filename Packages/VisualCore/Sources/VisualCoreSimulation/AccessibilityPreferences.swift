// AccessibilityPreferences.swift — the app's motion and flashing choices combined with the system settings
// (feature 016 T-A01-501; gap G-UI; FR-A01-501, FR-A01-502, FR-A01-506; research R1, R2). Pure, host-testable logic
// shared by every animated app; VisualCoreUI.SystemAccessibilityObserver supplies the system values on iOS.
import Foundation

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

// feature 210 (R02-F10) T-R02F10-007: colour-vision choice (FR-R02F10, research R7, SC-R02F10-005).
/// The colour scheme an app uses for colour-coded content: the standard colours or one of three colour-vision presets.
public enum ColorVisionChoice: String, Sendable, Codable, CaseIterable, Identifiable {
    /// The experience's own colours (the default).
    case standard
    /// A warm-and-cool preset (orange against blue) that stays apart under red-green colour blindness.
    case warmCool
    /// A red-and-cyan preset that stays apart under blue-yellow colour blindness.
    case redCyan
    /// A lightness-only preset that relies on brightness differences, not hue.
    case lightness

    /// Stable identifier (the raw value).
    public var id: String { rawValue }
    /// Display title: "Standard colours", "Warm and cool", "Red and cyan" or "Lightness".
    public var title: String {
        switch self {
        case .standard: return "Standard colours"
        case .warmCool: return "Warm and cool"
        case .redCyan: return "Red and cyan"
        case .lightness: return "Lightness"
        }
    }

    /// Reads a stored raw value; nil or an unknown value becomes `.standard`.
    public init(storedValue: String?) {
        self = storedValue.flatMap(ColorVisionChoice.init(rawValue:)) ?? .standard
    }

    /// Decodes a raw string; an unknown value becomes `.standard` instead of failing.
    public init(from decoder: Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}

/// An app's accessibility choices for animated content; motion and flashing default to following the system and
/// the colour-vision choice defaults to `.standard`.
public struct AccessibilityPreferences: Sendable, Equatable, Codable {
    /// Reduce Motion choice.
    public var reduceMotion: AccessibilityChoice
    /// Reduce Flashing choice.
    public var reduceFlashing: AccessibilityChoice
    /// Colour-vision choice (feature 210 T-R02F10-007); `.standard` keeps the experience's own colours.
    public var colorVision: ColorVisionChoice

    /// Creates preferences; motion and flashing default to `.system`, colour vision to `.standard`.
    public init(reduceMotion: AccessibilityChoice = .system, reduceFlashing: AccessibilityChoice = .system,
                colorVision: ColorVisionChoice = .standard) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        self.colorVision = colorVision
    }

    /// JSON keys; the first two keep the names used before feature 210 so older data decodes.
    private enum CodingKeys: String, CodingKey {
        case reduceMotion, reduceFlashing, colorVision
    }

    /// Decodes preferences; an absent key takes its default, so JSON written before feature 210 still decodes.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(reduceMotion: try c.decodeIfPresent(AccessibilityChoice.self, forKey: .reduceMotion) ?? .system,
                  reduceFlashing: try c.decodeIfPresent(AccessibilityChoice.self, forKey: .reduceFlashing) ?? .system,
                  colorVision: try c.decodeIfPresent(ColorVisionChoice.self, forKey: .colorVision) ?? .standard)
    }

    /// Encodes all three choices as raw strings.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reduceMotion, forKey: .reduceMotion)
        try c.encode(reduceFlashing, forKey: .reduceFlashing)
        try c.encode(colorVision, forKey: .colorVision)
    }

    /// Combines the choices with the system values: `.system` takes the system flag, `.on`/`.off` override it.
    public func resolve(_ system: SystemAccessibility) -> EffectiveAccessibility {
        EffectiveAccessibility(reduceMotion: reduceMotion.resolve(system.reduceMotion),
                               reduceFlashing: reduceFlashing.resolve(system.dimFlashingLights))
    }
}

// MARK: Storage (feature 016 T-A01-510; constitution II)

extension AccessibilityPreferences {
    /// The two `UserDefaults` keys for a prefix: `<prefix>.reduceMotion` and `<prefix>.reduceFlashing` (raw
    /// `AccessibilityChoice` values). Apps can use them with SwiftUI's `@AppStorage`.
    public static func keys(prefix: String) -> (reduceMotion: String, reduceFlashing: String) {
        ("\(prefix).reduceMotion", "\(prefix).reduceFlashing")
    }

    /// The `UserDefaults` key of the colour-vision choice: `<prefix>.colorVision` (a raw `ColorVisionChoice`
    /// value; feature 210 T-R02F10-007). Kept apart from `keys(prefix:)` so that tuple's shape stays unchanged.
    public static func colorVisionKey(prefix: String) -> String {
        "\(prefix).colorVision"
    }

    /// Reads the choices stored under `prefix`; absent or unknown motion and flashing values become `.system`,
    /// an absent or unknown colour-vision value becomes `.standard`.
    public static func load(from defaults: UserDefaults, keyPrefix prefix: String) -> AccessibilityPreferences {
        let k = keys(prefix: prefix)
        return AccessibilityPreferences(reduceMotion: AccessibilityChoice(storedValue: defaults.string(forKey: k.reduceMotion)),
                                        reduceFlashing: AccessibilityChoice(storedValue: defaults.string(forKey: k.reduceFlashing)),
                                        colorVision: ColorVisionChoice(storedValue: defaults.string(forKey: colorVisionKey(prefix: prefix))))
    }

    /// Stores all three choices under `prefix` as raw values.
    public func save(to defaults: UserDefaults, keyPrefix prefix: String) {
        let k = Self.keys(prefix: prefix)
        defaults.set(reduceMotion.rawValue, forKey: k.reduceMotion)
        defaults.set(reduceFlashing.rawValue, forKey: k.reduceFlashing)
        defaults.set(colorVision.rawValue, forKey: Self.colorVisionKey(prefix: prefix))
    }
}
