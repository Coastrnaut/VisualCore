// FrameChecks — feature 195 T-U09-009 (FR-U09-040, FR-U09-042; data-model section 3; research R2; contract
// specs/195-ua-f09-verification-runner/contracts/verification-api.md). Pure checks on a captured frame: non-blank,
// black, luma histogram, non-finite values, silhouette bounds, colour classes and probes. `FrameProbe` and
// `FrameColorClass` are part of every build, because a presenter declares its probes in every build; the checks
// themselves compile only under DEBUG or VISUALCORE_AUTOMATION.
//
// Buffer convention: the RGBA bytes are those of `RenderHost.readPixels`, 4 bytes per pixel (R, G, B, A), rows
// bottom-up: row 0 of the buffer is the BOTTOM row of the image. Normalized probe coordinates measure y from the TOP
// of the image, as a presenter sees its layout; `FrameChecks.pixel` converts between the two.
import Foundation

/// The colour class of a sampled pixel: what a probe expects and what the runner observes.
public enum FrameColorClass: String, CaseIterable, Sendable, Codable {
    /// Rec. 709 luma below 40 of 255.
    case dark
    /// Rec. 709 luma above 215 of 255 with the channels less than 30 apart.
    case light
    /// Red exceeds green and blue by at least 30 of 255.
    case red
    /// Green exceeds red and blue by at least 30 of 255.
    case green
    /// Blue exceeds red and green by at least 30 of 255.
    case blue
    /// None of the other classes.
    case other
}

/// A point of a frame and the colour class expected there; the runner samples it and compares the classes.
public struct FrameProbe: Sendable, Equatable, Codable {
    /// The name of the probe, reported in the evidence record.
    public let name: String
    /// The horizontal position, 0 at the left edge and 1 at the right edge.
    public let x: Double
    /// The vertical position, 0 at the TOP edge and 1 at the bottom edge.
    public let y: Double
    /// The expected colour class: the raw value of a `FrameColorClass`.
    public let expected: String

    /// Creates a probe; `nil` when the name is empty, x or y is not a finite value in 0…1, or `expected` is not one
    /// of `dark`, `light`, `red`, `green`, `blue` or `other`.
    public init?(name: String, x: Double, y: Double, expected: String) {
        guard !name.isEmpty,
              x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y),
              FrameColorClass(rawValue: expected) != nil else { return nil }
        self.name = name
        self.x = x
        self.y = y
        self.expected = expected
    }
}

#if DEBUG || VISUALCORE_AUTOMATION
/// The bounding box of a silhouette in buffer coordinates: columns from the left, rows from the BOTTOM (row 0 of the
/// buffer is the bottom row of the image). Both bounds are inclusive.
public struct FrameBounds: Sendable, Equatable {
    /// The leftmost column.
    public let minX: Int
    /// The lowest buffer row (nearest the bottom of the image).
    public let minY: Int
    /// The rightmost column.
    public let maxX: Int
    /// The highest buffer row (nearest the top of the image).
    public let maxY: Int

    /// Creates bounds.
    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

/// Pure checks on a captured frame. Every function takes RGBA bytes (4 per pixel, rows bottom-up) with the frame's
/// width and height; a buffer whose byte count is not `width * height * 4`, or a width or height below 1, gives a
/// false, empty or `nil` result and never traps.
public enum FrameChecks {
    /// The smallest Rec. 709 luma spread, of 255, a non-blank frame has.
    public static let minimumLumaSpread = 8.0
    /// The largest channel value, of 255, a black pixel has.
    public static let blackThreshold: UInt8 = 4
    /// Luma below this is `dark`.
    public static let darkLuma = 40.0
    /// Luma above this, with a channel spread below `lightChannelSpread`, is `light`.
    public static let lightLuma = 215.0
    /// The largest channel spread a `light` pixel has (exclusive).
    public static let lightChannelSpread = 30
    /// The margin by which a dominant channel exceeds both others for `red`, `green` or `blue`.
    public static let dominanceMargin = 30

    /// Whether the buffer holds exactly `width * height` RGBA pixels.
    private static func isValid(_ rgba: [UInt8], width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        let (pixels, overflowA) = width.multipliedReportingOverflow(by: height)
        guard !overflowA else { return false }
        let (bytes, overflowB) = pixels.multipliedReportingOverflow(by: 4)
        return !overflowB && bytes == rgba.count
    }

