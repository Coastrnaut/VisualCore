// Bookmark.swift — saved explorer locations with their coordinates and rendering precision mode, kept in a VisualCore
// NamedLibrary (feature 028 T-A03-304; FR-A03-303; data model specs/028-fe-p03-navigation-bookmarks/data-model.md).
// The framing (VisualCoreMath.PlaneFraming) makes a bookmark independent of the canvas shape.
import Foundation
import VisualCoreMath
import VisualCorePersistence

/// The rendering precision a bookmark was saved with (A03 truthful precision).
public struct PrecisionMode: Codable, Equatable, Sendable {
    /// How precision is judged.
    public enum Level: String, Codable, Sendable, CaseIterable {
        case reliable, nearLimit, beyondLimit

        /// Shown in the bookmark list when not reliable.
        public var displayText: String? {
            switch self {
            case .reliable: nil
            case .nearLimit: "Near precision limit"
            case .beyondLimit: "At precision limit"
            }
        }
    }

    /// The only format so far: 32-bit floats in the fragment shader.
    public static let gpuFloat32 = "gpu-float32"

    /// The shader's number format.
    public var format: String
    /// Mantissa bits in use when saved (1…64).
    public var mantissaBits: Int
    /// The precision level of the saved view at save time.
    public var level: Level

    /// Creates a precision mode.
    public init(format: String = PrecisionMode.gpuFloat32, mantissaBits: Int, level: Level) {
        self.format = format; self.mantissaBits = mantissaBits; self.level = level
    }

    /// The mode for a view, judged by `PrecisionAdvisor` with the shader's bits.
    public init(viewport: PlaneViewport, mantissaBits: Int, pixelsPerPoint: Double) {
        let status = PrecisionAdvisor.assess(mantissaBits: mantissaBits,
                                             magnitude: max(abs(viewport.center.x), abs(viewport.center.y)),
                                             pixelStep: viewport.unitsPerPoint / pixelsPerPoint)
        let level: Level = switch status.level {
        case .reliable: .reliable
        case .nearLimit: .nearLimit
        case .beyondLimit: .beyondLimit
        }
        self.init(mantissaBits: mantissaBits, level: level)
    }

    var isValid: Bool { format == Self.gpuFloat32 && (1...64).contains(mantissaBits) }
}

/// A saved explorer location: everything needed to come back to the same picture (FR-A03-303).
public struct Bookmark: Codable, Equatable, Sendable {
    /// The palettes the explorer offers (VisualCore built-ins, Sunset first).
    public static let paletteIDs = ["sunset", "ocean", "forest", "neon", "ember"]
    /// The largest |x| or |y| of a saved center.
    public static let maxCoordinate = 4.0

    /// The fractal family.
    public var mode: FractalMode
    /// Center and span across the shorter side.
    public var framing: PlaneFraming
    /// The Julia seed (kept for both modes).
    public var juliaSeed: Vec2
    /// Iterations per point (1…10,000).
    public var iterationCap: Int
    /// Escape radius (≥ 2).
    public var escapeRadius: Double
    /// One of `paletteIDs`.
    public var paletteID: String
    /// The precision mode at save time.
    public var precision: PrecisionMode

    /// Creates a bookmark as given (see `validated()`).
    public init(mode: FractalMode, framing: PlaneFraming, juliaSeed: Vec2, iterationCap: Int, escapeRadius: Double,
                paletteID: String, precision: PrecisionMode) {
        self.mode = mode; self.framing = framing; self.juliaSeed = juliaSeed; self.iterationCap = iterationCap
        self.escapeRadius = escapeRadius; self.paletteID = paletteID; self.precision = precision
    }

    /// The bookmark of a state.
    public init(state: FractalState, paletteID: String, precision: PrecisionMode) {
        self.init(mode: state.mode, framing: PlaneFraming(state.viewport), juliaSeed: state.juliaSeed,
                  iterationCap: state.iterationCap, escapeRadius: state.escapeRadius, paletteID: paletteID,
                  precision: precision)
    }

    /// The bookmark when every field is within its rules, else nil (the file is then reported as damaged).
    public func validated() -> Bookmark? {
        let c = framing.center
        guard c.isFinite, abs(c.x) <= Self.maxCoordinate, abs(c.y) <= Self.maxCoordinate,
              framing.span.isFinite, framing.span > 0,
              juliaSeed.isFinite, FractalMath.capRange.contains(iterationCap),
              escapeRadius.isFinite, escapeRadius >= FractalMath.minimumRadius,
              Self.paletteIDs.contains(paletteID), precision.isValid else { return nil }
        return self
    }

    /// The state this bookmark describes on a canvas of `size` points (mode first, so its reframing is replaced).
    public func state(size: Vec2) -> FractalState {
        var s = FractalState(mode: mode, size: size)
        s.juliaSeed = juliaSeed
        s.iterationCap = iterationCap
        s.escapeRadius = escapeRadius
        s.viewport = framing.viewport(size: size)
        return s
    }

    /// "−0.743644 + 0.131826i · zoom 1000×": the list row's coordinates.
    public var summary: String {
        let s = state(size: Vec2(1, 1))
        return "\(FractalState.complex(framing.center)) · zoom \(FractalState.zoomText(s.zoom))"
    }
}

/// The explorer's bookmarks: a VisualCore `NamedLibrary` of `Bookmark` in `Application Support/Bookmarks`.
public typealias BookmarkLibrary = NamedLibrary<Bookmark>

public extension NamedLibrary where Payload == Bookmark {
    /// Envelope kind of bookmark files.
    static var bookmarkKind: String { "dev.visualcore.fe.bookmark" }
    /// Stored schema version.
    static var bookmarkSchemaVersion: Int { 1 }

    /// The bookmark library in `directory` (default `Application Support/Bookmarks`).
    static func bookmarks(directory: URL = NamedLibrary.defaultDirectory(named: "Bookmarks")) -> NamedLibrary<Bookmark> {
        NamedLibrary(directory: directory, kind: bookmarkKind,
                     migrations: MigrationChain(currentVersion: bookmarkSchemaVersion)) { $0.validated() }
    }
}
