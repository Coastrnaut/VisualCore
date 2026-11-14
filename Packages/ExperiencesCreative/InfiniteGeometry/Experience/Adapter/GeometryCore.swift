// GeometryCore — feature 040 (A05-P01) T-A05-104 (FR-A05-120, FR-A05-130; data-model GeometryCore; clarifications).
// The state of Infinite Geometry as an experience: the preparation seed, the curated preset last selected and the
// current preset with the digest and element count of the composition it builds. Every change is checked twice
// before it is taken: the preset must validate (`GeometryPreset.validated()`) and its composition must build within
// its budget (`Composition.build`); a failure refuses the action with the error's code and changes nothing, so an
// accepted state always builds and the outcome `composition-built` holds after the preparation and after every
// accepted change (clarification 5).
//
// Compositions are static: nothing moves with time, so `update(step:)` does nothing and the digest depends only on
// the preparation seed and the accepted actions. The snapshot is the core itself as JSON (seed, preset index,
// preset); decoding rebuilds the composition, so a damaged or foreign payload that no longer builds is refused.
import Foundation
import InfiniteGeometryCore
import VisualCoreExperience
import VisualCorePersistence

/// The state of Infinite Geometry: the preparation seed, the selected curated preset and the current preset with
/// the composition it builds. Schema version 1.
public struct GeometryCore: ExperienceCore, Equatable, Codable {
    /// The experience's id in the catalog.
    public static let experienceID = "a05.infinite-geometry"
    /// The step `reseed` adds to the motif seed (the golden-ratio increment, as Particle Universe's "New seed").
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// The outcome code reached while the current preset builds.
    public static let outcomeCode = "composition-built"
    /// The rule code of `symmetry.order` on a tiling: the lattice fixes the symmetry (FR-A05-120).
    public static let orderFixedCode = "a05.order-fixed-by-lattice"
    /// The rule code of an action that would leave the preset as it is.
    public static let unchangedCode = "a05.unchanged"
    /// The rule code of a preparation or a restore whose preset does not build.
    public static let invalidStateCode = "a05.invalid-state"

    /// The preparation seed; `reset()` returns to curated preset 0 with it.
    public private(set) var seed: UInt64
    /// The index of the curated preset last selected (0 ..< `GeometryPreset.curated.count`).
    public private(set) var presetIndex: Int
    /// The current, validated preset.
    public private(set) var preset: GeometryPreset
    /// The digest of the composition `preset` builds (derived; not encoded, rebuilt on decoding).
    public private(set) var compositionDigest: String
    /// The number of elements of that composition: polygons for a plane, triangles for a solid (derived).
    public private(set) var elementCount: Int

    // MARK: Contract

    /// One schema version, no migration.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The six actions of FR-A05-120 with the ranges of `GeometryPreset`. Whole-number controls round their value.
    public static var controls: [ExperienceControl] {
        [
            ExperienceControl(id: "preset.select", ranges: [0...Double(GeometryPreset.curated.count - 1)]),
            ExperienceControl(id: "symmetry.order", ranges: [range(GeometryPreset.orderRange)]),
            ExperienceControl(id: "repeats.set", ranges: [range(GeometryPreset.repeatsRange)]),
            ExperienceControl(id: "scale.set", ranges: [GeometryPreset.scaleRange]),
            ExperienceControl(id: "palette.set", ranges: [range(GeometryPreset.paletteRange)]),
            ExperienceControl(id: "reseed"),
        ]
    }

    /// An integer range as the closed range of doubles a control declares.
    private static func range(_ r: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(r.lowerBound)...Double(r.upperBound)
    }

    /// Curated preset 0 with `seed` as its motif seed, built once to prove it fits its budget.
    public static func prepare(seed: UInt64) async throws -> GeometryCore {
        try Task.checkCancellation()
        return try GeometryCore(seed: seed)
    }

    /// The preparation: curated preset 0 with `seed` as motif seed. Throws `ExperienceFailure` when it does not build.
    init(seed: UInt64) throws(ExperienceFailure) {
        var start = GeometryPreset.curated[0]
        start.seed = seed
        try self.init(seed: seed, presetIndex: 0, preset: start)
    }

    /// The state of `preset`, validated and built; throws `ExperienceFailure` with the error's code otherwise.
    private init(seed: UInt64, presetIndex: Int, preset: GeometryPreset) throws(ExperienceFailure) {
        guard GeometryPreset.curated.indices.contains(presetIndex) else {
            throw ExperienceFailure(code: Self.invalidStateCode, message: "preset index \(presetIndex)")
        }
        switch Self.build(preset) {
        case .success(let built):
            self.seed = seed
            self.presetIndex = presetIndex
            self.preset = built.preset
            compositionDigest = built.composition.digest
            elementCount = built.composition.elementCount
        case .failure(let rejection):
            throw ExperienceFailure(code: Self.invalidStateCode, message: rejection.code)
        }
    }

