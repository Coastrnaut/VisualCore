// WallpaperProject — feature 138 (A19-P01) T-A19-104 (FR-A19-102; clarification Q4). The project document: scene,
// preset, seed, parameters, template, orientation, animation time and format, stored as a versioned JSON envelope of
// kind `a19.wallpaper-project` with typed refusals. Pure Foundation; A19-P04 stores it.
// Feature 140 (A19-P03) T-A19-302 (FR-A19-301; clarification Q1): schema 2 adds the optional `customColors` (nil or
// exactly four colours, each component in 0…1); a schema-1 file decodes with nil.
import Foundation

/// Why a project file was refused. A refused file leaves ``WallpaperProject/default``.
public enum ProjectRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field or has a schema version below 1.
    case damaged
    /// The file was written by a newer version (schema above ``WallpaperProject/schemaVersion``); the value is that
    /// version.
    case newerVersion(Int)
    /// The scene id is not in ``SceneCatalog``; the value is the id.
    case unknownScene(String)
    /// The preset index is outside the scene's presets; the value is the index.
    case unknownPreset(Int)
    /// The template id is not in ``CanvasTemplates``; the value is the id.
    case unknownTemplate(String)
    /// A parameter has an unknown id, a non-finite value or a value out of range, or the animation time is not
    /// finite and in 0…3600 (id `animationTime`), or the custom colours are not exactly four with every component
    /// finite and in 0…1 (id `customColors`); the value is the id.
    case invalidParameter(String)
    /// The file is larger than ``WallpaperProject/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)

    /// The stable code: `damaged`, `newer-version`, `unknown-scene`, `unknown-preset`, `unknown-template`,
    /// `invalid-parameter` or `too-large`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .unknownScene: return "unknown-scene"
        case .unknownPreset: return "unknown-preset"
        case .unknownTemplate: return "unknown-template"
        case .invalidParameter: return "invalid-parameter"
        case .tooLarge: return "too-large"
        }
    }

    /// One sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The wallpaper project file is damaged and was not read."
        case .newerVersion(let version):
            return "The wallpaper project file has schema version \(version), newer than version "
                + "\(WallpaperProject.schemaVersion) that this version reads."
        case .unknownScene(let id):
            return "The wallpaper project names the unknown scene \"\(id)\"."
        case .unknownPreset(let index):
            return "The wallpaper project names the unknown colour preset \(index)."
        case .unknownTemplate(let id):
            return "The wallpaper project names the unknown canvas template \"\(id)\"."
        case .invalidParameter(let id):
            return "The wallpaper project has an invalid value for \"\(id)\"."
        case .tooLarge(let bytes):
            return "The wallpaper project file is \(bytes) bytes, above the limit of "
                + "\(WallpaperProject.maxBytes) bytes."
        }
    }
}

/// A wallpaper project (schema 2): everything needed to render and export the same image again.
public struct WallpaperProject: Codable, Equatable, Sendable {
    /// The envelope kind of a project file.
    public static let kind = "a19.wallpaper-project"
    /// The schema version this code writes; it reads this version and every earlier one down to 1.
    public static let schemaVersion = 2
    /// The number of custom colours a project holds when it has any.
    public static let customColorCount = 4
    /// The largest project file accepted, in bytes.
    public static let maxBytes = 16_384
    /// The accepted animation time range, in seconds.
    public static let animationTimeRange: ClosedRange<Double> = 0...3600

    /// The scene id (one of ``SceneCatalog/scenes``).
    public var scene: String
    /// The index of the scene's colour preset.
    public var preset: Int
    /// The seed of the scene's procedural variation.
    public var seed: UInt64
    /// Parameter values by parameter id; a parameter of the scene that is absent uses its default.
    public var parameters: [String: Double]
    /// The canvas template id (one of ``CanvasTemplates/all``).
    public var template: String
    /// The canvas orientation.
    public var orientation: Orientation
    /// The moment of the scene's animation that is rendered, in seconds (finite, in 0…3600).
    public var animationTime: Double
    /// The export format.
    public var format: ExportFormat
    /// The four edited colours that replace the preset's colours, or nil for the preset's own (schema 2; a schema-1
    /// file has none).
    public var customColors: [RGBColor]?

