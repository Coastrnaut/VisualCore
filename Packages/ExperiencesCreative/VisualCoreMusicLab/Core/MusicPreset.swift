// MusicPreset — feature 050 (A06-P04) T-A06-403 (FR-A06-411, FR-A06-412, FR-A06-413; spec clarifications 3–4;
// data-model "MusicPreset"; research D5, D6). A named Music Lab preset: a scene and that scene's mapping choices, the
// three read-only built-ins, the seven action values of `preset.apply`, and the versioned one-file-per-preset coding
// (format 1, sorted keys, id bound to the file name). GPU-free and audio-free.
import Foundation

/// A saved Music Lab preset: a name, a scene and one mapping choice per parameter of that scene.
public struct MusicPreset: Sendable, Equatable, Identifiable {
    /// The file format written by `fileData()`; greater formats are refused as `.newer`.
    public static let format = 1
    /// The maximum number of characters of a preset name.
    public static let nameLimit = 60

    /// The stable identifier, also part of the file name.
    public let id: UUID
    /// The cleaned name (trimmed, at most `nameLimit` characters, never empty).
    public let name: String
    /// The scene the preset selects.
    public let scene: MusicLabScene
    /// The mapping choices in slot order, one per parameter of `scene`.
    public let choices: [MappingChoice]
    /// When the preset was saved.
    public let saved: Date
    /// Whether the preset is one of the read-only built-ins (not written to files).
    public let isBuiltIn: Bool

    /// Creates a preset, or returns `nil` when the number of choices differs from the scene's parameter count or any
    /// choice is out of range. The name is cleaned with `clean(_:)`.
    /// - Parameters:
    ///   - id: The stable identifier.
    ///   - name: The name, cleaned before it is stored.
    ///   - scene: The scene.
    ///   - choices: One valid choice per parameter of the scene.
    ///   - saved: The save time.
    ///   - isBuiltIn: Whether the preset is a read-only built-in.
    public init?(
        id: UUID, name: String, scene: MusicLabScene, choices: [MappingChoice], saved: Date, isBuiltIn: Bool = false
    ) {
        guard choices.count == scene.parameters.count, choices.allSatisfy(\.isValid) else { return nil }
        self.id = id
        self.name = Self.clean(name)
        self.scene = scene
        self.choices = choices
        self.saved = saved
        self.isBuiltIn = isBuiltIn
    }

    // MARK: Names

