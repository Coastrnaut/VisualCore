// ColorVisionPreferenceTests — feature 210 (R02-F10) T-R02F10-007 (research R7; SC-R02F10-005).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Test func jsonFromBeforeFeatureDecodesWithStandard() throws {
    let old = Data(#"{"reduceMotion":"on","reduceFlashing":"off"}"#.utf8)
    let prefs = try JSONDecoder().decode(AccessibilityPreferences.self, from: old)
    #expect(prefs == AccessibilityPreferences(reduceMotion: .on, reduceFlashing: .off, colorVision: .standard))
}

@Test func unknownColorVisionJSONBecomesStandard() throws {
    let json = Data(#"{"reduceMotion":"system","reduceFlashing":"system","colorVision":"bogus"}"#.utf8)
    #expect(try JSONDecoder().decode(AccessibilityPreferences.self, from: json).colorVision == .standard)
    #expect(ColorVisionChoice(storedValue: nil) == .standard)
    #expect(ColorVisionChoice(storedValue: "bogus") == .standard)
    #expect(ColorVisionChoice(storedValue: "redCyan") == .redCyan)
}

@Test func codableRoundTripOfEveryChoice() throws {
    for choice in ColorVisionChoice.allCases {
        let prefs = AccessibilityPreferences(reduceMotion: .off, reduceFlashing: .on, colorVision: choice)
        let data = try JSONEncoder().encode(prefs)
        #expect(try JSONDecoder().decode(AccessibilityPreferences.self, from: data) == prefs, "\(choice)")
    }
}

@Test func colorVisionStorage() throws {
    let suite = "vc.a11y.cv.test.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(AccessibilityPreferences.colorVisionKey(prefix: "vc.a11y") == "vc.a11y.colorVision")
    #expect(AccessibilityPreferences.keys(prefix: "vc.a11y") == ("vc.a11y.reduceMotion", "vc.a11y.reduceFlashing"))
    defaults.set("on", forKey: "vc.a11y.reduceMotion")
    defaults.set("off", forKey: "vc.a11y.reduceFlashing")
    #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "vc.a11y")
            == AccessibilityPreferences(reduceMotion: .on, reduceFlashing: .off, colorVision: .standard))
    for choice in ColorVisionChoice.allCases {
        let prefs = AccessibilityPreferences(reduceMotion: .system, reduceFlashing: .on, colorVision: choice)
        prefs.save(to: defaults, keyPrefix: "vc.a11y")
        #expect(defaults.string(forKey: "vc.a11y.colorVision") == choice.rawValue)
        #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "vc.a11y") == prefs, "\(choice)")
    }
    defaults.set("sepia", forKey: "vc.a11y.colorVision")
    #expect(AccessibilityPreferences.load(from: defaults, keyPrefix: "vc.a11y").colorVision == .standard)
}

@Test func colorVisionTitlesNonEmptyAndDistinct() {
    let titles = ColorVisionChoice.allCases.map(\.title)
    #expect(titles == ["Standard colours", "Warm and cool", "Red and cyan", "Lightness"])
    #expect(titles.allSatisfy { !$0.isEmpty })
    #expect(Set(titles).count == titles.count)
    #expect(ColorVisionChoice.allCases.map(\.id) == ["standard", "warmCool", "redCyan", "lightness"])
}
