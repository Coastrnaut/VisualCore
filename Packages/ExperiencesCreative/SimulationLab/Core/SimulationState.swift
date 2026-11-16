// SimulationState — feature 117 (A16-P01) T-A16-104 (FR-A16-110, FR-A16-120; SC-A16-104; clarification Q5;
// data-model "SimulationState (schema 1)"). The saved state of a simulation: the spec, the scheduler and the field
// itself, so a restore never re-runs thousands of steps.
//
// Written as JSON with sorted keys:
// `{"channels": ["<base64>", …], "scheduler": {…}, "schema": 1, "spec": {…}}` (spec and scheduler as in
// `SimulationSpec` and `SimulationScheduler`). The channels hold the storage bit patterns, row-major from the bottom
// row: the automaton one channel of `unorm8` bytes (0 or 255); reaction-diffusion two channels, u then v, of
// little-endian IEEE half bit patterns; the wave two grids, current then previous, of half bit patterns. The largest
// state (reaction-diffusion or wave at 256 × 256) is about 350 kB, below the limit of 1,048,576 bytes.
//
// `decode(_:)` refuses, in this order:
// - `out-of-range`: more than 1,048,576 bytes;
// - `damaged`: not JSON, no integer `schema`, a schema below 1, a missing or malformed key, invalid base64, or a spec
//   that cannot be read;
// - `newer-version`: a schema (or the spec's schema or algorithm version) above 1;
// - `out-of-range`: a spec `SimulationSpec.validated()` refuses (unknown kind or boundary, grid size, range, non-finite
//   value, stability), a scheduler of another kind or with a value outside its range, a channel count or byte count
//   that does not match the grid, an automaton byte other than 0 or 255, a reaction-diffusion value that is not
//   finite or outside 0…1, or a wave value that is not finite or a border cell that is not zero.
// A refusal changes nothing; the caller opens the seeded start. Encoding a decoded state gives the same bytes.
import Foundation
import VisualCoreSimulation

/// Why a saved simulation state was refused.
public enum SimulationStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version.
    case newerVersion = "newer-version"
    /// Too large, or a value, size or setting outside its range.
    case outOfRange = "out-of-range"
}

/// The saved state of a simulation (schema 1): spec, scheduler and field.
public struct SimulationState: Codable, Equatable, Sendable {
    /// The state schema this code reads and writes.
    public static let schemaVersion = 1
    /// The largest state accepted, in bytes.
    public static let maxBytes = 1_048_576

    /// The spec (valid).
    public let spec: SimulationSpec
    /// The scheduler (of the spec's kind).
    public let scheduler: SimulationScheduler
    /// The field, rounded to the kind's storage precision.
    public let field: SimulationField

    /// A state; nil when the spec is refused, the scheduler is of another kind or the field does not fit the spec.
    public init?(spec: SimulationSpec, scheduler: SimulationScheduler, field: SimulationField) {
        guard spec.refusal() == nil, scheduler.kind == spec.kind, Self.fits(field, spec) else { return nil }
        self.spec = spec
        self.scheduler = scheduler
        self.field = field
    }

    /// True when `field` has the shape of `spec`'s field (sizes, channels, a previous grid only for the wave).
    static func fits(_ field: SimulationField, _ spec: SimulationSpec) -> Bool {
        let n = spec.gridSize, c = spec.kind.channels
        func ok(_ g: FieldGrid) -> Bool { g.width == n && g.height == n && g.channels == c }
        guard ok(field.current) else { return false }
        if spec.kind == .wave { return field.previous.map(ok) ?? false }
        return field.previous == nil
    }

    // MARK: Codec

    private enum CodingKeys: String, CodingKey { case channels, scheduler, schema, spec }

    /// Writes the JSON of the file header.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(spec, forKey: .spec)
        try c.encode(scheduler, forKey: .scheduler)
        try c.encode(FieldBits.channels(of: field, kind: spec.kind).map { $0.base64EncodedString() }, forKey: .channels)
    }

    /// Reads and checks the JSON of the file header; throws a `SimulationStateRefusal` (another error reads as
    /// `damaged` in `decode(_:)`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let schema = try? c.decode(Int.self, forKey: .schema), schema >= 1 else {
            throw SimulationStateRefusal.damaged
        }
        guard schema <= Self.schemaVersion else { throw SimulationStateRefusal.newerVersion }
        let spec: SimulationSpec
        do {
            spec = try c.decode(SimulationSpec.self, forKey: .spec)
        } catch let refusal as SimulationRefusal {
            switch refusal.reason {
            case .damaged: throw SimulationStateRefusal.damaged
            case .unknownVersion: throw SimulationStateRefusal.newerVersion
            default: throw SimulationStateRefusal.outOfRange
            }
        } catch {
            throw SimulationStateRefusal.damaged
        }
        let scheduler = try c.decode(SimulationScheduler.self, forKey: .scheduler)
        let texts = try c.decode([String].self, forKey: .channels)
        var channels: [Data] = []
        for text in texts {
            guard let data = Data(base64Encoded: text) else { throw SimulationStateRefusal.damaged }
            channels.append(data)
        }
        guard scheduler.kind == spec.kind,
              let field = FieldBits.field(from: channels, spec: spec) else { throw SimulationStateRefusal.outOfRange }
        self.spec = spec
        self.scheduler = scheduler
        self.field = field
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data { (try? SimulationSpec.sortedEncoder().encode(self)) ?? Data() }

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<SimulationState, SimulationStateRefusal> {
        guard data.count <= maxBytes else { return .failure(.outOfRange) }
        do {
            return .success(try JSONDecoder().decode(SimulationState.self, from: data))
        } catch let refusal as SimulationStateRefusal {
            return .failure(refusal)
        } catch {
            return .failure(.damaged)
        }
    }
}

