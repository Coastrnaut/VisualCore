// ScopeQuality — feature 065 (A08-P05) T-A08-503 (FR-A08-521; SC-A08-504; clarification 3; data-model
// "ScopeQuality"). Oscilloscope Studio's three quality levels: level 0 draws every pixel column and analyses the
// spectrum every frame, level 1 half the columns and every second frame, level 2 a quarter of the columns and every
// fourth frame (the last spectrum readout is kept in between). The host's quality governor passes a tier; a forced
// level (tests) overrides it. Pure and host-free, modelled on Audio Odyssey's `OdysseyQuality` and its presenter's
// clamped `level(tier:forced:)`.
import Foundation

/// One quality level of the scope: the share of pixel columns drawn and how often the spectrum is analysed.
public struct ScopeQuality: Sendable, Equatable {
    /// The share of the pixel columns the trace is drawn with, in 0…1.
    public let columnShare: Double
    /// The spectrum is analysed every `analysisInterval` frames (at least 1).
    public let analysisInterval: Int

    /// Creates a level with `columnShare` (clamped to a small positive share … 1) and `analysisInterval` (at least 1).
    public init(columnShare: Double, analysisInterval: Int) {
        let share = columnShare.isFinite ? columnShare : 1
        self.columnShare = min(max(share, 0.000_001), 1)
        self.analysisInterval = max(1, analysisInterval)
    }

    /// The three levels, best first: (1, 1), (½, 2), (¼, 4).
    public static let levels: [ScopeQuality] = [
        ScopeQuality(columnShare: 1, analysisInterval: 1),
        ScopeQuality(columnShare: 0.5, analysisInterval: 2),
        ScopeQuality(columnShare: 0.25, analysisInterval: 4),
    ]

    /// The quality level names registered in the catalog, best first.
    public static let levelNames = ["level-0", "level-1", "level-2"]

    /// The level index for the governor's `tier`, or `forced` when it is not nil, clamped to 0…2.
    public static func level(tier: Int, forced: Int? = nil) -> Int {
        min(max(forced ?? tier, 0), levels.count - 1)
    }

    /// The level at `index`, clamped to 0…2.
    public static func level(_ index: Int) -> ScopeQuality {
        levels[min(max(index, 0), levels.count - 1)]
    }

    /// The number of columns to draw across `pixelWidth` pixels: max(1, round(width × share)); a non-finite or
    /// non-positive width gives 1.
    public func columns(forPixelWidth pixelWidth: Double) -> Int {
        guard pixelWidth.isFinite, pixelWidth > 0 else { return 1 }
        return max(1, Int((pixelWidth * columnShare).rounded()))
    }

    /// True when the spectrum is analysed on frame `frame`: frame mod ``analysisInterval`` is 0 (negative frames
    /// count the same way, so frame −4 at interval 4 analyses).
    public func shouldAnalyse(frame: Int) -> Bool {
        frame % analysisInterval == 0
    }
}