    /// Cleans a name: trims whitespace and newlines, cuts it to `nameLimit` characters and turns an empty result into
    /// "Untitled".
    /// - Parameter name: The name as typed.
    /// - Returns: The cleaned name.
    public static func clean(_ name: String) -> String {
        var cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(nameLimit))
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    /// Cleans a name and makes it unique among existing names, ignoring case, by appending " 2", " 3", … (the first
    /// free number); the base is cut so that the result stays within `nameLimit` characters.
    /// - Parameters:
    ///   - name: The wanted name.
    ///   - existing: The names already in use.
    /// - Returns: A cleaned name not equal (ignoring case) to any existing name.
    public static func uniqueName(_ name: String, among existing: [String]) -> String {
        let base = clean(name)
        let taken = Set(existing.map { $0.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while true {
            let suffix = " \(number)"
            let cut = String(base.prefix(nameLimit - suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = cut + suffix
            if !taken.contains(candidate.lowercased()) { return candidate }
            number += 1
        }
    }

    // MARK: Built-ins

    /// The three read-only built-in presets, one per scene: "Spectrum" (bars), "Waveform rings" (rings) and
    /// "Pulse geometry" (geometry), each with curated choices that differ from the scene defaults.
    public static let builtIns: [MusicPreset] = [
        builtIn("00000000-0000-4000-8000-0000000006a1", "Spectrum", .bars, [(0, 1.5), (2, 1)]),
        builtIn("00000000-0000-4000-8000-0000000006a2", "Waveform rings", .rings, [(3, 1.2), (6, 2)]),
        builtIn("00000000-0000-4000-8000-0000000006a3", "Pulse geometry", .geometry, [(2, 1.5), (5, 1), (3, 1.5)]),
    ]

    private static func builtIn(
        _ id: String, _ name: String, _ scene: MusicLabScene, _ pairs: [(Int, Double)]
    ) -> MusicPreset {
        let choices = pairs.compactMap { MappingChoice(feature: $0.0, gain: $0.1) }
        guard let uuid = UUID(uuidString: id),
            let preset = MusicPreset(
                id: uuid, name: name, scene: scene, choices: choices,
                saved: Date(timeIntervalSinceReferenceDate: 0), isBuiltIn: true)
        else {
            preconditionFailure("built-in preset \(name) is invalid")
        }
        return preset
    }

    // MARK: Apply action

    /// The seven values of the `preset.apply` action: `[scene, feature0, gain0, feature1, gain1, feature2, gain2]`,
    /// with zeros for slots the scene does not have.
    public var actionValues: [Double] {
        var values = [Double(scene.rawValue)]
        for slot in 0..<3 {
            if slot < choices.count {
                values.append(Double(choices[slot].feature))
                values.append(choices[slot].gain)
            } else {
                values.append(0)
                values.append(0)
            }
        }
        return values
    }

    // MARK: File coding

    /// Why a preset file was refused.
    public enum FileError: Error, Equatable {
        /// The file has a greater format than `MusicPreset.format` (the associated value); it is never rewritten.
        case newer(Int)
        /// The file cannot be read as a format-1 preset (bad JSON, missing keys, id not matching the file name,
        /// unknown scene, wrong choice count or a choice out of range).
        case malformed
    }

    private struct FormatProbe: Decodable {
        let format: Int
    }

    private struct FileBody: Codable {
        let choices: [MappingChoice]
        let format: Int
        let id: String
        let name: String
        let saved: Double
        let scene: Int
    }

    /// Encodes the preset as format-1 JSON with sorted keys `choices`, `format`, `id`, `name`, `saved` (seconds since
    /// 2001-01-01) and `scene`. `isBuiltIn` is not coded.
    /// - Returns: The file contents.
    public func fileData() throws -> Data {
        let body = FileBody(
            choices: choices, format: Self.format, id: id.uuidString, name: name,
            saved: saved.timeIntervalSinceReferenceDate, scene: scene.rawValue)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(body)
    }

    /// Decodes a preset file. A greater format is refused as `.newer`; anything else that is not a valid format-1
    /// preset whose id equals `fileID` is refused as `.malformed`. The result is never a built-in.
    /// - Parameters:
    ///   - data: The file contents.
    ///   - fileID: The id taken from the file name (see `id(fromFileName:)`).
    /// - Returns: The decoded preset.
    public static func decode(_ data: Data, fileID: UUID) throws(FileError) -> MusicPreset {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(FormatProbe.self, from: data) else { throw .malformed }
        if probe.format > format { throw .newer(probe.format) }
        guard probe.format == format,
            let body = try? decoder.decode(FileBody.self, from: data),
            let id = UUID(uuidString: body.id), id == fileID,
            let scene = MusicLabScene(rawValue: body.scene),
            body.saved.isFinite,
            let preset = MusicPreset(
                id: id, name: body.name, scene: scene, choices: body.choices,
                saved: Date(timeIntervalSinceReferenceDate: body.saved))
        else { throw .malformed }
        return preset
    }

    /// The file name of a preset: `preset-<lowercased uuid>.json`.
    /// - Parameter id: The preset id.
    /// - Returns: The file name.
    public static func fileName(for id: UUID) -> String {
        "preset-\(id.uuidString.lowercased()).json"
    }

    /// The preset id encoded in a file name made by `fileName(for:)`, or `nil` for any other name.
    /// - Parameter fileName: The file name (without directory).
    /// - Returns: The id, or `nil`.
    public static func id(fromFileName fileName: String) -> UUID? {
        let prefix = "preset-"
        let suffix = ".json"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }
        let core = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        guard core.count == 36 else { return nil }
        return UUID(uuidString: String(core))
    }
}
