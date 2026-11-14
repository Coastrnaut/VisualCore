// MetricTextTests — feature 051 (A06-P05) T-A06-503 (FR-A06-510, FR-A06-511; SC-A06-503; spec clarifications 2 and
// 3; research D3–D4). The metric text of VisualCore Music Lab, host-free and short: exact strings for silence, a tone
// in the high-mid region and a beat, rounding, the minus sign, non-finite input, the region grouping, and the
// announcement gate over a scripted 10 s timeline.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct MetricTextTests {
    @Test func silenceReadsAsSilentWithNoRegionAndNoBeat() {
        #expect(MetricText.silentBelowDB == -90)
        #expect(MetricText.regionNames == ["low", "low-mid", "high-mid", "high"])
        let silence = "Level silent, strongest none, no beat"
        #expect(MetricText.make(rmsDB: -120, regionEnergies: [0, 0, 0, 0], beat: 0) == silence)
        #expect(MetricText.make(rmsDB: -90, regionEnergies: [1, 2, 3, 4], beat: 0) == silence)
        #expect(MetricText.make(rmsDB: -.infinity, regionEnergies: [1, 2, 3, 4], beat: 0) == silence)
    }

    @Test func aToneInTheHighMidRegionIsNamedWithTheMinusSign() {
        let text = MetricText.make(rmsDB: -9.03, regionEnergies: [0.01, 0.02, 0.9, 0.03], beat: 0)
        #expect(text == "Level \u{2212}9 dB, strongest high-mid, no beat")
        #expect(text.unicodeScalars.contains("\u{2212}"))
        #expect(!text.contains("-9"))
    }

    @Test func aBeatAboveOneHalfReadsAsBeat() {
        #expect(MetricText.make(rmsDB: -9.03, regionEnergies: [0.01, 0.02, 0.9, 0.03], beat: 0.8)
            == "Level \u{2212}9 dB, strongest high-mid, beat")
        #expect(MetricText.make(rmsDB: -20, regionEnergies: [1, 0, 0, 0], beat: 0.5)
            == "Level \u{2212}20 dB, strongest low, no beat")
        #expect(MetricText.make(rmsDB: -20, regionEnergies: [1, 0, 0, 0], beat: .nan)
            == "Level \u{2212}20 dB, strongest low, no beat")
    }

    @Test func theLevelRoundsToTheNearestInteger() {
        #expect(MetricText.make(rmsDB: -9.5, regionEnergies: [0, 0, 0, 1], beat: 0)
            == "Level \u{2212}10 dB, strongest high, no beat")
        #expect(MetricText.make(rmsDB: -0.2, regionEnergies: [0, 1, 0, 0], beat: 0)
            == "Level 0 dB, strongest low-mid, no beat")
        #expect(MetricText.make(rmsDB: 0, regionEnergies: [0, 1, 0, 0], beat: 0)
            == "Level 0 dB, strongest low-mid, no beat")
        #expect(MetricText.make(rmsDB: 3.4, regionEnergies: [0, 1, 0, 0], beat: 0)
            == "Level 3 dB, strongest low-mid, no beat")
    }

    @Test func nonFiniteInputReadsAsSilentOrNone() {
        #expect(MetricText.make(rmsDB: .nan, regionEnergies: [1, 2, 3, 4], beat: 0.9)
            == "Level silent, strongest none, beat")
        #expect(MetricText.make(rmsDB: -30, regionEnergies: [.nan, .infinity, 0, 0], beat: 0)
            == "Level \u{2212}30 dB, strongest none, no beat")
        #expect(MetricText.make(rmsDB: -30, regionEnergies: [], beat: 0)
            == "Level \u{2212}30 dB, strongest none, no beat")
        #expect(MetricText.make(rmsDB: -30, regionEnergies: [0.5, 0.5, 0.2, 0], beat: 0)
            == "Level \u{2212}30 dB, strongest low, no beat")
    }

    @Test func bandsAreSummedIntoFourRegions() {
        let sixteen: [Float] = (0..<16).map { Float($0) }
        #expect(MetricText.regionEnergies(bandEnergies: sixteen) == [6, 22, 38, 54])
        let eight: [Float] = Array(repeating: 1, count: 8)
        #expect(MetricText.regionEnergies(bandEnergies: eight) == [4, 4, 0, 0])
        #expect(MetricText.regionEnergies(bandEnergies: []) == [0, 0, 0, 0])
        #expect(MetricText.regionEnergies(bandEnergies: [1, .nan, 2, .infinity, 3]) == [3, 3, 0, 0])
    }

    @Test func theGateAnnouncesOnlyChangedTextTwoSecondsApart() {
        var gate = AnnouncementGate()
        #expect(AnnouncementGate.minimumInterval == 2)
        #expect(gate.lastText == nil && gate.lastTime == nil)
        let announced1 = gate.shouldAnnounce(text: "", at: 0)
        #expect(!announced1)
        let announced2 = gate.shouldAnnounce(text: "A", at: 0)
        #expect(announced2)
        #expect(gate.lastText == "A" && gate.lastTime == 0)
        let announced3 = gate.shouldAnnounce(text: "A", at: 0.5)
        #expect(!announced3)
        let announced4 = gate.shouldAnnounce(text: "A", at: 10)
        #expect(!announced4)
        let announced5 = gate.shouldAnnounce(text: "B", at: 1)
        #expect(!announced5)
        let announced6 = gate.shouldAnnounce(text: "B", at: 2)
        #expect(announced6)
        #expect(gate.lastText == "B" && gate.lastTime == 2)
        let announced7 = gate.shouldAnnounce(text: "", at: 10)
        #expect(!announced7)
    }

    @Test func aScriptedTenSecondTimelineIsRateLimited() {
        var gate = AnnouncementGate()
        var announced: [(time: Double, text: String)] = []
        for step in 0..<20 {
            let time = Double(step) * 0.5
            let text = step.isMultiple(of: 2) ? "Level \u{2212}9 dB, strongest high-mid, no beat"
                : "Level \u{2212}9 dB, strongest high-mid, beat"
            if gate.shouldAnnounce(text: text, at: time) { announced.append((time, text)) }
        }
        #expect(!announced.isEmpty)
        #expect(announced.count <= 5)
        for (earlier, later) in zip(announced, announced.dropFirst()) {
            #expect(later.time - earlier.time >= AnnouncementGate.minimumInterval)
            #expect(later.text != earlier.text)
        }
        var repeats = AnnouncementGate()
        let count = (0..<20).filter { repeats.shouldAnnounce(text: "same", at: Double($0) * 0.5) }.count
        #expect(count == 1)
    }
}
