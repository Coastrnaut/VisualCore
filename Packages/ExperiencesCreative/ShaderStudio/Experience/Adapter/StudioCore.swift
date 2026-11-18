// StudioCore — feature 160 (A22-P02) T-A22-203 (FR-A22-201, FR-A22-205; clarification Q1; data-model.md
// "StudioCore"); feature 161 (A22-P03) T-A22-308 (FR-A22-304, FR-A22-305; clarifications Q4, Q5; data-model.md)
// added the texture choices; feature 162 (A22-P04) T-A22-406 (FR-A22-404; clarification Q3) the reset count; feature
// 163 (A22-P05) T-A22-506 (FR-A22-503; clarification Q2) the document's shape. The state of Shader Studio as an
// experience: the selected template, the normalized uniform values, the texture choices, the shape of the document
// (its uniform and texture-input counts) and the run and reset counts. The edited source is not state: it is the
// presenter's document (`StudioPresenter`), set from the template, through `setSource(_:)` or by opening a project;
// the presenter tells the core its shape with `document.shape`. The core never draws, never compiles and reads no
// clock.
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses them itself with the same reasons):
//   template.select [0…3]       the template at that index of `ShaderTemplates.all`, a whole number (`a22.not-whole`);
//                               the values become the template's defaults, normalized, the shape becomes the
//                               template's counts, and the run count grows by 1;
//   uniform.set [0…15, 0…1]     the uniform index, a whole number (`a22.not-whole`) below the shape's uniform count
//                               (`a22.no-uniform`), and its normalized value;
//   texture.set [0…1, 0…2]      the texture input index and the recipe (`TextureRecipe`: 0 checker, 1 ramp, 2 noise),
//                               both whole numbers (`a22.not-whole`); the input index must be below the shape's
//                               texture-input count (`a22.no-texture`). The choices are kept across a
//                               template change (a template without texture inputs simply does not use them);
//   shader.run [1…1]            the run count grows by 1 (a request to compile the presenter's document);
//   preview.reset [1…1]         the reset count grows by 1 (feature 162: the presenter swaps its fallback back at the
//                               next draw, or queues the template's starter; nothing compiles from the control);
//   document.shape [0…16, 0…2]  the document's uniform and texture-input counts, both whole (`a22.not-whole`; feature
//                               163). Values and texture choices are kept by position: a position past the new count
//                               keeps its value, unused, until the count includes it again.
// A refused action changes nothing.
//
// Digest ("a22.shader-studio.v1"): the template, then the 16 values, then the 2 texture choices (from feature 161),
// then the reset count (from feature 162), then the shape (from feature 163). The run count is in the snapshot, not
// in the digest. Snapshot schema 1: the JSON object `{"resets", "runs", "shape", "template", "textures", "values"}`
// with sorted keys; `textures`, `resets` and `shape` are optional on restore: a payload without `textures` (A22-P02)
// restores with the default choices `[0, 1]`, one without `resets` (A22-P03) with 0, one without `shape` (A22-P04)
// with the template's counts. Since values are kept by position (feature 163), a value past the uniform count is no
// longer required to be 0. Restoring a damaged payload throws `StudioRestoreRefusal.damaged`, and a template, value,
// texture choice, shape or run or reset count out of range `.outOfRange(_:)`.
// Outcome `template-<id>`, for example `template-gradient`. Quality: one tier, `level-0`.
import Foundation
import ShaderStudioCore
import VisualCoreExperience
import VisualCoreParameters
import VisualCorePersistence

/// The rule codes of Shader Studio's refusals (feature 160).
public enum StudioRule {
    /// A value that must be a whole number (a template or uniform index) and is not.
    public static let notWhole = "a22.not-whole"
    /// A uniform index at or past the shape's uniform count (the template's until `document.shape`, feature 163).
    public static let noUniform = "a22.no-uniform"
    /// A texture input index at or past the shape's texture-input count (feature 161; the shape from feature 163).
    public static let noTexture = "a22.no-texture"
}

