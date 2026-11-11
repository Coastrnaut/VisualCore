// PassSchemas.swift — input slots and parameters (defaults, clamps) of every built-in pass type
// (feature 005 T-F403; FR-F405, FR-F406). Documented in Packages/VisualCoreRendering/README.md.

/// Default value and clamp range of one pass parameter.
public struct ParameterSpec: Sendable, Equatable {
    /// Default used when the graph omits the parameter; scalars are one-element arrays.
    public let defaultValue: [Double]
    /// Closed range every component is clamped to during validation.
    public let range: ClosedRange<Double>
    /// Creates a spec with `defaultValue` and clamp `range`.
    public init(_ defaultValue: [Double], _ range: ClosedRange<Double>) { self.defaultValue = defaultValue; self.range = range }
}

/// Input slots and parameters of one built-in pass type.
public struct PassSchema: Sendable, Equatable {
    /// Pass type name, e.g. `blur` or `bloom`.
    public let type: String
    /// Input slot names that every pass of this type must bind.
    public let inputs: [String]
    /// Accepted parameters by name; unknown parameters are ignored with a warning.
    public let parameters: [String: ParameterSpec]
}

/// Registry of the built-in pass types: copy, colorMatrix, blur, bloom, distort, composite, feedback, flashLimit.
public enum PassSchemas {
    /// Maximum number of passes in one graph (32); more throws `tooManyPasses`.
    public static let maxPasses = 32

    private static let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]

    /// Every built-in pass schema keyed by type name.
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

    /// Schema for `type`, or nil when the type is not built in.
    public static func schema(for type: String) -> PassSchema? { all[type] }

    /// Bytes per pixel of a pass's output (bloom with `hdr` uses half-float RGBA).
    static func bytesPerPixel(type: String, params: [String: [Double]]) -> Int {
        type == "bloom" && (params["hdr"]?.first ?? 0) >= 0.5 ? 8 : 4
    }
}
