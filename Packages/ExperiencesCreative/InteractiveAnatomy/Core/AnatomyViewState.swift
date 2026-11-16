// AnatomyViewState — feature 125 (A17-P02) T-A17-203 (FR-A17-205, FR-A17-210; clarification Q5; data-model
// "AnatomyViewState"; contracts/scene.md). The saved state of Interactive Anatomy, schema 1 JSON with sorted keys:
// `schema`, `camera` (`turn`, `tilt`, `zoom`), `visibleLayers` (three booleans: bones, cartilage, ligaments), the
// optional `selection` (a part id) and the optional `framed` (the part id the camera frames; kept after the selection
// is cleared until Reset view). A nil optional is left out.
//
// `decode(_:parts:)` refuses, in this order: `damaged` (not a JSON object, no whole-number `schema`, a schema below
// 1), `newer-version` (a schema above 1), `damaged` (any other decoding failure, not exactly three layers, or a camera
// step out of range), `missing-reference` (a selection or framed id that is not a part). A selection whose part's
// layer is hidden is cleared by `normalized(layers:)`, as when the layer is hidden.
import Foundation

/// The saved view of Interactive Anatomy (see the file header).
public struct AnatomyViewState: Codable, Equatable, Sendable {
    /// The schema version this code reads and writes.
    public static let schemaVersion = 1
    /// The opening state: the opening camera, every layer shown, nothing selected or framed.
    public static let opening = AnatomyViewState(camera: .opening, visibleLayers: [true, true, true], selection: nil,
                                                 framed: nil)

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

    /// Creates a state at the current schema.
    public init(camera: AnatomyCameraState, visibleLayers: [Bool], selection: String?, framed: String?) {
        self.schema = Self.schemaVersion
        self.camera = camera
        self.visibleLayers = visibleLayers
        self.selection = selection
        self.framed = framed
    }

    /// The shown layers.
    public var visibleLayerSet: Set<AnatomyLayer> {
        var set = Set<AnatomyLayer>()
        for (index, layer) in AnatomyLayer.allCases.enumerated() where index < visibleLayers.count && visibleLayers[index] {
            set.insert(layer)
        }
        return set
    }

    /// This state with the selection cleared when its part's layer (from `layers`, part id → layer) is hidden.
    public func normalized(layers: [String: AnatomyLayer]) -> AnatomyViewState {
        var copy = self
        if let id = selection, let layer = layers[id], !visibleLayerSet.contains(layer) { copy.selection = nil }
        return copy
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Decodes a state whose ids must be among `parts`, or the first refusal (see the file header).
    public static func decode(_ data: Data, parts: [String]) -> Result<AnatomyViewState, ContentRefusal> {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(ContentRefusal(.damaged, "The saved view is not a JSON object."))
        }
        guard let number = object["schema"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let schema = Int(exactly: number.doubleValue) else {
            return .failure(ContentRefusal(.damaged, "The saved view has no whole-number schema."))
        }
        if schema > schemaVersion {
            return .failure(ContentRefusal(.newerVersion,
                                           "The saved view uses schema \(schema), newer than schema \(schemaVersion)."))
        }
        if schema < 1 {
            return .failure(ContentRefusal(.damaged, "The saved view uses schema \(schema), which does not exist."))
        }
        guard let state = try? JSONDecoder().decode(AnatomyViewState.self, from: data) else {
            return .failure(ContentRefusal(.damaged, "The saved view does not match schema \(schema)."))
        }
        if state.visibleLayers.count != AnatomyLayer.allCases.count {
            return .failure(ContentRefusal(.damaged,
                "The saved view has \(state.visibleLayers.count) layer switches, not \(AnatomyLayer.allCases.count)."))
        }
        if !state.camera.isValid {
            return .failure(ContentRefusal(.damaged,
                "The saved camera turn \(state.camera.turn), tilt \(state.camera.tilt) or zoom \(state.camera.zoom) is out of range."))
        }
        let known = Set(parts)
        for id in [state.selection, state.framed].compactMap({ $0 }) where !known.contains(id) {
            return .failure(ContentRefusal(.missingReference, "The saved view names \(id), which is not a part."))
        }
        return .success(state)
    }
}
