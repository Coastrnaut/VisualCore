// JourneyPreset — feature 057 (A07-P04) T-A07-402 (FR-A07-401, FR-A07-402, FR-A07-403, FR-A07-404; clarifications 1–3;
// research D1–D3; data-model "JourneyPreset"). A named Audio Odyssey journey: the world, the three per-world mappings,
// the speed target, the camera easing and the calm-motion setting; the three read-only built-ins; the sixteen values of
// the `preset.apply` action and their validation; and the versioned one-file-per-preset coding (format 1, sorted keys,
// id bound to the file name). GPU-free and audio-free.
//
// Rules: the name is trimmed, cut to 60 characters and never empty ("Untitled"); the speed target is finite and in
// 0.5…7 and is snapped to the 0.5 grid; there are exactly three mappings (world order). The file name is
// `journey-<lowercased uuid>.json`; a file with a greater format is refused as `.newer(format)`, anything else that is
// not a valid format-1 preset whose id matches the file name is refused as `.malformed`.
import Foundation

/// A saved Audio Odyssey journey: a name, a world, the mapping of every world, the speed target, the easing and calm
/// motion.
public struct JourneyPreset: Sendable, Equatable, Identifiable {
    /// The file format written by `fileData()`; greater formats are refused as `.newer`.
    public static let format = 1
    /// The maximum number of characters of a preset name.
    public static let nameLimit = 60
    /// The number of values of the `preset.apply` action: world, 4 × 3 mapping values, speed target, easing, calm.
    public static let actionValueCount = 16

    /// The stable identifier, also part of the file name.
    public let id: UUID
    /// The cleaned name (trimmed, at most `nameLimit` characters, never empty).
    public let name: String
    /// When the preset was saved.
    public let saved: Date
    /// Whether the preset is one of the read-only built-ins (not written to files).
    public let isBuiltIn: Bool
    /// The world the preset selects.
    public let world: JourneyWorld
    /// The mapping of every world, in world order (always three).
    public let mappings: [WorldMapping]
    /// The speed target in units per second, in 0.5…7 on the 0.5 grid.
    public let speedTarget: Double
    /// The camera easing.
    public let easing: Easing
    /// The in-app calm-motion setting.
    public let calmMotion: Bool

    /// Creates a preset, or returns `nil` when the mapping count is not 3 or the speed target is not finite or outside
    /// 0.5…7. The name is cleaned with `clean(_:)` and the speed target is snapped to the 0.5 grid.
    /// - Parameters:
    ///   - id: The stable identifier.
    ///   - name: The name, cleaned before it is stored.
    ///   - saved: The save time.
    ///   - world: The world.
    ///   - mappings: The three mappings in world order.
    ///   - speedTarget: The speed target in 0.5…7.
    ///   - easing: The camera easing.
    ///   - calmMotion: The calm-motion setting.
    ///   - isBuiltIn: Whether the preset is a read-only built-in.
    public init?(
        id: UUID, name: String, saved: Date, world: JourneyWorld, mappings: [WorldMapping], speedTarget: Double,
        easing: Easing, calmMotion: Bool, isBuiltIn: Bool = false
    ) {
        guard mappings.count == JourneyWorld.allCases.count, let snapped = Self.validSpeedTarget(speedTarget) else {
            return nil
        }
        self.id = id
        self.name = Self.clean(name)
        self.saved = saved
        self.isBuiltIn = isBuiltIn
        self.world = world
        self.mappings = mappings
        self.speedTarget = snapped
        self.easing = easing
        self.calmMotion = calmMotion
    }

    /// A user preset of the journey fields of `state` (world, mappings, speed target, easing, calm motion).
    /// - Parameters:
    ///   - state: The journey state to capture.
    ///   - id: The stable identifier.
    ///   - name: The name, cleaned before it is stored.
    ///   - saved: The save time.
    public init(from state: JourneyState, id: UUID, name: String, saved: Date) {
        self.id = id
        self.name = Self.clean(name)
        self.saved = saved
        self.isBuiltIn = false
        self.world = state.world
        self.mappings = state.mappings
        self.speedTarget = state.speedTarget
        self.easing = state.easing
        self.calmMotion = state.calmMotion
    }

    /// The mapping of `world` in this preset.
    public func mapping(for world: JourneyWorld) -> WorldMapping { mappings[world.rawValue] }

