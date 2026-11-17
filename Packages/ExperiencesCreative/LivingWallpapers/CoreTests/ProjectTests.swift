// ProjectTests — feature 138 (A19-P01) T-A19-105 (FR-A19-102; SC-A19-101, SC-A19-104; clarification Q4). The default
// project; the encoded file decodes to an equal project and re-encodes to the same bytes; each of the seven refusals
// (damaged, newer-version, unknown-scene, unknown-preset, unknown-template, invalid-parameter, too-large) comes from
// one sample, has its code and sentence, and leaves the default when the caller falls back.
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
        #expect(WallpaperProject.schemaVersion == 1)
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
        #expect(text.hasSuffix("\"schemaVersion\":1}"))
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
        let data = Data(#"{"kind":"a19.wallpaper-project","schemaVersion":2,"project":{}}"#.utf8)
        let refusal = Self.refusal(WallpaperProject.decode(data))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
        #expect(refusal?.sentence.contains("2") == true)
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
}
