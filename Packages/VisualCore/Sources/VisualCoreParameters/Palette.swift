// Palette.swift — named color gradients stored in sRGB and interpolated in linear light (feature 012 T-A01-102;
// docs/rendering/color-space.md).
import Foundation

/// A named color gradient of 2–8 sRGB stops (components 0…1), sampled in linear light.
public struct Palette: Codable, Equatable, Sendable, Identifiable {
    /// Stable id matching `^[a-z0-9-]{1,40}$`.
    public let id: String
    /// User-facing name.
    public let name: String
    /// Color stops in sRGB, evenly spaced from 0 to 1.
    public let stops: [SIMD3<Double>]

    /// Creates a validated palette; throws `.invalidPalette` for a bad id, stop count or component.
    public init(id: String, name: String, stops: [SIMD3<Double>]) throws(ParameterError) {
        guard id.range(of: #"^[a-z0-9-]{1,40}$"#, options: .regularExpression) != nil, (2...8).contains(stops.count),
              stops.allSatisfy({ s in (0..<3).allSatisfy { s[$0].isFinite && (0...1).contains(s[$0]) } })
        else { throw .invalidPalette(id) }
        self.id = id
        self.name = name
        self.stops = stops
    }

    /// Decodes and re-validates a palette.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(id: c.decode(String.self, forKey: .id), name: c.decode(String.self, forKey: .name),
                          stops: c.decode([SIMD3<Double>].self, forKey: .stops))
        } catch let e as ParameterError {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "\(e)"))
        }
    }

    /// The exact sRGB transfer function, decoding one encoded component to linear light.
    public static func linear(fromSRGB c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    /// The exact sRGB transfer function, encoding one linear component.
    public static func sRGB(fromLinear c: Double) -> Double { c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055 }

    /// Stops converted to linear light (what shaders receive).
    public var linearStops: [SIMD3<Double>] { stops.map { SIMD3(Self.linear(fromSRGB: $0.x), Self.linear(fromSRGB: $0.y), Self.linear(fromSRGB: $0.z)) } }

    /// The linear-light color at `t` (clamped to 0…1), interpolated between evenly spaced stops.
    public func sample(_ t: Double) -> SIMD3<Double> {
        let lin = linearStops
        let x = min(max(t.isFinite ? t : 0, 0), 1) * Double(lin.count - 1)
        let i = min(Int(x), lin.count - 2)
        let f = x - Double(i)
        return lin[i] * (1 - f) + lin[i + 1] * f
    }

    // swiftlint:disable force_try
    /// Six general-purpose palettes any app may offer.
    public static let builtIns: [Palette] = [
        try! Palette(id: "sunset", name: "Sunset", stops: [SIMD3(0.13, 0.05, 0.25), SIMD3(0.76, 0.18, 0.36), SIMD3(0.98, 0.56, 0.24), SIMD3(1.0, 0.89, 0.55)]),
        try! Palette(id: "ocean", name: "Ocean", stops: [SIMD3(0.01, 0.07, 0.18), SIMD3(0.02, 0.33, 0.52), SIMD3(0.17, 0.71, 0.75), SIMD3(0.86, 0.97, 0.94)]),
        try! Palette(id: "forest", name: "Forest", stops: [SIMD3(0.05, 0.12, 0.06), SIMD3(0.18, 0.39, 0.16), SIMD3(0.55, 0.69, 0.27), SIMD3(0.93, 0.91, 0.62)]),
        try! Palette(id: "neon", name: "Neon", stops: [SIMD3(0.04, 0.0, 0.12), SIMD3(0.98, 0.0, 0.62), SIMD3(0.0, 0.94, 0.98), SIMD3(0.95, 1.0, 0.2)]),
        try! Palette(id: "mono", name: "Monochrome", stops: [SIMD3(0.02, 0.02, 0.02), SIMD3(0.98, 0.98, 0.98)]),
        try! Palette(id: "ember", name: "Ember", stops: [SIMD3(0.0, 0.0, 0.0), SIMD3(0.45, 0.04, 0.02), SIMD3(0.93, 0.33, 0.04), SIMD3(1.0, 0.85, 0.4)]),
    ]
    // swiftlint:enable force_try

    /// The built-in palette with `id`, if any.
    public static func builtIn(_ id: String) -> Palette? { builtIns.first { $0.id == id } }
}
