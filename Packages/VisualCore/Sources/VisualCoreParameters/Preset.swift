// Preset.swift — a named starting point: seed, palette and parameter values (feature 012 T-A01-102).
import Foundation

/// A curated starting point for a scene: title, seed, palette and parameter values. The seed is encoded as a decimal
/// string because JSON numbers lose precision above 2^53.
public struct Preset: Codable, Equatable, Sendable, Identifiable {
    /// Stable id.
    public let id: String
    /// User-facing title.
    public let title: String
    /// Seed for deterministic generation (full 64-bit range).
    public let seed: UInt64
    /// Palette id.
    public let paletteID: String
    /// Parameter values by name (resolved against a schema before use).
    public let values: [String: Double]

    /// Creates a preset.
    public init(id: String, title: String, seed: UInt64, paletteID: String, values: [String: Double]) {
        self.id = id
        self.title = title
        self.seed = seed
        self.paletteID = paletteID
        self.values = values
    }

    private enum CodingKeys: String, CodingKey { case id, title, seed, paletteID, values }

    /// Decodes a preset; the seed must be a decimal string representing a UInt64.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let seed = UInt64(try c.decode(String.self, forKey: .seed)) else {
            throw DecodingError.dataCorruptedError(forKey: .seed, in: c, debugDescription: "seed must be a decimal UInt64 string")
        }
        self.init(id: try c.decode(String.self, forKey: .id), title: try c.decode(String.self, forKey: .title), seed: seed,
                  paletteID: try c.decode(String.self, forKey: .paletteID), values: try c.decode([String: Double].self, forKey: .values))
    }

    /// Encodes the preset with the seed as a decimal string.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(String(seed), forKey: .seed)
        try c.encode(paletteID, forKey: .paletteID)
        try c.encode(values, forKey: .values)
    }
}
