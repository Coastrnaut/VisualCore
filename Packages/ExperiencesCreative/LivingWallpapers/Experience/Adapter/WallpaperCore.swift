// WallpaperCore — feature 139 (A19-P02) T-A19-207 (FR-A19-203, FR-A19-204, FR-A19-206; clarification Q5; data-model.md
// "WallpaperCore"; contracts/experience.md "Actions"). The state of Living Wallpapers as an experience: numbers only,
// so replays and digests stay deterministic. The core never draws and reads no clock; the presenter
// (`WallpaperPresenter`) draws it with the scene shaders (`SceneShaders`) and the export (`StillExport`) plans it with
// the A19-P01 planner through `project`.
//
// Fields (defaults in brackets): the scene, an index of `SceneCatalog.scenes` 0…3 [0, aurora-bands]; the colour
// preset 0…2 [0]; three parameter values in the scene's parameter order, each inside that parameter's range, unused
// slots 0 [the scene's defaults]; the canvas template, an index of `CanvasTemplates.all` 0…8 [1, iphone-16-pro]; the
// orientation 0 portrait, 1 landscape [0]; the animation time in seconds 0…3600 [0]; the export format, an index of
// `ExportFormat.allCases` 0 png, 1 jpeg, 2 heic [0]; motion on or off [on]; and the seed of the preparation (it varies
// the scene's procedural detail). The quality tier is presentation only: it is not in `==`, the digest or the
// snapshot, and it is kept across `reset()`.
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses an unknown control and a wrong count itself):
//   scene.select [0…3]            the scene, a whole index (`a19.invalid-choice` otherwise); choosing another scene
//                                 resets the preset to 0 and the parameters to that scene's defaults (choosing the
//                                 shown one keeps them).
//   scene.preset [0…2]            the colour preset, a whole index (`a19.invalid-choice` otherwise).
//   scene.parameter [0…2, 0…40]   the parameter at a whole index of the scene's parameters (`a19.invalid-choice` for a
//                                 fraction, `a19.unknown-parameter` for an index the scene does not have) and its
//                                 value, which must lie in that parameter's range (`action.out-of-range` at index 1).
//   canvas.template [0…8]         the template, a whole index (`a19.invalid-choice` otherwise).
//   canvas.orientation [0…1]      exactly 0 (portrait) or 1 (landscape); `a19.invalid-choice` otherwise.
//   scene.time [0…3600]           the animation time in seconds.
//   export.format [0…2]           the format, a whole index (`a19.invalid-choice` otherwise).
//   motion.enabled [0…1]          exactly 0 (still) or 1 (moving); `a19.invalid-choice` otherwise.
// A refusal changes nothing.
//
// Digest of A19-P02 ("a19.wallpaper.v1"): scene, preset, the three parameter values, template, orientation,
// animation time, format, motion and seed. Snapshot schema 1 (A19-P02): `{"animationTime", "format", "motion",
// "orientation", "parameters", "preset", "scene", "template"}` as JSON with sorted keys; decoding refuses a value
// outside its range (a parameter outside its scene's range, an unused slot other than 0). The seed is not stored:
// `restore(payload:seed:)` takes the session's seed, so a round trip keeps the digest.
//
// Quality: `level-0` (full detail, resolution and iteration shares 1) and `level-1` (shares 0.5: fewer octaves, cells
// or layers and one sample per 2 × 2 pixels); each level is one full-screen draw.
//
// Outcome: `scene-<id>` of the scene shown, for example `scene-ink-flow`.
//
// Feature 140 (A19-P03) T-A19-303 (FR-A19-301; clarification Q1; data-model.md "WallpaperCore snapshot schema 2"):
// the four colours of the preset can be edited.
//   - Fields: `custom` 0 (the preset's colours) or 1 (edited), and `colors`, twelve components (r, g, b of the four
//     slots, each 0…1). While `custom` is 0 the components are the preset's own colours.
//   - Actions: `preset.color [slot 0…3, r 0…1, g 0…1, b 0…1]` sets one slot (a slot that is not a whole index is
//     `a19.invalid-choice`, a component outside 0…1 `action.out-of-range` at its index) and sets `custom` 1;
//     `preset.reset []` sets `custom` 0 and the preset's colours again. Another scene or another preset
//     (`scene.select`, `scene.preset`) sets `custom` 0 and the new preset's colours; choosing the shown scene or
//     preset keeps the edit.
//   - Digest ("a19.wallpaper.v2"): the schema-1 fields, then `custom`, then the twelve components only when `custom`
//     is 1, then the seed.
//   - Snapshot schema 2: the schema-1 keys plus `custom` (0/1) and `colors` (twelve numbers in 0…1). The migration
//     1 → 2 sets `custom` 0 and copies the stored preset's colours. A schema-1 payload handed to the restore without
//     the migration is refused (the new keys are missing).
//   - `project` carries `customColors` (the four edited colours) only when `custom` is 1.
import Foundation
import LivingWallpapersCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Living Wallpapers' refusals (feature 139).
public enum WallpaperRule {
    /// A value that is not a whole index, or a switch other than exactly 0 or 1.
    public static let invalidChoice = "a19.invalid-choice"
    /// A parameter index the shown scene does not have.
    public static let unknownParameter = "a19.unknown-parameter"
}

