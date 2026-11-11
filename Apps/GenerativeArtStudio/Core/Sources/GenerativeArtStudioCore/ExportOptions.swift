// ExportOptions.swift — the app's still-export choices (feature 015 T-A01-404; FR-A01-401, FR-A01-403, FR-A01-405).
// Size math is VisualCore's ExportGeometry (constitution Principle II); this file holds only the product's offered
// sizes, the file-naming rule and the format label.
import VisualCoreScenes

/// The size and aspect a user picks for one still export, capped by the device's maximum render size.
public struct ExportOptions: Sendable, Equatable {
    /// Long edges offered, in pixels (manual §2: 1080, 2048, 4096).
    public static let offeredLongEdges = [1080, 2048, 4096]
    /// The only format the app exports, shown in the export panel.
    public static let formatLabel = "Opaque · sRGB"
    /// Maximum file-name stem length before the size suffix.
    public static let maxNameLength = 60

    /// Requested long edge in pixels (one of `offeredLongEdges`).
    public var longEdge: Int
    /// Requested aspect.
    public var aspect: ExportAspect
    /// Device edge limit in pixels (`RenderHost.maxRenderSize`).
    public let maxEdge: Int

    /// Creates options; defaults to 2048 px Square.
    public init(longEdge: Int = 2048, aspect: ExportAspect = .square, maxEdge: Int) {
        self.longEdge = longEdge
        self.aspect = aspect
        self.maxEdge = maxEdge
    }

    /// The geometry for this device.
    public var geometry: ExportGeometry { ExportGeometry(maxEdge: maxEdge) }

    /// The exact pixel size that will be rendered.
    public var size: ExportSize { geometry.size(longEdge: longEdge, aspect: aspect) }

    /// Offered long edges after clamping to the device limit, without duplicates, ascending.
    public var availableLongEdges: [Int] {
        var seen: [Int] = []
        for edge in Self.offeredLongEdges.map(geometry.clampedLongEdge) where !seen.contains(edge) { seen.append(edge) }
        return seen
    }

    /// The dimension label, for example "864 × 1080 px".
    public var dimensionsLabel: String { "\(size.width) × \(size.height) px" }

    /// A file name `<name>-<w>x<h>.png`: letters, digits, `-` and `_` are kept, anything else becomes `-`; an empty
    /// name becomes `Untitled`; the stem is at most 60 characters.
    public func fileName(for name: String) -> String {
        let mapped = String(name.trimmingCharactersInWhitespace().map { c -> Character in
            (c.isASCII && (c.isLetter || c.isNumber)) || c == "-" || c == "_" ? c : "-"
        })
        let stem = mapped.isEmpty ? "Untitled" : String(mapped.prefix(Self.maxNameLength))
        return "\(stem)-\(size.width)x\(size.height).png"
    }
}

private extension String {
    func trimmingCharactersInWhitespace() -> Substring {
        var s = Substring(self)
        while let f = s.first, f.isWhitespace { s.removeFirst() }
        while let l = s.last, l.isWhitespace { s.removeLast() }
        return s
    }
}
