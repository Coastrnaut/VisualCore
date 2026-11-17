// GardenPalette — feature 145 (A20-P01) T-A20-103 (FR-A20-104; clarifications Q1, Q3). The fixed palette of the
// Digital Zen Garden: one tray (`small-tray`, 4:3, reference field 160 × 120), three opaque sand tones, two rake styles
// with their own tine counts, widths and depths, and five procedural stone kinds with base radii in tray widths.
// Pure Foundation; nothing here draws (A20-P02 adds the relief and stones).
import Foundation

/// The fixed palette of the garden: the tray, the sand tones, the rake styles and the stone kinds, with lookups by id.
public enum GardenPalette {
    /// A tray: the garden's rectangle. Positions are normalized (x in 0…1 across the width, y in 0…1 down the
    /// height); distances are in tray widths with y scaled by ``yScale``.
    public struct TrayDefinition: Equatable, Hashable, Sendable {
        /// The stable id (for example `small-tray`).
        public let id: String
        /// The display name.
        public let name: String
        /// The width divided by the height.
        public let aspect: Double
        /// The number of columns of the reference sand field.
        public let fieldColumns: Int
        /// The number of rows of the reference sand field.
        public let fieldRows: Int
        /// The factor that converts a normalized y distance into tray widths (the height divided by the width).
        public let yScale: Double
    }

    /// An opaque sRGB sand tone; every component is in 0…1 and there is no alpha, so it is opaque by construction.
    public struct SandTone: Equatable, Hashable, Sendable {
        /// The stable id (for example `pale`).
        public let id: String
        /// The display name.
        public let name: String
        /// The red component, in 0…1.
        public let red: Double
        /// The green component, in 0…1.
        public let green: Double
        /// The blue component, in 0…1.
        public let blue: Double
    }

    /// A rake style: its groove profile is depth·cos(2π·tines·u/width) for |u| ≤ width/2.
    public struct RakeStyle: Equatable, Hashable, Sendable {
        /// The stable id (for example `fine-rake`).
        public let id: String
        /// The display name.
        public let name: String
        /// The number of tines.
        public let tines: Int
        /// The width of the rake across the stroke, in tray widths.
        public let width: Double
        /// The depth of the grooves, in units of the deepest groove (0…1).
        public let depth: Double
    }

    /// A procedural stone kind with base radii in tray widths (each in ``stoneRadiusRange``).
    public struct StoneKind: Equatable, Hashable, Sendable {
        /// The stable id (for example `river-pebble`).
        public let id: String
        /// The display name.
        public let name: String
        /// The base radius along the stone's own x axis, in tray widths.
        public let radiusX: Double
        /// The base radius along the stone's own y axis, in tray widths.
        public let radiusY: Double
    }

    /// The range every base stone radius lies in, in tray widths.
    public static let stoneRadiusRange: ClosedRange<Double> = 0.01...0.08

    /// The one tray: `small-tray`, 4:3, field 160 × 120, y scale 0.75.
    public static let smallTray = TrayDefinition(id: "small-tray", name: "Small tray", aspect: 4.0 / 3.0,
                                                 fieldColumns: 160, fieldRows: 120, yScale: 0.75)

    /// Every tray (one in this phase).
    public static let trays: [TrayDefinition] = [smallTray]

    /// The three sand tones: `pale`, `warm` and `grey`.
    public static let tones: [SandTone] = [
        SandTone(id: "pale", name: "Pale sand", red: 0.93, green: 0.89, blue: 0.80),
        SandTone(id: "warm", name: "Warm sand", red: 0.86, green: 0.74, blue: 0.56),
        SandTone(id: "grey", name: "Grey sand", red: 0.72, green: 0.71, blue: 0.68),
    ]

    /// The two rake styles: `fine-rake` (5 tines, 0.06 wide, depth 0.6) and `wide-rake` (3 tines, 0.10 wide,
    /// depth 1.0).
    public static let rakes: [RakeStyle] = [
        RakeStyle(id: "fine-rake", name: "Fine rake", tines: 5, width: 0.06, depth: 0.6),
        RakeStyle(id: "wide-rake", name: "Wide rake", tines: 3, width: 0.10, depth: 1.0),
    ]

    /// The five procedural stone kinds.
    public static let stones: [StoneKind] = [
        StoneKind(id: "river-pebble", name: "River pebble", radiusX: 0.020, radiusY: 0.015),
        StoneKind(id: "flat-slate", name: "Flat slate", radiusX: 0.050, radiusY: 0.025),
        StoneKind(id: "round-granite", name: "Round granite", radiusX: 0.040, radiusY: 0.038),
        StoneKind(id: "tall-basalt", name: "Tall basalt", radiusX: 0.022, radiusY: 0.060),
        StoneKind(id: "moss-boulder", name: "Moss boulder", radiusX: 0.075, radiusY: 0.065),
    ]

    /// The id of the default sand tone (`pale`).
    public static let defaultToneID = "pale"
    /// The id of the default rake style (`fine-rake`).
    public static let defaultRakeID = "fine-rake"

    /// The default sand tone (`pale`).
    public static var defaultTone: SandTone { tones[0] }
    /// The default rake style (`fine-rake`).
    public static var defaultRake: RakeStyle { rakes[0] }

    /// The tray with `id`, or nil when it is unknown.
    public static func tray(id: String) -> TrayDefinition? { trays.first { $0.id == id } }
    /// The sand tone with `id`, or nil when it is unknown.
    public static func tone(id: String) -> SandTone? { tones.first { $0.id == id } }
    /// The rake style with `id`, or nil when it is unknown.
    public static func rake(id: String) -> RakeStyle? { rakes.first { $0.id == id } }
    /// The stone kind with `id`, or nil when it is unknown.
    public static func stone(id: String) -> StoneKind? { stones.first { $0.id == id } }
}
