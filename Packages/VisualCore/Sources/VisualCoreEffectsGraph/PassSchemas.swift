// PassSchemas.swift — input slots and parameters (defaults, clamps) of every built-in pass type
// (feature 005 T-F403; FR-F405, FR-F406). Documented in Packages/VisualCoreRendering/README.md.

public struct ParameterSpec: Sendable, Equatable {
    public let defaultValue: [Double]
    public let range: ClosedRange<Double>
    public init(_ defaultValue: [Double], _ range: ClosedRange<Double>) { self.defaultValue = defaultValue; self.range = range }
}

public struct PassSchema: Sendable, Equatable {
    public let type: String
    public let inputs: [String]
    public let parameters: [String: ParameterSpec]
}

public enum PassSchemas {
    public static let maxPasses = 32

    private static let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]

    public static let all: [String: PassSchema] = [
        "copy": PassSchema(type: "copy", inputs: ["input"], parameters: [:]),
        "colorMatrix": PassSchema(type: "colorMatrix", inputs: ["input"], parameters: [
            "matrix": ParameterSpec(identity, -10...10), "offset": ParameterSpec([0, 0, 0, 0], -1...1)]),
        "blur": PassSchema(type: "blur", inputs: ["input"], parameters: ["radius": ParameterSpec([4], 1...32)]),
        "bloom": PassSchema(type: "bloom", inputs: ["input"], parameters: [
            "threshold": ParameterSpec([0.8], 0...1), "intensity": ParameterSpec([1], 0...4),
            "radius": ParameterSpec([8], 1...32), "hdr": ParameterSpec([0], 0...1)]),
        "distort": PassSchema(type: "distort", inputs: ["input"], parameters: [
            "strength": ParameterSpec([0.02], 0...0.2), "frequency": ParameterSpec([8], 0...64), "speed": ParameterSpec([1], 0...10)]),
        "composite": PassSchema(type: "composite", inputs: ["base", "overlay"], parameters: [
            "mode": ParameterSpec([0], 0...1), "opacity": ParameterSpec([1], 0...1)]),
        "feedback": PassSchema(type: "feedback", inputs: ["input"], parameters: ["decay": ParameterSpec([0.9], 0...1)]),
        "flashLimit": PassSchema(type: "flashLimit", inputs: ["input"], parameters: ["limit": ParameterSpec([0.3], 0.05...1)]),
    ]

    public static func schema(for type: String) -> PassSchema? { all[type] }

    /// Bytes per pixel of a pass's output (bloom with `hdr` uses half-float RGBA).
    static func bytesPerPixel(type: String, params: [String: [Double]]) -> Int {
        type == "bloom" && (params["hdr"]?.first ?? 0) >= 0.5 ? 8 : 4
    }
}
