// SimulationStateTests — feature 117 (A16-P01) T-A16-104 (FR-A16-110, FR-A16-120; SC-A16-104; clarification Q5). The
// saved state, host-free and short: the round trip is byte for byte for every family (and restores the same model and
// digest); the largest state fits the limit; each refusal (damaged, newer-version, out-of-range) is given for its
// cases; the half bit patterns convert exactly.
import Foundation
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct SimulationStateTests {
    /// A 16 × 16 model of `kind` after `steps` iterations.
    private func model(_ kind: SimulationKind, steps: Int = 7) -> SimulationModel {
        var spec = SimulationSpec.standard(kind, preset: 1, seed: 21)
        spec.gridSize = 16
        var m = try! SimulationModel(spec: spec)
        for _ in 0..<steps { m.step() }
        m.setSpeed(1)
        _ = m.advance()
        return m
    }

    /// The refusal of `data`, or nil when it decodes.
    private func refusal(_ data: Data) -> SimulationStateRefusal? {
        if case .failure(let reason) = SimulationState.decode(data) { return reason }
        return nil
    }

    /// `data` with channel `index` replaced by `bytes`.
    private func replacingChannel(_ data: Data, _ index: Int, _ bytes: [UInt8]) -> Data {
        mutatedJSON(data) { object in
            var channels = object["channels"] as? [String] ?? []
            if channels.indices.contains(index) { channels[index] = Data(bytes).base64EncodedString() }
            object["channels"] = channels
        }
    }

    @Test func theRoundTripIsByteForByte() throws {
        for kind in SimulationKind.allCases {
            let m = model(kind)
            let data = m.state.encoded()
            #expect(!data.isEmpty && data.count <= SimulationState.maxBytes)
            let decoded = try SimulationState.decode(data).get()
            #expect(decoded == m.state, "\(kind)")
            #expect(decoded.encoded() == data, "\(kind)")
            let restored = SimulationModel(state: decoded)
            #expect(restored == m && restored.digest == m.digest)
            var a = restored, b = m
            a.step(); b.step()
            #expect(a == b)
        }
        let text = try #require(String(data: model(.automaton).state.encoded(), encoding: .utf8))
        #expect(text.hasPrefix(#"{"channels":[""#) && text.contains(#""schema":1,"spec":{"#))
    }

    @Test func theLargestStateFitsTheLimit() throws {
        let kinds: [SimulationKind] = [.reactionDiffusion, .wave]
        for kind in kinds {
            var spec = SimulationSpec.standard(kind)
            spec.gridSize = 256
            let data = try SimulationModel(spec: spec).state.encoded()
            #expect(data.count <= SimulationState.maxBytes && data.count > 256 * 256 * 4)
            #expect(refusal(data) == nil)
        }
        #expect(refusal(Data(repeating: 32, count: SimulationState.maxBytes + 1)) == .outOfRange)
    }

    @Test func damagedPayloadsAreRefused() {
        let data = model(.reactionDiffusion).state.encoded()
        let damaged: [Data] = [Data(), Data("garbage".utf8), Data("{}".utf8), Data("[]".utf8), data.prefix(100),
                               mutatedJSON(data) { $0["schema"] = 0 },
                               mutatedJSON(data) { $0["schema"] = "1" },
                               mutatedJSON(data) { $0.removeValue(forKey: "channels") },
                               mutatedJSON(data) { $0.removeValue(forKey: "scheduler") },
                               mutatedJSON(data) { $0["channels"] = ["@@@", "@@@"] },
                               mutatedJSON(data) { $0["spec"] = "x" },
                               mutatedJSON(data) { object in
                                   var scheduler = object["scheduler"] as? [String: Any] ?? [:]
                                   scheduler.removeValue(forKey: "running")
                                   object["scheduler"] = scheduler
                               }]
        for (i, input) in damaged.enumerated() { #expect(refusal(input) == .damaged, "case \(i)") }
    }

    @Test func newerVersionsAreRefused() {
        let data = model(.wave).state.encoded()
        #expect(refusal(mutatedJSON(data) { $0["schema"] = 2 }) == .newerVersion)
        let newerSpec = mutatedJSON(data) { object in
            var spec = object["spec"] as? [String: Any] ?? [:]
            spec["algorithmVersion"] = 2
            object["spec"] = spec
        }
        #expect(refusal(newerSpec) == .newerVersion)
    }

    @Test func outOfRangeSettingsAreRefused() {
        let data = model(.wave).state.encoded()
        func spec(_ key: String, _ value: Any) -> Data {
            mutatedJSON(data) { object in
                var spec = object["spec"] as? [String: Any] ?? [:]
                spec[key] = value
                object["spec"] = spec
            }
        }
        func scheduler(_ key: String, _ value: Any) -> Data {
            mutatedJSON(data) { object in
                var scheduler = object["scheduler"] as? [String: Any] ?? [:]
                scheduler[key] = value
                object["scheduler"] = scheduler
            }
        }
        let refused: [Data] = [spec("kind", "fluid"), spec("boundary", "wrap"), spec("gridSize", 32),
                               spec("gridSize", 48), spec("timeStep", 0.9), spec("parameters", ["speed": 3.0]),
                               scheduler("speedIndex", 5), scheduler("stepCount", -1), scheduler("accumulator", 1.5),
                               scheduler("kind", "automaton"), scheduler("kind", "fluid"),
                               mutatedJSON(data) { object in
                                   let channels = object["channels"] as? [String] ?? []
                                   object["channels"] = Array(channels.prefix(1))
                               }]
        for (i, input) in refused.enumerated() { #expect(refusal(input) == .outOfRange, "case \(i)") }
    }

    @Test func outOfRangeFieldValuesAreRefused() {
        let automaton = model(.automaton).state.encoded()
        var bytes = [UInt8](repeating: 0, count: 256)
        #expect(refusal(replacingChannel(automaton, 0, bytes)) == nil)
        bytes[5] = 7
        #expect(refusal(replacingChannel(automaton, 0, bytes)) == .outOfRange)
        #expect(refusal(replacingChannel(automaton, 0, [UInt8](repeating: 0, count: 255))) == .outOfRange)

        let rd = model(.reactionDiffusion).state.encoded()
        var half = [UInt8](repeating: 0, count: 512)
        #expect(refusal(replacingChannel(rd, 1, half)) == nil)
        let invalidWords: [UInt16] = [0x4000, 0x7E00, 0x7C00, 0xBC00]   // 2, NaN, +∞, −1
        for word in invalidWords {
            half[10] = UInt8(word & 0xFF)
            half[11] = UInt8(word >> 8)
            #expect(refusal(replacingChannel(rd, 0, half)) == .outOfRange, "\(word)")
        }
        #expect(refusal(replacingChannel(rd, 0, [UInt8](repeating: 0, count: 510))) == .outOfRange)

        let wave = model(.wave).state.encoded()
        var field = [UInt8](repeating: 0, count: 512)
        field[2 * 17] = 0x00
        field[2 * 17 + 1] = 0x3C   // interior cell (1, 1) = 1
        #expect(refusal(replacingChannel(wave, 1, field)) == nil)
        field[0] = 0x00
        field[1] = 0x3C            // border cell (0, 0) = 1
        #expect(refusal(replacingChannel(wave, 1, field)) == .outOfRange)
        field[0] = 0x00
        field[1] = 0x7E            // NaN on the border
        #expect(refusal(replacingChannel(wave, 0, field)) == .outOfRange)
    }

    @Test func halfBitPatternsConvertExactly() {
        #expect(FieldBits.halfBits(1) == 0x3C00 && FieldBits.halfBits(0.5) == 0x3800 && FieldBits.halfBits(-2) == 0xC000)
        #expect(FieldBits.halfBits(65504) == 0x7BFF && FieldBits.halfBits(0x1p-24) == 0x0001)
        #expect(FieldBits.halfBits(-0.0) == 0x8000 && FieldBits.halfBits(.infinity) == 0x7C00)
        var exact = 0
        for word in 0...0xFFFF {
            let bits = UInt16(word)
            let value = FieldBits.float(halfBits: bits)
            if value.isNaN { continue }
            if FieldBits.halfBits(value) == bits && StoragePrecision.float16.round(value) == value { exact += 1 }
        }
        #expect(exact == 65536 - 2046)   // every pattern except the 2046 NaNs
    }
}
