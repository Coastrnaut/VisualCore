// SceneDocument.swift — the saved-scene format, version 2 (feature 036 A04-P04 T-A04-403; FR-A04-402, FR-A04-404,
// FR-A04-410…412; US1, US2; data model; contracts/actions.md; research D1, D2). Pure data: no storage, no adapter.
import Foundation
import VisualCoreMath
import VisualCoreParameters

/// The placed force as saved: a `PlacedForceKind` raw value, a scene position within ±`PlacedForce.worldHalfExtent`
/// and a strength in `PlacedForce.strengthRange`.
public struct SavedForce: Codable, Equatable, Sendable {
    /// The `PlacedForceKind` raw value.
    public var kind: String
    /// Scene x, −500…500.
    public var x: Double
    /// Scene y, −500…500.
    public var y: Double
    /// Strength multiplier, `PlacedForce.strengthRange`.
    public var strength: Double

    /// Creates a saved force (not validated; `SceneDocument` validates it).
    public init(kind: String, x: Double, y: Double, strength: Double) {
        self.kind = kind; self.x = x; self.y = y; self.strength = strength
    }

    /// Creates the saved form of `force`.
    public init(_ force: PlacedForce) {
        self.init(kind: force.kind.rawValue, x: force.position.x, y: force.position.y, strength: force.strength)
    }

    /// The runtime force; nil for an unknown kind.
    public var placedForce: PlacedForce? {
        PlacedForceKind(rawValue: kind).map { PlacedForce(kind: $0, position: Vec2(x, y), strength: strength) }
    }

    /// Throws the first problem found: a non-finite value, an unknown kind or a value out of range.
    public func validate() throws(SceneError) {
        guard PlacedForceKind(rawValue: kind) != nil else { throw .invalidDocument("force.kind") }
        let h = PlacedForce.worldHalfExtent
        for (field, value) in [("force.x", x), ("force.y", y)] {
            guard value.isFinite else { throw .nonFinite(field) }
            guard (-h...h).contains(value) else { throw .invalidDocument(field) }
        }
        guard strength.isFinite else { throw .nonFinite("force.strength") }
        guard PlacedForce.strengthRange.contains(strength) else { throw .invalidDocument("force.strength") }
    }
}

/// A named, saved scene, format version 2: the scene, the placed force and the looks (trails, trail strength,
/// blend). Version 1 files (a bare `ParticleScene`) are migrated on decode with no force and the default looks.
public struct SceneDocument: Codable, Equatable, Sendable {
    /// The format version written.
    public static let version = 2
    /// The longest name, in characters after trimming.
    public static let maxNameLength = 64
    /// The name a version-1 file without a name opens under.
    public static let untitledName = "Untitled"
    /// Trails for a migrated version-1 file (the core's start value).
    public static let defaultTrailsOn = false
    /// Trail strength for a migrated version-1 file (the core's start value).
    public static let defaultTrailStrength = 0.85
    /// Blend for a migrated version-1 file: false is normal blending (the core's start value).
    public static let defaultAdditive = false
    /// The most actions `openActions()` produces: begin, 8 emitters, force, look.
    public static let maxOpenActions = 3 + ParticleScene.maxEmitters
    /// The gradients by index: 0 is none (the family's colors), then the built-in palettes in order.
    public static let gradientIDs: [String?] = [nil] + Palette.builtIns.map(\.id)

    /// The name, 1…64 characters after trimming (stored trimmed).
    public var name: String
    /// The scene (validated with the `ParticleScene` rules).
    public var scene: ParticleScene
    /// The placed force, or nil for none.
    public var force: SavedForce?
    /// Whether trails are on.
    public var trailsOn: Bool
    /// Trail strength, 0…1.
    public var trailStrength: Double
    /// True for additive blending, false for normal.
    public var additive: Bool

