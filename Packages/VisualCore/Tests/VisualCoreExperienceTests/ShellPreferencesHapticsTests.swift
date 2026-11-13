// ShellPreferencesHapticsTests — feature 226 (R02-F26) T-R02F26-012 (FR-R02F26-042; SC-R02F26-006): preferences written
// before the haptics switch decode with haptics on; the switch round-trips; schema 1 stays.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ShellPreferencesHapticsTests {
    @Test func preferencesWithoutTheSwitchDecodeWithHapticsOn() throws {
        let old = #"{"schema":1,"welcomeSeen":true,"lastRoute":"catalog","searchText":"","reduceMotion":"system","reduceFlashing":"system"}"#
        let decoded = try JSONDecoder().decode(ShellPreferences.self, from: Data(old.utf8))
        #expect(decoded.haptics == nil)
        #expect(decoded.hapticsOn)
        #expect(decoded.welcomeSeen)
    }

    @Test func theSwitchRoundTripsAndAbsentWritesNoKey() throws {
        var preferences = ShellPreferences()
        let plain = String(decoding: try JSONEncoder().encode(preferences), as: UTF8.self)
        #expect(!plain.contains("haptics"))
        preferences.haptics = false
        let data = try JSONEncoder().encode(preferences)
        let back = try JSONDecoder().decode(ShellPreferences.self, from: data)
        #expect(back.haptics == false)
        #expect(!back.hapticsOn)
    }
}