/// Why a stored Living Wallpapers state is refused (feature 139).
public enum WallpaperRestoreError: Error, Equatable {
    /// A field of the payload lies outside its range (its key is named).
    case outOfRange(String)
}

/// The state of Living Wallpapers (see the file header). Snapshot schema 2 (feature 140).
public struct WallpaperCore: ExperienceCore, Equatable, Codable {
    /// The experience's id in the catalog.
    public static let experienceID = "a19.living-wallpapers"
    /// The action ids in declaration order.
    public static let actionIDs = ["scene.select", "scene.preset", "scene.parameter", "canvas.template",
                                   "canvas.orientation", "scene.time", "export.format", "motion.enabled",
                                   "preset.color", "preset.reset"]
    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["scene.select": 1, "scene.preset": 1, "scene.parameter": 2,
                                             "canvas.template": 1, "canvas.orientation": 1, "scene.time": 1,
                                             "export.format": 1, "motion.enabled": 1, "preset.color": 4,
                                             "preset.reset": 0]
    /// The snapshot schema this build writes (2 since feature 140: the edited colours).
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "a19.wallpaper.v2"
    /// The number of colour slots of a preset.
    public static let colorSlots = 4
    /// The number of colour components: r, g and b of every slot.
    public static let componentCount = 12
    /// The range of one colour component.
    public static let componentRange: ClosedRange<Double> = 0...1
    /// The prefix of the outcome code: `scene-<id>`.
    public static let sceneCodePrefix = "scene-"
    /// The number of parameter slots (the most parameters a scene has).
    public static let parameterSlots = 3
    /// The declared range of a parameter value: the union of every scene parameter's range (0…40).
    public static let parameterValueRange: ClosedRange<Double> = 0...40
    /// The range of the animation time, seconds (`WallpaperProject.animationTimeRange`).
    public static var timeRange: ClosedRange<Double> { WallpaperProject.animationTimeRange }
    /// The number of scenes (`SceneCatalog.scenes`).
    public static var sceneCount: Int { SceneCatalog.scenes.count }
    /// The number of presets of every scene.
    public static let presetCount = 3
    /// The number of templates (`CanvasTemplates.all`).
    public static var templateCount: Int { CanvasTemplates.all.count }
    /// The number of formats (`ExportFormat.allCases`).
    public static var formatCount: Int { ExportFormat.allCases.count }
    /// The default template's index: `iphone-16-pro`, the A19-P01 default project's template.
    public static var defaultTemplate: Int {
        CanvasTemplates.all.firstIndex { $0.id == WallpaperProject.default.template } ?? 0
    }

