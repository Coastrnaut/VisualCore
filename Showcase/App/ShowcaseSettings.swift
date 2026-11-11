// ShowcaseSettings.swift — accessibility and debug settings shared by all scenes (feature 007 T-F604; FR-F609, FR-F604).
// Launch arguments land in UserDefaults' argument domain as strings; bool(forKey:) parses YES/NO.
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ShowcaseSettings {
    /// System Reduce Motion, or `-uitestReduceMotion YES|NO`.
    var reduceMotion: Bool
    /// Reduce Flashing: defaults to Reduce Motion, user-toggleable, persisted.
    var reduceFlashing: Bool { didSet { UserDefaults.standard.set(reduceFlashing, forKey: Self.flashingKey) } }
    /// Debug-only fault injection for the shader error demonstration (`-showcaseInjectShaderError YES`).
    let injectShaderError: Bool

    static let flashingKey = "showcase.reduceFlashing"

    init(defaults: UserDefaults = .standard) {
        let motionOverride = defaults.object(forKey: "uitestReduceMotion") == nil ? nil : defaults.bool(forKey: "uitestReduceMotion")
        let motion = motionOverride ?? UIAccessibility.isReduceMotionEnabled
        reduceMotion = motion
        reduceFlashing = defaults.object(forKey: Self.flashingKey) == nil ? motion : defaults.bool(forKey: Self.flashingKey)
        #if DEBUG
        injectShaderError = defaults.bool(forKey: "showcaseInjectShaderError")
        #else
        injectShaderError = false
        #endif
    }
}
