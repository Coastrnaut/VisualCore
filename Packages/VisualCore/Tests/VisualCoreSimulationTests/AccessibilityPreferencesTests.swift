// AccessibilityPreferencesTests — feature 016 T-A01-501 (FR-A01-501, FR-A01-502, FR-A01-506; SC-A01-501).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Test func twelveResolutionCases() {
    var cases = 0
    for systemOn in [false, true] {
        for choice in AccessibilityChoice.allCases {
            let expected = choice == .system ? systemOn : choice == .on
            let motion = AccessibilityPreferences(reduceMotion: choice).resolve(SystemAccessibility(reduceMotion: systemOn))
            #expect(motion.reduceMotion == expected, "motion system=\(systemOn) choice=\(choice)")
            #expect(motion.reduceFlashing == false)
            let flashing = AccessibilityPreferences(reduceFlashing: choice).resolve(SystemAccessibility(dimFlashingLights: systemOn))
            #expect(flashing.reduceFlashing == expected, "flashing system=\(systemOn) choice=\(choice)")
            #expect(flashing.reduceMotion == false)
            cases += 2
        }
    }
    #expect(cases == 12)
}

@Test func offOverridesSystemOn() {
    let effective = AccessibilityPreferences(reduceMotion: .off, reduceFlashing: .off)
        .resolve(SystemAccessibility(reduceMotion: true, dimFlashingLights: true))
    #expect(effective == EffectiveAccessibility(reduceMotion: false, reduceFlashing: false))
}

@Test func playbackRateFollowsReduceMotion() {
    #expect(EffectiveAccessibility(reduceMotion: true, reduceFlashing: false).playbackRate == SceneClock.reducedMotionFactor)
    #expect(EffectiveAccessibility(reduceMotion: false, reduceFlashing: true).playbackRate == 1)
    #expect(SceneClock.reducedMotionFactor == 0.5)
}

@Test func storedValuesAndCodable() throws {
    #expect(AccessibilityChoice(storedValue: nil) == .system)
    #expect(AccessibilityChoice(storedValue: "bogus") == .system)
    #expect(AccessibilityChoice(storedValue: "on") == .on)
    #expect(AccessibilityChoice.allCases.map(\.title) == ["System", "On", "Off"])
    let prefs = AccessibilityPreferences(reduceMotion: .on, reduceFlashing: .off)
    let data = try JSONEncoder().encode(prefs)
    #expect(try JSONDecoder().decode(AccessibilityPreferences.self, from: data) == prefs)
    let unknown = Data(#"{"reduceMotion":"sometimes","reduceFlashing":"on"}"#.utf8)
    #expect(try JSONDecoder().decode(AccessibilityPreferences.self, from: unknown)
            == AccessibilityPreferences(reduceMotion: .system, reduceFlashing: .on))
}

@Test func storageRoundTripAndFallback() throws {
    let suite = "vc.a11y.test.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(AccessibilityPreferences.keys(prefix: "app.a11y") == ("app.a11y.reduceMotion", "app.a11y.reduceFlashing"))
    #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "app.a11y") == AccessibilityPreferences())
    let prefs = AccessibilityPreferences(reduceMotion: .off, reduceFlashing: .on)
    prefs.save(to: defaults, keyPrefix: "app.a11y")
    #expect(defaults.string(forKey: "app.a11y.reduceMotion") == "off")
    #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "app.a11y") == prefs)
    defaults.set("loud", forKey: "app.a11y.reduceFlashing")
    #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "app.a11y").reduceFlashing == .system)
}