    /// `value` snapped to the 0.5 grid when it is finite and in 0.5…7, otherwise `nil`.
    private static func validSpeedTarget(_ value: Double) -> Double? {
        guard value.isFinite, JourneyState.speedTargetRange.contains(value) else { return nil }
        return JourneyState.snappedSpeedTarget(value)
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

    /// The three read-only built-in presets (clarification 2): "Deep tunnel" (tunnel, 3.5, gentle; tunnel bass/high,
    /// light overall/medium), "Rolling hills" (landscape, 4, standard; landscape mids/medium) and "Night stars" (star
    /// corridor, 2.5, gentle, calm on; star corridor beats/high). The other worlds keep their default mappings; ids
    /// `00000000-0000-4000-8000-0000000007B1…B3`, saved at the reference date.
    public static let builtIns: [JourneyPreset] = [
        builtIn("00000000-0000-4000-8000-0000000007B1", "Deep tunnel", .tunnel, ChannelMapping(channel: .low,
                sensitivity: .high), speed: 3.5, .gentle, calm: false),
        builtIn("00000000-0000-4000-8000-0000000007B2", "Rolling hills", .landscape, ChannelMapping(channel: .mid,
                sensitivity: .medium), speed: 4.0, .standard, calm: false),
        builtIn("00000000-0000-4000-8000-0000000007B3", "Night stars", .starCorridor, ChannelMapping(
                channel: .transient, sensitivity: .high), speed: 2.5, .gentle, calm: true),
    ]

    private static func builtIn(
        _ id: String, _ name: String, _ world: JourneyWorld, _ primary: ChannelMapping, speed: Double,
        _ easing: Easing, calm: Bool
    ) -> JourneyPreset {
        var mappings = WorldMapping.allDefaults
        mappings[world.rawValue] = WorldMapping(primary: primary, light: ChannelMapping(channel: .overall))
        guard let uuid = UUID(uuidString: id),
            let preset = JourneyPreset(
                id: uuid, name: name, saved: Date(timeIntervalSinceReferenceDate: 0), world: world, mappings: mappings,
                speedTarget: speed, easing: easing, calmMotion: calm, isBuiltIn: true)
        else {
            preconditionFailure("built-in preset \(name) is invalid")
        }
        return preset
    }

    // MARK: Apply action

    /// The sixteen values of the `preset.apply` action (research D2): `[world, then for tunnel, landscape and star
    /// corridor: primary channel, primary sensitivity, light channel, light sensitivity, then speedTarget, easing,
    /// calm (0 or 1)]`, enum values as their raw values.
    public var actionValues: [Double] {
        var values = [Double(world.rawValue)]
        for mapping in mappings {
            values.append(Double(mapping.primary.channel.rawValue))
            values.append(Double(mapping.primary.sensitivity.rawValue))
            values.append(Double(mapping.light.channel.rawValue))
            values.append(Double(mapping.light.sensitivity.rawValue))
        }
        values.append(speedTarget)
        values.append(Double(easing.rawValue))
        values.append(calmMotion ? 1 : 0)
        return values
    }

    /// Reads the sixteen values of a `preset.apply` action (the layout of `actionValues`), or returns `nil` when the
    /// count is not 16 or any value is invalid: an enum value that is not a whole number naming a case, a speed target
    /// that is not finite or outside 0.5…7 (an in-range target is snapped to the 0.5 grid), or a calm value other than
    /// 0 or 1. The adapter applies the result atomically.
    /// - Parameter values: The action values.
    /// - Returns: The world, the three mappings, the speed target, the easing and calm motion, or `nil`.
    public static func fromActionValues(_ values: [Double])
        -> (world: JourneyWorld, mappings: [WorldMapping], speedTarget: Double, easing: Easing, calmMotion: Bool)?
    {
        guard values.count == actionValueCount, let world = whole(values[0]).flatMap(JourneyWorld.init(rawValue:))
        else { return nil }
        var mappings: [WorldMapping] = []
        for index in 0..<JourneyWorld.allCases.count {
            let base = 1 + index * 4
            guard let primaryChannel = whole(values[base]).flatMap(EnvelopeChannel.init(rawValue:)),
                let primarySensitivity = whole(values[base + 1]).flatMap(Sensitivity.init(rawValue:)),
                let lightChannel = whole(values[base + 2]).flatMap(EnvelopeChannel.init(rawValue:)),
                let lightSensitivity = whole(values[base + 3]).flatMap(Sensitivity.init(rawValue:))
            else { return nil }
            mappings.append(WorldMapping(
                primary: ChannelMapping(channel: primaryChannel, sensitivity: primarySensitivity),
                light: ChannelMapping(channel: lightChannel, sensitivity: lightSensitivity)))
        }
        guard let speedTarget = validSpeedTarget(values[13]),
            let easing = whole(values[14]).flatMap(Easing.init(rawValue:)),
            let calm = whole(values[15]), calm == 0 || calm == 1
        else { return nil }
        return (world, mappings, speedTarget, easing, calm == 1)
    }

    /// `value` as an `Int` when it is a finite whole number of small magnitude, otherwise `nil`.
    private static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value.rounded() == value, abs(value) < 1_000 else { return nil }
        return Int(value)
    }

