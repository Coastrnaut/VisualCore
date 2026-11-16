// AnatomyCore — feature 125 (A17-P02) T-A17-204 (FR-A17-202–208; clarifications Q1–Q5; contracts/scene.md). The state
// of Interactive Anatomy as an experience: the bundled right knee (`AnatomyContent.bundledRightKnee()`), its scene at
// both quality levels (`AnatomyScene.build`, built once per process and cached; a level change selects the other
// scene and changes nothing else), the canonical `AnatomyViewState` (camera steps, visible layers, selection, framed
// part) and the preparation seed. Nothing animates: a host step changes nothing.
//
// Preparation: every seed opens with the opening view (`AnatomyViewState.opening`: the opening camera, every layer
// shown, nothing selected or framed). Content the scene cannot build (or content refused) makes `prepare(seed:)`
// throw an `ExperienceFailure` (`a17.scene-refused` or `a17.content-refused`) whose message is the refusal's sentence,
// so the experience does not open.
//
// Actions (numbers; the engine refuses a value outside the declared range, a non-finite value and a wrong value
// count before the core sees it; called directly, the core refuses an unknown control and a wrong count itself):
//   structure.select [0…13]   the part by inventory index: selected and framed; a value that is not a whole index is
//                             refused with `a17.invalid-choice`, a part on a hidden layer with `a17.hidden-structure`.
//   structure.clear           clears the selection; the framing stays until Reset view.
//   layer.show [0…2, 0…1]     shows (1) or hides (0) a layer (bones, cartilage, ligaments); a value that is not a
//                             whole index or exactly 0 or 1 is refused with `a17.invalid-choice`. Hiding the selected
//                             part's layer clears the selection.
//   camera.turn [−1…1]        one 15° turn step, wrapping; camera.tilt [−1…1] one 10° step within −6…6; camera.zoom
//                             [−1…1] one × 0.85 step within −4…6. A value other than ±1 is refused with
//                             `a17.invalid-choice`, a step beyond a limit with `a17.camera-limit`.
//   view.reset                the opening camera, framing the region; the selection and the layers stay.
// A refusal changes nothing.
//
// Digest: "a17.anatomy.v1|" and the canonical JSON of the view state (`AnatomyViewState.encoded()`), so drawing and
// the quality tier never change it. Snapshot schema 1 (`MigrationChain(currentVersion: 1)`): the payload is the view
// state's JSON; `restore` decodes it with `AnatomyViewState.decode(_:parts:)` (damaged, newer or an unknown part id
// throw ``AnatomyRestoreError``) and clears a selection on a hidden layer.
//
// Outcome: `selected-<part id with dots as hyphens>` ("selected-knee-femur") while a part is selected, else
// `viewing-knee`. The canvas description: "Right knee, <shown layers in words, joined by commas, or 'no layer
// shown'>; selected: <English name or 'nothing selected'>."
import Foundation
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence

/// The rule codes of Interactive Anatomy's refusals.
public enum AnatomyRule {
    /// A camera step beyond its limit (tilt −6…6, zoom −4…6).
    public static let cameraLimit = "a17.camera-limit"
    /// Selecting a part whose layer is hidden.
    public static let hiddenStructure = "a17.hidden-structure"
    /// A value that is not a whole index, a layer switch other than 0 or 1, or a camera step other than ±1.
    public static let invalidChoice = "a17.invalid-choice"
}

/// Why a stored Interactive Anatomy state is refused.
public enum AnatomyRestoreError: Error, Equatable {
    /// `AnatomyViewState.decode(_:parts:)` refused the payload.
    case refused(ContentRefusal)
}

/// The state of Interactive Anatomy (see the file header).
public struct AnatomyCore: ExperienceCore {
    /// The experience's id in the catalog.
    public static let experienceID = "a17.interactive-anatomy"
    /// The failure code of a preparation whose scene could not be built.
    public static let sceneRefusedCode = "a17.scene-refused"
    /// The failure code of a preparation whose bundled content was refused.
    public static let contentRefusedCode = "a17.content-refused"
    /// The action ids in declaration order.
    public static let actionIDs = ["structure.select", "structure.clear", "layer.show", "camera.turn", "camera.tilt",
                                   "camera.zoom", "view.reset"]
    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["structure.select": 1, "structure.clear": 0, "layer.show": 2,
                                             "camera.turn": 1, "camera.tilt": 1, "camera.zoom": 1, "view.reset": 0]
    /// The number of parts of the bundled knee (inventory order).
    public static let partCount = 14

