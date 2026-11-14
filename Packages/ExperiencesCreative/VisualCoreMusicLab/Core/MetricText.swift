// MetricText — feature 051 (A06-P05) T-A06-503 (FR-A06-510, FR-A06-511; SC-A06-503; spec clarifications 2 and 3;
// research D3–D4; data-model "MetricText", "AnnouncementGate"). The sound metrics of VisualCore Music Lab put into
// words for VoiceOver ("Level −9 dB, strongest high-mid, no beat"), and the gate that rate-limits their announcement to
// at most one per 2 s and only for changed text. GPU-free and audio-free: plain numbers in, a plain string out.
import Foundation

/// The approximate sound metrics of VisualCore Music Lab as one short sentence (FR-A06-510).
public enum MetricText {
    /// The RMS level in dBFS at or below which the sound reads as silent.
    public static let silentBelowDB: Float = -90

    /// The names of the four spectrum regions, lowest first (bands 0–3, 4–7, 8–11, 12–15).
    public static let regionNames = ["low", "low-mid", "high-mid", "high"]

    /// The number of spectrum bands summed into one region.
    static let bandsPerRegion = 4

    /// Sums the band energies into the four regions of ``regionNames``.
    /// - Parameter bandEnergies: The band energies, lowest band first; missing bands count as 0 and non-finite values
    ///   are ignored. Bands past the sixteenth are ignored.
    /// - Returns: Four region energies: the sums of bands 0–3, 4–7, 8–11 and 12–15.
    public static func regionEnergies(bandEnergies: [Float]) -> [Float] {
        var regions = [Float](repeating: 0, count: regionNames.count)
        for (index, energy) in bandEnergies.enumerated() where energy.isFinite {
            let region = index / bandsPerRegion
            guard region < regions.count else { break }
            regions[region] += energy
        }
        return regions
    }

    /// Builds the metric text, for example "Level −9 dB, strongest high-mid, no beat".
    /// - Parameters:
    ///   - rmsDB: The RMS level in dBFS; non-finite or at most ``silentBelowDB`` reads as "Level silent". Otherwise it is
    ///     rounded to the nearest integer and negative values carry the minus sign U+2212.
    ///   - regionEnergies: The region energies (see ``regionEnergies(bandEnergies:)``); the largest names the strongest
    ///     region (ties go to the lowest region). "strongest none" when silent or when no region has a positive finite
    ///     energy.
    ///   - beat: The smoothed beat energy; above 0.5 reads as "beat", else (or non-finite) "no beat".
    /// - Returns: The level, region and beat parts joined with ", ".
    public static func make(rmsDB: Float, regionEnergies: [Float], beat: Float) -> String {
        let silent = !rmsDB.isFinite || rmsDB <= silentBelowDB
        let level: String
        if silent {
            level = "Level silent"
        } else {
            let rounded = Int(min(max(rmsDB, -1_000_000), 1_000_000).rounded())
            level = "Level \(rounded < 0 ? "\u{2212}" : "")\(abs(rounded)) dB"
        }
        var strongest = "none"
        if !silent {
            var best: Int?
            for (index, energy) in regionEnergies.prefix(regionNames.count).enumerated()
            where energy.isFinite && energy > 0 {
                if let current = best, regionEnergies[current] >= energy { continue }
                best = index
            }
            if let best { strongest = regionNames[best] }
        }
        let beatPart = beat > AnalysisDisplay.beatThreshold ? "beat" : "no beat"
        return [level, "strongest \(strongest)", beatPart].joined(separator: ", ")
    }
}

/// Rate-limits announcements of the metric text: at most one per ``minimumInterval`` and only for changed text
/// (FR-A06-511).
public struct AnnouncementGate: Sendable, Equatable {
    /// The shortest time between two announcements, in seconds.
    public static let minimumInterval: Double = 2

    /// The text of the last announcement, or nil before the first.
    public private(set) var lastText: String?
    /// The time of the last announcement in seconds, or nil before the first.
    public private(set) var lastTime: Double?

    /// Creates a gate that has announced nothing yet.
    public init() {}

    /// Decides whether to announce a text now, and records it when it does.
    /// - Parameters:
    ///   - text: The text to announce; empty text never announces.
    ///   - time: The current time in seconds (any monotonic clock).
    /// - Returns: True when the text differs from the last announced text and at least ``minimumInterval`` has passed
    ///   since the last announcement (or there was none); the text and time are then recorded.
    public mutating func shouldAnnounce(text: String, at time: Double) -> Bool {
        guard !text.isEmpty, text != lastText else { return false }
        if let lastTime, time - lastTime < Self.minimumInterval { return false }
        lastText = text
        lastTime = time
        return true
    }
}
