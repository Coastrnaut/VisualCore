// ShellColorVisionTests — feature 210 (R02-F10) T-R02F10-008 (FR-R02F10-010; research R12): preferences written before
// the colour-vision choice decode with nil (standard); a choice round-trips; an unknown value reads as standard; schema 1
// stays.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ShellColorVisionTests {
    @Test func schemaOneWithoutTheKeyDecodesAsNil() throws {
        let old = #"{"schema":1,"welcomeSeen":true,"lastRoute":"catalog","searchText":"","reduceMotion":"system","reduceFlashing":"system"}"#
        let decoded = try JSONDecoder().decode(ShellPreferences.self, from: Data(old.utf8))
        #expect(decoded.colorVision == nil)
        #expect(decoded.welcomeSeen)
        #expect(ShellPreferences.decode(Data(old.utf8)).note == nil)
    }

    @Test func redCyanRoundTripsAndAbsentWritesNoKey() throws {
        var preferences = ShellPreferences()
        let plain = String(decoding: preferences.encoded(), as: UTF8.self)
        #expect(!plain.contains("colorVision"))
        preferences.colorVision = .redCyan
        let data = preferences.encoded()
        #expect(String(decoding: data, as: UTF8.self).contains(#""colorVision":"redCyan""#))
        #expect(String(decoding: data, as: UTF8.self).contains(#""schema":1"#))
        let back = ShellPreferences.decode(data)
        #expect(back.note == nil)
        #expect(back.preferences.colorVision == .redCyan)
        #expect(back.preferences == preferences)
    }

    @Test func anUnknownValueReadsAsStandard() throws {
        let stored = #"{"schema":1,"colorVision":"ultraviolet"}"#
        let back = ShellPreferences.decode(Data(stored.utf8))
        #expect(back.note == nil)
        #expect(back.preferences.colorVision == .standard)
    }
}
