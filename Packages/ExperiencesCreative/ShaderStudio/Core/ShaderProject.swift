// ShaderProject — feature 159 (A22-P01) T-A22-103 (FR-A22-101, FR-A22-102; clarifications Q2, Q3; data-model.md
// "ShaderLimits", "UniformDeclaration", "ShaderProject"). The person's shader project: a name (1…40 characters), the
// fragment source, the float uniforms (a `ParameterDefinition` each), the limits and the texture-input names (0…2),
// kept in a versioned JSON envelope of kind `a22.shader-project` (schema 1, at most 65,536 bytes encoded, canonical
// with sorted keys, so a round trip is byte-identical) with five typed refusals: `damaged`, `newer-version`,
// `too-large`, `not-finite` and `out-of-range`.
// Choices recorded here: the uniforms are stored through a private record with the same keys as
// `ParameterDefinition`, so that a NaN or infinity (written as the strings "NaN", "Infinity", "-Infinity") is refused
// as `not-finite` and a bad name, a reversed range or a default outside the range as `out-of-range` rather than as
// damage. A wrong kind, a missing field, a field of the wrong type or a version below 1 is `damaged`; a file above
// 65,536 bytes is `too-large`. The initializer checks the name, the limits and the texture-input names; the source,
// the uniform count and name clashes are the validator's (``ShaderValidator``). Pure Foundation; no UI, GPU or clock.
import Foundation
import VisualCoreParameters
import VisualCoreShaderSource

/// The size limits of a shader project. A project's limits may be lower than ``standard``, never higher.
public struct ShaderLimits: Sendable, Equatable, Codable {
    /// The largest source accepted, in UTF-8 bytes.
    public var maxSourceBytes: Int
    /// The largest number of source lines accepted.
    public var maxLines: Int
    /// The largest number of float uniforms accepted.
    public var maxUniforms: Int
    /// The largest number of texture inputs accepted (declared in 0.1, bound from A22-P03).
    public var maxTextureInputs: Int

    /// The standard limits: 16,384 bytes, 400 lines, 16 uniforms and 2 texture inputs.
    public static let standard = ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: 16,
                                              maxTextureInputs: 2)
    /// The hard ceiling of an expanded shader, in bytes (``ShaderLibrary/maxExpandedBytes``, 64 KiB).
    public static let hardCeilingBytes = ShaderLibrary.maxExpandedBytes

    /// Limits with the values as given; ``isAcceptable`` says whether a project may carry them.
    public init(maxSourceBytes: Int, maxLines: Int, maxUniforms: Int, maxTextureInputs: Int) {
        self.maxSourceBytes = maxSourceBytes
        self.maxLines = maxLines
        self.maxUniforms = maxUniforms
        self.maxTextureInputs = maxTextureInputs
    }

    /// Whether these limits are within ``standard`` and the hard ceiling: at least 1 byte and 1 line, at least 0
    /// uniforms and texture inputs, and none above the standard value.
    public var isAcceptable: Bool {
        (1...Self.standard.maxSourceBytes).contains(maxSourceBytes) && maxSourceBytes <= Self.hardCeilingBytes
            && (1...Self.standard.maxLines).contains(maxLines)
            && (0...Self.standard.maxUniforms).contains(maxUniforms)
            && (0...Self.standard.maxTextureInputs).contains(maxTextureInputs)
    }
}

/// Why a shader project was refused. The code is one of `damaged`, `newer-version`, `too-large`, `not-finite` and
/// `out-of-range`.
public enum ShaderProjectRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field, has a field of the wrong type or has a version
    /// below 1.
    case damaged
    /// The file was written by a newer version (above ``ShaderProject/schemaVersion``); the value is that version.
    case newerVersion(Int)
    /// The file (or the encoding) is larger than ``ShaderProject/maxEncodedBytes``; the value is its size in bytes.
    case tooLarge(Int)
    /// A uniform's minimum, maximum or default is NaN or infinite.
    case notFinite
    /// A value is outside its range: the name length, a limit above the standard or the hard ceiling, a texture-input
    /// name or count, or a uniform's name, range or default. The value names the field.
    case outOfRange(String)

    /// The stable code: `damaged`, `newer-version`, `too-large`, `not-finite` or `out-of-range`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        case .notFinite: return "not-finite"
        case .outOfRange: return "out-of-range"
        }
    }
}

/// A shader project (schema 1): the name, the person's fragment source, the float uniforms in order, the limits and
/// the texture-input names. ``encoded()`` and ``decode(_:)`` round-trip byte-identical.
public struct ShaderProject: Sendable, Equatable {
    /// The envelope kind of a project file.
    public static let kind = "a22.shader-project"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest project file accepted or written, in bytes.
    public static let maxEncodedBytes = 65_536
    /// The accepted name length, in characters.
    public static let nameLength: ClosedRange<Int> = 1...40
    /// The accepted number of texture inputs.
    public static let textureInputCount: ClosedRange<Int> = 0...2

