// ScopeStateTests — feature 061 (A08-P01) T-A08-104 (FR-A08-111; clarification 4; data-model "ScopeState", schema 1).
// The state rules of Oscilloscope Studio, host-free and short: the first state, the choice tables, the JSON round
// trip, refusal of unknown indices and of a non-finite or out-of-range trigger level, the setters and the digest text.
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct ScopeStateTests {
    private func decode(_ json: String) throws -> ScopeState {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf",
                                                                         negativeInfinity: "-inf", nan: "nan")
        return try decoder.decode(ScopeState.self, from: Data(json.utf8))
    }

    private func payload(source: String = "0", waveform: String = "1", frequency: String = "1", gain: String = "2",
                         timebase: String = "5", level: String = "0.25", slope: String = "1",
                         mode: String = "1") -> String {
        "{\"source\":\(source),\"waveform\":\(waveform),\"frequency\":\(frequency),\"gain\":\(gain),"
            + "\"timebase\":\(timebase),\"level\":\(level),\"slope\":\(slope),\"mode\":\(mode)}"
    }

    @Test func theFirstStateIsAOneKilohertzSineAtOneMillisecondPerDivision() {
        let state = ScopeState.initial
        #expect(ScopeState.currentSchema == 1)
        #expect(state.source == .testSignal)
        #expect(state.waveform == .sine)
        #expect(state.frequency == 1_000 && state.gain == 1 && state.timebaseMilliseconds == 1)
        #expect(state.secondsPerDivision == 0.001)
        #expect(state.triggerLevel == 0 && state.triggerSlope == .rising && state.triggerMode == .auto)
        #expect(state == ScopeState())
    }

    @Test func theChoiceTablesMatchTheClarification() {
        #expect(ScopeSource.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(ScopeSource.allCases.map(\.displayName) == ["Test signal", "File", "Microphone"])
        #expect(ScopeSettings.frequencies == [100, 440, 1_000, 5_000])
        #expect(ScopeSettings.gains == [0.5, 1, 2, 5, 10])
        #expect(ScopeSettings.timebasesMilliseconds == [0.1, 0.2, 0.5, 1, 2, 5])
        #expect(ScopeSettings.waveforms.map(ScopeSettings.displayName(of:)) == ["Sine", "Square", "Sweep"])
        #expect((0..<4).map(ScopeSettings.frequencyName) == ["100 Hz", "440 Hz", "1 kHz", "5 kHz"])
        #expect((0..<5).map(ScopeSettings.gainName) == ["×0.5", "×1", "×2", "×5", "×10"])
        #expect(ScopeSettings.timebaseName(0) == "0.1 ms per division")
        #expect(ScopeSettings.timebaseName(5) == "5 ms per division")
        #expect(ScopeSettings.frequencyName(4).isEmpty && ScopeSettings.gainName(-1).isEmpty)
        #expect(ScopeSettings.displayName(of: TriggerSlope.falling) == "Falling")
        #expect(ScopeSettings.displayName(of: TriggerMode.normal) == "Normal")
    }

    @Test func jsonRoundTripKeepsEveryField() throws {
        let state = try #require(ScopeState(source: .microphone, waveform: .sweep, frequencyIndex: 3, gainIndex: 4,
                                            timebaseIndex: 0, triggerLevel: -0.375, triggerSlope: .falling,
                                            triggerMode: .normal))
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(ScopeState.self, from: data)
        #expect(back == state)
        #expect(back.digestText == state.digestText)
        let first = try JSONDecoder().decode(ScopeState.self, from: JSONEncoder().encode(ScopeState.initial))
        #expect(first == .initial)
    }

    @Test func aValidPayloadDecodes() throws {
        let state = try decode(payload())
        #expect(state.source == .testSignal && state.waveform == .square)
        #expect(state.frequency == 440 && state.gain == 2 && state.timebaseMilliseconds == 5)
        #expect(state.triggerLevel == 0.25 && state.triggerSlope == .falling && state.triggerMode == .normal)
    }

    @Test func unknownIndicesAreRefused() {
        for bad in [payload(source: "3"), payload(waveform: "3"), payload(frequency: "4"), payload(frequency: "-1"),
                    payload(gain: "5"), payload(timebase: "6"), payload(slope: "2"), payload(mode: "2")] {
            #expect(throws: DecodingError.self) { try decode(bad) }
        }
        #expect(ScopeState(source: .file, waveform: .sine, frequencyIndex: 9, gainIndex: 0, timebaseIndex: 0,
                           triggerLevel: 0, triggerSlope: .rising, triggerMode: .auto) == nil)
    }

    @Test func aNonFiniteOrOutOfRangeLevelIsRefused() {
        for level in ["\"nan\"", "\"inf\"", "\"-inf\"", "1.5", "-1.01"] {
            #expect(throws: DecodingError.self) { try decode(payload(level: level)) }
        }
        #expect(ScopeState(source: .file, waveform: .sine, frequencyIndex: 0, gainIndex: 0, timebaseIndex: 0,
                           triggerLevel: .nan, triggerSlope: .rising, triggerMode: .auto) == nil)
        #expect((try? decode(payload(level: "1"))) != nil)
        #expect((try? decode(payload(level: "-1"))) != nil)
    }

    @Test func settersRefuseUnknownValuesAndChangeNothing() {
        var state = ScopeState.initial
        let refused = [state.selectFrequency(4), state.selectGain(-1), state.selectTimebase(6),
                       state.setTriggerLevel(.nan), state.setTriggerLevel(2)]
        #expect(refused == [false, false, false, false, false])
        #expect(state == .initial)
        let accepted = [state.selectFrequency(0), state.selectGain(3), state.selectTimebase(5),
                        state.setTriggerLevel(-0.5)]
        #expect(accepted == [true, true, true, true])
        state.select(ScopeSource.file)
        state.select(TestSignal.Waveform.square)
        state.select(TriggerSlope.falling)
        state.select(TriggerMode.normal)
        #expect(state.frequency == 100 && state.gain == 5 && state.timebaseMilliseconds == 5)
        #expect(state.triggerLevel == -0.5 && state.source == .file && state.waveform == .square)
        #expect(state.triggerSlope == .falling && state.triggerMode == .normal)
    }

    @Test func theDigestIsStableAndCoversEveryField() throws {
        let base = ScopeState.initial
        #expect(base.digestText
                    == "a08.scope.v1|source=0|waveform=0|frequency=2|gain=1|timebase=3|level=0.0|slope=0|mode=0")
        #expect(ScopeState().digestText == base.digestText)
        var negativeZero = base
        let acceptedZero = negativeZero.setTriggerLevel(-0.0)
        #expect(acceptedZero)
        #expect(negativeZero.digestText == base.digestText)

        var variants: [ScopeState] = []
        var s = base; s.select(ScopeSource.microphone); variants.append(s)
        s = base; s.select(TestSignal.Waveform.sweep); variants.append(s)
        s = base; s.selectFrequency(1); variants.append(s)
        s = base; s.selectGain(2); variants.append(s)
        s = base; s.selectTimebase(0); variants.append(s)
        s = base; s.setTriggerLevel(0.125); variants.append(s)
        s = base; s.select(TriggerSlope.falling); variants.append(s)
        s = base; s.select(TriggerMode.normal); variants.append(s)
        let texts = Set(variants.map(\.digestText) + [base.digestText])
        #expect(texts.count == variants.count + 1)
    }
}
