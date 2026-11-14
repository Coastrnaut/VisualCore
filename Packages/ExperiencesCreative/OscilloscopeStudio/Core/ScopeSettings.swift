// ScopeSettings — feature 061 (A08-P01) T-A08-104 (FR-A08-110, FR-A08-111; clarification 4; data-model "ScopeState").
// The choice tables of Oscilloscope Studio: the sources, the test waveforms, the test frequencies (100, 440, 1,000 and
// 5,000 Hz), the gains (×0.5, ×1, ×2, ×5, ×10), the timebases (0.1, 0.2, 0.5, 1, 2 and 5 ms per division over ten
// divisions), the trigger slopes and modes, and the names spoken in the canvas description. The positions in these
// tables are the persisted indices of `ScopeState` and the values of the experience actions; they never change order.
// Feature 062 (A08-P02) T-A08-205 (FR-A08-211, FR-A08-212) adds the display mode, waveform or XY.
import Foundation
import VisualCoreAudioDSP

/// The signal source of the scope. The raw values are persisted and are the values of the `source.select` action.
public enum ScopeSource: Int, CaseIterable, Codable, Sendable {
    /// The built-in deterministic test signal (the first choice and the fallback when the microphone is denied).
    case testSignal = 0
    /// An audio file the person picked (kept app-owned; one or two channels).
    case file = 1
    /// The live microphone (one channel), after the person allowed access.
    case microphone = 2

    /// The name shown on the source picker and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .testSignal: "Test signal"
        case .file: "File"
        case .microphone: "Microphone"
        }
    }
}

/// The display mode of the scope. The raw values are persisted and are the values of the `display.select` action
/// (feature 062, A08-P02, FR-A08-211, FR-A08-212).
public enum ScopeDisplay: Int, Sendable, CaseIterable, Codable {
    /// The waveform view: each channel drawn against time (the first choice and the schema-1 migration value).
    case waveform = 0
    /// The XY view: the left channel plotted against the right channel (stereo windows only).
    case xy = 1

    /// The name shown on the display picker and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .waveform: "waveform"
        case .xy: "XY"
        }
    }
}

/// The choice tables of the scope; every persisted index points into one of them.
public enum ScopeSettings {
    /// The test waveforms in action order (`signal.waveform` 0…2): sine, square, sweep.
    public static let waveforms: [TestSignal.Waveform] = [.sine, .square, .sweep]
    /// The test frequencies in hertz (`signal.frequency` 0…3).
    public static let frequencies: [Double] = [100, 440, 1_000, 5_000]
    /// The display gains (`gain.select` 0…4).
    public static let gains: [Double] = [0.5, 1, 2, 5, 10]
    /// The timebases in milliseconds per division (`timebase.select` 0…5).
    public static let timebasesMilliseconds: [Double] = [0.1, 0.2, 0.5, 1, 2, 5]
    /// The trigger slopes in action order (`trigger.slope` 0…1): rising, falling.
    public static let slopes: [TriggerSlope] = [.rising, .falling]
    /// The trigger modes in action order (`trigger.mode` 0…1): auto, normal.
    public static let modes: [TriggerMode] = [.auto, .normal]
    /// The trigger level range (full scale).
    public static let triggerLevelRange: ClosedRange<Double> = -1...1
    /// The trigger hysteresis in full scale (2 %, clarification 3).
    public static let triggerHysteresis = 0.02

    /// The index of the 1 kHz test frequency (the first choice).
    public static let defaultFrequencyIndex = 2
    /// The index of the ×1 gain (the first choice).
    public static let defaultGainIndex = 1
    /// The index of the 1 ms/div timebase (the first choice).
    public static let defaultTimebaseIndex = 3

    /// The index of `waveform` in ``waveforms``.
    public static func index(of waveform: TestSignal.Waveform) -> Int { waveforms.firstIndex(of: waveform) ?? 0 }
    /// The index of `slope` in ``slopes``.
    public static func index(of slope: TriggerSlope) -> Int { slopes.firstIndex(of: slope) ?? 0 }
    /// The index of `mode` in ``modes``.
    public static func index(of mode: TriggerMode) -> Int { modes.firstIndex(of: mode) ?? 0 }

    /// The spoken name of `waveform`.
    public static func displayName(of waveform: TestSignal.Waveform) -> String {
        switch index(of: waveform) {
        case 1: "Square"
        case 2: "Sweep"
        default: "Sine"
        }
    }

    /// The spoken name of `slope`.
    public static func displayName(of slope: TriggerSlope) -> String { index(of: slope) == 1 ? "Falling" : "Rising" }

    /// The spoken name of `mode`.
    public static func displayName(of mode: TriggerMode) -> String { index(of: mode) == 1 ? "Normal" : "Auto" }

    /// The spoken text of the frequency at `index` ("100 Hz", "440 Hz", "1 kHz", "5 kHz"); empty when unknown.
    public static func frequencyName(_ index: Int) -> String {
        guard frequencies.indices.contains(index) else { return "" }
        let hz = frequencies[index]
        return hz >= 1_000 ? "\(Self.trimmed(hz / 1_000)) kHz" : "\(Self.trimmed(hz)) Hz"
    }

    /// The spoken text of the gain at `index` ("×0.5" … "×10"); empty when unknown.
    public static func gainName(_ index: Int) -> String {
        gains.indices.contains(index) ? "×\(Self.trimmed(gains[index]))" : ""
    }

    /// The spoken text of the timebase at `index` ("0.1 ms per division" …); empty when unknown.
    public static func timebaseName(_ index: Int) -> String {
        timebasesMilliseconds.indices.contains(index)
            ? "\(Self.trimmed(timebasesMilliseconds[index])) ms per division" : ""
    }

    /// `value` without a trailing ".0" when it is whole.
    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
