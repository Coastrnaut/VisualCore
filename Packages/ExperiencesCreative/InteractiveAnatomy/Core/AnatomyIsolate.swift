// AnatomyIsolate — feature 126 (A17-P03) T-A17-305 (FR-A17-304; SC-A17-304; clarification Q3, Q4; data-model
// "AnatomyIsolate"; contracts/layers-search.md). What the learner isolates: one part (by inventory index) or one
// layer, drawn solid together with the selection; in the ghost mode (the default) every other part on a shown layer is
// drawn translucent, in the hide mode nothing else is drawn. The sets themselves are computed by
// `AnatomyViewState.solidParts(parts:)` and `ghostParts(parts:)`.
//
// JSON (inside the view state, schema 2): `{"id": …, "kind": "part" | "layer", "mode": "ghost" | "hide"}`, where the
// id of a part is its structure id and the id of a layer its raw value. A part index maps to its id through the part
// ids given in the coder's `userInfo[AnatomyIsolate.partIDsKey]` (`[String]`), or the bundled right knee's part ids
// when none are given. `AnatomyViewState.decode(_:parts:)` reads the isolate itself, so an unknown id is dropped with a
// reason there instead of failing the whole view.
import Foundation

/// An isolate: a target and a mode (see the file header).
public struct AnatomyIsolate: Codable, Equatable, Sendable {
    /// What is isolated.
    public enum Target: Equatable, Hashable, Sendable {
        /// One part, by inventory index (among the structures with a parent, in content order).
        case part(Int)
        /// One layer.
        case layer(AnatomyLayer)
    }

    /// How the parts outside the isolate are drawn.
    public enum Mode: String, Codable, CaseIterable, Sendable {
        /// Drawn translucent (the default).
        case ghost
        /// Not drawn.
        case hide
    }

    /// The `userInfo` key under which a coder carries the part ids (`[String]`, in inventory order).
    public static let partIDsKey = CodingUserInfoKey(rawValue: "a17.partIDs")!

    /// The part ids of the bundled right knee, in inventory order; empty when the bundled content cannot be read.
    public static let bundledPartIDs: [String] = {
        guard let region = try? AnatomyContent.bundledRightKnee() else { return [] }
        return region.structures.filter { $0.parent != nil }.map(\.id)
    }()

    /// What is isolated.
    public var target: Target
    /// How the other parts are drawn.
    public var mode: Mode

    /// Creates an isolate; the mode defaults to ghost.
    public init(target: Target, mode: Mode = .ghost) {
        self.target = target
        self.mode = mode
    }

    /// The inventory indices of the target among `parts`: the part itself (when in range) or every part of the layer.
    public func targetSet(parts: [AnatomicalStructure]) -> Set<Int> {
        switch target {
        case .part(let index):
            return parts.indices.contains(index) ? [index] : []
        case .layer(let layer):
            return Set(parts.indices.filter { parts[$0].layer == layer })
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, mode
    }

    /// Decodes `{"id", "kind", "mode"}`; a part id is resolved through ``partIDsKey`` or ``bundledPartIDs``.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let id = try container.decode(String.self, forKey: .id)
        mode = try container.decode(Mode.self, forKey: .mode)
        let partIDs = decoder.userInfo[Self.partIDsKey] as? [String] ?? Self.bundledPartIDs
        switch kind {
        case "part":
            guard let index = partIDs.firstIndex(of: id) else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container,
                                                       debugDescription: "\(id) is not a part.")
            }
            target = .part(index)
        case "layer":
            guard let layer = AnatomyLayer(rawValue: id) else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container,
                                                       debugDescription: "\(id) is not a layer.")
            }
            target = .layer(layer)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container,
                                                   debugDescription: "\(kind) is not part or layer.")
        }
    }

    /// Encodes `{"id", "kind", "mode"}`; a part index is mapped through ``partIDsKey`` or ``bundledPartIDs``.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch target {
        case .part(let index):
            let partIDs = encoder.userInfo[Self.partIDsKey] as? [String] ?? Self.bundledPartIDs
            guard partIDs.indices.contains(index) else {
                throw EncodingError.invalidValue(index, EncodingError.Context(codingPath: encoder.codingPath,
                                                 debugDescription: "Part index \(index) is out of range."))
            }
            try container.encode("part", forKey: .kind)
            try container.encode(partIDs[index], forKey: .id)
        case .layer(let layer):
            try container.encode("layer", forKey: .kind)
            try container.encode(layer.rawValue, forKey: .id)
        }
        try container.encode(mode, forKey: .mode)
    }
}
