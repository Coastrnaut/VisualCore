// PreferencesTests — feature 154 (A21-P03) T-A21-304 (FR-A21-303, FR-A21-304; clarifications Q3, Q4). The
// preferences' constants and defaults match the spec; the defaults and a changed value set round-trip exactly and
// encode deterministically within 4,096 bytes; one hand-built sample per refusal code: damaged bytes (and a wrong
// kind, a missing field, a fractional integer, an oversized value), version 2 (newer-version) and every field out of
// range (out-of-range, including NaN, infinity and an unknown preset). Synthetic data only.
import Foundation
import Testing
@testable import AuroraCore

@Suite struct PreferencesTests {
    /// A changed value set: every field differs from the defaults.
    private static let changed = SkyPreferences(preset: "dawn-haze", hue: -0.25, speed: 1.5, turbulence: 0.8,
                                                ribbons: 4, stars: 17, clouds: 0.9, limit: 0.3, soundOn: true,
                                                volume: 0.75)

    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<SkyPreferences, PreferencesRefusal>) -> PreferencesRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// The decoded preferences of `result`, or nil when it was refused.
    private static func value(_ result: Result<SkyPreferences, PreferencesRefusal>) -> SkyPreferences? {
        if case let .success(value) = result { return value }
        return nil
    }

    /// The JSON object of the defaults' body.
    private static func body() throws -> [String: Any] {
        let data = try JSONEncoder().encode(SkyPreferences.defaults)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A hand-built value: the envelope `{body, kind, version}`.
    private static func file(_ body: Any, kind: String = SkyPreferences.kind, version: Int = 1) throws -> Data {
        var envelope: [String: Any] = [:]
        envelope["body"] = body
        envelope["kind"] = kind
        envelope["version"] = version
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    /// The defaults' body with `key` set to `value`, as a file.
    private static func file(setting key: String, to value: Any) throws -> Data {
        var object = try body()
        object[key] = value
        return try file(object)
    }

    @Test func theConstantsAreDocumented() {
        #expect(SkyPreferences.kind == "a21.preferences")
        #expect(SkyPreferences.schemaVersion == 1)
        #expect(SkyPreferences.storageKey == "prefs.v1")
        #expect(SkyPreferences.maxBytes == 4_096)
        #expect(SkyPreferences.hueRange == -0.5...0.5)
        #expect(SkyPreferences.speedRange == 0...2)
        #expect(SkyPreferences.turbulenceRange == 0...1)
        #expect(SkyPreferences.ribbonsRange == 1...4)
        #expect(SkyPreferences.starsRange == 0...400)
        #expect(SkyPreferences.cloudsRange == 0...1)
        #expect(SkyPreferences.limitRange == 0.2...0.72)
        #expect(SkyPreferences.volumeRange == 0...1)
    }

    @Test func theDefaultsMatchTheSpec() throws {
        let defaults = SkyPreferences.defaults
        let scene = SkyPresets.polarNight.scene
        #expect(defaults.preset == "polar-night")
        #expect(defaults.hue == 0)
        #expect(defaults.speed == scene.speed)
        #expect(defaults.turbulence == scene.turbulence)
        #expect(defaults.ribbons == scene.ribbons)
        #expect(defaults.stars == scene.stars)
        #expect(defaults.clouds == scene.cloudiness)
        #expect(defaults.limit == 0.6)
        #expect(defaults.soundOn == false)
        #expect(defaults.volume == 0.5)
        #expect(defaults.validate() == nil)
        #expect(defaults.scene == scene)
    }

    @Test func theDefaultsRoundTripExactly() {
        let data = SkyPreferences.defaults.encoded()
        #expect(Self.value(SkyPreferences.decode(data)) == SkyPreferences.defaults)
        #expect(data == SkyPreferences.defaults.encoded())
        #expect(data.count <= SkyPreferences.maxBytes)
    }

    @Test func aChangedValueSetRoundTripsExactlyAndDeterministically() throws {
        let data = Self.changed.encoded()
        let decoded = try #require(Self.value(SkyPreferences.decode(data)))
        #expect(decoded == Self.changed)
        #expect(decoded.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"body\":{"))
        #expect(text.contains("\"kind\":\"a21.preferences\""))
        #expect(text.hasSuffix("\"version\":1}"))
        let scene = try #require(decoded.scene)
        #expect(scene.preset == "dawn-haze")
        #expect(scene.ribbons == 4)
        #expect(scene.stars == 17)
    }

    @Test func theEncodingStaysWithinTheBoundAtTheLargestValues() {
        let wide = SkyPreferences(preset: "violet-veil", hue: -0.4999999999999999, speed: 1.9999999999999998,
                                  turbulence: 0.9999999999999999, ribbons: 4, stars: 400,
                                  clouds: 0.9999999999999999, limit: 0.7199999999999999, soundOn: true,
                                  volume: 0.9999999999999999)
        let data = wide.encoded()
        #expect(data.count <= SkyPreferences.maxBytes)
        #expect(data.count < 512)
        #expect(Self.value(SkyPreferences.decode(data)) == wide)
    }

    @Test func damagedBytesAreRefusedAsDamaged() throws {
        var samples: [Data] = []
        samples.append(Data("not json".utf8))
        samples.append(Data())
        samples.append(try Self.file(try Self.body(), kind: "a21.sky-scene"))
        samples.append(try Self.file(try Self.body(), version: 0))
        samples.append(try Self.file([String: Any]()))
        samples.append(try Self.file(setting: "ribbons", to: 2.5))
        samples.append(try Self.file(setting: "stars", to: 10.5))
        samples.append(try Self.file(setting: "soundOn", to: "yes"))
        var missing = try Self.body()
        missing["volume"] = nil
        samples.append(try Self.file(missing))
        var padded = try Self.body()
        padded["padding"] = String(repeating: "x", count: SkyPreferences.maxBytes)
        samples.append(try Self.file(padded))
        for sample in samples {
            let refusal = Self.refusal(SkyPreferences.decode(sample))
            #expect(refusal == .damaged)
            #expect(refusal?.code == "damaged")
        }
    }

    @Test func versionTwoIsRefusedAsNewer() throws {
        let refusal = Self.refusal(SkyPreferences.decode(try Self.file(try Self.body(), version: 2)))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
    }

    @Test func eachFieldOutOfRangeIsRefusedAsOutOfRange() throws {
        var cases: [(String, Any)] = []
        cases.append(("preset", "northern-lights"))
        cases.append(("hue", -0.51))
        cases.append(("hue", 0.51))
        cases.append(("speed", -0.01))
        cases.append(("speed", 2.01))
        cases.append(("turbulence", -0.01))
        cases.append(("turbulence", 1.01))
        cases.append(("ribbons", 0))
        cases.append(("ribbons", 5))
        cases.append(("stars", -1))
        cases.append(("stars", 401))
        cases.append(("clouds", -0.01))
        cases.append(("clouds", 1.01))
        cases.append(("limit", 0.19))
        cases.append(("limit", 0.73))
        cases.append(("volume", -0.01))
        cases.append(("volume", 1.01))
        cases.append(("hue", "NaN"))
        cases.append(("limit", "Infinity"))
        cases.append(("volume", "-Infinity"))
        for (field, value) in cases {
            let refusal = Self.refusal(SkyPreferences.decode(try Self.file(setting: field, to: value)))
            #expect(refusal == .outOfRange(field), "field \(field) value \(value)")
            #expect(refusal?.code == "out-of-range")
        }
    }

    @Test func aNonFiniteValueFromTheInitializerIsWrittenAndRefused() {
        var bad = SkyPreferences.defaults
        bad.speed = .nan
        let refusal = Self.refusal(SkyPreferences.decode(bad.encoded()))
        #expect(refusal == .outOfRange("speed"))
    }

    @Test func theRangeEndsAreAccepted() {
        let low = SkyPreferences(preset: "polar-night", hue: -0.5, speed: 0, turbulence: 0, ribbons: 1, stars: 0,
                                 clouds: 0, limit: 0.2, soundOn: false, volume: 0)
        let high = SkyPreferences(preset: "violet-veil", hue: 0.5, speed: 2, turbulence: 1, ribbons: 4, stars: 400,
                                  clouds: 1, limit: 0.72, soundOn: true, volume: 1)
        #expect(low.validate() == nil)
        #expect(high.validate() == nil)
        #expect(Self.value(SkyPreferences.decode(low.encoded())) == low)
        #expect(Self.value(SkyPreferences.decode(high.encoded())) == high)
    }
}
