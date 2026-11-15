// SavedView — feature 106 (A14-P04) T-A14-404 (FR-A14-421; SC-A14-405; clarification Q5; data-model "SavedView").
// The view a person saves in Solar System Explorer ("Save view", "Restore view"), stored as `view.json` in the
// experience's storage: the selection 0…8, the day offset (finite, in `SimulatedDate.range`), the rate index 0…3, the
// yaw steps (unbounded), the pitch 5…85 on the grid 5 + 10k, the zoom steps −1…12 and the scale mode 0…1 — the ranges
// of `SolarState`.
//
// Written as JSON with sorted keys: `{"dayOffset": <days>, "pitchDegrees": <deg>, "rateIndex": <0…3>, "scaleMode":
// <0|1>, "schema": 1, "selection": <index>, "yawSteps": <n>, "zoomSteps": <n>}`. `decode(_:)` refuses, in this order:
// - `oversized`: more than 4,096 bytes (checked before parsing);
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or malformed key;
// - `newer-version`: a schema above 1;
// - `out-of-range`: a value outside its range.
// A refused file changes nothing. `values` lists the fields in the order of the action `view.apply` (selection,
// dayOffset, rateIndex, yawSteps, pitchDegrees, zoomSteps, scaleMode) and `init?(values:)` reads them back, refusing a
// wrong count, a fraction where a whole number belongs or a value outside its range.
import Foundation

/// Why a saved view file was refused.
public enum SavedViewRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``SavedView/schemaVersion``).
    case newerVersion = "newer-version"
    /// A value outside its range.
    case outOfRange = "out-of-range"
    /// More than ``SavedView/maxBytes`` bytes.
    case oversized = "oversized"
}

/// A saved camera, date, rate and scale of Solar System Explorer.
public struct SavedView: Codable, Equatable, Sendable {
    /// The document schema this code writes and reads.
    public static let schemaVersion = 1
    /// The file name in the experience's storage.
    public static let fileName = "view.json"
    /// The largest accepted file in bytes.
    public static let maxBytes = 4_096
    /// The number of values of the `view.apply` action.
    public static let valueCount = 7

    /// The selected body's catalog index, 0…8.
    public let selection: Int
    /// Days since J2000.0, finite and in ``SimulatedDate/range``.
    public let dayOffset: Double
    /// The clock rate index into ``SimClock/rates``, 0…3.
    public let rateIndex: Int
    /// The yaw in steps (unbounded).
    public let yawSteps: Int
    /// The pitch in degrees, 5…85 on the grid 5 + 10k.
    public let pitchDegrees: Int
    /// The zoom steps, −1…12.
    public let zoomSteps: Int
    /// The scale mode raw value, 0 (enhanced) or 1 (true relative).
    public let scaleMode: Int

    /// A view from its fields; nil when any is outside its range (see the file header).
    public init?(selection: Int, dayOffset: Double, rateIndex: Int, yawSteps: Int, pitchDegrees: Int, zoomSteps: Int,
                 scaleMode: Int) {
        guard (0..<SolarState.bodyCount).contains(selection),
              dayOffset.isFinite, SimulatedDate.range.contains(dayOffset),
              SimClock.rates.indices.contains(rateIndex),
              SolarState.pitchRange.contains(pitchDegrees),
              (pitchDegrees - SolarState.pitchRange.lowerBound) % SolarState.pitchStep == 0,
              SolarState.zoomRange.contains(zoomSteps),
              ScaleMode(rawValue: scaleMode) != nil else { return nil }
        self.selection = selection; self.dayOffset = dayOffset; self.rateIndex = rateIndex
        self.yawSteps = yawSteps; self.pitchDegrees = pitchDegrees; self.zoomSteps = zoomSteps
        self.scaleMode = scaleMode
    }

    /// The values in `view.apply` order: selection, dayOffset, rateIndex, yawSteps, pitchDegrees, zoomSteps, scaleMode.
    public var values: [Double] {
        [Double(selection), dayOffset, Double(rateIndex), Double(yawSteps), Double(pitchDegrees), Double(zoomSteps),
         Double(scaleMode)]
    }

    /// A view from `view.apply` values; nil for a count other than 7, a non-whole value where a whole number belongs
    /// (every value but the day offset) or a value outside its range.
    public init?(values: [Double]) {
        guard values.count == Self.valueCount else { return nil }
        func whole(_ value: Double) -> Int? {
            guard value.isFinite, value.rounded() == value, abs(value) <= 1e15 else { return nil }
            return Int(value)
        }
        guard let selection = whole(values[0]), let rateIndex = whole(values[2]), let yawSteps = whole(values[3]),
              let pitchDegrees = whole(values[4]), let zoomSteps = whole(values[5]),
              let scaleMode = whole(values[6]) else { return nil }
        self.init(selection: selection, dayOffset: values[1], rateIndex: rateIndex, yawSteps: yawSteps,
                  pitchDegrees: pitchDegrees, zoomSteps: zoomSteps, scaleMode: scaleMode)
    }

    // MARK: Codec

    private enum CodingKeys: String, CodingKey {
        case schema, selection, dayOffset, rateIndex, yawSteps, pitchDegrees, zoomSteps, scaleMode
    }

    /// Decodes a schema-1 view; throws for another schema, a missing or malformed key or a value outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schema) == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "not schema 1")
        }
        guard let view = SavedView(selection: try c.decode(Int.self, forKey: .selection),
                                   dayOffset: try c.decode(Double.self, forKey: .dayOffset),
                                   rateIndex: try c.decode(Int.self, forKey: .rateIndex),
                                   yawSteps: try c.decode(Int.self, forKey: .yawSteps),
                                   pitchDegrees: try c.decode(Int.self, forKey: .pitchDegrees),
                                   zoomSteps: try c.decode(Int.self, forKey: .zoomSteps),
                                   scaleMode: try c.decode(Int.self, forKey: .scaleMode)) else {
            throw DecodingError.dataCorruptedError(forKey: .selection, in: c, debugDescription: "not a valid view")
        }
        self = view
    }

    /// Encodes the view at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
        try c.encode(dayOffset, forKey: .dayOffset)
        try c.encode(rateIndex, forKey: .rateIndex)
        try c.encode(yawSteps, forKey: .yawSteps)
        try c.encode(pitchDegrees, forKey: .pitchDegrees)
        try c.encode(zoomSteps, forKey: .zoomSteps)
        try c.encode(scaleMode, forKey: .scaleMode)
    }

    /// The view as JSON with sorted keys (deterministic bytes for equal views).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The view in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<SavedView, SavedViewRefusal> {
        guard data.count <= maxBytes else { return .failure(.oversized) }
        struct Header: Decodable { var schema: Int }
        struct Payload: Decodable {
            var selection: Int; var dayOffset: Double; var rateIndex: Int; var yawSteps: Int; var pitchDegrees: Int
            var zoomSteps: Int; var scaleMode: Int
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let p = try? decoder.decode(Payload.self, from: data) else { return .failure(.damaged) }
        guard let view = SavedView(selection: p.selection, dayOffset: p.dayOffset, rateIndex: p.rateIndex,
                                   yawSteps: p.yawSteps, pitchDegrees: p.pitchDegrees, zoomSteps: p.zoomSteps,
                                   scaleMode: p.scaleMode) else { return .failure(.outOfRange) }
        return .success(view)
    }
}
