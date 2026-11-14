// OnsetDetectorTests — feature 048 (A06-P02) T-A06-203 (FR-A06-203; SC-A06-203): a flux spike over a steady history
// fires once, never twice within the 0.1 s minimum interval, never on constant (after its first window) or zero flux;
// reset clears the history and the last onset.
import Testing
@testable import VisualCoreAudioDSP

private let onsetHop = 1_024.0 / 48_000.0

/// Feeds `count` windows of `flux` starting at `start` and returns the number of onsets and the next window time.
private func feedOnsetFlux(
    _ detector: inout OnsetDetector, flux: Float, count: Int, start: Double
) -> (onsets: Int, next: Double) {
    var onsets = 0
    var time = start
    for _ in 0..<count {
        if detector.update(flux: flux, time: time) { onsets += 1 }
        time += onsetHop
    }
    return (onsets, time)
}

@Test func onsetDetectorDefaultsMatchTheContract() {
    let detector = OnsetDetector()
    #expect(detector.historyCount == 43)
    #expect(detector.multiple == 1.5)
    #expect(detector.minimum == 1e-4)
    #expect(detector.minimumInterval == 0.1)
}

@Test func onsetDetectorFiresOnceOnASpikeOverASteadyHistory() {
    var detector = OnsetDetector()
    let steady = feedOnsetFlux(&detector, flux: 0.01, count: 60, start: 0)
    #expect(steady.onsets == 1)  // only the very first window, whose history is empty
    let result1 = detector.update(flux: 1, time: steady.next)
    #expect(result1 == true)
    let after = feedOnsetFlux(&detector, flux: 0.01, count: 10, start: steady.next + onsetHop)
    #expect(after.onsets == 0)
}

@Test func onsetDetectorHonoursTheMinimumInterval() {
    var detector = OnsetDetector()
    let steady = feedOnsetFlux(&detector, flux: 0.01, count: 60, start: 0)
    let first = steady.next
    let result2 = detector.update(flux: 1, time: first)
    #expect(result2)
    let result3 = detector.update(flux: 50, time: first + 0.05)
    #expect(result3 == false)
    let result4 = detector.update(flux: 50, time: first + 0.099)
    #expect(result4 == false)
    let result5 = detector.update(flux: 5_000, time: first + 0.101)
    #expect(result5)
}

@Test func onsetDetectorNeverFiresOnConstantOrZeroFlux() {
    var constant = OnsetDetector()
    let result6 = constant.update(flux: 0.2, time: 0)
    #expect(result6)  // first window: empty history, as in SC-A06-203
    #expect(feedOnsetFlux(&constant, flux: 0.2, count: 200, start: onsetHop).onsets == 0)

    var zero = OnsetDetector()
    #expect(feedOnsetFlux(&zero, flux: 0, count: 200, start: 0).onsets == 0)

    var nonFinite = OnsetDetector()
    let result7 = nonFinite.update(flux: .nan, time: 0)
    #expect(result7 == false)
    let result8 = nonFinite.update(flux: .infinity, time: 0.2)
    #expect(result8 == false)
}

@Test func onsetDetectorResetClearsHistoryAndLastOnset() {
    var detector = OnsetDetector()
    let loud = feedOnsetFlux(&detector, flux: 10, count: 50, start: 0)
    // A flux that is high in absolute terms but below 1.5 × the loud history does not fire.
    let result9 = detector.update(flux: 12, time: loud.next + 1)
    #expect(result9 == false)
    let lastOnsetTime = loud.next + 2
    let result10 = detector.update(flux: 1_000, time: lastOnsetTime)
    #expect(result10)

    detector.reset()
    // Empty history: the same moderate flux fires, even within 0.1 s of the onset before the reset.
    let result11 = detector.update(flux: 12, time: lastOnsetTime + 0.01)
    #expect(result11)
}
