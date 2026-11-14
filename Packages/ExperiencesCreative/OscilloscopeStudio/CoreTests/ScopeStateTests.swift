// ScopeStateTests — feature 061 (A08-P01) T-A08-104 (FR-A08-111; clarification 4; data-model "ScopeState", schema 1).
// The state rules of Oscilloscope Studio, host-free and short: the first state, the choice tables, the JSON round
// trip, refusal of unknown indices and of a non-finite or out-of-range trigger level, the setters and the digest text.
// Feature 062 (A08-P02) T-A08-205 (FR-A08-211, FR-A08-212; schema 2): the display mode round trips, a schema-1 payload
// decodes with the waveform display, an unknown display is refused and the digest names the display.
// Feature 063 (A08-P03) T-A08-302 (FR-A08-304; clarification 1): the spectrum display (2) is accepted, round trips and
// is named in the digest; an A08-P02 payload (display 1) restores unchanged; 3 is refused. The P02 display tests below
// were widened from {0, 1} to {0, 1, 2}.
// Feature 064 (A08-P04) T-A08-402 (FR-A08-402, FR-A08-411; clarification 1; schema 3): the schema is 3 and the digest
// text v3 appends the freeze flag, the cursors' visibility and the four cursor positions (the earlier expectations
// below were updated: schema 2 → 3, digest v2 → v3 with the schema-3 suffix, `hasSuffix("|display=…")` →
// `contains("|display=…|")`, nine keys → fifteen); schema 3 round trips, a schema-2 payload decodes with the defaults,
// a non-finite or out-of-range cursor is refused, the setters clamp and refuse non-finite values, and moving any cursor
// changes the digest.
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

    /// The digest suffix of the schema-3 fields at their first (and schema-2 migration) values.
    private let defaultSuffix = "|frozen=0|cursors=0|cursorA=0.25|cursorB=0.75|frequencyCursor=0.5|levelCursor=0.5"

    private func payload(source: String = "0", waveform: String = "1", frequency: String = "1", gain: String = "2",
                         timebase: String = "5", level: String = "0.25", slope: String = "1",
                         mode: String = "1") -> String {
        "{\"source\":\(source),\"waveform\":\(waveform),\"frequency\":\(frequency),\"gain\":\(gain),"
            + "\"timebase\":\(timebase),\"level\":\(level),\"slope\":\(slope),\"mode\":\(mode)}"
    }

    @Test func theFirstStateIsAOneKilohertzSineAtOneMillisecondPerDivision() {
        let state = ScopeState.initial
        #expect(ScopeState.currentSchema == 3)
        #expect(state.display == .waveform)
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
                    == "a08.scope.v3|source=0|waveform=0|frequency=2|gain=1|timebase=3|level=0.0|slope=0|mode=0"
                    + "|display=0" + defaultSuffix)
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
        s = base; s.select(ScopeDisplay.xy); variants.append(s)
        let texts = Set(variants.map(\.digestText) + [base.digestText])
        #expect(texts.count == variants.count + 1)
    }

    // MARK: - Feature 062 (A08-P02) T-A08-205: display mode, schema 2

    @Test func theDisplayChoicesAreWaveformXYAndSpectrum() {
        #expect(ScopeDisplay.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(ScopeDisplay.allCases.map(\.displayName) == ["waveform", "XY", "spectrum"])
    }

    @Test func schemaTwoRoundTripKeepsTheXYDisplay() throws {
        let state = try #require(ScopeState(source: .file, waveform: .square, frequencyIndex: 0, gainIndex: 3,
                                            timebaseIndex: 2, triggerLevel: 0.5, triggerSlope: .rising,
                                            triggerMode: .auto, display: .xy))
        let data = try JSONEncoder().encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["display"] as? Int == 1)
        let back = try JSONDecoder().decode(ScopeState.self, from: data)
        #expect(back == state && back.display == .xy)
        #expect(back.digestText == state.digestText)
    }

    @Test func aSchemaOnePayloadDecodesWithTheWaveformDisplay() throws {
        // Exactly the shape the A08-P01 (schema 1) encoder wrote: eight keys, no `display`.
        let state = try decode(payload())
        #expect(state.display == .waveform)
        #expect(state.source == .testSignal && state.waveform == .square && state.frequency == 440)
        #expect(state.triggerLevel == 0.25 && state.triggerSlope == .falling && state.triggerMode == .normal)
        let initialV1 = "{\"source\":0,\"waveform\":0,\"frequency\":2,\"gain\":1,\"timebase\":3,\"level\":0,"
            + "\"slope\":0,\"mode\":0}"
        #expect(try decode(initialV1) == .initial)
    }

    @Test func anUnknownDisplayIsRefused() {
        for bad in ["3", "-1"] {
            let json = String(payload().dropLast()) + ",\"display\":\(bad)}"
            #expect(throws: DecodingError.self) { try decode(json) }
        }
        #expect((try? decode(String(payload().dropLast()) + ",\"display\":1}"))?.display == .xy)
    }

    @Test func theDisplaySettersAndDigest() {
        var state = ScopeState.initial
        #expect(state.selectDisplay(3) == false)
        #expect(state == .initial)
        #expect(state.selectDisplay(1) == true)
        #expect(state.display == .xy)
        #expect(state.digestText.contains("|display=1|"))
        #expect(state.digestText != ScopeState.initial.digestText)
        state.select(ScopeDisplay.waveform)
        #expect(state == .initial)
        #expect(state.digestText == ScopeState.initial.digestText)
    }

    // MARK: - Feature 063 (A08-P03) T-A08-302: spectrum display (schema 2 then; schema 3 since A08-P04)

    @Test func theSpectrumDisplayIsAcceptedAndNamedInTheDigest() {
        var state = ScopeState.initial
        #expect(state.selectDisplay(2) == true)
        #expect(state.display == .spectrum)
        #expect(state.digestText.contains("|display=2|"))
        #expect(ScopeState.currentSchema == 3)
        let refused = state.selectDisplay(3)
        #expect(refused == false && state.display == .spectrum)
        var digests: Set<String> = []
        for display in ScopeDisplay.allCases {
            var s = ScopeState.initial
            s.select(display)
            digests.insert(s.digestText)
        }
        #expect(digests.count == 3)
    }

    @Test func theSpectrumDisplayRoundTrips() throws {
        let state = try #require(ScopeState(source: .microphone, waveform: .sweep, frequencyIndex: 0, gainIndex: 4,
                                            timebaseIndex: 1, triggerLevel: -0.25, triggerSlope: .falling,
                                            triggerMode: .normal, display: .spectrum))
        let data = try JSONEncoder().encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["display"] as? Int == 2)
        #expect(object.count == 15)
        let back = try JSONDecoder().decode(ScopeState.self, from: data)
        #expect(back == state && back.display == .spectrum)
        #expect(back.digestText == state.digestText)
        #expect(try decode(String(payload().dropLast()) + ",\"display\":2}").display == .spectrum)
    }

    @Test func anA08P02PayloadRestoresUnchanged() throws {
        // Exactly the shape the A08-P02 encoder wrote: nine keys with display 1 (XY).
        let json = "{\"source\":1,\"waveform\":2,\"frequency\":3,\"gain\":0,\"timebase\":4,\"level\":-0.5,"
            + "\"slope\":1,\"mode\":0,\"display\":1}"
        let state = try decode(json)
        #expect(state.display == .xy && state.source == .file && state.waveform == .sweep)
        #expect(state.frequency == 5_000 && state.gain == 0.5 && state.timebaseMilliseconds == 2)
        #expect(state.triggerLevel == -0.5 && state.triggerSlope == .falling && state.triggerMode == .auto)
        #expect(state.digestText
                    == "a08.scope.v3|source=1|waveform=2|frequency=3|gain=0|timebase=4|level=-0.5|slope=1|mode=0"
                    + "|display=1" + defaultSuffix)
        let reencoded = try JSONDecoder().decode(ScopeState.self, from: JSONEncoder().encode(state))
        #expect(reencoded == state)
    }

    @Test func anOutOfRangeDisplayIsRefused() {
        let json = String(payload().dropLast()) + ",\"display\":3}"
        #expect(throws: DecodingError.self) { try decode(json) }
    }

    // MARK: - Feature 064 (A08-P04) T-A08-402: freeze and cursors, schema 3

    @Test func theFirstStateIsNotFrozenWithTheCursorsHiddenAtTheirDefaults() {
        let state = ScopeState.initial
        #expect(!state.frozen && !state.cursorsShown)
        #expect(state.cursorA == 0.25 && state.cursorB == 0.75)
        #expect(state.frequencyCursor == 0.5 && state.levelCursor == 0.5)
    }

    @Test func schemaThreeRoundTripKeepsFreezeAndCursors() throws {
        let state = try #require(ScopeState(source: .file, waveform: .square, frequencyIndex: 1, gainIndex: 2,
                                            timebaseIndex: 4, triggerLevel: 0.125, triggerSlope: .falling,
                                            triggerMode: .normal, display: .spectrum, frozen: true,
                                            cursorsShown: true, cursorA: 0.9, cursorB: 0.1, frequencyCursor: 0.375,
                                            levelCursor: -0.625))
        let data = try JSONEncoder().encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["frozen"] as? Bool == true && object["cursorsShown"] as? Bool == true)
        #expect(object["cursorA"] as? Double == 0.9 && object["levelCursor"] as? Double == -0.625)
        let back = try JSONDecoder().decode(ScopeState.self, from: data)
        #expect(back == state)
        #expect(back.digestText == state.digestText)
        #expect(back.digestText.hasSuffix("|frozen=1|cursors=1|cursorA=0.9|cursorB=0.1|frequencyCursor=0.375"
                                          + "|levelCursor=-0.625"))
    }

    @Test func aSchemaTwoPayloadDecodesWithTheMigrationDefaults() throws {
        // Exactly the shape the A08-P03 (schema 2) encoder wrote: nine keys, none of the schema-3 keys.
        let state = try decode(String(payload().dropLast()) + ",\"display\":2}")
        #expect(state.display == .spectrum && state.waveform == .square && state.frequency == 440)
        #expect(!state.frozen && !state.cursorsShown)
        #expect(state.cursorA == 0.25 && state.cursorB == 0.75)
        #expect(state.frequencyCursor == 0.5 && state.levelCursor == 0.5)
    }

    @Test func aNonFiniteOrOutOfRangeCursorIsRefused() {
        let base = String(payload().dropLast())
        let bad = ["\"cursorA\":\"nan\"", "\"cursorB\":\"inf\"", "\"frequencyCursor\":\"-inf\"",
                   "\"levelCursor\":\"nan\"", "\"cursorA\":1.5", "\"cursorB\":-0.01",
                   "\"frequencyCursor\":2", "\"levelCursor\":-1.01"]
        for entry in bad {
            #expect(throws: DecodingError.self) { try decode(base + "," + entry + "}") }
        }
        #expect((try? decode(base + ",\"cursorA\":0,\"cursorB\":1,\"levelCursor\":-1}")) != nil)
        #expect(ScopeState(source: .testSignal, waveform: .sine, frequencyIndex: 0, gainIndex: 0, timebaseIndex: 0,
                           triggerLevel: 0, triggerSlope: .rising, triggerMode: .auto, cursorA: .nan) == nil)
        #expect(ScopeState(source: .testSignal, waveform: .sine, frequencyIndex: 0, gainIndex: 0, timebaseIndex: 0,
                           triggerLevel: 0, triggerSlope: .rising, triggerMode: .auto, levelCursor: 1.5) == nil)
        #expect(ScopeState(source: .testSignal, waveform: .sine, frequencyIndex: 0, gainIndex: 0, timebaseIndex: 0,
                           triggerLevel: 0, triggerSlope: .rising, triggerMode: .auto,
                           frequencyCursor: .infinity) == nil)
    }

    @Test func theCursorSettersClampAndRefuseNonFiniteValues() {
        var state = ScopeState.initial
        let refused = [state.setCursorA(.nan), state.setCursorB(.infinity), state.setFrequencyCursor(-.infinity),
                       state.setLevelCursor(.nan)]
        #expect(refused == [false, false, false, false])
        #expect(state == .initial)
        let accepted = [state.setCursorA(-0.5), state.setCursorB(1.5), state.setFrequencyCursor(0.3),
                        state.setLevelCursor(-2)]
        #expect(accepted == [true, true, true, true])
        #expect(state.cursorA == 0 && state.cursorB == 1 && state.frequencyCursor == 0.3 && state.levelCursor == -1)
        #expect(state.cursorA.sign == .plus)   // a clamped −0.5 is stored as +0
        state.setFrozen(true)
        state.setCursorsShown(true)
        #expect(state.frozen && state.cursorsShown)
        state.setFrozen(false)
        #expect(!state.frozen)
    }

    @Test func theDigestDiffersWhenFreezeOrAnyCursorChanges() {
        let base = ScopeState.initial
        var variants: [ScopeState] = []
        var s = base; s.setFrozen(true); variants.append(s)
        s = base; s.setCursorsShown(true); variants.append(s)
        s = base; s.setCursorA(0.26); variants.append(s)
        s = base; s.setCursorB(0.74); variants.append(s)
        s = base; s.setFrequencyCursor(0.51); variants.append(s)
        s = base; s.setLevelCursor(0.49); variants.append(s)
        let texts = Set(variants.map(\.digestText) + [base.digestText])
        #expect(texts.count == variants.count + 1)
        var moved = base
        moved.setCursorA(0.6)
        moved.setCursorA(0.25)
        #expect(moved.digestText == base.digestText)
    }
}