    // MARK: File coding

    /// Why a preset file was refused.
    public enum FileError: Error, Equatable {
        /// The file has a greater format than `JourneyPreset.format` (the associated value); it is never rewritten.
        case newer(Int)
        /// The file cannot be read as a format-1 preset (bad JSON, missing keys, id not matching the file name, an
        /// unknown world, channel, sensitivity or easing, a speed target outside 0.5…7, a mapping count other than 3).
        case malformed
    }

    private struct FormatProbe: Decodable {
        let format: Int
    }

    private struct FileMapping: Codable {
        let lightChannel: Int
        let lightSensitivity: Int
        let primaryChannel: Int
        let primarySensitivity: Int
    }

    private struct FileBody: Codable {
        let calm: Bool
        let easing: Int
        let format: Int
        let id: String
        let mappings: [FileMapping]
        let name: String
        let saved: Double
        let speedTarget: Double
        let world: Int
    }

    /// Encodes the preset as format-1 JSON with sorted keys `calm`, `easing`, `format`, `id`, `mappings` (each
    /// `lightChannel`, `lightSensitivity`, `primaryChannel`, `primarySensitivity`), `name`, `saved` (seconds since
    /// 2001-01-01), `speedTarget` and `world`; enum values as raw values. `isBuiltIn` is not coded.
    /// - Returns: The file contents.
    public func fileData() throws -> Data {
        let body = FileBody(
            calm: calmMotion, easing: easing.rawValue, format: Self.format, id: id.uuidString,
            mappings: mappings.map {
                FileMapping(lightChannel: $0.light.channel.rawValue, lightSensitivity: $0.light.sensitivity.rawValue,
                            primaryChannel: $0.primary.channel.rawValue,
                            primarySensitivity: $0.primary.sensitivity.rawValue)
            },
            name: name, saved: saved.timeIntervalSinceReferenceDate, speedTarget: speedTarget, world: world.rawValue)
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
    public static func decode(_ data: Data, fileID: UUID) throws(FileError) -> JourneyPreset {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(FormatProbe.self, from: data) else { throw .malformed }
        if probe.format > format { throw .newer(probe.format) }
        guard probe.format == format,
            let body = try? decoder.decode(FileBody.self, from: data),
            let id = UUID(uuidString: body.id), id == fileID,
            let world = JourneyWorld(rawValue: body.world),
            let easing = Easing(rawValue: body.easing),
            body.saved.isFinite,
            body.mappings.count == JourneyWorld.allCases.count
        else { throw .malformed }
        var mappings: [WorldMapping] = []
        for entry in body.mappings {
            guard let primaryChannel = EnvelopeChannel(rawValue: entry.primaryChannel),
                let primarySensitivity = Sensitivity(rawValue: entry.primarySensitivity),
                let lightChannel = EnvelopeChannel(rawValue: entry.lightChannel),
                let lightSensitivity = Sensitivity(rawValue: entry.lightSensitivity)
            else { throw .malformed }
            mappings.append(WorldMapping(
                primary: ChannelMapping(channel: primaryChannel, sensitivity: primarySensitivity),
                light: ChannelMapping(channel: lightChannel, sensitivity: lightSensitivity)))
        }
        guard let preset = JourneyPreset(
            id: id, name: body.name, saved: Date(timeIntervalSinceReferenceDate: body.saved), world: world,
            mappings: mappings, speedTarget: body.speedTarget, easing: easing, calmMotion: body.calm)
        else { throw .malformed }
        return preset
    }

    /// The file name of a preset: `journey-<lowercased uuid>.json`.
    /// - Parameter id: The preset id.
    /// - Returns: The file name.
    public static func fileName(for id: UUID) -> String {
        "journey-\(id.uuidString.lowercased()).json"
    }

    /// The preset id encoded in a file name made by `fileName(for:)`, or `nil` for any other name.
    /// - Parameter fileName: The file name (without directory).
    /// - Returns: The id, or `nil`.
    public static func id(fromFileName fileName: String) -> UUID? {
        let prefix = "journey-"
        let suffix = ".json"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }
        let core = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        guard core.count == 36 else { return nil }
        return UUID(uuidString: String(core))
    }
}