    /// The project name (1…40 characters).
    public let name: String
    /// The person's fragment source, unchanged (placed as `ss/shader.frag`).
    public let source: String
    /// The float uniforms, in order.
    public let uniforms: [ParameterDefinition]
    /// The limits (never above ``ShaderLimits/standard``).
    public let limits: ShaderLimits
    /// The texture-input names (0…2 GLSL identifiers), declared as `uniform sampler2D <name>;` in the source.
    public let textureInputs: [String]

    /// Creates a project; throws ``ShaderProjectRefusal/outOfRange(_:)`` naming `name`, `limits` or `textureInputs`
    /// when the name is not 1…40 characters, the limits are not acceptable (``ShaderLimits/isAcceptable``), or the
    /// texture inputs are more than 2 or not valid GLSL identifiers. The source is checked by ``ShaderValidator``.
    public init(name: String, source: String, uniforms: [ParameterDefinition] = [],
                limits: ShaderLimits = .standard, textureInputs: [String] = []) throws(ShaderProjectRefusal) {
        guard Self.nameLength.contains(name.count) else { throw .outOfRange("name") }
        guard limits.isAcceptable else { throw .outOfRange("limits") }
        guard Self.textureInputCount.contains(textureInputs.count),
              textureInputs.allSatisfy(Self.isIdentifier) else { throw .outOfRange("textureInputs") }
        self.name = name
        self.source = source
        self.uniforms = uniforms
        self.limits = limits
        self.textureInputs = textureInputs
    }

    /// Whether `text` is a GLSL identifier: a letter or underscore, then up to 31 letters, digits or underscores,
    /// not starting with the reserved `gl_` prefix.
    static func isIdentifier(_ text: String) -> Bool {
        text.range(of: #"^[A-Za-z_][A-Za-z0-9_]{0,31}$"#, options: .regularExpression) != nil
            && !text.hasPrefix("gl_")
    }

    /// One stored uniform, with the keys of `ParameterDefinition`; checked on decode.
    private struct UniformRecord: Codable {
        var defaultValue: Double
        var maximum: Double
        var minimum: Double
        var name: String
        var title: String
        var transform: ParameterTransform
        var unit: String
    }

    private struct Body: Codable {
        var limits: ShaderLimits
        var name: String
        var source: String
        var textureInputs: [String]
        var uniforms: [UniformRecord]
    }

    private struct Envelope: Codable {
        var body: Body?
        var kind: String
        var version: Int
    }

    private struct Header: Decodable {
        var kind: String
        var version: Int
    }

    /// The strings that stand for non-finite numbers, so that a NaN or infinity in a file is refused as
    /// ``ShaderProjectRefusal/notFinite`` rather than as damage.
    private static let positiveInfinityText = "Infinity"
    private static let negativeInfinityText = "-Infinity"
    private static let nanText = "NaN"

    /// The stored file: the JSON envelope `{"body", "kind", "version"}` with sorted keys and unescaped slashes, the
    /// same bytes for the same project. Throws ``ShaderProjectRefusal/tooLarge(_:)`` when the result is above
    /// ``maxEncodedBytes``.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let records = uniforms.map {
            UniformRecord(defaultValue: $0.defaultValue, maximum: $0.maximum, minimum: $0.minimum, name: $0.name,
                          title: $0.title, transform: $0.transform, unit: $0.unit)
        }
        let body = Body(limits: limits, name: name, source: source, textureInputs: textureInputs, uniforms: records)
        let data = try encoder.encode(Envelope(body: body, kind: Self.kind, version: Self.schemaVersion))
        guard data.count <= Self.maxEncodedBytes else { throw ShaderProjectRefusal.tooLarge(data.count) }
        return data
    }

    /// Reads a stored file. Checks, in order: the size (``ShaderProjectRefusal/tooLarge(_:)``), the envelope and its
    /// kind (``ShaderProjectRefusal/damaged``), the version (``ShaderProjectRefusal/newerVersion(_:)``), the body
    /// (``ShaderProjectRefusal/damaged``), each uniform (``ShaderProjectRefusal/notFinite``, then
    /// ``ShaderProjectRefusal/outOfRange(_:)`` naming `uniforms[i]`), then the initializer's checks. Nothing the caller
    /// holds is changed.
    public static func decode(_ data: Data) throws(ShaderProjectRefusal) -> ShaderProject {
        guard data.count <= maxEncodedBytes else { throw .tooLarge(data.count) }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.version >= 1 else { throw .damaged }
        guard header.version <= schemaVersion else { throw .newerVersion(header.version) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let body = envelope.body else { throw .damaged }
        var uniforms: [ParameterDefinition] = []
        for (index, record) in body.uniforms.enumerated() {
            guard record.minimum.isFinite, record.maximum.isFinite, record.defaultValue.isFinite else {
                throw .notFinite
            }
            guard record.minimum < record.maximum,
                  let definition = try? ParameterDefinition(
                      name: record.name, title: record.title, unit: record.unit,
                      range: record.minimum...record.maximum, defaultValue: record.defaultValue,
                      transform: record.transform) else { throw .outOfRange("uniforms[\(index)]") }
            uniforms.append(definition)
        }
        return try ShaderProject(name: body.name, source: body.source, uniforms: uniforms, limits: body.limits,
                                 textureInputs: body.textureInputs)
    }
}