    /// The scene, an index of `SceneCatalog.scenes` (default 0, aurora-bands).
    public private(set) var scene = 0
    /// The colour preset of the scene, 0…2 (default 0).
    public private(set) var preset = 0
    /// The three parameter values in the scene's parameter order; unused slots are 0 (default: the scene's
    /// defaults).
    public private(set) var parameters: [Double] = WallpaperCore.defaultParameters(scene: 0)
    /// The canvas template, an index of `CanvasTemplates.all` (default `iphone-16-pro`).
    public private(set) var template = WallpaperCore.defaultTemplate
    /// The orientation: 0 portrait, 1 landscape (default 0).
    public private(set) var orientation = 0
    /// The animation time, seconds 0…3600 (default 0).
    public private(set) var animationTime = 0.0
    /// The export format, an index of `ExportFormat.allCases` (default 0, png).
    public private(set) var format = 0
    /// Whether the scene moves (default true).
    public private(set) var motion = true
    /// The seed of the preparation (not stored; in the digest).
    public private(set) var seed: UInt64 = 1
    /// Whether the colours are edited: 0 the preset's own, 1 edited (default 0).
    public private(set) var custom = 0
    /// The twelve colour components (r, g, b of the four slots); while `custom` is 0 the preset's own colours.
    public private(set) var colors: [Double] = WallpaperCore.presetComponents(scene: 0, preset: 0)
    /// The quality tier the host set (0 = level-0, 1 = level-1, clamped); presentation only — not in the digest,
    /// the snapshot or `==`.
    public private(set) var qualityTier = 0

    /// The opening state with `seed` (default 1): aurora-bands, preset 0, its default parameters, iPhone 16 Pro in
    /// portrait, time 0, PNG, motion on.
    public init(seed: UInt64 = 1) {
        self.seed = seed
    }

    // MARK: Derived

    /// The scene's catalog definition.
    public var sceneDefinition: SceneDefinition { SceneCatalog.scenes[Self.clampedScene(scene)] }

    /// The colour preset's definition.
    public var presetDefinition: ColorPreset {
        let presets = sceneDefinition.presets
        return presets[min(max(preset, 0), presets.count - 1)]
    }

    /// The canvas template's definition.
    public var templateDefinition: CanvasTemplate {
        CanvasTemplates.all[min(max(template, 0), Self.templateCount - 1)]
    }

    /// The four colours drawn: the edited ones when `custom` is 1, else the preset's.
    public var palette: [RGBColor] {
        custom == 1 ? Self.rgbColors(colors) : presetDefinition.colors
    }

    /// The four edited colours when `custom` is 1; nil otherwise.
    public var customColors: [RGBColor]? { custom == 1 ? Self.rgbColors(colors) : nil }

    /// The twelve components of preset `preset` of scene `scene` (both clamped); a missing slot is black.
    public static func presetComponents(scene: Int, preset: Int) -> [Double] {
        let presets = SceneCatalog.scenes[clampedScene(scene)].presets
        let chosen = presets[min(max(preset, 0), presets.count - 1)]
        var values = [Double](repeating: 0, count: componentCount)
        for (slot, color) in chosen.colors.prefix(colorSlots).enumerated() {
            values[slot * 3] = color.r
            values[slot * 3 + 1] = color.g
            values[slot * 3 + 2] = color.b
        }
        return values
    }

    /// The colours of twelve components, in slot order.
    static func rgbColors(_ components: [Double]) -> [RGBColor] {
        (0..<colorSlots).map { slot in
            func at(_ index: Int) -> Double { index < components.count ? components[index] : 0 }
            return RGBColor(r: at(slot * 3), g: at(slot * 3 + 1), b: at(slot * 3 + 2))
        }
    }

    /// The orientation as the core model names it.
    public var orientationValue: Orientation { orientation == 1 ? .landscape : .portrait }

