// SignalWindowTests — feature 061 (A08-P01) T-A08-104 (FR-A08-110; data-model "SignalWindow"). The window value,
// host-free and short: mono windows drop the right channel, display values are samples × gain clamped to −1…1, and the
// clipping rule.
import Foundation
import Testing
import OscilloscopeStudioCore

@Suite struct SignalWindowTests {
    private func window(left: [Float], right: [Float], channels: Int) -> SignalWindow {
        SignalWindow(sampleRate: 48_000, channelCount: channels, startFrame: 7, left: left, right: right,
                     triggered: true, waiting: false, partial: false, shortened: false, clipped: false)
    }

    @Test func aMonoWindowHasOneChannelAndNoRightSamples() {
        let mono = window(left: [0.1, 0.2, 0.3], right: [0.9, 0.9, 0.9], channels: 1)
        #expect(mono.channelCount == 1 && mono.right.isEmpty && mono.sampleCount == 3)
        #expect(mono.displayValues(channel: 1, gain: 1).isEmpty)
        #expect(window(left: [0], right: [], channels: 0).channelCount == 1)
        #expect(window(left: [0], right: [0], channels: 5).channelCount == 2)
    }

    @Test func displayValuesAreScaledAndClamped() {
        let stereo = window(left: [0.3, -0.3, 0.6], right: [-0.9, 0.05, 0], channels: 2)
        #expect(stereo.displayValues(channel: 0, gain: 2) == [0.6, -0.6, 1])
        #expect(stereo.displayValues(channel: 1, gain: 2) == [-1, 0.1, 0])
        #expect(stereo.displayValues(channel: 0, gain: 0.5) == [0.15, -0.15, 0.3])
        #expect(stereo.displayValues(channel: 2, gain: 1).isEmpty)
        #expect(stereo.left == [0.3, -0.3, 0.6])   // the samples themselves are never scaled
    }

    @Test func clippingIsAnySampleTimesGainOutsideFullScale() {
        #expect(!SignalWindow.isClipped(left: [0.5, -0.5], right: [], gain: 2))
        #expect(SignalWindow.isClipped(left: [0.5, -0.51], right: [], gain: 2))
        #expect(SignalWindow.isClipped(left: [0], right: [0.2], gain: 10))
        #expect(!SignalWindow.isClipped(left: [], right: [], gain: 10))
        let flagged = window(left: [0.5], right: [], channels: 1).with(triggered: false, waiting: true, clipped: true)
        #expect(flagged.clipped && flagged.waiting && !flagged.triggered && flagged.startFrame == 7)
    }

    @Test func anEmptyWindowIsPartial() {
        let empty = SignalWindow.empty(sampleRate: 48_000, channelCount: 2, waiting: true, shortened: false)
        #expect(empty.sampleCount == 0 && empty.partial && empty.waiting && !empty.triggered && !empty.clipped)
    }
}
