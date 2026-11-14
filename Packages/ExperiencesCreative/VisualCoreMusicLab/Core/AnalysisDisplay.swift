// AnalysisDisplay — feature 048 (A06-P02) T-A06-205 (FR-A06-210, FR-A06-212; data-model "AnalysisDisplay", research
// D6). The display mapping of the analysed features of VisualCore Music Lab: band, RMS and peak levels in dBFS become
// bar, level and peak-mark heights in 0…1 (−80…0 dB mapped linearly, clamped), the smoothed beat energy is drawn as is
// (clamped to 0…1), and the RMS level is put into words for the canvas description. GPU-free and audio-free: plain
// numbers in, plain numbers out.
import Foundation

/// The heights VisualCore Music Lab draws for one frame of analysed features, each in 0…1.
public struct AnalysisDisplay: Sendable, Equatable {
    /// The lowest level drawn, in dBFS: this and anything quieter is drawn at height 0.
    public static let floorDB: Double = -80

    /// The smoothed beat energy above which the canvas description says "beat" (FR-A06-212).
    public static let beatThreshold: Float = 0.5

    /// One bar height per spectrum band, in the order of the bands, each in 0…1.
    public let bars: [Double]
    /// The height of the level meter (RMS), in 0…1.
    public let level: Double
    /// The height of the peak mark on the level meter, in 0…1.
    public let peakMark: Double
    /// The height of the beat meter (smoothed beat energy, clamped), in 0…1.
    public let beat: Double

    /// Maps a level in dBFS linearly from −80…0 dB to a height in 0…1, clamped; NaN maps to 0.
    /// - Parameter dB: The level in dBFS.
    /// - Returns: The height in 0…1.
    public static func height(dB: Double) -> Double {
        guard !dB.isNaN else { return 0 }
        let fraction = (dB - floorDB) / (0 - floorDB)
        return min(max(fraction, 0), 1)
    }

    /// Builds the display heights from one frame of analysed features.
    /// - Parameters:
    ///   - bandDB: The spectrum band levels in dBFS; one bar is drawn per band.
    ///   - rmsDB: The RMS level in dBFS (the level meter).
    ///   - peakDB: The peak level in dBFS (the peak mark).
    ///   - beat: The smoothed beat energy; clamped to 0…1, NaN draws as 0.
    public init(bandDB: [Float], rmsDB: Float, peakDB: Float, beat: Float) {
        bars = bandDB.map { Self.height(dB: Double($0)) }
        level = Self.height(dB: Double(rmsDB))
        peakMark = Self.height(dB: Double(peakDB))
        self.beat = beat.isNaN ? 0 : min(max(Double(beat), 0), 1)
    }

    /// A display with every height at 0, for silence or before the first analysis.
    /// - Parameter bandCount: The number of bars (negative counts give no bars).
    /// - Returns: The all-zero display.
    public static func silent(bandCount: Int) -> AnalysisDisplay {
        AnalysisDisplay(
            bandDB: Array(repeating: Float(floorDB), count: max(bandCount, 0)),
            rmsDB: Float(floorDB), peakDB: Float(floorDB), beat: 0)
    }

    /// Whether the smoothed beat energy is above ``beatThreshold``, so the canvas description says "beat".
    public var isBeat: Bool { beat > Double(Self.beatThreshold) }
}

/// The level of the sound in words, as the canvas description states it (FR-A06-212).
public enum LevelWord: String, Sendable, CaseIterable {
    /// Below −40 dBFS RMS.
    case quiet
    /// From −40 dBFS up to, but not including, −20 dBFS RMS.
    case medium
    /// −20 dBFS RMS and louder.
    case loud

    /// RMS levels below this, in dBFS, are "quiet".
    public static let quietBelowDB: Float = -40
    /// RMS levels below this (and not quiet), in dBFS, are "medium".
    public static let mediumBelowDB: Float = -20

    /// The word for an RMS level.
    /// - Parameter rmsDB: The RMS level in dBFS; NaN is "quiet".
    /// - Returns: The level word.
    public static func from(rmsDB: Float) -> LevelWord {
        guard !rmsDB.isNaN else { return .quiet }
        if rmsDB < quietBelowDB { return .quiet }
        if rmsDB < mediumBelowDB { return .medium }
        return .loud
    }
}
