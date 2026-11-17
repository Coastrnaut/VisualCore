// ThemePresetTests — feature 133 (A18-P03) T-A18-303 (FR-A18-302, FR-A18-304; clarification Q3). The default preset;
// the encoded file decodes to an equal preset and re-encodes to the same bytes; each refusal (damaged, newer-version,
// too-large, out-of-range for theme, palette and speed) has its code and a sentence naming the value; the checking
// initializer refuses what the decoder refuses.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct ThemePresetTests {
    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<ThemePreset, ThemePresetRefusal>) -> ThemePresetRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// The preset of `result`, or nil when it was refused.
    private static func decoded(_ result: Result<ThemePreset, ThemePresetRefusal>) -> ThemePreset? {
        if case let .success(preset) = result { return preset }
        return nil
    }

    /// A schema-1 preset file with the given body fields written verbatim.
    private static func file(theme: String = "0", palette: String = "0", speed: String = "1",
                             motion: String = "true", kind: String = ThemePreset.kind, schema: Int = 1) -> Data {
        Data(("{\"kind\":\"\(kind)\",\"preset\":{\"motion\":\(motion),\"palette\":\(palette),\"speed\":\(speed),"
            + "\"theme\":\(theme)},\"schemaVersion\":\(schema)}").utf8)
    }

    @Test func theDefaultsAreDocumented() {
        let standard = ThemePreset.standard
        #expect(standard.theme == 0)
        #expect(standard.palette == 0)
        #expect(standard.speed == 1)
        #expect(standard.motion == true)
        #expect(ThemePreset.kind == "a18.theme-preset")
        #expect(ThemePreset.schemaVersion == 1)
        #expect(ThemePreset.maxBytes == 4096)
        #expect(ThemePreset.themeRange.count == ThemeCatalog.themes.count)
    }

    @Test func theRoundTripIsExact() throws {
        let samples = [
            ThemePreset.standard,
            try ThemePreset(theme: 3, palette: 2, speed: 2, motion: false),
            try ThemePreset(theme: 1, palette: 1, speed: 0.25, motion: true),
            try ThemePreset(theme: 2, palette: 0, speed: 1.375, motion: false),
        ]
        for sample in samples {
            let data = try sample.encoded()
            let back = Self.decoded(ThemePreset.decode(data))
            #expect(back == sample)
            #expect(try back?.encoded() == data)
        }
    }

    @Test func theFileIsTheDocumentedEnvelope() throws {
        let text = String(decoding: try ThemePreset(theme: 2, palette: 1, speed: 0.5, motion: false).encoded(),
                          as: UTF8.self)
        #expect(text == "{\"kind\":\"a18.theme-preset\",\"preset\":{\"motion\":false,\"palette\":1,\"speed\":0.5,"
            + "\"theme\":2},\"schemaVersion\":1}")
        #expect(Self.decoded(ThemePreset.decode(Self.file())) == ThemePreset.standard)
    }

    @Test func badJSONIsDamaged() {
        let refusal = Self.refusal(ThemePreset.decode(Data("not json {".utf8)))
        #expect(refusal == .damaged)
        #expect(refusal?.code == "damaged")
        #expect(refusal?.sentence.contains("damaged") == true)
    }

    @Test func aWrongKindAMissingBodyOrVersionZeroIsDamaged() {
        let noBody = Data("{\"kind\":\"a18.theme-preset\",\"schemaVersion\":1}".utf8)
        let notBool = Self.file(motion: "\"yes\"")
        for data in [Self.file(kind: "a18.clock-preferences"), Self.file(schema: 0), noBody, notBool] {
            #expect(Self.refusal(ThemePreset.decode(data)) == .damaged, "\(String(decoding: data, as: UTF8.self))")
        }
    }

    @Test func aNewerVersionIsRefusedNamingIt() {
        let refusal = Self.refusal(ThemePreset.decode(Self.file(schema: 2)))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
        #expect(refusal?.sentence.contains("version 2") == true)
    }

    @Test func aFileAboveTheLimitIsRefusedNamingItsSize() {
        let refusal = Self.refusal(ThemePreset.decode(Data(repeating: 0x20, count: 4097)))
        #expect(refusal == .tooLarge(4097))
        #expect(refusal?.code == "too-large")
        #expect(refusal?.sentence.contains("4097") == true)
        #expect(refusal?.sentence.contains("4096") == true)
    }

    @Test func aFileAtTheLimitIsRead() throws {
        var data = try ThemePreset.standard.encoded()
        data.append(Data(repeating: 0x20, count: ThemePreset.maxBytes - data.count))
        #expect(Self.decoded(ThemePreset.decode(data)) == ThemePreset.standard)
    }

    @Test func eachOutOfRangeFieldIsRefusedNamingIt() {
        let cases: [(Data, String, String)] = [
            (Self.file(theme: "4"), "theme", "4"),
            (Self.file(theme: "-1"), "theme", "-1"),
            (Self.file(palette: "3"), "palette", "3"),
            (Self.file(palette: "-1"), "palette", "-1"),
            (Self.file(speed: "2.5"), "speed", "2.5"),
            (Self.file(speed: "0.2"), "speed", "0.2"),
        ]
        for (data, field, value) in cases {
            let refusal = Self.refusal(ThemePreset.decode(data))
            #expect(refusal == .outOfRange(field: field, value: value), "\(field) \(value)")
            #expect(refusal?.code == "out-of-range")
            #expect(refusal?.sentence.contains("\(field) \(value)") == true, "\(refusal?.sentence ?? "")")
        }
    }

    @Test func theCheckingInitializerRefusesOutOfRange() {
        #expect(throws: ThemePresetRefusal.outOfRange(field: "theme", value: "4")) {
            _ = try ThemePreset(theme: 4, palette: 0, speed: 1, motion: true)
        }
        #expect(throws: ThemePresetRefusal.outOfRange(field: "palette", value: "3")) {
            _ = try ThemePreset(theme: 0, palette: 3, speed: 1, motion: true)
        }
        #expect(throws: ThemePresetRefusal.outOfRange(field: "speed", value: "nan")) {
            _ = try ThemePreset(theme: 0, palette: 0, speed: .nan, motion: true)
        }
        #expect(ThemePreset.standard.validated() == .success(.standard))
    }

    @Test func everyRefusalHasADistinctCodeAndOneSentence() {
        let refusals: [ThemePresetRefusal] = [.damaged, .newerVersion(3), .tooLarge(5000),
                                              .outOfRange(field: "speed", value: "9.0")]
        #expect(refusals.map(\.code) == ["damaged", "newer-version", "too-large", "out-of-range"])
        for refusal in refusals {
            #expect(refusal.sentence.hasSuffix("."), "\(refusal.code)")
            #expect(!refusal.sentence.contains("\n"), "\(refusal.code)")
        }
        #expect(ThemePresetRefusal.outOfRange(field: "speed", value: "9.0").sentence.contains("0.25–2.0"))
    }
}
