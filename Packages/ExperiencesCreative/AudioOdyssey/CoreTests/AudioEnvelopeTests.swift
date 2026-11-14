// AudioEnvelopeTests — feature 056 (A07-P03) T-A07-302 (FR-A07-310; clarification 1; data-model "AudioEnvelope"). The
// audio envelope, host-free and short: band grouping, normalisation into 0…1, the onset floor, attack faster than
// release, the overall channel, NaN and negative inputs, and the elapsed-time guard.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct AudioEnvelopeTests {
    private let frame = 1.0 / 60

    /// Feeds `frames` identical frames and returns the envelope.
    private func feed(_ envelope: inout AudioEnvelope, bands: [Float], flux: Float = 0, onset: Bool = false,
                      frames: Int) {
        for _ in 0..<frames {
            envelope.update(bandEnergies: bands, flux: flux, onset: onset, time: envelope.timestamp + frame,
                            elapsed: frame)
        }
    }

    @Test func itStartsSilent() {
        let envelope = AudioEnvelope()
        #expect(EnvelopeChannel.allCases.map(envelope.value) == [0, 0, 0, 0, 0])
        #expect(envelope.timestamp == 0)
        #expect(EnvelopeChannel.allCases.map(\.rawValue) == [0, 1, 2, 3, 4])
    }

    @Test func bandsAreGroupedAsTheClarificationSays() {
        let sixteen = (0..<16).map(Float.init)
        #expect(AudioEnvelope.groupMeans(sixteen) == [1.5, 6.5, 12.5])
        #expect(AudioEnvelope.groupMeans(sixteen + [1_000]) == [1.5, 6.5, 12.5])
        #expect(AudioEnvelope.groupMeans([1, 1, 2, 2, 3, 3]) == [1, 2, 3])
        #expect(AudioEnvelope.groupMeans([1, 2, 3]) == [1, 2, 3])
        #expect(AudioEnvelope.groupMeans([2, 4]) == [3, 3, 3])
        #expect(AudioEnvelope.groupMeans([]) == [0, 0, 0])
        #expect(AudioEnvelope.groupMeans([.nan, -1, .infinity]) == [0, 0, 0])
    }

    @Test func aBandPulseRaisesOnlyItsChannel() {
        var envelope = AudioEnvelope()
        var bands = [Float](repeating: 0, count: 16)
        bands[5] = 0.4
        feed(&envelope, bands: bands, frames: 30)
        #expect(envelope.mid > 0.99)
        #expect(envelope.low == 0 && envelope.high == 0 && envelope.transient == 0)
        #expect(abs(envelope.overall - envelope.mid / 3) < 1e-12)
    }

    @Test func valuesStayInZeroToOneForLoudAndRandomInput() {
        var envelope = AudioEnvelope()
        var state: UInt64 = 0xA07_302
        for i in 0..<600 {
            let bands = (0..<16).map { _ -> Float in
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Float(state >> 40) / Float(1 << 24) * (i % 50 == 0 ? 1_000 : 2)
            }
            envelope.update(bandEnergies: bands, flux: bands[3] * 3, onset: i % 7 == 0, time: Double(i) * frame,
                            elapsed: frame)
            for channel in EnvelopeChannel.allCases {
                #expect((0...1).contains(envelope.value(channel)))
            }
        }
    }

    @Test func aSteadySoundNormalisesToOne() {
        var envelope = AudioEnvelope()
        feed(&envelope, bands: [Float](repeating: 0.002, count: 16), flux: 0.01, frames: 60)
        #expect(envelope.low > 0.999 && envelope.mid > 0.999 && envelope.high > 0.999 && envelope.transient > 0.999)
        #expect(envelope.overall > 0.999)
    }

    @Test func anOnsetRaisesTheTransientToAtLeastTheFloor() {
        var envelope = AudioEnvelope()
        feed(&envelope, bands: [Float](repeating: 0, count: 16), flux: 0, onset: true, frames: 60)
        #expect(abs(envelope.transient - AudioEnvelope.onsetFloor) < 1e-6)
        #expect(envelope.low == 0)
        var quiet = envelope
        feed(&quiet, bands: [Float](repeating: 0, count: 16), frames: 120)
        #expect(quiet.transient < 0.01)
    }

    @Test func attackIsFasterThanRelease() {
        var envelope = AudioEnvelope()
        let loud = [Float](repeating: 1, count: 16)
        feed(&envelope, bands: loud, frames: 1)
        let rise = envelope.low
        #expect(abs(rise - (1 - exp(-frame / AudioEnvelope.attack))) < 1e-9)
        feed(&envelope, bands: loud, frames: 60)
        let top = envelope.low
        feed(&envelope, bands: [Float](repeating: 0, count: 16), frames: 1)
        let fall = top - envelope.low
        #expect(abs(fall - top * (1 - exp(-frame / AudioEnvelope.release))) < 1e-9)
        #expect(rise > 5 * fall)
    }

    @Test func invalidInputCountsAsSilenceAndABadElapsedChangesOnlyTheTimestamp() {
        var envelope = AudioEnvelope()
        envelope.update(bandEnergies: [Float](repeating: .nan, count: 16), flux: -.infinity, onset: false, time: 1,
                        elapsed: frame)
        #expect(envelope.overall == 0 && envelope.transient == 0 && envelope.timestamp == 1)
        feed(&envelope, bands: [Float](repeating: 0.5, count: 16), frames: 10)
        let before = envelope
        for elapsed in [0, -1, Double.nan, .infinity] {
            var copy = before
            copy.update(bandEnergies: [Float](repeating: 9, count: 16), flux: 9, onset: true, time: 42,
                        elapsed: elapsed)
            #expect(copy.timestamp == 42)
            #expect(EnvelopeChannel.allCases.map(copy.value) == EnvelopeChannel.allCases.map(before.value))
        }
        var copy = before
        copy.update(bandEnergies: [], flux: 0, onset: false, time: .nan, elapsed: frame)
        #expect(copy.timestamp == before.timestamp)
        #expect(copy.low < before.low)
    }
}
