// GeometryPreset.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-110, FR-A05-111).

/// A complete, serialisable description of one Infinite Geometry composition (schema 1).
///
/// The preset is the only input of `Composition.build(_:)`: the same preset (including its seed) always gives the same
/// composition (FR-A05-113). Values are checked by `validated()` on entry; decoding alone does not validate.
public struct GeometryPreset: Sendable, Equatable, Codable {
    /// What a preset composes.
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// The motif tiled under the square lattice (p4m).
        case squareTiling
        /// The motif tiled under the hexagonal lattice (p6m).
        case hexTiling
        /// The motif under the dihedral group of `order`, repeated in concentric rings.
        case kaleidoscope
        /// `order` revolved petals arranged around the vertical axis (a 3D mesh).
        case solid
    }

    /// What this preset composes.
    public var kind: Kind
    /// Symmetry order (1…24); meaningful for `kaleidoscope` and `solid` only (see `usesOrder`).
    public var order: Int
    /// Repetitions (1…12): lattice rings for tilings, concentric rings for the kaleidoscope.
    public var repeats: Int
    /// View scale (0.25…4, finite): the visible view is the square −1…1 divided by the scale.
    public var scale: Double
    /// Index into `Palette.builtIns` (0…5).
    public var palette: Int
    /// The motif seed (`SeededRandom(seed:)`).
    public var seed: UInt64
    /// The schema version this preset was written with; only 1 is supported.
    public var schemaVersion: Int

    /// Creates a preset without validating it; call `validated()` before use.
    public init(kind: Kind, order: Int, repeats: Int, scale: Double, palette: Int, seed: UInt64,
                schemaVersion: Int = 1) {
        self.kind = kind
        self.order = order
        self.repeats = repeats
        self.scale = scale
        self.palette = palette
        self.seed = seed
        self.schemaVersion = schemaVersion
    }

    /// Allowed symmetry orders.
    public static let orderRange = 1...24
    /// Allowed repetitions.
    public static let repeatsRange = 1...12
    /// Allowed view scales.
    public static let scaleRange = 0.25...4.0
    /// Allowed palette indices (the six `Palette.builtIns`).
    public static let paletteRange = 0...5

    /// The four curated presets, one per `Kind` in `Kind.allCases` order (FR-A05-110).
    public static let curated: [GeometryPreset] = [
        GeometryPreset(kind: .squareTiling, order: 4, repeats: 3, scale: 1, palette: 0, seed: 0xA05_0001),
        GeometryPreset(kind: .hexTiling, order: 6, repeats: 3, scale: 1, palette: 1, seed: 0xA05_0002),
        GeometryPreset(kind: .kaleidoscope, order: 8, repeats: 3, scale: 1, palette: 2, seed: 0xA05_0003),
        GeometryPreset(kind: .solid, order: 6, repeats: 1, scale: 1, palette: 3, seed: 0xA05_0004),
    ]

    /// This preset if every value is acceptable (FR-A05-111).
    ///
    /// - Throws: `.unsupportedVersion` for a schema version other than 1; `.notFinite("scale")` for a non-finite scale;
    ///   `.outOfRange(field)` for an order, repetition count, scale or palette outside its range. Checked in that order.
    public func validated() throws(PresetError) -> GeometryPreset {
        guard schemaVersion == InfiniteGeometryCore.schemaVersion else { throw .unsupportedVersion(schemaVersion) }
        guard scale.isFinite else { throw .notFinite("scale") }
        guard Self.orderRange.contains(order) else { throw .outOfRange("order") }
        guard Self.repeatsRange.contains(repeats) else { throw .outOfRange("repeats") }
        guard Self.scaleRange.contains(scale) else { throw .outOfRange("scale") }
        guard Self.paletteRange.contains(palette) else { throw .outOfRange("palette") }
        return self
    }

    /// Whether `order` affects the composition (`kaleidoscope` and `solid`); tilings have a fixed group.
    public var usesOrder: Bool { kind == .kaleidoscope || kind == .solid }
}

/// Why a preset was refused.
public enum PresetError: Error, Sendable, Equatable {
    /// The named field is outside its range.
    case outOfRange(String)
    /// The named field is NaN or infinite.
    case notFinite(String)
    /// The preset's schema version is not supported.
    case unsupportedVersion(Int)

    /// The stable refusal code used by the experience controls.
    public var code: String {
        switch self {
        case .outOfRange: "a05.out-of-range"
        case .notFinite: "a05.not-finite"
        case .unsupportedVersion: "a05.unsupported-version"
        }
    }
}
