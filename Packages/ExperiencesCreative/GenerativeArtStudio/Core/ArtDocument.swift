// ArtDocument.swift — the versioned, validated composition document (feature 012 T-A01-107; FR-A01-103–FR-A01-106).
import Foundation
import VisualCoreParameters

/// Why a document could not be used.
public enum DocumentError: Error, Equatable, Sendable {
    /// The scene family id is not one of `SceneFamilyID`.
    case unknownFamily(String)
    /// The schema version is newer than supported (or below 1).
    case unsupportedVersion(Int)
    /// A parameter value is NaN or infinite, or the preview time is.
    case nonFinite(String)
    /// The data is not a decodable document.
    case corrupt(String)
}

/// A composition: scene family, seed, palette, parameter values and preview time. Pure data; rendering depends only on
/// this and an explicit time. JSON stores the seed as a decimal string (exact for the full 64-bit range).
public struct ArtDocument: Codable, Equatable, Sendable, Identifiable {
    /// The schema version this build writes and reads.
    public static let currentSchemaVersion = 1
    /// Upper bound of `previewTime` (seconds); also bounds particle replay work.
    public static let maxPreviewTime = 120.0

    /// Document id.
    public var id: UUID
    /// Schema version of the stored form.
    public var schemaVersion: Int
    /// Scene family id (raw `SceneFamilyID`).
    public var familyID: String
    /// Seed for every random choice (full 64-bit range).
    public var seed: UInt64
    /// Palette id.
    public var paletteID: String
    /// Parameter values by name.
    public var parameters: [String: Double]
    /// Time at which still previews render (seconds, 0…120).
    public var previewTime: Double

    /// Creates a document of the current schema version.
    public init(id: UUID = UUID(), family: SceneFamilyID, seed: UInt64, paletteID: String, parameters: [String: Double], previewTime: Double = 0) {
        self.id = id
        schemaVersion = Self.currentSchemaVersion
        familyID = family.rawValue
        self.seed = seed
        self.paletteID = paletteID
        self.parameters = parameters
        self.previewTime = previewTime
    }

    /// A document from a family's preset.
    public static func from(_ preset: Preset, family: SceneFamilyID, id: UUID = UUID()) -> ArtDocument {
        ArtDocument(id: id, family: family, seed: preset.seed, paletteID: preset.paletteID, parameters: preset.values)
    }

    /// The validated form: parameters resolved through the family schema (clamped, defaults filled, unknown names
    /// dropped), an unknown palette replaced by the family default, preview time clamped to 0…120; with warnings.
    public func validated() throws(DocumentError) -> (document: ArtDocument, warnings: [String]) {
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else { throw .unsupportedVersion(schemaVersion) }
        guard let familyID = SceneFamilyID(rawValue: familyID) else { throw .unknownFamily(self.familyID) }
        guard previewTime.isFinite else { throw .nonFinite("previewTime") }
        let family = FamilyCatalog.family(familyID)
        let resolved: ResolvedParameters
        do { resolved = try family.schema.resolve(parameters) } catch {
            if case .nonFinite(let name) = error { throw .nonFinite(name) }
            throw .corrupt("\(error)")
        }
        var out = self
        var warnings = resolved.warnings
        out.parameters = resolved.values
        if FamilyCatalog.palette(paletteID) == nil {
            warnings.append("palette '\(paletteID)' unknown; using '\(family.defaultPaletteID)'")
            out.paletteID = family.defaultPaletteID
        }
        let clamped = min(max(previewTime, 0), Self.maxPreviewTime)
        if clamped != previewTime { warnings.append("previewTime \(previewTime) clamped to \(clamped)") }
        out.previewTime = clamped
        return (out, warnings)
    }

    /// The family of a validated document.
    public var family: SceneFamily? { SceneFamilyID(rawValue: familyID).map(FamilyCatalog.family) }

    /// Stable hash of family, seed, palette and parameters (thumbnail cache key).
    public var hash: String { ParameterHash.of(scope: familyID, seed: seed, paletteID: paletteID, values: parameters) }

    /// Canonical JSON: sorted keys, seed as a decimal string.
    public func canonicalJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Decodes, migrates and validates stored data.
    public static func decode(_ data: Data) throws(DocumentError) -> (document: ArtDocument, warnings: [String]) {
        let raw: ArtDocument
        do { raw = try JSONDecoder().decode(ArtDocument.self, from: data) } catch { throw .corrupt("\(error)") }
        return try migrate(raw).validated()
    }

    /// Upgrades an older stored version to the current one (version 1 is current; newer versions are rejected by
    /// `validated()` without modification).
    public static func migrate(_ document: ArtDocument) -> ArtDocument { document }

    private enum CodingKeys: String, CodingKey { case id, schemaVersion, familyID, seed, paletteID, parameters, previewTime }

    /// Decodes the stored form; the seed must be a decimal UInt64 string.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let seed = UInt64(try c.decode(String.self, forKey: .seed)) else {
            throw DecodingError.dataCorruptedError(forKey: .seed, in: c, debugDescription: "seed must be a decimal UInt64 string")
        }
        id = try c.decode(UUID.self, forKey: .id)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        familyID = try c.decode(String.self, forKey: .familyID)
        self.seed = seed
        paletteID = try c.decode(String.self, forKey: .paletteID)
        parameters = try c.decode([String: Double].self, forKey: .parameters)
        previewTime = try c.decode(Double.self, forKey: .previewTime)
    }

    /// Encodes the stored form with the seed as a decimal string.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(familyID, forKey: .familyID)
        try c.encode(String(seed), forKey: .seed)
        try c.encode(paletteID, forKey: .paletteID)
        try c.encode(parameters, forKey: .parameters)
        try c.encode(previewTime, forKey: .previewTime)
    }
}
