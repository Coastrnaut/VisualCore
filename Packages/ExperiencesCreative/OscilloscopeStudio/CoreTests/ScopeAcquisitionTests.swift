// ScopeAcquisitionTests — feature 061 (A08-P01) T-A08-104 (FR-A08-110; SC-A08-101, SC-A08-102; clarifications 3 and
// 4). The acquisition rule, host-free and short, on buffers filled from `TestSignal` at 48 kHz: the periods per window
// for 100 Hz, 440 Hz, 1 kHz and 5 kHz at every timebase, the spectrum peak bin of the 1 kHz window, 440 Hz at 5 ms/div,
// consecutive triggered windows on the same phase, the flat line (auto untriggered, normal waiting), the partial
// window, the mono ring window, gain and clipping.
//
// The periods in a window are measured from its samples alone with the sine recurrence x[n+1] + x[n−1] = 2·cos ω·x[n]
// (least squares over the window), so the measurement works for windows shorter than one period too.
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct ScopeAcquisitionTests {
    private let rate = 48_000.0

    /// A sine test signal at `frequency` with `amplitude` (both channels at the same frequency).
    private func sine(_ frequency: Double, amplitude: Double = 0.8) -> TestSignal {
        TestSignal(waveform: .sine, frequency: frequency, amplitude: amplitude, sampleRate: rate, channelCount: 2)
    }

    /// A 16,384-frame buffer (the experience's size).
    private func makeBuffer() throws -> StereoSampleBuffer { StereoSampleBuffer(capacityFrames: 16_384) }

    /// Writes frames `start..<start + count` of `signal` (closed form) into `buffer`.
    private func write(_ signal: TestSignal, frames start: Int, count: Int, into buffer: StereoSampleBuffer) {
        let left = (start..<(start + count)).map { signal.value(atFrame: $0, channel: 0) }
        let right = (start..<(start + count)).map { signal.value(atFrame: $0, channel: 1) }
        buffer.write(left: left, right: right)
    }

    /// A state with the given table indices and trigger.
    private func state(frequency: Int = 2, gain: Int = 1, timebase: Int = 3, level: Double = 0,
                       slope: TriggerSlope = .rising, mode: TriggerMode = .auto) throws -> ScopeState {
        try #require(ScopeState(source: .testSignal, waveform: .sine, frequencyIndex: frequency, gainIndex: gain,
                                timebaseIndex: timebase, triggerLevel: level, triggerSlope: slope, triggerMode: mode))
    }

    /// The number of sine periods in `samples` from the recurrence x[n+1] + x[n−1] = 2·cos ω·x[n].
    private func measuredPeriods(_ samples: [Float]) -> Double {
        guard samples.count >= 3 else { return 0 }
        var num = 0.0, den = 0.0
        for n in 1..<(samples.count - 1) {
            let x = Double(samples[n])
            num += x * (Double(samples[n - 1]) + Double(samples[n + 1]))
            den += 2 * x * x
        }
        let omega = acos(min(max(num / den, -1), 1))
        return Double(samples.count) * omega / (2 * .pi)
    }

    /// The expected span at `timebase` index.
    private func span(_ timebase: Int) -> Int {
        TimebaseWindow(secondsPerDivision: ScopeSettings.timebasesMilliseconds[timebase] / 1_000)
            .sampleCount(sampleRate: rate)
    }

    @Test func periodsPerWindowMatchTheTestSignalAtEveryTimebase() throws {
        for (f, frequency) in ScopeSettings.frequencies.enumerated() {
            let signal = sine(frequency)
            let buffer = try makeBuffer()
            write(signal, frames: 0, count: 12_288, into: buffer)
            let acquisition = ScopeAcquisition()
            for t in ScopeSettings.timebasesMilliseconds.indices {
                let window = acquisition.window(from: buffer, channelCount: 2, sampleRate: rate,
                                                state: try state(frequency: f, timebase: t))
                let expectedCount = span(t)
                #expect(window.sampleCount == expectedCount)
                #expect(window.channelCount == 2 && window.right.count == expectedCount)
                #expect(!window.partial && !window.shortened)
                let expected = TestSignal.periods(frequency: frequency, sampleCount: expectedCount, sampleRate: rate)
                #expect(abs(expected - frequency * Double(expectedCount) / rate) < 1e-9)
                let measured = measuredPeriods(window.left)
                #expect(abs(measured - expected) <= 0.1, "\(frequency) Hz at timebase \(t): \(measured) vs \(expected)")
                // The window is exactly the samples the signal wrote at its frames.
                #expect(window.left[0] == signal.value(atFrame: window.startFrame, channel: 0))
            }
        }
    }

    @Test func fourFortyHertzAtFiveMillisecondsShowsTwentyTwoPeriods() throws {
        let buffer = try makeBuffer()
        write(sine(440), frames: 0, count: 8_192, into: buffer)
        let window = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate,
                                               state: try state(frequency: 1, timebase: 5))
        #expect(window.sampleCount == 2_400)
        #expect(abs(measuredPeriods(window.left) - 22) <= 0.1)
    }

    @Test func theOneKilohertzWindowPeaksAtTheExpectedBin() throws {
        // The widest 48 kHz window (5 ms/div, 2,400 samples) in a 4,096-point spectrum (zero-padded by the analyser).
        let buffer = try makeBuffer()
        write(sine(1_000), frames: 0, count: 8_192, into: buffer)
        let window = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate,
                                               state: try state(frequency: 2, timebase: 5))
        let analyzer = try #require(SpectrumAnalyzer(size: 4_096))
        let expected = SpectrumAnalyzer.expectedBin(frequency: 1_000, sampleRate: rate, size: 4_096)
        #expect(expected == 85)
        #expect(SpectrumAnalyzer.peakBin(analyzer.magnitudesDB(window.left)) == expected)
    }

    @Test func consecutiveWindowsStartOnTheSamePhase() throws {
        let signal = sine(1_000)
        let buffer = try makeBuffer()
        let acquisition = ScopeAcquisition()
        let step = 1_000 / rate   // periods per sample (1/48)
        var written = 0
        for _ in 0..<12 {
            write(signal, frames: written, count: 1_024, into: buffer)
            written += 1_024
            let window = acquisition.window(from: buffer, channelCount: 2, sampleRate: rate, state: try state())
            #expect(window.triggered && window.sampleCount == 480)
            #expect(window.startFrame + window.sampleCount <= written)
            // The first sample is the first one at or above the level after the signal was below it.
            #expect(window.left[0] >= 0)
            #expect(signal.value(atFrame: window.startFrame - 1, channel: 0) < 0)
            // Its phase is within one sample step after the rising zero crossing.
            let phase = Double((window.startFrame * 1_000) % 48_000) / 48_000   // exact integer phase
            #expect(phase >= 0 && phase < step + 1e-9)
        }
    }

    @Test func aFlatLineIsUntriggeredInAutoAndWaitingInNormal() throws {
        let buffer = try makeBuffer()
        buffer.write(left: [Float](repeating: 0, count: 4_096), right: [Float](repeating: 0, count: 4_096))
        let auto = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate,
                                             state: try state(level: 0.5))
        #expect(!auto.triggered && !auto.waiting && auto.sampleCount == 480 && auto.startFrame == 4_096 - 480)
        let normal = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate,
                                               state: try state(level: 0.5, mode: .normal))
        #expect(!normal.triggered && normal.waiting && normal.sampleCount == 480)
    }

    @Test func normalModeKeepsTheLastTriggeredWindow() throws {
        let buffer = try makeBuffer()
        let acquisition = ScopeAcquisition()
        let normal = try state(mode: .normal)
        write(sine(1_000), frames: 0, count: 2_048, into: buffer)
        let triggered = acquisition.window(from: buffer, channelCount: 2, sampleRate: rate, state: normal)
        #expect(triggered.triggered && !triggered.waiting)
        buffer.write(left: [Float](repeating: 0, count: 2_048), right: [Float](repeating: 0, count: 2_048))
        let held = acquisition.window(from: buffer, channelCount: 2, sampleRate: rate, state: normal)
        #expect(held.waiting && held.left == triggered.left && held.startFrame == triggered.startFrame)
    }

    @Test func aShortBufferGivesAPartialWindow() throws {
        let buffer = try makeBuffer()
        write(sine(1_000), frames: 0, count: 100, into: buffer)
        let window = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate, state: try state())
        #expect(window.partial && window.sampleCount == 100 && window.startFrame == 0 && !window.triggered)
        let empty = ScopeAcquisition().window(from: try makeBuffer(), channelCount: 2, sampleRate: rate,
                                              state: try state())
        #expect(empty.partial && empty.sampleCount == 0)
    }

    @Test func aMonoRingGivesAOneChannelWindow() throws {
        let ring = SampleRingBuffer(capacity: 16_384)
        let signal = sine(1_000)
        let samples = (0..<4_096).map { signal.value(atFrame: $0, channel: 0) }
        samples.withUnsafeBufferPointer { ring.write($0) }
        let window = ScopeAcquisition().window(from: ring, sampleRate: rate, state: try state())
        #expect(window.channelCount == 1 && window.right.isEmpty && window.sampleCount == 480)
        #expect(window.triggered && window.left[0] == samples[window.startFrame])
        let monoBuffer = try makeBuffer()
        write(signal, frames: 0, count: 4_096, into: monoBuffer)
        let fromStereo = ScopeAcquisition().window(from: monoBuffer, channelCount: 1, sampleRate: rate,
                                                   state: try state())
        #expect(fromStereo.channelCount == 1 && fromStereo.right.isEmpty)
    }

    @Test func gainScalesTheDisplayAndMarksClipping() throws {
        let buffer = try makeBuffer()
        write(sine(1_000, amplitude: 0.3), frames: 0, count: 4_096, into: buffer)
        let unity = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate, state: try state(gain: 1))
        let doubled = ScopeAcquisition().window(from: buffer, channelCount: 2, sampleRate: rate,
                                                state: try state(gain: 2))
        let maxUnity = unity.displayValues(channel: 0, gain: 1).map(abs).max() ?? 0
        let maxDoubled = doubled.displayValues(channel: 0, gain: 2).map(abs).max() ?? 0
        #expect(abs(maxDoubled - 2 * maxUnity) < 1e-6 && maxUnity > 0.29)
        #expect(!unity.clipped && !doubled.clipped)

        let loud = try makeBuffer()
        write(sine(1_000, amplitude: 0.5), frames: 0, count: 4_096, into: loud)
        let clipped = ScopeAcquisition().window(from: loud, channelCount: 2, sampleRate: rate, state: try state(gain: 3))
        #expect(clipped.clipped)
        #expect(clipped.displayValues(channel: 0, gain: 5).allSatisfy { abs($0) <= 1 })
    }
}
