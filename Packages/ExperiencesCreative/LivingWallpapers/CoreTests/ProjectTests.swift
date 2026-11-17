// ProjectTests — feature 138 (A19-P01) T-A19-105 (FR-A19-102; SC-A19-101, SC-A19-104; clarification Q4). The default
// project; the encoded file decodes to an equal project and re-encodes to the same bytes; each of the seven refusals
// (damaged, newer-version, unknown-scene, unknown-preset, unknown-template, invalid-parameter, too-large) comes from
// one sample, has its code and sentence, and leaves the default when the caller falls back.
// Feature 140 (A19-P03) T-A19-302 (FR-A19-301; clarification Q1): schema 2 writes `customColors`; a schema-1 sample
// decodes with nil, four custom colours round-trip exactly, three or five are refused, and schema 3 is newer.
import Foundation
import Testing
@testable import LivingWallpapersCore

@Suite struct ProjectTests {
    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<WallpaperProject, ProjectRefusal>) -> ProjectRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// What a caller loads: the decoded project, or the default when the file is refused.
    private static func loaded(_ data: Data) -> WallpaperProject {
        (try? WallpaperProject.decode(data).get()) ?? .default
    }

    /// The encoded file of the default project changed by `change`.
    private static func file(_ change: (inout WallpaperProject) -> Void) throws -> Data {
        var project = WallpaperProject.default
        change(&project)
        return try project.encoded()
    }

    @Test func theDefaultIsDocumented() {
        let project = WallpaperProject.default
        #expect(project.scene == "aurora-bands")
        #expect(project.preset == 0)
        #expect(project.seed == 1)
        #expect(project.template == "iphone-16-pro")
        #expect(project.orientation == .portrait)
        #expect(project.animationTime == 0)
        #expect(project.format == .png)
        #expect(project.parameters == SceneCatalog.scene(id: "aurora-bands")?.defaultParameters)
        #expect(project.validation() == nil)
        #expect(WallpaperProject.kind == "a19.wallpaper-project")
        #expect(WallpaperProject.schemaVersion == 2)
        #expect(project.customColors == nil)
        #expect(WallpaperProject.maxBytes == 16_384)
    }

    @Test func theRoundTripIsExact() throws {
        var samples = [WallpaperProject.default]
        for scene in SceneCatalog.scenes {
            var parameters: [String: Double] = [:]
            for parameter in scene.parameters { parameters[parameter.id] = parameter.maximum }
            samples.append(WallpaperProject(scene: scene.id, preset: 2, seed: UInt64.max, parameters: parameters,
                                            template: "ipad-pro-13-m4", orientation: .landscape,
                                            animationTime: 1234.5678, format: .png))
        }
        for sample in samples {
            let data = try sample.encoded()
            let back = try WallpaperProject.decode(data).get()
            #expect(back == sample)
            #expect(try back.encoded() == data)
        }
    }

    @Test func theFileIsTheDocumentedEnvelope() throws {
        let text = String(decoding: try WallpaperProject.default.encoded(), as: UTF8.self)
        #expect(text.hasPrefix("{\"kind\":\"a19.wallpaper-project\",\"project\":{"))
        #expect(text.hasSuffix("\"schemaVersion\":2}"))
        #expect(!text.contains("customColors"))
        #expect(text.contains("\"template\":\"iphone-16-pro\""))
        #expect(text.contains("\"format\":\"png\""))
    }

    @Test func aDamagedFileIsRefused() {
        let data = Data("not a project".utf8)
        #expect(Self.refusal(WallpaperProject.decode(data)) == .damaged)
        #expect(ProjectRefusal.damaged.code == "damaged")
        #expect(Self.loaded(data) == .default)
        let wrongKind = Data(#"{"kind":"a18.clock-preferences","schemaVersion":1,"project":{}}"#.utf8)
        #expect(Self.refusal(WallpaperProject.decode(wrongKind)) == .damaged)
    }

    @Test func aNewerVersionIsRefused() {
        let data = Data(#"{"kind":"a19.wallpaper-project","schemaVersion":3,"project":{}}"#.utf8)
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .newerVersion(3))
        #expect(refusal?.code == "newer-version")
        #expect(refusal?.sentence.contains("3") == true)
        #expect(Self.loaded(data) == .default)
    }

    @Test func anUnknownSceneIsRefused() throws {
        let data = try Self.file { $0.scene = "nebula" }
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .unknownScene("nebula"))
        #expect(refusal?.code == "unknown-scene")
        #expect(refusal?.sentence.contains("nebula") == true)
        #expect(Self.loaded(data) == .default)
    }

    @Test func anUnknownPresetIsRefused() throws {
        let data = try Self.file { $0.preset = 3 }
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .unknownPreset(3))
        #expect(refusal?.code == "unknown-preset")
        #expect(Self.refusal(WallpaperProject.decode(try Self.file { $0.preset = -1 })) == .unknownPreset(-1))
        #expect(Self.loaded(data) == .default)
    }

    @Test func anUnknownTemplateIsRefused() throws {
        let data = try Self.file { $0.template = "iphone-99" }
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .unknownTemplate("iphone-99"))
        #expect(refusal?.code == "unknown-template")
        #expect(refusal?.sentence.contains("iphone-99") == true)
        #expect(Self.loaded(data) == .default)
    }

    @Test func anInvalidParameterIsRefused() throws {
        let outOfRange = try Self.file { $0.parameters["bandCount"] = 99 }
        let refusal = Self.refusal(WallpaperProject.decode(outOfRange))
        #expect(refusal == .invalidParameter("bandCount"))
        #expect(refusal?.code == "invalid-parameter")
        #expect(refusal?.sentence.contains("bandCount") == true)
        #expect(Self.loaded(outOfRange) == .default)
        let unknownId = try Self.file { $0.parameters["warp"] = 1 }
        #expect(Self.refusal(WallpaperProject.decode(unknownId)) == .invalidParameter("warp"))
        let lateTime = try Self.file { $0.animationTime = 3600.5 }
        #expect(Self.refusal(WallpaperProject.decode(lateTime)) == .invalidParameter("animationTime"))
        let earlyTime = try Self.file { $0.animationTime = -1 }
        #expect(Self.refusal(WallpaperProject.decode(earlyTime)) == .invalidParameter("animationTime"))
        var nonFinite = WallpaperProject.default
        nonFinite.animationTime = .infinity
        #expect(nonFinite.validation() == .invalidParameter("animationTime"))
    }

    @Test func aTooLargeFileIsRefused() {
        let data = Data(repeating: 0x20, count: WallpaperProject.maxBytes + 1)
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .tooLarge(16_385))
        #expect(refusal?.code == "too-large")
        #expect(refusal?.sentence.contains("16385") == true)
        #expect(Self.loaded(data) == .default)
    }

    @Test func absentParametersResolveToTheirDefaults() {
        var project = WallpaperProject.default
        project.parameters = ["drift": 0.9]
        #expect(project.validation() == nil)
        #expect(project.resolvedParameters == ["bandCount": 4, "drift": 0.9, "softness": 0.6])
    }

    /// Four distinct opaque colours with components that are not multiples of 1/255.
    private static let fourColors = [RGBColor(r: 0.1, g: 0.2, b: 0.3), RGBColor(r: 0.4, g: 0.5, b: 0.6),
                                     RGBColor(r: 0.7, g: 0.8, b: 0.9), RGBColor(r: 1, g: 0, b: 0.123456789)]

    @Test func aSchemaOneFileDecodesWithoutCustomColours() throws {
        let text = """
            {"kind":"a19.wallpaper-project","project":{"animationTime":12.5,"format":"jpeg","orientation":"landscape",\
            "parameters":{"drift":0.9},"preset":1,"scene":"aurora-bands","seed":7,"template":"iphone-16"},\
            "schemaVersion":1}
            """
        let project = try WallpaperProject.decode(Data(text.utf8)).get()
        #expect(project.customColors == nil)
        #expect(project.preset == 1 && project.seed == 7 && project.template == "iphone-16")
        #expect(project.orientation == .landscape && project.format == .jpeg && project.animationTime == 12.5)
        let withColours = """
            {"kind":"a19.wallpaper-project","project":{"animationTime":0,"customColors":[{"b":0,"g":0,"r":0}],\
            "format":"png","orientation":"portrait","parameters":{},"preset":0,"scene":"aurora-bands","seed":1,\
            "template":"iphone-16-pro"},"schemaVersion":1}
            """
        #expect(try WallpaperProject.decode(Data(withColours.utf8)).get().customColors == nil)
        let rewritten = String(decoding: try project.encoded(), as: UTF8.self)
        #expect(rewritten.hasSuffix("\"schemaVersion\":2}"))
    }

    @Test func customColoursRoundTripExactly() throws {
        var project = WallpaperProject.default
        project.customColors = Self.fourColors
        #expect(project.validation() == nil)
        let data = try project.encoded()
        #expect(String(decoding: data, as: UTF8.self).contains("\"customColors\":["))
        let back = try WallpaperProject.decode(data).get()
        #expect(back == project)
        #expect(back.customColors == Self.fourColors)
        #expect(try back.encoded() == data)
    }

    @Test func aWrongCustomColourCountIsRefused() throws {
        for count in [0, 3, 5] {
            let colors = (0..<count).map { Self.fourColors[$0 % 4] }
            let data = try Self.file { $0.customColors = colors }
            let refusal = Self.refusal(WallpaperProject.decode(data))
            #expect(refusal == .invalidParameter("customColors"), "count \(count)")
            #expect(refusal?.code == "invalid-parameter")
            #expect(Self.loaded(data) == .default)
        }
    }

    @Test func anOutOfRangeCustomColourIsRefused() throws {
        let text = String(decoding: try Self.file { $0.customColors = Self.fourColors }, as: UTF8.self)
        let outOfRange = text.replacingOccurrences(of: "\"r\":1}", with: "\"r\":1.5}")
        #expect(outOfRange != text)
        #expect(Self.refusal(WallpaperProject.decode(Data(outOfRange.utf8))) == .invalidParameter("customColors"))
    }
}