    /// Nothing: a composition is static, so a step changes nothing (the digest depends only on the actions).
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action: the candidate preset must differ from the current one, validate and build;
    /// otherwise the action is refused and the state is unchanged.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        var next = preset
        var nextIndex = presetIndex
        switch action.control {
        case "preset.select":
            guard let i = v.first.map({ Int($0.rounded()) }), GeometryPreset.curated.indices.contains(i) else {
                return .rejected(.outOfRange(index: 0))
            }
            next = GeometryPreset.curated[i]
            next.seed = preset.seed          // the motif seed carries over; only `reseed` moves it
            nextIndex = i
        case "symmetry.order":
            guard preset.usesOrder else { return .rejected(.rule(code: Self.orderFixedCode)) }
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.order = Int(n.rounded())
        case "repeats.set":
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.repeats = Int(n.rounded())
        case "scale.set":
            guard let x = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.scale = x
        case "palette.set":
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.palette = Int(n.rounded())
        case "reseed":
            next.seed = preset.seed &+ Self.seedStep
        default:
            return .rejected(.unknownControl(action.control))
        }
        guard next != preset || nextIndex != presetIndex else { return .rejected(.rule(code: Self.unchangedCode)) }
        switch Self.build(next) {
        case .success(let built):
            preset = built.preset
            presetIndex = nextIndex
            compositionDigest = built.composition.digest
            elementCount = built.composition.elementCount
            return .accepted
        case .failure(let rejection):
            return .rejected(rejection)
        }
    }

    /// Back to the preparation: curated preset 0 with the preparation seed (it built when it was prepared).
    public mutating func reset() {
        if let fresh = try? GeometryCore(seed: seed) { self = fresh }
    }

    /// `composition-built`: every state this core holds was built from a validated preset (clarification 5).
    public var outcome: ExperienceOutcome? {
        compositionDigest.isEmpty ? nil : ExperienceOutcome(code: Self.outcomeCode)
    }

    /// The preparation seed, the preset index, every preset field and the composition's digest and element count.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(presetIndex)
        builder.add(Self.kindName(preset.kind))
        builder.add(preset.order)
        builder.add(preset.repeats)
        try builder.add(preset.scale)
        builder.add(preset.palette)
        builder.add(preset.seed)
        builder.add(preset.schemaVersion)
        builder.add(compositionDigest)
        builder.add(elementCount)
    }

    // MARK: Validation

    /// A validated preset and its composition.
    struct Built {
        /// The preset as `validated()` returned it.
        var preset: GeometryPreset
        /// The composition it builds.
        var composition: Composition
    }

    /// Validates `preset` and builds its composition; a failure is a rule rejection with the error's code.
    static func build(_ preset: GeometryPreset) -> Result<Built, ActionRejection> {
        let valid: GeometryPreset
        do throws(PresetError) {
            valid = try preset.validated()
        } catch {
            return .failure(.rule(code: error.code))
        }
        do throws(CompositionError) {
            return .success(Built(preset: valid, composition: try Composition.build(valid)))
        } catch {
            return .failure(.rule(code: error.code))
        }
    }

    /// The current composition, rebuilt from the preset (it built when the preset was accepted).
    public func composition() -> Composition? {
        try? Composition.build(preset)
    }

    // MARK: Names

    /// The spoken and displayed name of a preset kind.
    public static func kindName(_ kind: GeometryPreset.Kind) -> String {
        switch kind {
        case .squareTiling: "Square tiling"
        case .hexTiling: "Hexagonal tiling"
        case .kaleidoscope: "Kaleidoscope"
        case .solid: "3D composition"
        }
    }

    /// The symmetry in words: the lattice's fixed symmetry for a tiling, the order otherwise.
    public static func symmetryText(_ preset: GeometryPreset) -> String {
        switch preset.kind {
        case .squareTiling: "square lattice symmetry p4m"
        case .hexTiling: "hexagonal lattice symmetry p6m"
        case .kaleidoscope: "\(preset.order)-fold mirror symmetry"
        case .solid: "\(preset.order)-fold rotational symmetry"
        }
    }

    // MARK: Snapshot

    private enum CodingKeys: String, CodingKey {
        case seed, presetIndex, preset
    }

    /// Decodes the seed, the preset index and the preset, then validates and rebuilds; a payload whose preset does
    /// not build fails with `ExperienceFailure` (`a05.invalid-state`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(seed: try c.decode(UInt64.self, forKey: .seed),
                      presetIndex: try c.decode(Int.self, forKey: .presetIndex),
                      preset: try c.decode(GeometryPreset.self, forKey: .preset))
    }

    /// Encodes the seed, the preset index and the preset; the composition is derived and rebuilt on decoding.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seed, forKey: .seed)
        try c.encode(presetIndex, forKey: .presetIndex)
        try c.encode(preset, forKey: .preset)
    }
}