    /// Creates a validated document; the name is trimmed.
    public init(name: String, scene: ParticleScene, force: SavedForce?, trailsOn: Bool, trailStrength: Double,
                additive: Bool) throws(SceneError) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scene = scene; self.force = force
        self.trailsOn = trailsOn; self.trailStrength = trailStrength; self.additive = additive
        try validate()
    }

    /// Throws the first problem found: name, scene, force, trail strength.
    public func validate() throws(SceneError) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...Self.maxNameLength).contains(trimmed.count) else { throw .invalidDocument("name") }
        try scene.validate()
        try force?.validate()
        guard trailStrength.isFinite else { throw .nonFinite("trailStrength") }
        guard (0...1).contains(trailStrength) else { throw .invalidDocument("trailStrength") }
    }

    private enum CodingKeys: String, CodingKey { case version, name, scene, force, trailsOn, trailStrength, additive }

    /// Decodes and validates a version-2 document (use `decode(_:)` for files, which also migrates version 1).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .version)
        guard version == Self.version else { throw SceneError.unsupportedVersion(version) }
        name = try c.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        scene = try c.decode(ParticleScene.self, forKey: .scene)
        force = try c.decodeIfPresent(SavedForce.self, forKey: .force)
        trailsOn = try c.decode(Bool.self, forKey: .trailsOn)
        trailStrength = try c.decode(Double.self, forKey: .trailStrength)
        additive = try c.decode(Bool.self, forKey: .additive)
        try validate()
    }

    /// Encodes as version 2.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.version, forKey: .version)
        try c.encode(name, forKey: .name)
        try c.encode(scene, forKey: .scene)
        try c.encodeIfPresent(force, forKey: .force)
        try c.encode(trailsOn, forKey: .trailsOn)
        try c.encode(trailStrength, forKey: .trailStrength)
        try c.encode(additive, forKey: .additive)
    }

    private struct Header: Decodable { var version: Int; var name: String? }

    /// Reads a saved file: version 2 as is, version 1 (a bare `ParticleScene`, optionally with a `name`) migrated with
    /// no force and the default looks. Newer or older versions throw `unsupportedVersion`; damaged or truncated data
    /// throws `invalidDocument`; NaN or infinite values (also written as the strings "NaN", "Infinity") throw
    /// `nonFinite`; values out of range throw the matching `SceneError`.
    public static func decode(_ data: Data) throws(SceneError) -> SceneDocument {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity",
                                                                        negativeInfinity: "-Infinity", nan: "NaN")
        do {
            let header = try decoder.decode(Header.self, from: data)
            switch header.version {
            case Self.version:
                return try decoder.decode(SceneDocument.self, from: data)
            case ParticleUniverseCore.schemaVersion:
                let scene = try decoder.decode(ParticleScene.self, from: data)
                return try SceneDocument(name: header.name ?? untitledName, scene: scene, force: nil, trailsOn: defaultTrailsOn,
                                         trailStrength: defaultTrailStrength, additive: defaultAdditive)
            default:
                throw SceneError.unsupportedVersion(header.version)
            }
        } catch let error as SceneError {
            throw error
        } catch {
            throw .invalidDocument("data")
        }
    }

    /// The validated document as version-2 JSON with sorted keys.
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: Open sequence (contracts/actions.md)

    /// The family's index in `EmitterFamily.allCases` (the `family` control's order).
    public static func familyIndex(_ family: EmitterFamily) -> Int { EmitterFamily.allCases.firstIndex(of: family) ?? 0 }

    /// The gradient's index in `gradientIDs`: 0 for nil or an unknown id.
    public static func gradientIndex(_ id: String?) -> Int { gradientIDs.firstIndex(of: id) ?? 0 }

    /// The force kind's index for `force.define` (the `force.kind` control's order): 0 for none or an unknown kind,
    /// else 1 + its index in `PlacedForceKind.allCases`.
    public static func forceKindIndex(_ kind: String?) -> Int {
        guard let kind, let k = PlacedForceKind(rawValue: kind), let i = PlacedForceKind.allCases.firstIndex(of: k) else { return 0 }
        return i + 1
    }

    /// The logged actions that open this document: `scene.begin [count]`, one `emitter.define [family, x, y, size,
    /// lifetime, gradient]` per emitter, `force.define [kind, x, y, strength]` and `look.define [trails, trail
    /// strength, blend]` — at most `maxOpenActions` actions of at most 6 values. An emitter without a position uses
    /// its family's position; a size or lifetime of 0 means the family's own (both ranges exclude 0); gradient 0
    /// and force kind 0 mean none (a "none" force is `[0, 0, 0, 1]`). Blend 1 is additive. The scene's seed,
    /// particle limit, time scale and scene forces are not part of the sequence.
    public func openActions() -> [(id: String, values: [Double])] {
        var actions: [(id: String, values: [Double])] = [("scene.begin", [Double(scene.emitters.count)])]
        for e in scene.emitters {
            let p = e.position ?? e.family.emitter().position
            actions.append(("emitter.define", [Double(Self.familyIndex(e.family)), p.x, p.y, e.size ?? 0, e.lifetime ?? 0,
                                               Double(Self.gradientIndex(e.gradient))]))
        }
        if let force {
            actions.append(("force.define", [Double(Self.forceKindIndex(force.kind)), force.x, force.y, force.strength]))
        } else {
            actions.append(("force.define", [0, 0, 0, 1]))
        }
        actions.append(("look.define", [trailsOn ? 1 : 0, trailStrength, additive ? 1 : 0]))
        return actions
    }

    /// The emitter an `emitter.define` value list describes (the inverse of `openActions()`): a position equal to the
    /// family's own becomes nil, size or lifetime 0 becomes nil, gradient 0 becomes nil. Throws `invalidDocument`
    /// for a wrong count, a non-integral or unknown index, a position outside ±500 or an override out of range.
    public static func emitter(fromDefine v: [Double]) throws(SceneError) -> SceneEmitter {
        guard v.count == 6, v.allSatisfy(\.isFinite) else { throw .invalidDocument("emitter.define") }
        guard let f = index(v[0], count: EmitterFamily.allCases.count),
              let g = index(v[5], count: gradientIDs.count) else { throw .invalidDocument("emitter.define") }
        let h = PlacedForce.worldHalfExtent
        guard (-h...h).contains(v[1]), (-h...h).contains(v[2]) else { throw .invalidDocument("emitter.define") }
        let family = EmitterFamily.allCases[f]
        let p = Vec2(v[1], v[2])
        let size: Double? = v[3] == 0 ? nil : v[3]
        let lifetime: Double? = v[4] == 0 ? nil : v[4]
        if let size, !SceneEmitter.sizeRange.contains(size) { throw .invalidDocument("emitter.define") }
        if let lifetime, !SceneEmitter.lifetimeRange.contains(lifetime) { throw .invalidDocument("emitter.define") }
        return SceneEmitter(family: family, position: p == family.emitter().position ? nil : p, size: size,
                            lifetime: lifetime, gradient: gradientIDs[g])
    }

    /// The force a `force.define` value list describes (nil for kind 0), validated like a saved force. Throws
    /// `invalidDocument` (or `nonFinite`) for a wrong count, an unknown kind or a value out of range.
    public static func force(fromDefine v: [Double]) throws(SceneError) -> SavedForce? {
        guard v.count == 4 else { throw .invalidDocument("force.define") }
        guard let k = index(v[0], count: PlacedForceKind.allCases.count + 1) else { throw .invalidDocument("force.define") }
        guard k > 0 else { return nil }
        let force = SavedForce(kind: PlacedForceKind.allCases[k - 1].rawValue, x: v[1], y: v[2], strength: v[3])
        try force.validate()
        return force
    }

    /// `value` as an index below `count` when it is a whole number, else nil.
    private static func index(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value.rounded() == value, value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }
}
