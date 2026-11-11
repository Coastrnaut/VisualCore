// EffectGraph.swift — the serializable effect-graph description (feature 005 T-F403; FR-F401).

/// A versioned multi-pass effect graph. `inputs` map a pass's input slot to `scene` (the rendered
/// scene) or to another pass's output name; `output` names the pass output that is displayed.
public struct EffectGraphDescription: Codable, Equatable, Sendable {
    /// Graph format version this build accepts (1); other versions fail validation.
    public static let currentVersion = 1
    /// Format version of this description.
    public var version: Int
    /// Passes in declaration order; at most 32.
    public var passes: [EffectPassDescription]
    /// Output name of the pass whose result is displayed.
    public var output: String

    /// Creates a graph description; `version` defaults to `currentVersion`.
    public init(version: Int = EffectGraphDescription.currentVersion, passes: [EffectPassDescription], output: String) {
        self.version = version; self.passes = passes; self.output = output
    }
}

/// One pass in an effect graph: a built-in type, its input bindings, output name, scale and parameters.
public struct EffectPassDescription: Codable, Equatable, Sendable {
    /// Unique pass identifier within the graph.
    public var id: String
    /// Built-in pass type name (see `PassSchemas`).
    public var type: String
    /// Input slot name → `scene` or another pass's output name.
    public var inputs: [String: String]
    /// Unique name of this pass's output target; must not be `scene`.
    public var output: String
    /// Resolution scale relative to the view, 0 < scale ≤ 1.
    public var scale: Double
    /// Parameter values; scalars are one-element arrays.
    public var params: [String: [Double]]

    /// Creates a pass; `scale` defaults to 1 and `params` to empty (schema defaults apply).
    public init(id: String, type: String, inputs: [String: String], output: String, scale: Double = 1,
                params: [String: [Double]] = [:]) {
        self.id = id; self.type = type; self.inputs = inputs; self.output = output; self.scale = scale; self.params = params
    }

    enum CodingKeys: String, CodingKey { case id, type, inputs, output, scale, params }

    /// Decodes a pass; `inputs` and `params` default to empty and `scale` to 1 when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        inputs = try c.decodeIfPresent([String: String].self, forKey: .inputs) ?? [:]
        output = try c.decode(String.self, forKey: .output)
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        params = try c.decodeIfPresent([String: [Double]].self, forKey: .params) ?? [:]
    }
}

/// The reserved input source for the rendered scene.
public let effectSceneSource = "scene"
