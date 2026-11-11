// FieldGrid.swift — CPU grids for checking GPU field passes (feature 019 T-A02-102; gap G-CPUFIELD, research R2/R6).
// Any app that runs a simulation on GPU render targets (fluid, reaction–diffusion, cellular automata) keeps a CPU
// reference on a tiny grid. `StoragePrecision` rounds it the way the GPU storage format does after every step, so
// GPU and CPU results can be compared within one storage step.

/// The precision of the storage that holds a field between steps.
public enum StoragePrecision: String, Sendable, Codable, CaseIterable {
    /// 32-bit float: no rounding.
    case float32
    /// IEEE half precision (RGBA16F targets), round to nearest even; overflow gives ±infinity.
    case float16
    /// IEEE half precision with round toward zero; overflow saturates at ±65504. GLES leaves the float-to-half
    /// rounding of color writes implementation-defined, and some GPUs truncate (observed on the iOS 27.2 simulator,
    /// feature 019). Compare against both half modes when the mode is unknown.
    case float16TowardZero
    /// 8-bit normalized (RGBA8 targets): clamped to 0…1 and rounded to n/255.
    case unorm8

    /// Rounds `x` to the nearest value this storage can hold.
    public func round(_ x: Float) -> Float {
        switch self {
        case .float32: return x
        case .unorm8:
            guard !x.isNaN else { return 0 }
            return (min(max(x, 0), 1) * 255).rounded(.toNearestOrEven) / 255
        case .float16: return Self.roundToHalf(x, .toNearestOrEven)
        case .float16TowardZero: return Self.roundToHalf(x, .towardZero)
        }
    }

    /// Comparison tolerance of one storage step: 1e-6 (float32), 1e-3 (both half modes, for values up to 1),
    /// 1.5/255 (unorm8).
    public var tolerance: Float {
        switch self {
        case .float32: 1e-6
        case .float16, .float16TowardZero: 1e-3
        case .unorm8: 1.5 / 255
        }
    }

    /// Portable half rounding (no `Float16`, so it also runs on Intel macOS hosts).
    static func roundToHalf(_ x: Float, _ rule: FloatingPointRoundingRule) -> Float {
        guard x.isFinite else { return x }
        let a = abs(x)
        if rule == .towardZero, a >= 65504 { return x < 0 ? -65504 : 65504 }
        if a >= 65520 { return x < 0 ? -.infinity : .infinity }   // past the largest half (65504) plus half a step
        // Half has 10 fraction bits; below 2^-14 it is subnormal with a fixed step of 2^-24.
        let step: Float = a < 0x1p-14 ? 0x1p-24 : Float(sign: .plus, exponent: a.exponent - 10, significand: 1)
        let q = (a / step).rounded(rule) * step
        return x < 0 ? -q : q
    }
}

/// A width × height grid with 1…4 channels per cell, stored row-major from the bottom row up (GL order).
public struct FieldGrid: Sendable, Equatable {
    /// Cells per row (≥ 1).
    public let width: Int
    /// Rows (≥ 1).
    public let height: Int
    /// Values per cell (1…4).
    public let channels: Int
    /// `width · height · channels` values; cell (x, y) channel c is at `(y · width + x) · channels + c`.
    public var values: [Float]

    /// A grid filled with `fill`. Sizes below 1 become 1; channels are clamped to 1…4.
    public init(width: Int, height: Int, channels: Int, fill: Float = 0) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.channels = min(max(1, channels), 4)
        values = Array(repeating: fill, count: self.width * self.height * self.channels)
    }

    /// A grid over existing values; nil when a size is below 1, channels are outside 1…4 or the count is wrong.
    public init?(width: Int, height: Int, channels: Int, values: [Float]) {
        guard width >= 1, height >= 1, (1...4).contains(channels), values.count == width * height * channels else { return nil }
        self.width = width
        self.height = height
        self.channels = channels
        self.values = values
    }

    /// The value of channel `c` in cell (x, y), with y = 0 the bottom row.
    public subscript(x: Int, y: Int, c: Int) -> Float {
        get { values[(y * width + x) * channels + c] }
        set { values[(y * width + x) * channels + c] = newValue }
    }

    /// Every value rounded to `precision`.
    public func rounded(to precision: StoragePrecision) -> FieldGrid {
        var copy = self
        copy.values = values.map(precision.round)
        return copy
    }

    /// The largest absolute difference to `other`, or nil when the shapes differ. NaN in either grid gives NaN.
    public func maxAbsDifference(_ other: FieldGrid) -> Float? {
        guard width == other.width, height == other.height, channels == other.channels else { return nil }
        var worst: Float = 0
        for i in values.indices {
            let d = abs(values[i] - other.values[i])
            if d.isNaN { return .nan }
            worst = max(worst, d)
        }
        return worst
    }

    /// True when no value is NaN or infinite.
    public var isFinite: Bool { values.allSatisfy(\.isFinite) }

    /// The smallest value (NaN is ignored; +infinity for an all-NaN grid).
    public var minValue: Float { values.reduce(Float.infinity) { $1.isNaN ? $0 : min($0, $1) } }

    /// The grid with `channels` raised to `count` (extra channels set to `fill`); unchanged when it already has
    /// at least that many. Used to upload a 2-channel field into an RGBA target.
    public func padded(toChannels count: Int, fill: Float = 0) -> FieldGrid {
        let target = min(max(count, 1), 4)
        guard target > channels else { return self }
        var out = FieldGrid(width: width, height: height, channels: target, fill: fill)
        for cell in 0..<(width * height) {
            for c in 0..<channels { out.values[cell * target + c] = values[cell * channels + c] }
        }
        return out
    }
}