    /// The region and its scenes at every quality level.
    struct Prepared: Sendable {
        /// The region.
        let region: AnatomyRegion
        /// The scenes by quality level.
        let scenes: [AnatomyScene]
    }

    /// The bundled right knee and its scenes, built once.
    static let bundled: Result<Prepared, ExperienceFailure> = {
        do {
            return prepared(try AnatomyContent.bundledRightKnee())
        } catch let refusal as ContentRefusal {
            return .failure(ExperienceFailure(code: contentRefusedCode, message: refusal.sentence))
        } catch {
            return .failure(ExperienceFailure(code: contentRefusedCode, message: "The bundled knee could not be read."))
        }
    }()

    /// `region` with its scene at every level of `AnatomyQuality.levels`, or the first scene refusal as a failure.
    static func prepared(_ region: AnatomyRegion) -> Result<Prepared, ExperienceFailure> {
        var scenes: [AnatomyScene] = []
        for quality in AnatomyQuality.levels {
            switch AnatomyScene.build(region, quality: quality) {
            case .success(let scene): scenes.append(scene)
            case .failure(let refusal):
                return .failure(ExperienceFailure(code: sceneRefusedCode, message: refusal.sentence))
            }
        }
        return .success(Prepared(region: region, scenes: scenes))
    }

    /// The preparation seed; `reset()` returns to the opening state.
    public private(set) var preparationSeed: UInt64
    /// The canonical view state (camera, layers, selection, framing).
    public internal(set) var view: AnatomyViewState
    /// The region drawn.
    public let region: AnatomyRegion
    /// The scene at every quality level.
    let scenes: [AnatomyScene]
    /// The quality tier in use (0 full, 1 reduced).
    public private(set) var tier = 0

    /// The opening state of the bundled knee with `seed`; throws the `ExperienceFailure` of unbuildable content.
    public init(seed: UInt64) throws {
        try self.init(seed: seed, prepared: Self.bundled.get())
    }

    /// The opening state of `region` with `seed` (the test seam for unbuildable content); throws the
    /// `ExperienceFailure` whose message is the scene refusal's sentence.
    init(seed: UInt64, region: AnatomyRegion) throws {
        try self.init(seed: seed, prepared: Self.prepared(region).get())
    }

    /// A core over `prepared` holding `view`.
    init(seed: UInt64, prepared: Prepared, view: AnatomyViewState = .opening) {
        preparationSeed = seed
        region = prepared.region
        scenes = prepared.scenes
        self.view = view
    }

    /// The scene of the current quality tier.
    public var scene: AnatomyScene { scenes[min(max(tier, 0), scenes.count - 1)] }
    /// The part ids in inventory order.
    public var partIDs: [String] { scene.parts.map(\.id) }
    /// The shown layers.
    public var visibleLayers: Set<AnatomyLayer> { view.visibleLayerSet }
    /// The selected part's inventory index, or nil.
    public var selectedIndex: Int? { view.selection.flatMap { scene.partIndex($0) } }
    /// The framed part's inventory index, or nil when the region is framed.
    public var framedIndex: Int? { view.framed.flatMap { scene.partIndex($0) } }

    /// The layer of the part at `index` (bones for a part without one).
    func layer(ofPart index: Int) -> AnatomyLayer { scene.parts[index].layer ?? .bones }

    /// The camera at `aspect` (width / height): framing the framed part's sphere, else the region's.
    public func camera(aspect: Double) -> OrbitCamera {
        let sphere: (center: Vec3, radius: Double) = framedIndex.map { scene.structureSphere($0) }
            ?? (scene.regionCenter, scene.regionRadius)
        return view.camera.camera(center: sphere.center, radius: sphere.radius, aspect: aspect)
    }

    // MARK: Contract

    /// Two quality tiers, one per `AnatomyQuality` level.
    public static var qualityTiers: Int { AnatomyQuality.levels.count }

