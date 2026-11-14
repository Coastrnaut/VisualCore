// ScopeTrigger — feature 061 (A08-P01) T-A08-102 (FR-A08-103, FR-A08-104); gap G-TRIGGER.
// Spec Clarifications (trigger semantics; timebase, gain and window bounds); data-model.md;
// contract specs/061-os-p01-acquisition/contracts/api.md.
import Foundation

/// The direction of signal crossing that fires the trigger.
public enum TriggerSlope: Int, Sendable, CaseIterable {
    /// The signal crosses the level upwards.
    case rising
    /// The signal crosses the level downwards.
    case falling
}

/// What a scope shows when no trigger is found.
public enum TriggerMode: Int, Sendable, CaseIterable {
    /// Show the newest span untriggered.
    case auto
    /// Keep the last triggered span and report waiting.
    case normal
}

/// Trigger settings: channel, level, slope, hysteresis and mode.
public struct TriggerSettings: Sendable, Equatable {
    /// Default hysteresis (2 % of full scale).
    public static let defaultHysteresis = 0.02
    /// Allowed hysteresis range.
    public static let hysteresisRange = 0.0...0.5

    /// The channel searched: 0 (left) or 1 (right).
    public let channel: Int
    /// The trigger level in full scale, −1…1.
    public let level: Double
    /// The crossing direction.
    public let slope: TriggerSlope
    /// How far the signal must move away from the level (against the slope) to re-arm, 0…0.5.
    public let hysteresis: Double
    /// Behaviour when no crossing is found.
    public let mode: TriggerMode

    /// Creates trigger settings, or `nil` when `level` is not finite.
    ///
    /// - Parameters:
    ///   - channel: clamped to 0…1.
    ///   - level: clamped to −1…1; NaN or infinite is refused.
    ///   - slope: rising or falling.
    ///   - hysteresis: clamped to 0…0.5; a non-finite value gives the default 0.02.
    ///   - mode: auto or normal.
    public init?(channel: Int = 0, level: Double = 0, slope: TriggerSlope = .rising,
                 hysteresis: Double = TriggerSettings.defaultHysteresis, mode: TriggerMode = .auto) {
        guard level.isFinite else { return nil }
        self.channel = min(max(channel, 0), 1)
        self.level = min(max(level, -1), 1)
        self.slope = slope
        self.hysteresis = hysteresis.isFinite
            ? min(max(hysteresis, Self.hysteresisRange.lowerBound), Self.hysteresisRange.upperBound)
            : Self.defaultHysteresis
        self.mode = mode
    }
}

/// Trigger detection with hysteresis.
public enum ScopeTrigger {
    /// Returns the index of the most recent crossing within `searchRange`, or `nil` when there is none.
    ///
    /// A rising crossing is the first sample at or above the level after a sample at or below level − hysteresis:
    /// the trigger is armed by a sample at or below level − hysteresis and fires (then disarms) on the next sample at
    /// or above the level. Falling is the mirror image (armed at or above level + hysteresis, fires at or below the
    /// level). Samples before `searchRange` arm the trigger but crossings are only reported inside the range, which is
    /// clipped to the samples. The channel of the settings is the caller's choice of which samples to pass.
    /// - Parameters:
    ///   - samples: one channel of samples.
    ///   - settings: level, slope and hysteresis.
    ///   - searchRange: indices in which a crossing may be reported.
    /// - Returns: the crossing index, or `nil`.
    public static func find(in samples: [Float], settings: TriggerSettings, searchRange: Range<Int>) -> Int? {
        let lower = max(searchRange.lowerBound, 0)
        let upper = min(searchRange.upperBound, samples.count)
        guard lower < upper else { return nil }
        let level = Float(settings.level)
        let h = Float(settings.hysteresis)
        let rising = settings.slope == .rising
        let armLevel = rising ? level - h : level + h
        var armed = false
        var found: Int?
        samples.withUnsafeBufferPointer { s in
            for i in 0..<upper {
                let v = s[i]
                if rising {
                    if armed && v >= level {
                        armed = false
                        if i >= lower { found = i }
                    }
                    if v <= armLevel { armed = true }
                } else {
                    if armed && v <= level {
                        armed = false
                        if i >= lower { found = i }
                    }
                    if v >= armLevel { armed = true }
                }
            }
        }
        return found
    }
}

/// The span of a scope window: seconds per division over ten divisions, capped at ``maxSamples`` samples.
public struct TimebaseWindow: Sendable, Equatable {
    /// Largest number of samples per channel in a window.
    public static let maxSamples = 4_096

    /// Seconds per division.
    public let secondsPerDivision: Double
    /// Number of horizontal divisions (always 10).
    public let divisions: Int = 10

    /// Creates a timebase window.
    ///
    /// - Parameter secondsPerDivision: seconds per division; a non-positive or non-finite value gives a one-sample
    ///   window.
    public init(secondsPerDivision: Double) {
        self.secondsPerDivision = secondsPerDivision
    }

    /// The unclamped sample count `round(secondsPerDivision × divisions × sampleRate)`, or 0 when not computable.
    private func rawCount(sampleRate: Double) -> Double {
        let raw = (secondsPerDivision * Double(divisions) * sampleRate).rounded()
        return raw.isFinite ? raw : 0
    }

    /// Samples per channel in the window: `min(round(secondsPerDivision × 10 × sampleRate), 4,096)`, at least 1.
    ///
    /// - Parameter sampleRate: samples per second.
    /// - Returns: the sample count.
    public func sampleCount(sampleRate: Double) -> Int {
        let raw = rawCount(sampleRate: sampleRate)
        return Int(min(max(raw, 1), Double(Self.maxSamples)))
    }

    /// Whether the cap of ``maxSamples`` shortened the span at `sampleRate`.
    ///
    /// - Parameter sampleRate: samples per second.
    /// - Returns: `true` when the full span would need more than ``maxSamples`` samples.
    public func isShortened(sampleRate: Double) -> Bool {
        rawCount(sampleRate: sampleRate) > Double(Self.maxSamples)
    }
}
