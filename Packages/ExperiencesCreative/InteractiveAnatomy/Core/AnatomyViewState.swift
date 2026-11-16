// AnatomyViewState — feature 125 (A17-P02) T-A17-203 (FR-A17-205, FR-A17-210; clarification Q5) and feature 126
// (A17-P03) T-A17-305 (FR-A17-304, FR-A17-307; SC-A17-304, SC-A17-305; clarifications Q3, Q4; data-model
// "AnatomyViewState schema 2"; contracts/layers-search.md). The saved state of Interactive Anatomy, schema 2 JSON with
// sorted keys: `schema`, `camera` (`turn`, `tilt`, `zoom`), `visibleLayers` (three booleans: bones, cartilage,
// ligaments), the optional `selection` (a part id), the optional `framed` (the part id the camera frames; kept after
// the selection is cleared until Reset view) and the optional `isolate` (`AnatomyIsolate`: kind, id, mode). A nil
// optional is left out. Schema 1 (A17-P02) is schema 2 without `isolate`; `migrations` turns it into schema 2.
//
// `decode(_:parts:)` refuses, in this order: `damaged` (not a JSON object, no whole-number `schema`, a schema below
// 1), `newer-version` (a schema above 2), `damaged` (a failed migration, any other decoding failure, an isolate that
// is not an object with a string `id`, a `kind` of part or layer and a `mode` of ghost or hide, not exactly three
// layers, or a camera step out of range). A selection, framed or isolate id that does not resolve is dropped, and each
// drop is reported with a reason sentence. A selection whose part's layer is hidden is cleared by
// `normalized(layers:)` unless an isolate is active (the selection is then always drawn solid).
//
// Drawing sets (`solidParts(parts:)`, `ghostParts(parts:)`, inventory indices): without an isolate, the solid parts
// are the parts on shown layers and there are no ghosts; with an isolate, the solid parts are the isolate's target set
// (even when its layer is hidden) plus the selection, and the ghosts are, in the ghost mode, every other part on a
// shown layer, in the hide mode none.
import Foundation
import VisualCorePersistence

/// The saved view of Interactive Anatomy (see the file header).
public struct AnatomyViewState: Codable, Equatable, Sendable {
    /// The schema version this code reads and writes.
    public static let schemaVersion = 2
    /// The opening state: the opening camera, every layer shown, nothing selected, framed or isolated.
    public static let opening = AnatomyViewState(camera: .opening, visibleLayers: [true, true, true], selection: nil,
                                                 framed: nil)
    /// The payload migrations: 1 → 2 adds no isolate (only the schema number changes).
    public static let migrations = MigrationChain(currentVersion: schemaVersion, steps: [
        1: { payload in
            var next = payload
            next["schema"] = 2
            return next
        },
    ])

    /// The schema version of the state.
    public var schema: Int
    /// The camera steps.
    public var camera: AnatomyCameraState
    /// Whether each layer is shown, in `AnatomyLayer.allCases` order (bones, cartilage, ligaments).
    public var visibleLayers: [Bool]
    /// The selected part's id, or nil.
    public var selection: String?
    /// The framed part's id, or nil when the camera frames the whole region.
    public var framed: String?
    /// The isolate, or nil when every shown layer is drawn.
    public var isolate: AnatomyIsolate?

    /// Creates a state at the current schema.
    public init(camera: AnatomyCameraState, visibleLayers: [Bool], selection: String?, framed: String?,
                isolate: AnatomyIsolate? = nil) {
        self.schema = Self.schemaVersion
        self.camera = camera
        self.visibleLayers = visibleLayers
        self.selection = selection
        self.framed = framed
        self.isolate = isolate
    }

    /// The shown layers.
    public var visibleLayerSet: Set<AnatomyLayer> {
        var set = Set<AnatomyLayer>()
        for (index, layer) in AnatomyLayer.allCases.enumerated() where index < visibleLayers.count && visibleLayers[index] {
            set.insert(layer)
        }
        return set
    }

    /// This state with the selection cleared when its part's layer (from `layers`, part id → layer) is hidden and no
    /// isolate is active.
    public func normalized(layers: [String: AnatomyLayer]) -> AnatomyViewState {
        var copy = self
        if isolate == nil, let id = selection, let layer = layers[id], !visibleLayerSet.contains(layer) {
            copy.selection = nil
        }
        return copy
    }

    /// The inventory indices of the parts drawn solid (see the file header); `parts` are the structures with a
    /// parent, in content order.
    public func solidParts(parts: [AnatomicalStructure]) -> Set<Int> {
        guard let isolate else {
            let shown = visibleLayerSet
            return Set(parts.indices.filter { parts[$0].layer.map(shown.contains) ?? false })
        }
        var solid = isolate.targetSet(parts: parts)
        if let selection, let index = parts.firstIndex(where: { $0.id == selection }) { solid.insert(index) }
        return solid
    }

