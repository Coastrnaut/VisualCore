// RecentMoleculesTests — feature 113 (A15-P04) T-A15-402 (contracts/library.md; data-model "RecentMolecules";
// clarification Q1). The recent list, host-free and short: newest first, unique, capped at 8; re-recording moves an id
// to the front; ids outside the library are dropped on read; the sorted-key JSON round trip is byte-exact; one fixture
// per refusal (damaged, oversized, newer-version, and out-of-range for 9 ids, a duplicate, a malformed id, schema 0).
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct RecentMoleculesTests {
    /// The library ids.
    private let known: Set<String> = ["water", "methane", "ethanol", "benzene", "caffeine"]

    /// The refusal of `json`, or nil when it decodes.
    private func refusal(_ json: String, known: Set<String> = []) -> DocumentRefusal? {
        if case .failure(let reason) = RecentMolecules.decode(Data(json.utf8), known: known) { return reason }
        return nil
    }

    @Test func theConstantsMatchTheContract() {
        #expect(RecentMolecules.schemaVersion == 1 && RecentMolecules.cap == 8)
        #expect(RecentMolecules.maxBytes == 2_048 && RecentMolecules.fileName == "recent.json")
        #expect(RecentMolecules().ids.isEmpty)
    }

    @Test func recordingKeepsTheNewestEightUniqueIdsFirst() {
        var recent = RecentMolecules()
        for index in 0..<10 { recent.record("m\(index)") }
        #expect(recent.ids == ["m9", "m8", "m7", "m6", "m5", "m4", "m3", "m2"])
        recent.record("m9")
        #expect(recent.ids.count == 8 && recent.ids.first == "m9")
    }

    @Test func reRecordingMovesAnIdToTheFront() {
        var recent = RecentMolecules()
        recent.record("water"); recent.record("methane"); recent.record("benzene")
        recent.record("water")
        #expect(recent.ids == ["water", "benzene", "methane"])
    }

    @Test func unknownIdsAreDroppedOnRead() {
        let json = #"{"ids":["caffeine","gone","water"],"schemaVersion":1}"#
        let decoded = try? RecentMolecules.decode(Data(json.utf8), known: known).get()
        #expect(decoded?.ids == ["caffeine", "water"])
    }

    @Test func theRoundTripIsByteExact() {
        var recent = RecentMolecules()
        recent.record("water"); recent.record("caffeine")
        let text = String(decoding: recent.encoded(), as: UTF8.self)
        #expect(text == #"{"ids":["caffeine","water"],"schemaVersion":1}"#)
        let decoded = try? RecentMolecules.decode(recent.encoded(), known: known).get()
        #expect(decoded == recent)
        #expect(decoded?.encoded() == recent.encoded())
        #expect(String(decoding: RecentMolecules().encoded(), as: UTF8.self) == #"{"ids":[],"schemaVersion":1}"#)
    }

    @Test func damagedOversizedAndNewerPayloadsAreRefused() {
        #expect(refusal("not json") == .damaged)
        #expect(refusal(#"{"ids":"water","schemaVersion":1}"#) == .damaged)
        #expect(refusal(#"{"schemaVersion":1}"#) == .damaged)
        #expect(refusal(#"{"ids":[1],"schemaVersion":1}"#) == .damaged)
        let padding = String(repeating: " ", count: 2_049 - 35)
        let oversized = #"{"ids":["water"],"schemaVersion":1}"# + padding
        #expect(oversized.utf8.count == 2_049)
        #expect(refusal(oversized) == .oversized)
        #expect(refusal(String(repeating: "x", count: 2_049)) == .oversized, "checked before parsing")
        #expect(refusal(#"{"ids":["water"],"schemaVersion":2}"#) == .newerVersion)
    }

    @Test func outOfRangePayloadsAreRefused() {
        var nine: [String] = []
        for index in 0..<9 { nine.append("\"m\(index)\"") }
        let tooMany = #"{"ids":["# + nine.joined(separator: ",") + #"],"schemaVersion":1}"#
        #expect(refusal(tooMany) == .outOfRange)
        #expect(refusal(#"{"ids":["water","water"],"schemaVersion":1}"#) == .outOfRange)
        #expect(refusal(#"{"ids":["Water"],"schemaVersion":1}"#) == .outOfRange)
        #expect(refusal(#"{"ids":[""],"schemaVersion":1}"#) == .outOfRange)
        #expect(refusal(#"{"ids":["water_2"],"schemaVersion":1}"#) == .outOfRange)
        let long = String(repeating: "a", count: 33)
        #expect(refusal(#"{"ids":[""# + long + #""],"schemaVersion":1}"#) == .outOfRange)
        #expect(refusal(#"{"ids":[""# + String(long.dropLast()) + #""],"schemaVersion":1}"#) == nil, "32 accepted")
        #expect(refusal(#"{"ids":["water"],"schemaVersion":0}"#) == .outOfRange)
    }
}