/// Storage bit patterns of field channels: `unorm8` bytes and little-endian IEEE half words.
enum FieldBits {
    /// The channel data of `field` for `kind`, in the order of the `SimulationState` file header.
    static func channels(of field: SimulationField, kind: SimulationKind) -> [Data] {
        switch kind {
        case .automaton:
            return [unorm8(field.current, channel: 0)]
        case .reactionDiffusion:
            return [half(field.current, channel: 0), half(field.current, channel: 1)]
        case .wave:
            return [half(field.current, channel: 0), half(field.previous ?? field.current, channel: 0)]
        }
    }

    /// The field of `spec` from channel data; nil for a wrong channel or byte count or a value outside its range.
    static func field(from channels: [Data], spec: SimulationSpec) -> SimulationField? {
        let n = spec.gridSize, cells = n * n
        switch spec.kind {
        case .automaton:
            guard channels.count == 1, channels[0].count == cells else { return nil }
            var grid = FieldGrid(width: n, height: n, channels: 1)
            for (i, byte) in channels[0].enumerated() {
                guard byte == 0 || byte == 255 else { return nil }
                grid.values[i] = byte == 0 ? 0 : 1
            }
            return SimulationField(current: grid)
        case .reactionDiffusion:
            guard channels.count == 2, let u = halfValues(channels[0], count: cells),
                  let v = halfValues(channels[1], count: cells) else { return nil }
            var grid = FieldGrid(width: n, height: n, channels: 2)
            for i in 0..<cells {
                guard u[i].isFinite, v[i].isFinite, (0...1).contains(u[i]), (0...1).contains(v[i]) else { return nil }
                grid.values[i * 2] = u[i]
                grid.values[i * 2 + 1] = v[i]
            }
            return SimulationField(current: grid)
        case .wave:
            guard channels.count == 2, let current = halfValues(channels[0], count: cells),
                  let previous = halfValues(channels[1], count: cells),
                  let a = FieldGrid(width: n, height: n, channels: 1, values: current),
                  let b = FieldGrid(width: n, height: n, channels: 1, values: previous),
                  waveIsValid(a), waveIsValid(b) else { return nil }
            return SimulationField(current: a, previous: b)
        }
    }

    /// True when every value of `grid` is finite and every border cell is zero.
    static func waveIsValid(_ grid: FieldGrid) -> Bool {
        guard grid.isFinite else { return false }
        for y in 0..<grid.height {
            for x in 0..<grid.width where x == 0 || y == 0 || x == grid.width - 1 || y == grid.height - 1 {
                if grid[x, y, 0] != 0 { return false }
            }
        }
        return true
    }

    /// Channel `channel` of `grid` as `unorm8` bytes.
    static func unorm8(_ grid: FieldGrid, channel: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: grid.width * grid.height)
        for i in bytes.indices {
            bytes[i] = UInt8((StoragePrecision.unorm8.round(grid.values[i * grid.channels + channel]) * 255).rounded())
        }
        return Data(bytes)
    }

    /// Channel `channel` of `grid` as little-endian half words (values rounded to half first).
    static func half(_ grid: FieldGrid, channel: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: grid.width * grid.height * 2)
        for i in 0..<(grid.width * grid.height) {
            let bits = halfBits(StoragePrecision.float16.round(grid.values[i * grid.channels + channel]))
            bytes[i * 2] = UInt8(bits & 0xFF)
            bytes[i * 2 + 1] = UInt8(bits >> 8)
        }
        return Data(bytes)
    }

    /// `count` values from little-endian half words; nil when the byte count is not `2 · count`.
    static func halfValues(_ data: Data, count: Int) -> [Float]? {
        guard data.count == count * 2 else { return nil }
        let bytes = [UInt8](data)
        var values = [Float](repeating: 0, count: count)
        for i in 0..<count { values[i] = float(halfBits: UInt16(bytes[i * 2]) | UInt16(bytes[i * 2 + 1]) << 8) }
        return values
    }

    /// The half bit pattern of `x`, which must already be a half value (exact; no `Float16`, so Intel hosts work).
    static func halfBits(_ x: Float) -> UInt16 {
        let sign: UInt16 = x.sign == .minus ? 0x8000 : 0
        if x.isNaN { return 0x7E00 }
        let a = abs(x)
        if a.isInfinite { return sign | 0x7C00 }
        if a == 0 { return sign }
        if a < 0x1p-14 { return sign | UInt16(a / 0x1p-24) }   // subnormal: a multiple of 2⁻²⁴
        let exponent = UInt16(Int(a.exponent) + 15)
        let fraction = UInt16((a.significand - 1) * 1024)
        return sign | exponent << 10 | fraction
    }

    /// The value of half bit pattern `bits`.
    static func float(halfBits bits: UInt16) -> Float {
        let negative = bits & 0x8000 != 0
        let exponent = Int(bits >> 10 & 0x1F), fraction = Float(bits & 0x3FF)
        let magnitude: Float
        switch exponent {
        case 0: magnitude = fraction * 0x1p-24
        case 31: magnitude = fraction == 0 ? .infinity : .nan
        default: magnitude = Float(sign: .plus, exponent: exponent - 15, significand: 1 + fraction / 1024)
        }
        return negative ? -magnitude : magnitude
    }
}
