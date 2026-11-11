// EffectGraph.swift — the serializable effect-graph description (feature 005 T-F403; FR-F401).

/// A versioned multi-pass effect graph. `inputs` map a pass's input slot to `scene` (the rendered
/// scene) or to another pass's output name; `output` names the pass output that is displayed.
public struct EffectGraphDescription: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var version: Int
    public var passes: [EffectPassDescription]
    public var output: String

    public init(version: Int = EffectGraphDescription.currentVersion, passes: [EffectPassDescription], output: String) {
        self.version = version; self.passes = passes; self.output = output
    }
}

public struct EffectPassDescription: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var inputs: [String: String]
    public var output: String
    /// Resolution scale relative to the view, 0 < scale ≤ 1.
    public var scale: Double
    /// Parameter values; scalars are one-element arrays.
    public var params: [String: [Double]]

    public init(id: String, type: String, inputs: [String: String], output: String, scale: Double = 1,
                params: [String: [Double]] = [:]) {
        self.id = id; self.type = type; self.inputs = inputs; self.output = output; self.scale = scale; self.params = params
    }

    enum CodingKeys: String, CodingKey { case id, type, inputs, output, scale, params }

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
