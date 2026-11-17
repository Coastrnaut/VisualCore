// AuroraCore (the adapter core `SkyCore`) — feature 153 (A21-P02) T-A21-203 (FR-A21-201, FR-A21-202; clarifications
// Q1, Q4; data-model.md "AuroraCore"; contracts/experience.md "Actions"). The state of Aurora as an experience: the
// A21-P01 `SkyScene`, the hue shift and the brightness limit. The type is named `SkyCore` because `AuroraCore` is the
// name of the core module. The core never draws and reads no clock; `AuroraPresenter` draws it.
//
// Actions, one value each (the engine refuses a value outside the declared range, a non-finite value and a wrong
// value count before the core sees it; called directly, the core refuses them itself with the same reasons):
//   preset.select [0…2]        the scene of `SkyPresets.all[i]`, a whole index (`a21.not-whole` otherwise); the hue
//                              shift and the limit stay;
//   colour.hue [−0.5…0.5]      the hue shift in turns, applied by the presenter to every palette colour;
//   motion.speed [0…2]         the scene's speed;
//   motion.turbulence [0…1]    the scene's turbulence;
//   sky.ribbons [1…4]          the ribbon count, a whole number (`a21.not-whole`);
//   sky.stars [0…400]          the star count, a whole number (`a21.not-whole`);
//   sky.clouds [0…1]           the scene's cloudiness;
//   light.limit [0.2…0.72]     the brightness limit (default 0.6).
// A refused action changes nothing.
//
// Digest ("a21.aurora.v1"): exactly the snapshot: the scene (preset, palette, ribbons, turbulence, cloudiness, stars,
// speed), the hue shift and the limit. Snapshot schema 1: the JSON object `{"hue", "limit", "scene"}` with sorted
// keys, the scene in its A21-P01 body form. Restoring a damaged payload throws `SkyRestoreRefusal.damaged`, a scene
// `SkyScene.validate()` refuses `.scene(_:)`, and a hue or limit out of range `.outOfRange(_:)`; the engine refuses a
// newer schema. Hidden controls are presentation (the presenter's), not state. A restored core is marked
// `isRestored` (feature 154, presentation only), so the presenter lets a restored session win over the saved
// preferences.
//
// Outcome `preset-<id>`, for example `preset-polar-night`. Quality: `level-0` (5 fbm octaves) and `level-1` (3), each
// one full-screen draw at the full resolution.
import Foundation
import AuroraCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Aurora's refusals (feature 153).
public enum SkyRule {
    /// A value that must be a whole number (a preset index, the ribbons, the stars) and is not.
    public static let notWhole = "a21.not-whole"
}