    /// The export format as the core model names it.
    public var formatValue: ExportFormat { ExportFormat.allCases[min(max(format, 0), Self.formatCount - 1)] }

    /// The A19-P01 project of this state, which the export planner plans: the scene, preset, seed, the scene's
    /// parameters by id, the template id, the orientation, the animation time and the format, and the edited colours
    /// (`customColors`) when `custom` is 1.
    public var project: WallpaperProject {
        let definition = sceneDefinition
        var values: [String: Double] = [:]
        for (index, parameter) in definition.parameters.enumerated() where index < parameters.count {
            values[parameter.id] = parameters[index]
        }
        var made = WallpaperProject(scene: definition.id, preset: preset, seed: seed, parameters: values,
                                    template: templateDefinition.id, orientation: orientationValue,
                                    animationTime: animationTime, format: formatValue)
        made.customColors = customColors
        return made
    }

    /// The three parameter values of scene `scene` (clamped) at their defaults, unused slots 0.
    public static func defaultParameters(scene: Int) -> [Double] {
        let definition = SceneCatalog.scenes[clampedScene(scene)]
        var values = [Double](repeating: 0, count: parameterSlots)
        for (index, parameter) in definition.parameters.enumerated() where index < parameterSlots {
            values[index] = parameter.defaultValue
        }
        return values
    }

    /// `index` clamped to the scene catalog.
    static func clampedScene(_ index: Int) -> Int { min(max(index, 0), SceneCatalog.scenes.count - 1) }

    // MARK: Quality

    /// Two quality tiers: level-0 and level-1.
    public static var qualityTiers: Int { 2 }

