// FeatureExtractor — feature 048 (A06-P02) T-A06-204; gap G-AUDIODSP (FR-A06-203–206; research D1–D5; contract
// specs/048-ml-p02-feature-analysis/contracts/api.md). One object per window size and sample rate holds every buffer.
// `analyze(_:time:elapsed:into:)` writes into a caller-held feature set and allocates nothing after setup when the
// caller's band array already has the band count and is not shared (convergence T-A06-215); the returning
// `analyze(_:time:elapsed:)` is a convenience that makes a new feature set. Render side only: never called from an
// audio callback.
import Foundation

/// Turns the newest samples of a source into ``AudioFeatures``, once per update (for example once per frame).
///
/// Not thread-safe: one owner (the render side) creates, uses and releases it.
public final class FeatureExtractor {
    /// Attack of the smoothed beat energy, in seconds.
    public static let beatAttack: Double = 0.01
    /// Release of the smoothed beat energy, in seconds.
    public static let beatRelease: Double = 0.25

    /// The band layout used for ``AudioFeatures/bandEnergies``.
    public let layout: BandLayout
    /// The features of the latest analysis (silence before the first and after ``reset()``); a new value per read.
    public var features: AudioFeatures {
        AudioFeatures(timestamp: timestamp, rms: rms, peak: peak, bandEnergies: Array(bands), flux: flux, onset: onset,
                      beatEnergy: beatEnergy)
    }

    private let analyzer: SpectrumAnalyzer
    private let workspace: SpectrumWorkspace
    private let frame: UnsafeMutableBufferPointer<Float>
    private let power: UnsafeMutableBufferPointer<Float>
    private let bands: UnsafeMutableBufferPointer<Float>
    private var timestamp: Double = 0
    private var rms: Float = 0
    private var peak: Float = 0
    private var flux: Float = 0
    private var onset = false
    private var beatEnergy: Float = 0
    private var previousBands: [Float]
    private var hasPrevious = false
    private var onsets = OnsetDetector()
    private var beat = FeatureSmoother(attack: FeatureExtractor.beatAttack, release: FeatureExtractor.beatRelease)

    /// Window size in samples.
    public var size: Int { analyzer.size }
    /// Sample rate in hertz.
    public var sampleRate: Double { layout.sampleRate }

    /// Creates an extractor for windows of `size` samples at `sampleRate`, or `nil` when the size or the band layout
    /// is invalid (see ``SpectrumAnalyzer/init(size:)`` and ``BandLayout``).
    public init?(size: Int = 1_024, sampleRate: Double, bandCount: Int = 16) {
        guard let analyzer = SpectrumAnalyzer(size: size), let workspace = SpectrumWorkspace(size: size),
              let layout = BandLayout(bandCount: bandCount, sampleRate: sampleRate, size: size) else { return nil }
        self.analyzer = analyzer
        self.workspace = workspace
        self.layout = layout
        frame = .allocate(capacity: size)
        frame.initialize(repeating: 0)
        power = .allocate(capacity: size / 2)
        power.initialize(repeating: 0)
        bands = .allocate(capacity: layout.bandCount)
        bands.initialize(repeating: 0)
        previousBands = [Float](repeating: 0, count: layout.bandCount)
    }

    deinit {
        frame.deallocate()
        power.deallocate()
        bands.deallocate()
    }

    /// Analyses `samples` (the newest last; at most ``size`` of the newest are used, fewer are padded with silence in
    /// front) at `time`, with `elapsed` seconds since the previous update for the beat smoother.
    /// - Returns: the new ``features`` (a new value; use ``analyze(_:time:elapsed:into:)`` to avoid allocating).
    @discardableResult
    public func analyze(_ samples: UnsafeBufferPointer<Float>, time: Double, elapsed: Double) -> AudioFeatures {
        var out = AudioFeatures.silent(bandCount: layout.bandCount)
        analyze(samples, time: time, elapsed: elapsed, into: &out)
        return out
    }

    /// Analyses like ``analyze(_:time:elapsed:)`` and writes the features into `out`. Allocates nothing when
    /// `out.bandEnergies` already holds ``BandLayout/bandCount`` values and is not shared with another value.
    public func analyze(_ samples: UnsafeBufferPointer<Float>, time: Double, elapsed: Double,
                        into out: inout AudioFeatures) {
        let n = size
        let used = min(samples.count, n)
        let pad = n - used
        if pad > 0 { frame.baseAddress!.update(repeating: 0, count: pad) }
        if used > 0, let base = samples.baseAddress {
            for i in 0..<used {
                let s = base[samples.count - used + i]
                frame[pad + i] = s.isFinite ? s : 0
            }
        }
        let window = UnsafeBufferPointer(frame)
        let rms = LevelMeter.rms(window)
        let peak = LevelMeter.peak(window)
        analyzer.powerSpectrum(window, into: power, workspace: workspace)

        var flux: Float = 0
        for (band, bins) in layout.bins.enumerated() {
            var energy: Float = 0
            for k in bins { energy += power[k] }
            if hasPrevious { flux += max(0, energy - previousBands[band]) }
            previousBands[band] = energy
            bands[band] = energy
        }
        hasPrevious = true
        let onset = onsets.update(flux: flux, time: time)
        let beatEnergy = min(1, max(0, beat.update(target: onset ? 1 : 0, elapsed: elapsed)))
        (self.timestamp, self.rms, self.peak, self.flux, self.onset, self.beatEnergy) =
            (time, rms, peak, flux, onset, beatEnergy)
        if out.bandEnergies.count != bands.count {
            out.bandEnergies = [Float](repeating: 0, count: bands.count)
        }
        out.bandEnergies.withUnsafeMutableBufferPointer { dst in
            dst.baseAddress!.update(from: bands.baseAddress!, count: bands.count)
        }
        out.timestamp = time
        out.rms = rms
        out.peak = peak
        out.flux = flux
        out.onset = onset
        out.beatEnergy = beatEnergy
    }

    /// Forgets the previous window, the onset history and the beat energy (for example when the source changes).
    public func reset() {
        hasPrevious = false
        for i in previousBands.indices { previousBands[i] = 0 }
        onsets.reset()
        beat.reset()
        bands.update(repeating: 0)
        (timestamp, rms, peak, flux, onset, beatEnergy) = (0, 0, 0, 0, false, 0)
    }
}