/// Why a saved Aurora state was refused on restore (feature 153). A refused restore changes nothing.
public enum SkyRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"hue", "limit", "scene"}` or a field has the wrong type.
    case damaged
    /// The scene was refused by `SkyScene.validate()`; the value is that refusal.
    case scene(SceneRefusal)
    /// The hue shift or the limit is outside its range; the value names the field (`hue` or `limit`).
    case outOfRange(String)
}

/// The state of Aurora (see the file header). Snapshot schema 1.
public struct SkyCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a21.aurora"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a21.aurora.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["preset.select", "colour.hue", "motion.speed", "motion.turbulence", "sky.ribbons",
                                   "sky.stars", "sky.clouds", "light.limit"]
    /// The accepted hue shift, in turns.
    public static let hueRange: ClosedRange<Double> = -0.5...0.5
    /// The accepted brightness limits (`SkyShader.limitRange`).
    public static let limitRange: ClosedRange<Double> = SkyShader.limitRange
    /// The opening brightness limit.
    public static let defaultLimit = 0.6
    /// The prefix of the outcome code `preset-<id>`.
    public static let presetCodePrefix = "preset-"

    /// The sky scene.
    public private(set) var scene: SkyScene
    /// The hue shift in turns (−0.5…0.5).
    public private(set) var hue: Double
    /// The brightness limit (0.2…0.72).
    public private(set) var limit: Double
    /// The quality tier the host set (0 = level-0, 1 = level-1, clamped); presentation only — not in the digest,
    /// the snapshot or `==`.
    public private(set) var qualityTier = 0
    /// Whether this state came from a restored session snapshot (``restore(payload:seed:)``; feature 154): the
    /// presenter seeds a fresh state from the saved preferences and leaves a restored one as it is. Presentation only
    /// — not in the digest, the snapshot or `==`; a reset clears it.
    public private(set) var isRestored = false

    /// The opening state: the default preset's scene, no hue shift and the default limit.
    public init() {
        scene = SkyPresets.defaultPreset.scene
        hue = 0
        limit = Self.defaultLimit
    }

    /// A state with `scene`, `hue` and `limit` as given (nothing is checked; ``restore(payload:seed:)`` checks).
    public init(scene: SkyScene, hue: Double, limit: Double) {
        self.scene = scene
        self.hue = hue
        self.limit = limit
    }

    /// The index of the scene's preset in `SkyPresets.all` (0 when unknown).
    public var presetIndex: Int { SkyPresets.all.firstIndex { $0.id == scene.preset } ?? 0 }

    // MARK: Quality

    /// Two quality tiers: level-0 and level-1.
    public static var qualityTiers: Int { 2 }

    /// `level-0` (5 fbm octaves) and `level-1` (3 of 5 octaves); each level is one full-screen draw at the full
    /// resolution.
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "level-0", resolutionShare: 1, iterationShare: 1),
                      QualityLevel(name: "level-1", resolutionShare: 1,
                                   iterationShare: Double(SkyShader.octaves(forLevel: 1))
                                       / Double(SkyShader.octaves(forLevel: 0)))]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the scene, the hue shift and the limit (not the presentation-only `qualityTier`).
    public static func == (lhs: SkyCore, rhs: SkyCore) -> Bool {
        lhs.scene == rhs.scene && lhs.hue == rhs.hue && lhs.limit == rhs.limit
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "preset.select", ranges: [0...Double(SkyPresets.all.count - 1)]),
        ExperienceControl(id: "colour.hue", ranges: [hueRange]),
        ExperienceControl(id: "motion.speed", ranges: [SkyScene.speedRange]),
        ExperienceControl(id: "motion.turbulence", ranges: [SkyScene.turbulenceRange]),
        ExperienceControl(id: "sky.ribbons", ranges: [Double(SkyScene.ribbonsRange.lowerBound)...Double(
            SkyScene.ribbonsRange.upperBound)]),
        ExperienceControl(id: "sky.stars", ranges: [Double(SkyScene.starsRange.lowerBound)...Double(
            SkyScene.starsRange.upperBound)]),
        ExperienceControl(id: "sky.clouds", ranges: [SkyScene.cloudinessRange]),
        ExperienceControl(id: "light.limit", ranges: [limitRange]),
    ]

    /// The eight controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> SkyCore {
        try Task.checkCancellation()
        return SkyCore()
    }

    /// A host step changes nothing: the sky's animation time is the presenter's (frame time), not state.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        let value = action.values[0]
        let notWhole = ActionResult.rejected(.rule(code: SkyRule.notWhole))
        switch action.control {
        case "preset.select":
            guard let index = Self.whole(value) else { return notWhole }
            scene = SkyPresets.all[index].scene
        case "colour.hue":
            hue = value
        case "motion.speed":
            scene.setSpeed(value)
        case "motion.turbulence":
            scene.setTurbulence(value)
        case "sky.ribbons":
            guard let count = Self.whole(value) else { return notWhole }
            scene.setRibbons(count)
        case "sky.stars":
            guard let count = Self.whole(value) else { return notWhole }
            scene.setStars(count)
        case "sky.clouds":
            scene.setCloudiness(value)
        default:   // light.limit
            limit = value
        }
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the opening state; the quality tier, which is not state, is kept.
    public mutating func reset() {
        let tier = qualityTier
        self = SkyCore()
        qualityTier = tier
    }

    /// `preset-<id>` with the scene's preset id, for example `preset-polar-night`.
    public var outcome: ExperienceOutcome? { ExperienceOutcome(code: Self.presetCodePrefix + scene.preset) }

    /// "a21.aurora.v1", then the scene (preset, palette, ribbons, turbulence, cloudiness, stars, speed), the hue
    /// shift and the limit.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(scene.preset)
        builder.add(scene.palette.count)
        for color in scene.palette {
            try builder.add(color.red)
            try builder.add(color.green)
            try builder.add(color.blue)
        }
        builder.add(scene.ribbons)
        try builder.add(scene.turbulence)
        try builder.add(scene.cloudiness)
        builder.add(scene.stars)
        try builder.add(scene.speed)
        try builder.add(hue)
        try builder.add(limit)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        var hue: Double
        var limit: Double
        var scene: SkyScene
    }

    /// The JSON object `{"hue", "limit", "scene"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(hue: hue, limit: limit, scene: scene))
    }

    /// The core of `payload`; throws ``SkyRestoreRefusal`` for a damaged payload, a refused scene or a hue shift or
    /// limit out of range. The seed changes nothing. The restored core is marked ``isRestored``.
    public static func restore(payload: Data, seed: UInt64) throws -> SkyCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw SkyRestoreRefusal.damaged
        }
        if let refusal = decoded.scene.validate() { throw SkyRestoreRefusal.scene(refusal) }
        guard decoded.hue.isFinite, hueRange.contains(decoded.hue) else { throw SkyRestoreRefusal.outOfRange("hue") }
        guard decoded.limit.isFinite, limitRange.contains(decoded.limit) else {
            throw SkyRestoreRefusal.outOfRange("limit")
        }
        var core = SkyCore(scene: decoded.scene, hue: decoded.hue, limit: decoded.limit)
        core.isRestored = true
        return core
    }
}