/// Why a saved Shader Studio state was refused on restore (feature 160). A refused restore changes nothing.
public enum StudioRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"runs", "template", "values"}` (with an optional `textures`) or a field
    /// has the wrong type.
    case damaged
    /// A field is outside its range; the value names it (`template`, `values`, `textures`, `runs`, `resets` or
    /// `shape`).
    case outOfRange(String)
}

/// The state of Shader Studio (see the file header). Snapshot schema 1.
public struct StudioCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a22.shader-studio"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a22.shader-studio.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["template.select", "uniform.set", "texture.set", "shader.run", "preview.reset",
                                   "document.shape"]
    /// The number of uniform values held (``ShaderLimits/standard`` `maxUniforms`, 16).
    public static let valueCount = ShaderLimits.standard.maxUniforms
    /// The accepted normalized value of a uniform.
    public static let valueRange: ClosedRange<Double> = 0...1
    /// The prefix of the outcome code `template-<id>`.
    public static let templateCodePrefix = "template-"
    /// The number of texture choices held (``ShaderLimits/standard`` `maxTextureInputs`, 2).
    public static let textureCount = ShaderLimits.standard.maxTextureInputs
    /// The accepted recipe index of a texture choice (`TextureRecipe` raw values).
    public static let recipeRange: ClosedRange<Double> = 0...Double(TextureRecipe.allCases.count - 1)
    /// The default texture choices: checker for input 0, ramp for input 1.
    public static let defaultTextures = [TextureRecipe.checker.rawValue, TextureRecipe.ramp.rawValue]

    /// The index of the selected template in `ShaderTemplates.all`.
    public private(set) var template: Int
    /// The normalized uniform values (0…1), ``valueCount`` entries; entries past the template's uniform count are 0.
    public private(set) var values: [Double]
    /// The recipe index (`TextureRecipe` raw value) chosen for each texture input, ``textureCount`` entries.
    public private(set) var textures: [Int]
    /// How many runs were requested (in the snapshot, not in the digest).
    public private(set) var runs: Int
    /// How many preview resets were requested (feature 162; in the snapshot and the digest).
    public private(set) var resets: Int
    /// The document's shape (feature 163): `[uniform count 0…16, texture-input count 0…2]`; bounds `uniform.set` and
    /// `texture.set`.
    public private(set) var shape: [Int]

    /// The opening state: the first template with its default values, the default textures and no run.
    public init() {
        self.init(template: 0, values: Self.defaultValues(template: 0), runs: 0)
    }

    /// A state with the values as given (nothing is checked; ``restore(payload:seed:)`` checks).
    /// A nil `shape` is the template's counts (``templateShape(_:)``).
    public init(template: Int, values: [Double], textures: [Int] = StudioCore.defaultTextures, runs: Int,
                resets: Int = 0, shape: [Int]? = nil) {
        self.template = template
        self.values = values
        self.textures = textures
        self.runs = runs
        self.resets = resets
        self.shape = shape ?? Self.templateShape(template)
    }

    /// The shape of the template at `index`: its uniform and texture-input counts (feature 163).
    public static func templateShape(_ index: Int) -> [Int] {
        [uniformCount(template: index), textureInputCount(template: index)]
    }

    /// The accepted uniform count of a shape (``ShaderLimits/standard`` `maxUniforms`).
    public static let shapeUniformRange: ClosedRange<Double> = 0...Double(valueCount)
    /// The accepted texture-input count of a shape (``ShaderLimits/standard`` `maxTextureInputs`).
    public static let shapeInputRange: ClosedRange<Double> = 0...Double(textureCount)

    /// The selected template; the first when the index is unknown.
    public var selectedTemplate: ShaderTemplate? {
        let all = ShaderTemplates.all
        guard !all.isEmpty else { return nil }
        return all[min(max(template, 0), all.count - 1)]
    }

    /// The texture-input count of the template at `index`; 0 when there is none.
    public static func textureInputCount(template index: Int) -> Int {
        let all = ShaderTemplates.all
        guard all.indices.contains(index) else { return 0 }
        return all[index].textureInputs.count
    }

    /// The uniform count of the template at `index`; 0 when there is none.
    public static func uniformCount(template index: Int) -> Int {
        let all = ShaderTemplates.all
        guard all.indices.contains(index) else { return 0 }
        return all[index].uniforms.count
    }

    /// The template's default values, normalized by its uniforms' definitions, padded with 0 to ``valueCount``.
    public static func defaultValues(template index: Int) -> [Double] {
        var values = [Double](repeating: 0, count: valueCount)
        let all = ShaderTemplates.all
        guard all.indices.contains(index) else { return values }
        for (k, definition) in all[index].uniforms.prefix(valueCount).enumerated() {
            values[k] = definition.normalized(definition.defaultValue)
        }
        return values
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "template.select", ranges: [0...Double(max(ShaderTemplates.all.count - 1, 0))]),
        ExperienceControl(id: "uniform.set", ranges: [0...Double(valueCount - 1), valueRange]),
        ExperienceControl(id: "texture.set", ranges: [0...Double(textureCount - 1), recipeRange]),
        ExperienceControl(id: "shader.run", ranges: [1...1]),
        ExperienceControl(id: "preview.reset", ranges: [1...1]),
        ExperienceControl(id: "document.shape", ranges: [shapeUniformRange, shapeInputRange]),
    ]

    /// The six controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> StudioCore {
        try Task.checkCancellation()
        return StudioCore()
    }

    /// A host step changes nothing: the shader's time is the presenter's (frame time), not state.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        let notWhole = ActionResult.rejected(.rule(code: StudioRule.notWhole))
        switch action.control {
        case "template.select":
            guard let index = Self.whole(action.values[0]) else { return notWhole }
            template = index
            values = Self.defaultValues(template: index)
            shape = Self.templateShape(index)
            runs += 1
        case "uniform.set":
            guard let index = Self.whole(action.values[0]) else { return notWhole }
            guard index < shape[0] else {
                return .rejected(.rule(code: StudioRule.noUniform))
            }
            values[index] = action.values[1]
        case "texture.set":
            guard let input = Self.whole(action.values[0]), let recipe = Self.whole(action.values[1]) else {
                return notWhole
            }
            guard input < shape[1] else {
                return .rejected(.rule(code: StudioRule.noTexture))
            }
            textures[input] = recipe
        case "preview.reset":
            resets += 1
        case "document.shape":
            guard let uniforms = Self.whole(action.values[0]), let inputs = Self.whole(action.values[1]) else {
                return notWhole
            }
            shape = [uniforms, inputs]
        default:   // shader.run
            runs += 1
        }
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the opening state.
    public mutating func reset() {
        self = StudioCore()
    }

    /// `template-<id>` with the selected template's id, for example `template-gradient`.
    public var outcome: ExperienceOutcome? {
        guard let id = selectedTemplate?.id else { return nil }
        return ExperienceOutcome(code: Self.templateCodePrefix + id)
    }

    /// "a22.shader-studio.v1", then the template, the 16 values, the 2 texture choices and the reset count (not the
    /// run count).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(template)
        builder.add(values.count)
        for value in values { try builder.add(value) }
        builder.add(textures.count)
        for texture in textures { builder.add(texture) }
        builder.add(resets)
        builder.add(shape.count)
        for count in shape { builder.add(count) }
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        var resets: Int?
        var runs: Int
        var shape: [Int]?
        var template: Int
        var textures: [Int]?
        var values: [Double]
    }

    /// The JSON object `{"resets", "runs", "shape", "template", "textures", "values"}` with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(resets: resets, runs: runs, shape: shape, template: template,
                                           textures: textures, values: values))
    }

    /// The core of `payload`; throws ``StudioRestoreRefusal/damaged`` for a payload that does not decode and
    /// ``StudioRestoreRefusal/outOfRange(_:)`` for a template outside `ShaderTemplates.all`, values that are not
    /// ``valueCount`` finite numbers in 0…1, texture choices that are not ``textureCount`` recipe indices (a
    /// missing `textures` reads as ``defaultTextures``), a shape that is not a uniform count 0…16 and an input count
    /// 0…2 (a missing `shape` reads as the template's counts), or a negative run or reset count (a missing `resets`
    /// reads as 0). The seed changes nothing.
    public static func restore(payload: Data, seed: UInt64) throws -> StudioCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw StudioRestoreRefusal.damaged
        }
        guard ShaderTemplates.all.indices.contains(decoded.template) else {
            throw StudioRestoreRefusal.outOfRange("template")
        }
        guard decoded.values.count == valueCount,
              decoded.values.allSatisfy({ $0.isFinite && valueRange.contains($0) }) else {
            throw StudioRestoreRefusal.outOfRange("values")
        }
        let textures = decoded.textures ?? defaultTextures
        guard textures.count == textureCount, textures.allSatisfy({ recipeRange.contains(Double($0)) }) else {
            throw StudioRestoreRefusal.outOfRange("textures")
        }
        guard decoded.runs >= 0 else { throw StudioRestoreRefusal.outOfRange("runs") }
        let resets = decoded.resets ?? 0
        guard resets >= 0 else { throw StudioRestoreRefusal.outOfRange("resets") }
        let shape = decoded.shape ?? templateShape(decoded.template)
        guard shape.count == 2, shapeUniformRange.contains(Double(shape[0])),
              shapeInputRange.contains(Double(shape[1])) else {
            throw StudioRestoreRefusal.outOfRange("shape")
        }
        return StudioCore(template: decoded.template, values: decoded.values, textures: textures, runs: decoded.runs,
                          resets: resets, shape: shape)
    }
}
