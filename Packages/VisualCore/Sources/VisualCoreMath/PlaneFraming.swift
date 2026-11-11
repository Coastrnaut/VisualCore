// PlaneFraming.swift — a size-independent description of what a PlaneViewport shows (feature 028 T-A03-301; gap
// G-FRAMING; FR-A03-301; research R1). Saved views, bookmarks and resizes keep the center and the plane length across
// the view's shorter side, so a view saved in portrait reopens undistorted in landscape or split view.

/// The center and the span (plane length across the shorter side of the view) of a plane view, independent of the
/// view's size. Values are validated: a non-finite center becomes (0, 0), and a non-finite or non-positive span
/// becomes 1. Decoding applies the same rules.
public struct PlaneFraming: Sendable, Equatable, Hashable, Codable {
    /// Plane point at the middle of the view.
    public let center: Vec2
    /// Plane length across the shorter side of the view.
    public let span: Double

    /// Creates a framing; invalid values are replaced as described on the type.
    public init(center: Vec2, span: Double) {
        self.center = center.isFinite ? center : .zero
        self.span = span.isFinite && span > 0 ? span : 1
    }

    /// The framing a viewport shows: its center and `unitsPerPoint × min(width, height)`.
    public init(_ viewport: PlaneViewport) {
        self.init(center: viewport.center, span: viewport.unitsPerPoint * Swift.min(viewport.size.x, viewport.size.y))
    }

    /// A viewport of `size` points showing this framing: the same center (exactly), the span across the shorter side
    /// and square pixels. The viewport's scale limits apply (check `wasClamped`); an invalid size uses 1 × 1.
    public func viewport(size: Vec2) -> PlaneViewport {
        PlaneViewport.framing(width: span, center: center, size: size)
    }

    private enum CodingKeys: String, CodingKey { case center, span }

    /// Decodes `center` and `span`, applying the validation rules of `init(center:span:)`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(center: try c.decode(Vec2.self, forKey: .center), span: try c.decode(Double.self, forKey: .span))
    }

    /// Encodes `center` and `span`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(center, forKey: .center)
        try c.encode(span, forKey: .span)
    }
}
