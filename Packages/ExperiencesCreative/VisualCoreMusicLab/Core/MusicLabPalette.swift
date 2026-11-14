// MusicLabPalette — feature 051 (A06-P05) T-A06-504 (FR-A06-512; data-model "MusicLabPalette"; research D5).
// The three colour palettes of VisualCore Music Lab (Aurora 0, Ember 1, Mono 2) with an RGBA colour per drawing role.
// Aurora reproduces the presenter colours used before palettes existed. GPU-free and audio-free.
import Foundation

/// An RGBA colour with components in 0…1, independent of any graphics framework.
public struct PaletteColor: Sendable, Equatable {
    /// The red component, 0…1.
    public let r: Double
    /// The green component, 0…1.
    public let g: Double
    /// The blue component, 0…1.
    public let b: Double
    /// The alpha component, 0…1.
    public let a: Double

    /// Creates a colour from its components; alpha defaults to fully opaque.
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// An opaque grey with the same value in every colour component.
    static func grey(_ value: Double) -> PaletteColor { PaletteColor(value, value, value) }
}

/// A colour palette of Music Lab. The raw value is the persisted palette index 0…2.
public enum MusicLabPalette: Int, CaseIterable, Codable, Sendable {
    /// Cool blues, cyan and green: the original Music Lab colours.
    case aurora = 0
    /// Warm oranges, reds and yellows.
    case ember = 1
    /// Greys with a distinct luminance per role.
    case mono = 2

    /// The name shown in the palette picker and spoken by the canvas description.
    public var displayName: String {
        switch self {
        case .aurora: "Aurora"
        case .ember: "Ember"
        case .mono: "Mono"
        }
    }

    /// The colour of the spectrum bars.
    public var bar: PaletteColor {
        switch self {
        case .aurora: PaletteColor(0.45, 0.6, 1.0)
        case .ember: PaletteColor(1.0, 0.55, 0.2)
        case .mono: .grey(0.75)
        }
    }

    /// The colour of the waveform line and rings.
    public var wave: PaletteColor {
        switch self {
        case .aurora: PaletteColor(0.35, 0.85, 1.0)
        case .ember: PaletteColor(1.0, 0.75, 0.3)
        case .mono: .grey(0.95)
        }
    }

    /// The colour of the level meter.
    public var level: PaletteColor {
        switch self {
        case .aurora: PaletteColor(0.4, 0.95, 0.55)
        case .ember: PaletteColor(1.0, 0.85, 0.35)
        case .mono: .grey(0.6)
        }
    }

    /// The colour of the peak marker.
    public var peak: PaletteColor {
        switch self {
        case .aurora: PaletteColor(1.0, 0.9, 0.4)
        case .ember: PaletteColor(1.0, 1.0, 0.7)
        case .mono: .grey(1.0)
        }
    }

    /// The colour of the beat indicator.
    public var beat: PaletteColor {
        switch self {
        case .aurora: PaletteColor(1.0, 0.45, 0.6)
        case .ember: PaletteColor(0.95, 0.3, 0.25)
        case .mono: .grey(0.85)
        }
    }

    /// The colour of the sphere in the geometry scene.
    public var sphere: PaletteColor {
        switch self {
        case .aurora: PaletteColor(1.0, 0.45, 0.6)
        case .ember: PaletteColor(0.95, 0.35, 0.2)
        case .mono: .grey(0.8)
        }
    }

    /// The colour of the cubes in the geometry scene.
    public var cube: PaletteColor {
        switch self {
        case .aurora: PaletteColor(0.45, 0.6, 1.0)
        case .ember: PaletteColor(1.0, 0.6, 0.25)
        case .mono: .grey(0.5)
        }
    }

    /// Every role colour in a fixed order: bar, wave, level, peak, beat, sphere, cube.
    public var colors: [PaletteColor] { [bar, wave, level, peak, beat, sphere, cube] }
}