    /// `level-0`: the full resolution and iteration shares; `level-1`: resolution and iteration shares 0.5. Each
    /// level is one full-screen draw.
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "level-0", resolutionShare: 1, iterationShare: 1),
                      QualityLevel(name: "level-1", resolutionShare: 0.5, iterationShare: 0.5)]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: every stored value except the presentation-only `qualityTier`.
    public static func == (lhs: WallpaperCore, rhs: WallpaperCore) -> Bool {
        lhs.scene == rhs.scene && lhs.preset == rhs.preset && lhs.parameters == rhs.parameters
            && lhs.template == rhs.template && lhs.orientation == rhs.orientation
            && lhs.animationTime == rhs.animationTime && lhs.format == rhs.format && lhs.motion == rhs.motion
            && lhs.seed == rhs.seed && lhs.custom == rhs.custom && lhs.colors == rhs.colors
    }

    // MARK: Contract

    /// Schema 2; the step from schema 1 adds `custom` 0 and `colors`, the stored preset's twelve components (a scene
    /// or preset that is not a whole index in range throws ``WallpaperRestoreError/outOfRange(_:)``).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [
            1: { payload in
                var upgraded = payload
                guard let scene = (payload[CodingKeys.scene.rawValue] as? NSNumber)?.intValue,
                      (0..<WallpaperCore.sceneCount).contains(scene) else {
                    throw WallpaperRestoreError.outOfRange(CodingKeys.scene.rawValue)
                }
                guard let preset = (payload[CodingKeys.preset.rawValue] as? NSNumber)?.intValue,
                      (0..<SceneCatalog.scenes[scene].presets.count).contains(preset) else {
                    throw WallpaperRestoreError.outOfRange(CodingKeys.preset.rawValue)
                }
                if upgraded[CodingKeys.custom.rawValue] == nil { upgraded[CodingKeys.custom.rawValue] = 0 }
                if upgraded[CodingKeys.colors.rawValue] == nil {
                    upgraded[CodingKeys.colors.rawValue] = WallpaperCore.presetComponents(scene: scene,
                                                                                          preset: preset)
                }
                return upgraded
            },
        ])
    }

    /// The ten controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "scene.select", ranges: [0...Double(sceneCount - 1)]),
         ExperienceControl(id: "scene.preset", ranges: [0...Double(presetCount - 1)]),
         ExperienceControl(id: "scene.parameter", ranges: [0...Double(parameterSlots - 1), parameterValueRange]),
         ExperienceControl(id: "canvas.template", ranges: [0...Double(templateCount - 1)]),
         ExperienceControl(id: "canvas.orientation", ranges: [0...1]),
         ExperienceControl(id: "scene.time", ranges: [timeRange]),
         ExperienceControl(id: "export.format", ranges: [0...Double(formatCount - 1)]),
         ExperienceControl(id: "motion.enabled", ranges: [0...1]),
         ExperienceControl(id: "preset.color", ranges: [0...Double(colorSlots - 1), componentRange, componentRange,
                                                        componentRange]),
         ExperienceControl(id: "preset.reset", ranges: [])]
    }

    /// The opening state with `seed`; nothing is random beyond the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> WallpaperCore {
        try Task.checkCancellation()
        return WallpaperCore(seed: seed)
    }

    /// A host step changes nothing: the motion is drawn from the frame time.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        if let index = v.firstIndex(where: { !$0.isFinite }) { return .rejected(.nonFinite(index: index)) }
        let invalid = ActionResult.rejected(.rule(code: WallpaperRule.invalidChoice))
        switch action.control {
        case "scene.select":
            guard let chosen = Self.choice(v[0], count: Self.sceneCount) else { return invalid }
            if chosen != scene {
                scene = chosen
                preset = 0
                parameters = Self.defaultParameters(scene: chosen)
                clearColors()
            }
        case "scene.preset":
            guard let chosen = Self.choice(v[0], count: sceneDefinition.presets.count) else { return invalid }
            if chosen != preset {
                preset = chosen
                clearColors()
            }
        case "preset.color":
            guard let slot = Self.choice(v[0], count: Self.colorSlots) else { return invalid }
            for index in 1...3 where !Self.componentRange.contains(v[index]) {
                return .rejected(.outOfRange(index: index))
            }
            custom = 1
            colors.replaceSubrange((slot * 3)..<(slot * 3 + 3), with: v[1...3])
        case "preset.reset":
            clearColors()
        case "scene.parameter":
            guard let index = Self.choice(v[0], count: Self.parameterSlots) else { return invalid }
            let definitions = sceneDefinition.parameters
            guard index < definitions.count else {
                return .rejected(.rule(code: WallpaperRule.unknownParameter))
            }
            guard definitions[index].accepts(v[1]) else { return .rejected(.outOfRange(index: 1)) }
            parameters[index] = v[1]
        case "canvas.template":
            guard let chosen = Self.choice(v[0], count: Self.templateCount) else { return invalid }
            template = chosen
        case "canvas.orientation":
            guard let landscape = Self.flag(v[0]) else { return invalid }
            orientation = landscape ? 1 : 0
        case "scene.time":
            guard Self.timeRange.contains(v[0]) else { return .rejected(.outOfRange(index: 0)) }
            animationTime = v[0]
        case "export.format":
            guard let chosen = Self.choice(v[0], count: Self.formatCount) else { return invalid }
            format = chosen
        default:   // motion.enabled
            guard let on = Self.flag(v[0]) else { return invalid }
            motion = on
        }
        return .accepted
    }

    /// Sets `custom` 0 and the colours of the shown preset.
    private mutating func clearColors() {
        custom = 0
        colors = Self.presetComponents(scene: scene, preset: preset)
    }

    /// The index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// The switch named by `value`: exactly 0 (false) or 1 (true); nil otherwise.
    static func flag(_ value: Double) -> Bool? {
        value == 0 ? false : value == 1 ? true : nil
    }

    /// Back to the opening state with the same seed; the quality tier, which is not state, is kept.
    public mutating func reset() {
        let tier = qualityTier
        self = WallpaperCore(seed: seed)
        qualityTier = tier
    }

    /// `scene-<id>` of the scene shown, for example `scene-aurora-bands`.
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.sceneCodePrefix + sceneDefinition.id)
    }

    /// "a19.wallpaper.v2", then scene, preset, the three parameter values, template, orientation, animation time,
    /// format, motion, `custom`, the twelve colour components only when `custom` is 1, and the seed.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(scene)
        builder.add(preset)
        for value in parameters { try builder.add(value) }
        builder.add(template)
        builder.add(orientation)
        try builder.add(animationTime)
        builder.add(format)
        builder.add(motion)
        builder.add(custom)
        if custom == 1 {
            for value in colors { try builder.add(value) }
        }
        builder.add(seed)
    }

    // MARK: Snapshot

    private enum CodingKeys: String, CodingKey {
        case scene, preset, parameters, template, orientation, animationTime, format, motion, custom, colors
    }

    /// Decodes the schema-2 fields; a value outside its range throws ``WallpaperRestoreError/outOfRange(_:)``. The
    /// seed is 1 here; `restore(payload:seed:)` sets the session's seed.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func index(_ key: CodingKeys, count: Int) throws -> Int {
            let value = try c.decode(Int.self, forKey: key)
            guard (0..<count).contains(value) else { throw WallpaperRestoreError.outOfRange(key.rawValue) }
            return value
        }
        let scene = try index(.scene, count: Self.sceneCount)
        let definition = SceneCatalog.scenes[scene]
        let preset = try index(.preset, count: definition.presets.count)
        let values = try c.decode([Double].self, forKey: .parameters)
        guard values.count == Self.parameterSlots else {
            throw WallpaperRestoreError.outOfRange(CodingKeys.parameters.rawValue)
        }
        for (slot, value) in values.enumerated() {
            let valid = slot < definition.parameters.count ? definition.parameters[slot].accepts(value) : value == 0
            guard valid else { throw WallpaperRestoreError.outOfRange(CodingKeys.parameters.rawValue) }
        }
        let time = try c.decode(Double.self, forKey: .animationTime)
        guard time.isFinite, Self.timeRange.contains(time) else {
            throw WallpaperRestoreError.outOfRange(CodingKeys.animationTime.rawValue)
        }
        self.scene = scene
        self.preset = preset
        parameters = values
        template = try index(.template, count: Self.templateCount)
        orientation = try index(.orientation, count: 2)
        animationTime = time
        format = try index(.format, count: Self.formatCount)
        motion = try c.decode(Bool.self, forKey: .motion)
        custom = try index(.custom, count: 2)
        let components = try c.decode([Double].self, forKey: .colors)
        guard components.count == Self.componentCount,
              components.allSatisfy({ $0.isFinite && Self.componentRange.contains($0) }) else {
            throw WallpaperRestoreError.outOfRange(CodingKeys.colors.rawValue)
        }
        // While the colours are not edited they are the preset's own (the stored ones are not kept).
        colors = custom == 1 ? components : Self.presetComponents(scene: scene, preset: preset)
        seed = 1
    }

    /// Encodes the schema-2 fields: scene, preset, parameters, template, orientation, animation time, format,
    /// motion, `custom` and `colors` (not the seed or the quality tier).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scene, forKey: .scene)
        try c.encode(preset, forKey: .preset)
        try c.encode(parameters, forKey: .parameters)
        try c.encode(template, forKey: .template)
        try c.encode(orientation, forKey: .orientation)
        try c.encode(animationTime, forKey: .animationTime)
        try c.encode(format, forKey: .format)
        try c.encode(motion, forKey: .motion)
        try c.encode(custom, forKey: .custom)
        try c.encode(colors, forKey: .colors)
    }

    /// The core decoded from its schema-2 payload with `seed` as its seed.
    public static func restore(payload: Data, seed: UInt64) throws -> WallpaperCore {
        var core = try JSONDecoder().decode(WallpaperCore.self, from: payload)
        core.seed = seed
        return core
    }
}
