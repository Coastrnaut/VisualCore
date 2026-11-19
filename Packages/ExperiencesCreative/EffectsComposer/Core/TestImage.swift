// TestImage — feature 180 (A25-P01) T-A25-107 (FR-A25-104; SC-A25-104; clarification Q4; data-model.md "RGBAImage").
// An RGBA8 picture with rows stored top-down, and the 64 × 64 test image made in code that every effect's program and
// CPU reference are checked against: red rises with the column, green with the row, each n/255 with
// n = ⌊255·i/63⌋; blue is 255 on the 8 × 8 checker squares where (x/8 + y/8) is even and 0 elsewhere; alpha is 255.
// Choices recorded here: the row index `y` counts from the top (row 0 is the first row of `bytes`). OpenGL stores and
// reads textures bottom-up, so the tests flip rows when they upload or read back; the CPU reference states its
// texture coordinate in the GL convention (see `EffectReference`). Pure Swift; no UI, GPU or clock.
// Feature 181 (A25-P02) T-A25-203 (clarification Q2) adds `make(size:)`, the same pattern at any side 8…2,048 (clamped)
// with checker cells of side/8 pixels, for the 256 × 256 preview source; `make()` stays the 64 × 64 image.

/// An RGBA picture with 8 bits per channel, rows stored top-down.
public struct RGBAImage: Equatable, Sendable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// The pixels, 4 bytes each (red, green, blue, alpha), row 0 (the top row) first; `width × height × 4` bytes.
    public var bytes: [UInt8]

    /// A picture of `width × height` pixels from `bytes` (RGBA, rows top-down). The byte count must be
    /// `width × height × 4`.
    public init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(width > 0 && height > 0 && bytes.count == width * height * 4, "RGBAImage: bad size")
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// The index in `bytes` of the red channel of the pixel at column `x` and top-down row `y`.
    public func offset(x: Int, y: Int) -> Int { (y * width + x) * 4 }

    /// The channel `channel` (0 red, 1 green, 2 blue, 3 alpha) of the pixel at column `x` and top-down row `y`.
    public subscript(x: Int, y: Int, channel: Int) -> UInt8 {
        get { bytes[offset(x: x, y: y) + channel] }
        set { bytes[offset(x: x, y: y) + channel] = newValue }
    }

    /// The four channels of the pixel at column `x` and top-down row `y`.
    public func pixel(x: Int, y: Int) -> SIMD4<UInt8> {
        let i = offset(x: x, y: y)
        return SIMD4(bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
    }

    /// The largest absolute difference of any channel (alpha included) between this picture and `other`, in 8-bit
    /// steps; `Int.max` when the sizes differ.
    public func maxChannelDifference(_ other: RGBAImage) -> Int {
        guard width == other.width, height == other.height else { return .max }
        var largest = 0
        for i in bytes.indices { largest = max(largest, abs(Int(bytes[i]) - Int(other.bytes[i]))) }
        return largest
    }
}

/// The test image of clarification Q4.
public enum TestImage {
    /// The side of the square test image in pixels.
    public static let size = 64

    /// The smallest side `make(size:)` accepts; smaller sides are clamped up to it.
    public static let minimumSize = 8
    /// The largest side `make(size:)` accepts (the preview pool's cap); larger sides are clamped down to it.
    public static let maximumSize = 2_048

    /// The 64 × 64 test image: red ⌊255·x/63⌋, green ⌊255·y/63⌋ (y the top-down row), blue 255 where
    /// (x/8 + y/8) is even and 0 elsewhere, alpha 255. Equal to `make(size: 64)`.
    public static func make() -> RGBAImage { make(size: size) }

    /// The test image at `size × size` pixels (feature 181 T-A25-203, clarification Q2): red ⌊255·x/(n−1)⌋, green
    /// ⌊255·y/(n−1)⌋ (y the top-down row), blue 255 on the checker cells of n/8 pixels where (x/cell + y/cell) is
    /// even and 0 elsewhere, alpha 255, with n = `size` clamped to `minimumSize…maximumSize`.
    public static func make(size: Int) -> RGBAImage {
        let n = min(max(size, minimumSize), maximumSize)
        let cell = n / 8
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                let i = (y * n + x) * 4
                bytes[i] = UInt8(255 * x / (n - 1))
                bytes[i + 1] = UInt8(255 * y / (n - 1))
                bytes[i + 2] = (x / cell + y / cell) % 2 == 0 ? 255 : 0
                bytes[i + 3] = 255
            }
        }
        return RGBAImage(width: n, height: n, bytes: bytes)
    }
}