    /// Schema 1 only (the first schema).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: AnatomyViewState.schemaVersion)
    }

    /// The seven controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "structure.select", ranges: [0...Double(partCount - 1)]),
         ExperienceControl(id: "structure.clear"),
         ExperienceControl(id: "layer.show", ranges: [0...Double(AnatomyLayer.allCases.count - 1), 0...1]),
         ExperienceControl(id: "camera.turn", ranges: [-1...1]),
         ExperienceControl(id: "camera.tilt", ranges: [-1...1]),
         ExperienceControl(id: "camera.zoom", ranges: [-1...1]),
         ExperienceControl(id: "view.reset")]
    }

    /// The opening state with `seed`; throws the `ExperienceFailure` of unbuildable content.
    public static func prepare(seed: UInt64) async throws -> AnatomyCore {
        try Task.checkCancellation()
        let prepared = try bundled.get()
        try Task.checkCancellation()
        return AnatomyCore(seed: seed, prepared: prepared)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let invalid = ActionResult.rejected(.rule(code: AnatomyRule.invalidChoice))
        let limit = ActionResult.rejected(.rule(code: AnatomyRule.cameraLimit))
        var next = view
        switch action.control {
        case "structure.select":
            guard let index = Self.choice(v[0], count: scene.parts.count) else { return invalid }
            guard visibleLayers.contains(layer(ofPart: index)) else {
                return .rejected(.rule(code: AnatomyRule.hiddenStructure))
            }
            next.selection = scene.parts[index].id
            next.framed = scene.parts[index].id
        case "structure.clear":
            next.selection = nil
        case "layer.show":
            guard let index = Self.choice(v[0], count: AnatomyLayer.allCases.count), v[1] == 0 || v[1] == 1 else {
                return invalid
            }
            next.visibleLayers[index] = v[1] == 1
            next = next.normalized(layers: partLayers)
        case "view.reset":
            next.camera = .opening
            next.framed = nil
        default:   // camera.turn, camera.tilt, camera.zoom
            guard let step = Self.unitStep(v[0]) else { return invalid }
            switch action.control {
            case "camera.turn": guard next.camera.turn(step) else { return limit }
            case "camera.tilt": guard next.camera.tilt(step) else { return limit }
            default: guard next.camera.zoom(step) else { return limit }
            }
        }
        view = next
        return .accepted
    }

    /// Part id → layer, for `AnatomyViewState.normalized(layers:)`.
    var partLayers: [String: AnatomyLayer] {
        var map: [String: AnatomyLayer] = [:]
        for part in scene.parts { map[part.id] = part.layer ?? .bones }
        return map
    }

    /// The camera step named by `value`: exactly −1 or +1; nil otherwise.
    static func unitStep(_ value: Double) -> Int? {
        value == 1 ? 1 : value == -1 ? -1 : nil
    }

    /// The index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// Back to the opening state (the scenes and the tier stay).
    public mutating func reset() {
        view = .opening
    }

    /// Selects the scene of `tier` (clamped to the levels); never changes the digest.
    public mutating func setQualityTier(_ tier: Int) {
        self.tier = min(max(tier, 0), scenes.count - 1)
    }

    /// `selected-<part id>` while a part is selected, else `viewing-knee` (see the file header).
    public var outcome: ExperienceOutcome? {
        guard let id = view.selection else { return ExperienceOutcome(code: "viewing-knee") }
        return ExperienceOutcome(code: Self.outcomeCode(partID: id))
    }

    /// The outcome code of the part `partID`: "selected-" and the id with dots as hyphens.
    public static func outcomeCode(partID: String) -> String {
        "selected-" + partID.replacingOccurrences(of: ".", with: "-")
    }

    /// "a17.anatomy.v1|" and the canonical JSON of the view state.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: view.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a17.anatomy.v1|" + text)
    }

    /// The view state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        view.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed`; a refused payload throws
    /// ``AnatomyRestoreError/refused(_:)``, unbuildable content the preparation's `ExperienceFailure`.
    public static func restore(payload: Data, seed: UInt64) throws -> AnatomyCore {
        let prepared = try bundled.get()
        var core = AnatomyCore(seed: seed, prepared: prepared)
        switch AnatomyViewState.decode(payload, parts: core.partIDs) {
        case .success(let state): core.view = state.normalized(layers: core.partLayers)
        case .failure(let refusal): throw AnatomyRestoreError.refused(refusal)
        }
        return core
    }

    // MARK: Words

    /// The words of `layer`: "bones", "cartilage and menisci", "ligaments and tendons".
    public static func layerWords(_ layer: AnatomyLayer) -> String {
        switch layer {
        case .bones: return "bones"
        case .cartilage: return "cartilage and menisci"
        case .ligaments: return "ligaments and tendons"
        }
    }

    /// The canvas description (see the file header).
    public func describe() -> String {
        let shown = AnatomyLayer.allCases.filter { visibleLayers.contains($0) }.map(Self.layerWords)
        let layers = shown.isEmpty ? "no layer shown" : shown.joined(separator: ", ")
        let selected = selectedIndex.map { scene.parts[$0].englishName } ?? "nothing selected"
        return "Right knee, \(layers); selected: \(selected)."
    }
}