    /// The inventory indices of the parts drawn as translucent ghosts (see the file header).
    public func ghostParts(parts: [AnatomicalStructure]) -> Set<Int> {
        guard let isolate, isolate.mode == .ghost else { return [] }
        let shown = visibleLayerSet
        let solid = solidParts(parts: parts)
        return Set(parts.indices.filter { !solid.contains($0) && (parts[$0].layer.map(shown.contains) ?? false) })
    }

    /// The state as JSON with sorted keys; an isolated part is written by its id among `partIDs` (by default the
    /// bundled right knee's).
    public func encoded(partIDs: [String] = AnatomyIsolate.bundledPartIDs) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.userInfo[AnatomyIsolate.partIDsKey] = partIDs
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Decodes a state of schema 1 or 2 whose ids should be among `parts` (the part ids in inventory order): the
    /// state or the first refusal, and one reason sentence for each dropped id (see the file header).
    @_disfavoredOverload
    public static func decode(_ data: Data, parts: [String])
        -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return (.failure(ContentRefusal(.damaged, "The saved view is not a JSON object.")), [])
        }
        guard let number = object["schema"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let schema = Int(exactly: number.doubleValue) else {
            return (.failure(ContentRefusal(.damaged, "The saved view has no whole-number schema.")), [])
        }
        if schema > schemaVersion {
            return (.failure(ContentRefusal(.newerVersion,
                "The saved view uses schema \(schema), newer than schema \(schemaVersion).")), [])
        }
        if schema < 1 {
            return (.failure(ContentRefusal(.damaged, "The saved view uses schema \(schema), which does not exist.")), [])
        }
        guard var migrated = try? migrations.migrate(object, from: schema) else {
            return (.failure(ContentRefusal(.damaged, "The saved view of schema \(schema) could not be migrated.")), [])
        }
        var dropped: [String] = []
        var isolate: AnatomyIsolate?
        if let raw = migrated.removeValue(forKey: "isolate") {
            switch isolateValue(raw, parts: parts) {
            case .success(let value): isolate = value
            case .failure(let refusal):
                if refusal.reason == .missingReference { dropped.append(refusal.sentence) } else { return (.failure(refusal), []) }
            }
        }
        guard let body = try? JSONSerialization.data(withJSONObject: migrated),
              var state = try? JSONDecoder().decode(AnatomyViewState.self, from: body) else {
            return (.failure(ContentRefusal(.damaged, "The saved view does not match schema \(schema).")), [])
        }
        if state.visibleLayers.count != AnatomyLayer.allCases.count {
            return (.failure(ContentRefusal(.damaged,
                "The saved view has \(state.visibleLayers.count) layer switches, not \(AnatomyLayer.allCases.count).")), [])
        }
        if !state.camera.isValid {
            return (.failure(ContentRefusal(.damaged,
                "The saved camera turn \(state.camera.turn), tilt \(state.camera.tilt) or zoom \(state.camera.zoom) is out of range.")), [])
        }
        let known = Set(parts)
        if let id = state.selection, !known.contains(id) {
            state.selection = nil
            dropped.append("The saved selection \(id) is not a part and was dropped.")
        }
        if let id = state.framed, !known.contains(id) {
            state.framed = nil
            dropped.append("The saved framing \(id) is not a part and was dropped.")
        }
        state.isolate = isolate
        return (.success(state), dropped)
    }

    /// Compatibility path for the A17-P02 callers (to be removed once the experience reads the dropped ids): the
    /// result of the reporting `decode` when nothing was dropped, otherwise a `missing-reference` refusal with the
    /// first drop's sentence.
    public static func decode(_ data: Data, parts: [String]) -> Result<AnatomyViewState, ContentRefusal> {
        let (result, dropped): (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) = decode(data, parts: parts)
        if case .success = result, let first = dropped.first { return .failure(ContentRefusal(.missingReference, first)) }
        return result
    }

    /// The isolate of a raw JSON value: `damaged` when its shape is wrong, `missing-reference` (a drop) when its id
    /// names no part or layer.
    static func isolateValue(_ raw: Any, parts: [String]) -> Result<AnatomyIsolate, ContentRefusal> {
        guard let object = raw as? [String: Any], let kind = object["kind"] as? String, let id = object["id"] as? String,
              let modeText = object["mode"] as? String, let mode = AnatomyIsolate.Mode(rawValue: modeText) else {
            return .failure(ContentRefusal(.damaged, "The saved isolate is not an object with an id, a kind and a mode."))
        }
        switch kind {
        case "part":
            guard let index = parts.firstIndex(of: id) else {
                return .failure(ContentRefusal(.missingReference, "The saved isolate \(id) is not a part and was dropped."))
            }
            return .success(AnatomyIsolate(target: .part(index), mode: mode))
        case "layer":
            guard let layer = AnatomyLayer(rawValue: id) else {
                return .failure(ContentRefusal(.missingReference, "The saved isolate \(id) is not a layer and was dropped."))
            }
            return .success(AnatomyIsolate(target: .layer(layer), mode: mode))
        default:
            return .failure(ContentRefusal(.damaged, "The saved isolate kind \(kind) is neither part nor layer."))
        }
    }
}