    /// The Rec. 709 luma of a colour, 0…255.
    public static func luma(r: UInt8, g: UInt8, b: UInt8) -> Double {
        0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    /// Whether the frame shows something: more than one distinct RGB colour and a Rec. 709 luma spread (maximum
    /// minus minimum) of at least 8 of 255. False for an invalid buffer.
    public static func isNonBlank(_ rgba: [UInt8], width: Int, height: Int) -> Bool {
        guard isValid(rgba, width: width, height: height) else { return false }
        let first = (rgba[0], rgba[1], rgba[2])
        var distinct = false
        var minimum = Double.greatestFiniteMagnitude
        var maximum = -Double.greatestFiniteMagnitude
        for index in stride(from: 0, to: rgba.count, by: 4) {
            let r = rgba[index], g = rgba[index + 1], b = rgba[index + 2]
            if r != first.0 || g != first.1 || b != first.2 { distinct = true }
            let value = luma(r: r, g: g, b: b)
            minimum = Swift.min(minimum, value)
            maximum = Swift.max(maximum, value)
        }
        return distinct && maximum - minimum >= minimumLumaSpread
    }

    /// Whether every pixel is black: R, G and B each at most 4 of 255. False for an invalid buffer.
    public static func isBlack(_ rgba: [UInt8], width: Int, height: Int) -> Bool {
        guard isValid(rgba, width: width, height: height) else { return false }
        for index in stride(from: 0, to: rgba.count, by: 4)
        where rgba[index] > blackThreshold || rgba[index + 1] > blackThreshold || rgba[index + 2] > blackThreshold {
            return false
        }
        return true
    }

    /// The Rec. 709 luma histogram with `bins` equal bins over 0…255; it sums to the pixel count. Empty for an
    /// invalid buffer or fewer than one bin.
    public static func histogram(_ rgba: [UInt8], width: Int, height: Int, bins: Int = 16) -> [Int] {
        guard bins > 0, isValid(rgba, width: width, height: height) else { return [] }
        var counts = [Int](repeating: 0, count: bins)
        for index in stride(from: 0, to: rgba.count, by: 4) {
            let value = luma(r: rgba[index], g: rgba[index + 1], b: rgba[index + 2])
            let bin = Swift.min(bins - 1, Swift.max(0, Int(value / 256.0 * Double(bins))))
            counts[bin] += 1
        }
        return counts
    }

    /// Whether any value is NaN or infinite.
    public static func hasNonFinite(_ values: [Float]) -> Bool {
        values.contains { !$0.isFinite }
    }

    /// The bounding box, in buffer coordinates (row 0 is the bottom), of the pixels any of whose R, G or B differs
    /// from the background by more than `tolerance`; `nil` when there is none or the buffer is invalid.
    public static func silhouette(_ rgba: [UInt8], width: Int, height: Int,
                                  background: (UInt8, UInt8, UInt8), tolerance: UInt8) -> FrameBounds? {
        guard isValid(rgba, width: width, height: height) else { return nil }
        func differs(_ value: UInt8, _ reference: UInt8) -> Bool {
            (value > reference ? value - reference : reference - value) > tolerance
        }
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for row in 0..<height {
            for column in 0..<width {
                let index = (row * width + column) * 4
                guard differs(rgba[index], background.0) || differs(rgba[index + 1], background.1)
                        || differs(rgba[index + 2], background.2) else { continue }
                minX = Swift.min(minX, column)
                maxX = Swift.max(maxX, column)
                minY = Swift.min(minY, row)
                maxY = Swift.max(maxY, row)
            }
        }
        guard maxX >= 0 else { return nil }
        return FrameBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    /// The colour class of a pixel: luma below 40 is `dark`; luma above 215 with a channel spread below 30 is
    /// `light`; otherwise a channel exceeding both others by at least 30 gives `red`, `green` or `blue`; else
    /// `other`.
    public static func classify(r: UInt8, g: UInt8, b: UInt8) -> FrameColorClass {
        let value = luma(r: r, g: g, b: b)
        if value < darkLuma { return .dark }
        let ri = Int(r), gi = Int(g), bi = Int(b)
        let spread = Swift.max(ri, gi, bi) - Swift.min(ri, gi, bi)
        if value > lightLuma && spread < lightChannelSpread { return .light }
        if ri - gi >= dominanceMargin && ri - bi >= dominanceMargin { return .red }
        if gi - ri >= dominanceMargin && gi - bi >= dominanceMargin { return .green }
        if bi - ri >= dominanceMargin && bi - gi >= dominanceMargin { return .blue }
        return .other
    }

    /// The pixel at normalized `x` (0 left, 1 right) and `y` measured from the TOP of the image (0 top, 1 bottom).
    /// The buffer is bottom-up, as `RenderHost.readPixels` returns it (row 0 is the bottom row), so the sampled
    /// buffer row is `height - 1 - min(height - 1, Int(y * height))`. `nil` for an invalid buffer or for x or y
    /// outside 0…1 or not finite.
    public static func pixel(_ rgba: [UInt8], width: Int, height: Int,
                             x: Double, y: Double) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard isValid(rgba, width: width, height: height),
              x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
        let column = Swift.min(width - 1, Int(x * Double(width)))
        let rowFromTop = Swift.min(height - 1, Int(y * Double(height)))
        let row = height - 1 - rowFromTop
        let index = (row * width + column) * 4
        return (rgba[index], rgba[index + 1], rgba[index + 2])
    }

    /// The colour class observed at a probe's point (y from the top); `nil` for an invalid buffer.
    public static func probe(_ probe: FrameProbe, rgba: [UInt8], width: Int, height: Int) -> FrameColorClass? {
        guard let sample = pixel(rgba, width: width, height: height, x: probe.x, y: probe.y) else { return nil }
        return classify(r: sample.r, g: sample.g, b: sample.b)
    }
}
#endif
