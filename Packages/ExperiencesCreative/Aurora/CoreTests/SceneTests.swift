// SceneTests — feature 152 (A21-P01) T-A21-104 (FR-A21-101, FR-A21-102; SC-A21-101; clarification Q1). The scene's
// constants; a scene round-trips exactly and encodes deterministically within 4,096 bytes; one hand-built sample per
// refusal code (damaged, newer-version, too-large, not-finite, out-of-range, unknown-preset, palette-size) gives that
// code and a sentence; every setter clamps each bound and ignores NaN and infinity. Synthetic data only.
import Foundation
import Testing
@testable import AuroraCore

@Suite struct SceneTests {
    /// A valid scene to change.
    private static var sample: SkyScene { SkyPresets.violetVeil.scene }

    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<SkyScene, SceneRefusal>) -> SceneRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// The JSON object of the sample's body.
    private static func body() throws -> [String: Any] {
        let data = try JSONEncoder().encode(sample)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A hand-built file: the envelope `{kind, version, body}`.
    private static func file(_ body: Any, kind: String = SkyScene.kind, version: Int = 1) throws -> Data {
        var envelope: [String: Any] = [:]
        envelope["kind"] = kind
        envelope["version"] = version
        envelope["body"] = body
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    /// The sample's body with `key` set to `value`, as a file.
    private static func file(setting key: String, to value: Any) throws -> Data {
        var object = try body()
        object[key] = value
        return try file(object)
    }

    /// The sample after `change`.
    private static func changed(_ change: (inout SkyScene) -> Void) -> SkyScene {
        var scene = sample
        change(&scene)
        return scene
    }

    @Test func theConstantsAreDocumented() {
        #expect(SkyScene.kind == "a21.sky-scene")
        #expect(SkyScene.schemaVersion == 1)
        #expect(SkyScene.maxBytes == 4_096)
        #expect(SkyScene.paletteCountRange == 2...4)
        #expect(SkyScene.ribbonsRange == 1...4)
        #expect(SkyScene.turbulenceRange == 0...1)
        #expect(SkyScene.cloudinessRange == 0...1)
        #expect(SkyScene.starsRange == 0...400)
        #expect(SkyScene.speedRange == 0...2)
    }

    @Test func aChangedSceneRoundTripsExactlyAndDeterministically() throws {
        let scene = Self.changed { scene in
            scene.setPreset("dawn-haze")
            scene.setPalette([SkyColor(red: 0, green: 0.125, blue: 1), SkyColor(red: 0.3, green: 0.7, blue: 0.1)])
            scene.setRibbons(4)
            scene.setTurbulence(0.123_456_789)
            scene.setCloudiness(1)
            scene.setStars(0)
            scene.setSpeed(2)
        }
        let data = scene.encoded()
        #expect(data == scene.encoded())
        #expect(data.count <= SkyScene.maxBytes)
        let decoded = try SkyScene.decode(data).get()
        #expect(decoded == scene)
        #expect(decoded.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"body\":"))
        #expect(text.contains("\"kind\":\"a21.sky-scene\""))
        #expect(text.contains("\"version\":1"))
    }

    @Test func aDamagedFileIsRefused() throws {
        #expect(Self.refusal(SkyScene.decode(Data("not json".utf8))) == .damaged)
        #expect(Self.refusal(SkyScene.decode(Data())) == .damaged)
        #expect(Self.refusal(SkyScene.decode(try Self.file(try Self.body(), kind: "a20.garden"))) == .damaged)
        #expect(Self.refusal(SkyScene.decode(try Self.file(try Self.body(), version: 0))) == .damaged)
        var missing = try Self.body()
        missing["stars"] = nil
        #expect(Self.refusal(SkyScene.decode(try Self.file(missing))) == .damaged)
        #expect(Self.refusal(SkyScene.decode(try Self.file(setting: "stars", to: "many"))) == .damaged)
        #expect(Self.refusal(SkyScene.decode(try Self.file(setting: "ribbons", to: 2.5))) == .damaged)
        let refusal = SceneRefusal.damaged
        #expect(refusal.code == "damaged")
        #expect(!refusal.sentence.isEmpty)
    }

    @Test func aNewerVersionIsRefused() throws {
        let result = SkyScene.decode(try Self.file(try Self.body(), version: 2))
        #expect(Self.refusal(result) == .newerVersion(2))
        #expect(SceneRefusal.newerVersion(2).code == "newer-version")
        #expect(SceneRefusal.newerVersion(2).sentence.contains("2"))
    }

    @Test func aTooLargeFileIsRefused() throws {
        var padded = Self.sample.encoded()
        padded.append(Data(repeating: 0x20, count: SkyScene.maxBytes + 1 - padded.count))
        #expect(padded.count == SkyScene.maxBytes + 1)
        #expect(Self.refusal(SkyScene.decode(padded)) == .tooLarge(SkyScene.maxBytes + 1))
        #expect(SceneRefusal.tooLarge(5_000).code == "too-large")
        #expect(SceneRefusal.tooLarge(5_000).sentence.contains("5000"))
    }

    @Test func aNonFiniteValueIsRefused() throws {
        for field in ["turbulence", "cloudiness", "speed"] {
            for text in ["NaN", "Infinity", "-Infinity"] {
                let result = SkyScene.decode(try Self.file(setting: field, to: text))
                #expect(Self.refusal(result) == .notFinite(field))
            }
        }
        let palette: [[String: Any]] = [["red": 0.1, "green": 0.1, "blue": 0.1],
                                         ["red": "NaN", "green": 0.5, "blue": 0.5]]
        #expect(Self.refusal(SkyScene.decode(try Self.file(setting: "palette", to: palette))) == .notFinite("palette"))
        let unchecked = SkyScene(preset: "polar-night", palette: Self.sample.palette, ribbons: 2,
                                 turbulence: .nan, cloudiness: 0, stars: 0, speed: 0)
        #expect(Self.refusal(SkyScene.decode(unchecked.encoded())) == .notFinite("turbulence"))
        #expect(SceneRefusal.notFinite("speed").code == "not-finite")
        #expect(SceneRefusal.notFinite("speed").sentence.contains("speed"))
    }

    @Test func anOutOfRangeValueIsRefused() throws {
        let samples: [(String, Any)] = [("ribbons", 0), ("ribbons", 5), ("turbulence", -0.01), ("turbulence", 1.01),
                                        ("cloudiness", -1), ("cloudiness", 2), ("stars", -1), ("stars", 401),
                                        ("speed", -0.5), ("speed", 2.5)]
        for (field, value) in samples {
            let result = SkyScene.decode(try Self.file(setting: field, to: value))
            #expect(Self.refusal(result) == .outOfRange(field))
        }
        let palette: [[String: Any]] = [["red": 0.1, "green": 0.1, "blue": 0.1],
                                         ["red": 1.5, "green": 0.5, "blue": 0.5]]
        let result = SkyScene.decode(try Self.file(setting: "palette", to: palette))
        #expect(Self.refusal(result) == .outOfRange("palette"))
        #expect(SceneRefusal.outOfRange("stars").code == "out-of-range")
        #expect(SceneRefusal.outOfRange("stars").sentence.contains("stars"))
    }

    @Test func anUnknownPresetIsRefused() throws {
        let result = SkyScene.decode(try Self.file(setting: "preset", to: "midnight-sun"))
        #expect(Self.refusal(result) == .unknownPreset("midnight-sun"))
        #expect(SceneRefusal.unknownPreset("x").code == "unknown-preset")
        #expect(SceneRefusal.unknownPreset("midnight-sun").sentence.contains("midnight-sun"))
    }

    @Test func aPaletteOfTheWrongSizeIsRefused() throws {
        let colour: [String: Any] = ["red": 0.2, "green": 0.3, "blue": 0.4]
        for count in [0, 1, 5] {
            let result = SkyScene.decode(try Self.file(setting: "palette", to: Array(repeating: colour, count: count)))
            #expect(Self.refusal(result) == .paletteSize(count))
        }
        #expect(SceneRefusal.paletteSize(5).code == "palette-size")
        #expect(SceneRefusal.paletteSize(5).sentence.contains("5"))
    }

    @Test func aRefusedFileLeavesTheOpenSceneUnchanged() throws {
        let open = Self.sample
        var scene = open
        if case let .success(decoded) = SkyScene.decode(try Self.file(setting: "stars", to: 999)) { scene = decoded }
        #expect(scene == open)
    }

    @Test func theIntegerSettersClampEachBound() {
        let scene1 = Self.changed { $0.setRibbons(0) }
        #expect(scene1.ribbons == 1)
        let scene2 = Self.changed { $0.setRibbons(-7) }
        #expect(scene2.ribbons == 1)
        let scene3 = Self.changed { $0.setRibbons(9) }
        #expect(scene3.ribbons == 4)
        let scene4 = Self.changed { $0.setRibbons(3) }
        #expect(scene4.ribbons == 3)
        let scene5 = Self.changed { $0.setStars(-1) }
        #expect(scene5.stars == 0)
        let scene6 = Self.changed { $0.setStars(10_000) }
        #expect(scene6.stars == 400)
        let scene7 = Self.changed { $0.setStars(123) }
        #expect(scene7.stars == 123)
    }

    @Test func theFloatingSettersClampEachBound() {
        let scene8 = Self.changed { $0.setTurbulence(-0.5) }
        #expect(scene8.turbulence == 0)
        let scene9 = Self.changed { $0.setTurbulence(1.5) }
        #expect(scene9.turbulence == 1)
        let scene10 = Self.changed { $0.setTurbulence(0.25) }
        #expect(scene10.turbulence == 0.25)
        let scene11 = Self.changed { $0.setCloudiness(-2) }
        #expect(scene11.cloudiness == 0)
        let scene12 = Self.changed { $0.setCloudiness(3) }
        #expect(scene12.cloudiness == 1)
        let scene13 = Self.changed { $0.setCloudiness(0.75) }
        #expect(scene13.cloudiness == 0.75)
        let scene14 = Self.changed { $0.setSpeed(-1) }
        #expect(scene14.speed == 0)
        let scene15 = Self.changed { $0.setSpeed(9) }
        #expect(scene15.speed == 2)
        let scene16 = Self.changed { $0.setSpeed(1.5) }
        #expect(scene16.speed == 1.5)
    }

    @Test func nonFiniteSetterValuesAreIgnored() {
        let original = Self.sample
        for value in [Double.nan, .infinity, -.infinity] {
            let scene17 = Self.changed { $0.setTurbulence(value) }
            #expect(scene17 == original)
            let scene18 = Self.changed { $0.setCloudiness(value) }
            #expect(scene18 == original)
            let scene19 = Self.changed { $0.setSpeed(value) }
            #expect(scene19 == original)
            let palette = [SkyColor(red: value, green: 0, blue: 0), SkyColor(red: 0, green: 0, blue: 0)]
            let scene20 = Self.changed { $0.setPalette(palette) }
            #expect(scene20 == original)
        }
    }

    @Test func thePaletteSetterClampsComponentsAndIgnoresWrongSizes() {
        let original = Self.sample
        let one = [SkyColor(red: 0.5, green: 0.5, blue: 0.5)]
        let five = Array(repeating: SkyColor(red: 0.5, green: 0.5, blue: 0.5), count: 5)
        let scene21 = Self.changed { $0.setPalette(one) }
        #expect(scene21 == original)
        let scene22 = Self.changed { $0.setPalette(five) }
        #expect(scene22 == original)
        let wide = [SkyColor(red: -1, green: 0.5, blue: 2), SkyColor(red: 1.5, green: -0.1, blue: 0.3)]
        let clamped = Self.changed { $0.setPalette(wide) }.palette
        #expect(clamped == [SkyColor(red: 0, green: 0.5, blue: 1), SkyColor(red: 1, green: 0, blue: 0.3)])
        let four = Array(repeating: SkyColor(red: 0.1, green: 0.2, blue: 0.3), count: 4)
        let scene23 = Self.changed { $0.setPalette(four) }
        #expect(scene23.palette == four)
    }

    @Test func thePresetSetterIgnoresUnknownIds() {
        let scene24 = Self.changed { $0.setPreset("midnight-sun") }
        #expect(scene24 == Self.sample)
        let scene25 = Self.changed { $0.setPreset("dawn-haze") }
        #expect(scene25.preset == "dawn-haze")
    }

    @Test func aSetSceneAlwaysValidates() {
        let scene = Self.changed { scene in
            scene.setRibbons(99)
            scene.setStars(-5)
            scene.setTurbulence(7)
            scene.setCloudiness(-7)
            scene.setSpeed(.nan)
        }
        #expect(scene.validate() == nil)
    }
}
