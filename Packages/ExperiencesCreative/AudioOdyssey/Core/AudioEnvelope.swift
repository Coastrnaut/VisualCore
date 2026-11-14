// AudioEnvelope — feature 056 (A07-P03) T-A07-302 (FR-A07-310; clarification 1; research D1; data-model
// "AudioEnvelope"). The audio envelope of Audio Odyssey: low, mid, high and transient channels in 0…1 with the analysis
// timestamp, plus the derived overall channel (the mean of low, mid and high). Pure numbers built from plain arrays and
// flags, so the Core needs no audio module: the experience passes the analysed band energies, the spectral flux and the
// onset flag once per frame.
//
// Rules: with 16 (or more) bands, low = mean of bands 0–3, mid = mean of bands 4–9, high = mean of bands 10–15 (bands
// past 15 are ignored); with 3…15 bands the bands are split evenly into three consecutive groups; with 1 or 2 bands
// every group is the mean of all bands; with no band every group is 0. Each raw value (and the flux) is normalised by
// its own running peak, `peak = max(raw, peak × exp(−elapsed / 0.5))` with a floor of 1e-6, so a normalised value is
// always in 0…1. The transient's normalised flux is raised to at least 0.8 on an onset frame. Each channel then moves
// toward its normalised value with the factor `1 − exp(−elapsed / τ)`, τ = 0.03 s when rising (attack) and 0.3 s when
// falling (release). NaN, infinite and negative inputs count as 0. An elapsed time that is not finite and > 0 changes
// nothing but the timestamp (a non-finite time keeps the old timestamp).
import Foundation

/// A channel of the audio envelope that a world mapping can choose. The raw values are persisted (low 0, mid 1,
/// high 2, transient 3, overall 4).
public enum EnvelopeChannel: Int, CaseIterable, Codable, Sendable {
    /// The low bands (bands 0–3 of 16).
    case low = 0
    /// The middle bands (bands 4–9 of 16).
    case mid = 1
    /// The high bands (bands 10–15 of 16).
    case high = 2
    /// The normalised spectral flux, raised on onsets (the beats).
    case transient = 3
    /// The mean of low, mid and high (a level-like channel).
    case overall = 4

    /// The name shown in the mapping editor and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .low: "Bass"
        case .mid: "Mids"
        case .high: "Highs"
        case .transient: "Beats"
        case .overall: "Overall level"
        }
    }
}

/// The smoothed, normalised audio envelope: low, mid, high and transient in 0…1, the derived overall channel and the
/// timestamp of the analysis that produced it.
public struct AudioEnvelope: Equatable, Sendable {
    /// The band ranges of the low, mid and high channels when 16 bands are given.
    public static let standardGroups: [Range<Int>] = [0..<4, 4..<10, 10..<16]
    /// The time constant of the running-peak decay, in seconds.
    public static let peakDecay = 0.5
    /// The smallest running peak (keeps the normalisation finite in silence).
    public static let peakFloor = 1e-6
    /// The smoothing time constant of a rising channel, in seconds.
    public static let attack = 0.03
    /// The smoothing time constant of a falling channel, in seconds.
    public static let release = 0.3
    /// The lowest raw transient on an onset frame.
    public static let onsetFloor = 0.8

    /// The smoothed low channel, in 0…1.
    public private(set) var low: Double = 0
    /// The smoothed mid channel, in 0…1.
    public private(set) var mid: Double = 0
    /// The smoothed high channel, in 0…1.
    public private(set) var high: Double = 0
    /// The smoothed transient channel, in 0…1.
    public private(set) var transient: Double = 0
    /// The time of the analysis of the last update, in seconds (0 before the first update).
    public private(set) var timestamp: Double = 0

    private var peaks: [Double] = Array(repeating: AudioEnvelope.peakFloor, count: 4)

    /// A silent envelope: every channel 0, timestamp 0.
    public init() {}

    /// The mean of low, mid and high, in 0…1.
    public var overall: Double { (low + mid + high) / 3 }

    /// The value of `channel`, in 0…1.
    public func value(_ channel: EnvelopeChannel) -> Double {
        switch channel {
        case .low: low
        case .mid: mid
        case .high: high
        case .transient: transient
        case .overall: overall
        }
    }

    /// Advances the envelope by one analysis frame: groups and normalises the band energies and the flux, applies the
    /// onset floor and smooths every channel over `elapsed` seconds; `time` becomes the timestamp.
    public mutating func update(bandEnergies: [Float], flux: Float, onset: Bool, time: Double, elapsed: Double) {
        if time.isFinite { timestamp = time }
        guard elapsed.isFinite, elapsed > 0 else { return }
        let groups = Self.groupMeans(bandEnergies)
        let raws = [groups[0], groups[1], groups[2], Self.sanitised(flux)]
        let decay = exp(-elapsed / Self.peakDecay)
        var targets = [Double](repeating: 0, count: 4)
        for i in 0..<4 {
            peaks[i] = max(raws[i], peaks[i] * decay, Self.peakFloor)
            targets[i] = min(max(raws[i] / peaks[i], 0), 1)
        }
        if onset { targets[3] = max(targets[3], Self.onsetFloor) }
        low = Self.smooth(low, toward: targets[0], elapsed: elapsed)
        mid = Self.smooth(mid, toward: targets[1], elapsed: elapsed)
        high = Self.smooth(high, toward: targets[2], elapsed: elapsed)
        transient = Self.smooth(transient, toward: targets[3], elapsed: elapsed)
    }

    /// The raw low, mid and high values of `bands` (means of the groups described in the file header).
    public static func groupMeans(_ bands: [Float]) -> [Double] {
        let values = bands.map(sanitised)
        let n = values.count
        guard n > 0 else { return [0, 0, 0] }
        if n < 3 {
            let all = values.reduce(0, +) / Double(n)
            return [all, all, all]
        }
        let ranges = n >= 16 ? standardGroups : (0..<3).map { i in (i * n / 3)..<((i + 1) * n / 3) }
        return ranges.map { range in values[range].reduce(0, +) / Double(range.count) }
    }

    private static func sanitised(_ value: Float) -> Double {
        let v = Double(value)
        return v.isFinite && v > 0 ? v : 0
    }

    private static func smooth(_ value: Double, toward target: Double, elapsed: Double) -> Double {
        let tau = target > value ? attack : release
        let next = value + (target - value) * (1 - exp(-elapsed / tau))
        return min(max(next, 0), 1)
    }
}
