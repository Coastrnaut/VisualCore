// PreferencesTests — feature 131 (A18-P01) T-A18-106 (FR-A18-103; SC-A18-101; clarification Q4). The defaults; the
// encoded file decodes to equal preferences and re-encodes to the same bytes; each refusal (damaged, newer-version,
// unknown-time-zone, unknown-locale, too-large) has its code and a sentence naming the value; fixed zone and locale
// policies survive the round trip and win over the system values in the environment.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct PreferencesTests {
    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<ClockPreferences, PreferencesRefusal>) -> PreferencesRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// The preferences of `result`, or nil when it was refused.
    private static func decoded(_ result: Result<ClockPreferences, PreferencesRefusal>) -> ClockPreferences? {
        if case let .success(preferences) = result { return preferences }
        return nil
    }

    /// The JSON bytes of a string.
    private static func bytes(_ text: String) -> Data { Data(text.utf8) }

    @Test func theDefaultsAreDocumented() {
        let defaults = ClockPreferences()
        #expect(defaults.hourCycle == .system)
        #expect(defaults.showSeconds == false)
        #expect(defaults.showDate == true)
        #expect(defaults.timeZone == .system)
        #expect(defaults.locale == .system)
        #expect(ClockPreferences.kind == "a18.clock-preferences")
        #expect(ClockPreferences.schemaVersion == 1)
        #expect(ClockPreferences.maxBytes == 4096)
    }

    @Test func theRoundTripIsExact() throws {
        let samples = [
            ClockPreferences(),
            ClockPreferences(hourCycle: .h12, showSeconds: true, showDate: false),
            ClockPreferences(hourCycle: .h24, showSeconds: false, showDate: true, timeZone: .fixed("Asia/Kolkata"),
                             locale: .fixed("de_DE")),
            ClockPreferences(hourCycle: .system, timeZone: .fixed("America/New_York"), locale: .fixed("ar_EG")),
        ]
        for sample in samples {
            let data = try sample.encoded()
            let back = Self.decoded(ClockPreferences.decode(data))
            #expect(back == sample)
            let again = try back?.encoded()
            #expect(again == data)
        }
    }

    @Test func theFileIsTheDocumentedEnvelope() throws {
        let data = try ClockPreferences(timeZone: .fixed("Asia/Kolkata"), locale: .fixed("ja_JP")).encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"kind\":\"a18.clock-preferences\""))
        #expect(text.contains("\"schemaVersion\":1"))
        #expect(text.contains("\"timeZone\":\"Asia/Kolkata\""))
        #expect(text.contains("\"locale\":\"ja_JP\""))
        let system = String(decoding: try ClockPreferences().encoded(), as: UTF8.self)
        #expect(system.contains("\"timeZone\":\"system\""))
        #expect(system.contains("\"locale\":\"system\""))
    }

    @Test func fixedPoliciesSurviveTheRoundTrip() throws {
        let fixed = ClockPreferences(timeZone: .fixed("Asia/Kolkata"), locale: .fixed("ja_JP"))
        let back = Self.decoded(ClockPreferences.decode(try fixed.encoded()))
        #expect(back?.timeZone == .fixed("Asia/Kolkata"))
        #expect(back?.locale == .fixed("ja_JP"))
    }

    @Test func badJSONIsDamaged() {
        let refusal = Self.refusal(ClockPreferences.decode(Self.bytes("not json {")))
        #expect(refusal == .damaged)
        #expect(refusal?.code == "damaged")
        #expect(refusal?.sentence.contains("damaged") == true)
    }

    @Test func aWrongKindIsDamaged() {
        let json = "{\"kind\":\"a17.anatomy-preferences\",\"schemaVersion\":1,\"preferences\":{\"hourCycle\":\"h24\","
            + "\"showSeconds\":false,\"showDate\":true,\"timeZone\":\"system\",\"locale\":\"system\"}}"
        #expect(Self.refusal(ClockPreferences.decode(Self.bytes(json))) == .damaged)
    }

    @Test func aMissingBodyOrVersionZeroIsDamaged() {
        let noBody = "{\"kind\":\"a18.clock-preferences\",\"schemaVersion\":1}"
        let zero = "{\"kind\":\"a18.clock-preferences\",\"schemaVersion\":0,\"preferences\":{\"hourCycle\":\"h24\","
            + "\"showSeconds\":false,\"showDate\":true,\"timeZone\":\"system\",\"locale\":\"system\"}}"
        let badCycle = "{\"kind\":\"a18.clock-preferences\",\"schemaVersion\":1,\"preferences\":{\"hourCycle\":\"h25\","
            + "\"showSeconds\":false,\"showDate\":true,\"timeZone\":\"system\",\"locale\":\"system\"}}"
        for json in [noBody, zero, badCycle] {
            #expect(Self.refusal(ClockPreferences.decode(Self.bytes(json))) == .damaged, "\(json)")
        }
    }

    @Test func aNewerVersionIsRefusedNamingIt() {
        let json = "{\"kind\":\"a18.clock-preferences\",\"schemaVersion\":2,\"preferences\":{\"future\":true}}"
        let refusal = Self.refusal(ClockPreferences.decode(Self.bytes(json)))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
        #expect(refusal?.sentence.contains("version 2") == true)
    }

    @Test func anUnknownTimeZoneIsRefusedNamingIt() throws {
        #expect(TimeZone(identifier: "Mars/Olympus") == nil)
        let data = try ClockPreferences(timeZone: .fixed("Mars/Olympus")).encoded()
        let refusal = Self.refusal(ClockPreferences.decode(data))
        #expect(refusal == .unknownTimeZone("Mars/Olympus"))
        #expect(refusal?.code == "unknown-time-zone")
        #expect(refusal?.sentence.contains("Mars/Olympus") == true)
    }

    @Test func anUnknownLocaleIsRefusedNamingIt() throws {
        #expect(!Locale.availableIdentifiers.contains("xx_INVALID"))
        let data = try ClockPreferences(locale: .fixed("xx_INVALID")).encoded()
        let refusal = Self.refusal(ClockPreferences.decode(data))
        #expect(refusal == .unknownLocale("xx_INVALID"))
        #expect(refusal?.code == "unknown-locale")
        #expect(refusal?.sentence.contains("xx_INVALID") == true)
    }

    @Test func aFileAboveTheLimitIsRefusedNamingItsSize() {
        let refusal = Self.refusal(ClockPreferences.decode(Data(repeating: 0x20, count: 4097)))
        #expect(refusal == .tooLarge(4097))
        #expect(refusal?.code == "too-large")
        #expect(refusal?.sentence.contains("4097") == true)
        #expect(refusal?.sentence.contains("4096") == true)
    }

    @Test func aFileAtTheLimitIsRead() throws {
        var data = try ClockPreferences(hourCycle: .h24).encoded()
        data.append(Data(repeating: 0x20, count: ClockPreferences.maxBytes - data.count))
        #expect(data.count == ClockPreferences.maxBytes)
        #expect(Self.decoded(ClockPreferences.decode(data)) == ClockPreferences(hourCycle: .h24))
    }

    @Test func everyRefusalHasADistinctCodeAndOneSentence() {
        let refusals: [PreferencesRefusal] = [.damaged, .newerVersion(3), .unknownTimeZone("Mars/Olympus"),
                                              .unknownLocale("xx_INVALID"), .tooLarge(5000)]
        let codes = refusals.map(\.code)
        #expect(codes == ["damaged", "newer-version", "unknown-time-zone", "unknown-locale", "too-large"])
        for refusal in refusals {
            #expect(refusal.sentence.hasSuffix("."), "\(refusal.code)")
            #expect(!refusal.sentence.contains("\n"), "\(refusal.code)")
        }
    }

    @Test func fixedPoliciesWinOverTheSystem() {
        let fixed = ClockPreferences(timeZone: .fixed("Asia/Kolkata"), locale: .fixed("de_DE"))
        let environment = ClockEnvironment(preferences: fixed, systemLocale: Locale(identifier: "en_US"),
                                           systemTimeZone: ClockFixtures.newYork)
        #expect(environment.locale.identifier == "de_DE")
        #expect(environment.timeZone.identifier == "Asia/Kolkata")
        #expect(environment.calendar.identifier == .gregorian)
        #expect(environment.calendar.timeZone.identifier == "Asia/Kolkata")
        #expect(environment.calendar.locale?.identifier == "de_DE")
    }

    @Test func systemPoliciesUseTheSystemValues() {
        let environment = ClockEnvironment(preferences: ClockPreferences(), systemLocale: Locale(identifier: "ja_JP"),
                                           systemTimeZone: ClockFixtures.kolkata)
        #expect(environment.locale.identifier == "ja_JP")
        #expect(environment.timeZone.identifier == "Asia/Kolkata")
        #expect(environment.calendar.identifier == .gregorian)
    }

    @Test func anUnknownFixedZoneFallsBackToTheSystemZone() {
        let environment = ClockEnvironment(preferences: ClockPreferences(timeZone: .fixed("Mars/Olympus")),
                                           systemLocale: Locale(identifier: "en_US"),
                                           systemTimeZone: ClockFixtures.newYork)
        #expect(environment.timeZone.identifier == "America/New_York")
    }
}
