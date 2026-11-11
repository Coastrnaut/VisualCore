// ExportGeometry.swift — pixel sizes for still exports from a long edge and an aspect ratio
// (feature 015 T-A01-401; FR-A01-401, FR-A01-405; research R5). Pure logic shared by every app that exports images.
//   long edge  = min(requested, maxEdge, 8192)
//   short edge = 2 × round(long × shortRatio ÷ longRatio ÷ 2), clamped to [2, long]
//   then the long edge shrinks in steps of 2 until width × height ≤ maxPixels.

/// An export aspect ratio such as 4:5, expressed as whole-number width and height ratio terms.
public struct ExportAspect: Sendable, Hashable, Identifiable {
    /// Stable identifier (for example `portrait`).
    public let id: String
    /// Display title (for example "Portrait 4:5").
    public let title: String
    /// Width term of the ratio (> 0).
    public let width: Int
    /// Height term of the ratio (> 0).
    public let height: Int

    /// Creates an aspect; returns nil when either ratio term is not positive.
    public init?(id: String, title: String, width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.id = id
        self.title = title
        self.width = width
        self.height = height
    }

    private init(builtIn id: String, _ title: String, _ width: Int, _ height: Int) {
        self.id = id; self.title = title; self.width = width; self.height = height
    }

    /// Square 1:1.
    public static let square = ExportAspect(builtIn: "square", "Square 1:1", 1, 1)
    /// Portrait 4:5.
    public static let portrait = ExportAspect(builtIn: "portrait", "Portrait 4:5", 4, 5)
    /// Landscape 16:9.
    public static let landscape = ExportAspect(builtIn: "landscape", "Landscape 16:9", 16, 9)
    /// Story 9:16.
    public static let story = ExportAspect(builtIn: "story", "Story 9:16", 9, 16)
    /// The four built-in aspects in display order.
    public static let builtIns: [ExportAspect] = [.square, .portrait, .landscape, .story]

    /// True when the image is wider than tall.
    public var isLandscape: Bool { width > height }
}

/// An export size in pixels; both edges are even and at least 2.
public struct ExportSize: Sendable, Hashable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// width × height.
    public var pixelCount: Int { width * height }
    /// The longer edge in pixels.
    public var longEdge: Int { max(width, height) }
}

/// Derives export pixel sizes from a requested long edge and an aspect, capped by a device edge limit, a hard 8192 px
/// edge and a pixel-count limit (default 64 million).
public struct ExportGeometry: Sendable, Equatable {
    /// Absolute edge cap regardless of the device.
    public static let hardMaxEdge = 8192
    /// Default pixel-count cap per export.
    public static let defaultMaxPixels = 64_000_000

    /// Device edge limit in pixels (for example `RenderHost.maxRenderSize`); values below 2 are treated as 2.
    public let maxEdge: Int
    /// Pixel-count limit per export.
    public let maxPixels: Int

    /// Creates the geometry for a device edge limit and a pixel-count limit.
    public init(maxEdge: Int, maxPixels: Int = ExportGeometry.defaultMaxPixels) {
        self.maxEdge = maxEdge
        self.maxPixels = max(4, maxPixels)
    }

    /// The largest long edge allowed: min(maxEdge, 8192), even, at least 2.
    public var effectiveMaxEdge: Int { Self.even(max(2, min(maxEdge, Self.hardMaxEdge))) }

    /// `longEdge` clamped to [2, effectiveMaxEdge] and made even (rounded down).
    public func clampedLongEdge(_ longEdge: Int) -> Int {
        Self.even(min(max(2, longEdge), effectiveMaxEdge))
    }

    /// The pixel size for a requested long edge and aspect after every cap.
    public func size(longEdge: Int, aspect: ExportAspect) -> ExportSize {
        var long = clampedLongEdge(longEdge)
        var result = Self.make(long: long, aspect: aspect)
        while result.pixelCount > maxPixels && long > 2 {
            long -= 2
            result = Self.make(long: long, aspect: aspect)
        }
        return result
    }

    private static func make(long: Int, aspect: ExportAspect) -> ExportSize {
        let longRatio = Double(max(aspect.width, aspect.height))
        let shortRatio = Double(min(aspect.width, aspect.height))
        let raw = Double(long) * shortRatio / longRatio
        let short = min(long, max(2, 2 * Int((raw / 2).rounded())))
        return aspect.width >= aspect.height ? ExportSize(width: long, height: short) : ExportSize(width: short, height: long)
    }

    private static func even(_ v: Int) -> Int { v - v % 2 }
}
