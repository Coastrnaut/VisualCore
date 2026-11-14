// AudioFeatures — feature 048 (A06-P02) T-A06-204; gap G-AUDIODSP (FR-A06-205, FR-A06-206; data-model "AudioFeatures").
// The features of one analysis window: level, band energies, spectral flux, onset and smoothed beat energy. A value,
// never persisted and never part of an experience's state.
import Foundation

/// The features of one analysis window.
public struct AudioFeatures: Sendable, Equatable {
    /// Seconds of the analysis (the caller's clock, for example the frame time).
    public var timestamp: Double
    /// Root mean square level of the window (full scale = 1).
    public var rms: Float
    /// Largest absolute sample of the window.
    public var peak: Float
    /// Linear power per band of the ``BandLayout`` (full-scale sine centred on a bin ≈ 1).
    public var bandEnergies: [Float]
    /// Sum over bands of the positive increase in energy since the previous window.
    public var flux: Float
    /// Whether this window starts an onset (see ``OnsetDetector``).
    public var onset: Bool
    /// The onset pulse smoothed with ``FeatureExtractor/beatAttack`` and ``FeatureExtractor/beatRelease`` (0…1).
    public var beatEnergy: Float

    /// Creates a feature set from its fields.
    public init(timestamp: Double, rms: Float, peak: Float, bandEnergies: [Float], flux: Float, onset: Bool,
                beatEnergy: Float) {
        self.timestamp = timestamp
        self.rms = rms
        self.peak = peak
        self.bandEnergies = bandEnergies
        self.flux = flux
        self.onset = onset
        self.beatEnergy = beatEnergy
    }

    /// The features of silence for `bandCount` bands at time 0.
    public static func silent(bandCount: Int) -> AudioFeatures {
        AudioFeatures(timestamp: 0, rms: 0, peak: 0, bandEnergies: [Float](repeating: 0, count: max(0, bandCount)),
                      flux: 0, onset: false, beatEnergy: 0)
    }

    /// ``rms`` in dBFS, floored at ``LevelMeter/floorDB``.
    public var rmsDB: Float { LevelMeter.dBFS(rms) }
    /// ``peak`` in dBFS, floored at ``LevelMeter/floorDB``.
    public var peakDB: Float { LevelMeter.dBFS(peak) }

    /// Band `index` in dB (10·log10 of its power), floored at ``LevelMeter/floorDB``; the floor for an index out of range.
    public func bandDB(_ index: Int) -> Float {
        guard bandEnergies.indices.contains(index) else { return LevelMeter.floorDB }
        let energy = bandEnergies[index]
        guard energy > 0, energy.isFinite else { return LevelMeter.floorDB }
        return max(LevelMeter.floorDB, 10 * log10(energy))
    }
}