    /// Creates a project; `customColors` defaults to nil (the preset's own colours).
    public init(scene: String, preset: Int, seed: UInt64, parameters: [String: Double], template: String,
                orientation: Orientation, animationTime: Double, format: ExportFormat,
                customColors: [RGBColor]? = nil) {
        self.scene = scene
        self.preset = preset
        self.seed = seed
        self.parameters = parameters
        self.template = template
        self.orientation = orientation
        self.animationTime = animationTime
        self.format = format
        self.customColors = customColors
    }

    /// The default project: aurora-bands with its default parameters, preset 0, seed 1, iphone-16-pro, portrait,
    /// time 0, png.
    public static let `default` = WallpaperProject(
        scene: "aurora-bands", preset: 0, seed: 1,
        parameters: SceneCatalog.scene(id: "aurora-bands")?.defaultParameters ?? [:],
        template: "iphone-16-pro", orientation: .portrait, animationTime: 0, format: .png)

    /// Every parameter of the project's scene with its value: the stored one, or the default when absent. Empty when
    /// the scene is unknown.
    public var resolvedParameters: [String: Double] {
        guard let definition = SceneCatalog.scene(id: scene) else { return [:] }
        var values = definition.defaultParameters
        for (id, value) in parameters where values[id] != nil { values[id] = value }
        return values
    }

    private struct Envelope: Codable {
        var kind: String
        var schemaVersion: Int
        var project: WallpaperProject?
    }

    private struct Header: Decodable {
        var kind: String
        var schemaVersion: Int
    }

    /// The project file at schema ``schemaVersion``: the JSON envelope `{"kind", "project", "schemaVersion"}` with
    /// sorted keys and unescaped slashes; `customColors` is written only when it is not nil. Throws when a number is
    /// not finite.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: Self.kind, schemaVersion: Self.schemaVersion, project: self))
    }

    /// Reads a project file. Checks, in order: size (``ProjectRefusal/tooLarge(_:)``), the envelope's kind and
    /// version (``ProjectRefusal/damaged``, ``ProjectRefusal/newerVersion(_:)``), the body
    /// (``ProjectRefusal/damaged``), then the scene, the preset, the template, the parameters, the animation time and
    /// the custom colours. Schemas 1 and 2 are read; a schema-1 file always decodes with `customColors` nil.
    public static func decode(_ data: Data) -> Result<WallpaperProject, ProjectRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.schemaVersion >= 1 else { return .failure(.damaged) }
        guard header.schemaVersion <= schemaVersion else { return .failure(.newerVersion(header.schemaVersion)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              var project = envelope.project else { return .failure(.damaged) }
        if header.schemaVersion < 2 { project.customColors = nil }
        if let refusal = project.validation() { return .failure(refusal) }
        return .success(project)
    }

    /// The first refusal of the project's content (scene, preset, template, parameters, animation time, custom
    /// colours), or nil when it is valid.
    public func validation() -> ProjectRefusal? {
        guard let definition = SceneCatalog.scene(id: scene) else { return .unknownScene(scene) }
        guard definition.presets.indices.contains(preset) else { return .unknownPreset(preset) }
        guard CanvasTemplates.template(id: template) != nil else { return .unknownTemplate(template) }
        for id in parameters.keys.sorted() {
            guard let parameter = definition.parameter(id), let value = parameters[id], parameter.accepts(value)
            else { return .invalidParameter(id) }
        }
        guard animationTime.isFinite, Self.animationTimeRange.contains(animationTime) else {
            return .invalidParameter("animationTime")
        }
        if let colors = customColors {
            guard colors.count == Self.customColorCount,
                  colors.allSatisfy({ color in
                      [color.r, color.g, color.b].allSatisfy { $0.isFinite && (0...1).contains($0) }
                  })
            else { return .invalidParameter("customColors") }
        }
        return nil
    }
}
