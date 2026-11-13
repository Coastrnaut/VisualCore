// CanvasDescription.swift — the live canvas's VoiceOver description (feature 016 T-A01-506; FR-A01-503).
// "<Family>, <preset> preset, <palette> palette, seed <n>, <playing/paused>."
import Foundation

/// One sentence describing what the canvas shows: family, preset (or custom), palette, seed and play state.
public struct CanvasDescription: Sendable, Equatable {
    /// Family title.
    public let family: String
    /// Matching preset title, or nil when the composition no longer matches a preset ("custom").
    public let preset: String?
    /// Palette name, or nil for an unknown palette ("custom palette").
    public let palette: String?
    /// The seed.
    public let seed: UInt64
    /// Whether playback is running.
    public let isPlaying: Bool

    /// Describes `document` as shown in its family.
    public init(document: ArtDocument, isPlaying: Bool) {
        let family = document.family
        self.family = family?.title ?? document.familyID
        // A preset's values are partial; the schema defaults fill the rest, exactly as when a document is created.
        preset = family.flatMap { f in
            f.presets.first { p in
                let resolved = f.schema.defaults.merging(p.values) { $1 }
                return p.seed == document.seed && p.paletteID == document.paletteID
                    && resolved.count == document.parameters.count
                    && resolved.allSatisfy { key, value in abs((document.parameters[key] ?? .nan) - value) <= 1e-9 }
            }?.title
        }
        palette = FamilyCatalog.palette(document.paletteID)?.name
        seed = document.seed
        self.isPlaying = isPlaying
    }

    /// The spoken sentence.
    public var text: String {
        let presetPart = preset.map { "\($0) preset" } ?? "custom preset"
        let palettePart = palette.map { "\($0) palette" } ?? "custom palette"
        return "\(family), \(presetPart), \(palettePart), seed \(seed), \(isPlaying ? "playing" : "paused")."
    }
}
