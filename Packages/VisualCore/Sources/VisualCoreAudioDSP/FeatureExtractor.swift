// FeatureExtractor — feature 048 (A06-P02) T-A06-204; gap G-AUDIODSP (FR-A06-203–206; research D1–D5; contract
// specs/048-ml-p02-feature-analysis/contracts/api.md). One object per window size and sample rate holds every buffer,
// so an analysis allocates nothing after setup (the returned features share the stored band array until a caller
// mutates its copy). Render side only: never called from an audio callback.
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
    /// The features of the latest ``analyze(_:time:elapsed:)`` (silence before the first and after ``reset()``).
    public private(set) var features: AudioFeatures

    private let analyzer: SpectrumAnalyzer
    private let workspace: SpectrumWorkspace
    private let frame: UnsafeMutableBufferPointer<Float>
    private let power: UnsafeMutableBufferPointer<Float>
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
        previousBands = [Float](repeating: 0, count: layout.bandCount)
        features = .silent(bandCount: layout.bandCount)
    }

    deinit {
        frame.deallocate()
        power.deallocate()
    }

    /// Analyses `samples` (the newest last; at most ``size`` of the newest are used, fewer are padded with silence in
    /// front) at `time`, with `elapsed` seconds since the previous update for the beat smoother.
    /// - Returns: the new ``features``.
    @discardableResult
    public func analyze(_ samples: UnsafeBufferPointer<Float>, time: Double, elapsed: Double) -> AudioFeatures {
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
            features.bandEnergies[band] = energy
        }
        hasPrevious = true
        let onset = onsets.update(flux: flux, time: time)
        let beatEnergy = min(1, max(0, beat.update(target: onset ? 1 : 0, elapsed: elapsed)))
        features.timestamp = time
        features.rms = rms
        features.peak = peak
        features.flux = flux
        features.onset = onset
        features.beatEnergy = beatEnergy
        return features
    }

    /// Forgets the previous window, the onset history and the beat energy (for example when the source changes).
    public func reset() {
        hasPrevious = false
        for i in previousBands.indices { previousBands[i] = 0 }
        onsets.reset()
        beat.reset()
        features = .silent(bandCount: layout.bandCount)
    }
}
