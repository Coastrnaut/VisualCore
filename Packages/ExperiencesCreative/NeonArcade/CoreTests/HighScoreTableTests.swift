// HighScoreTableTests — feature 078 (A10-P04) T-A10-402 (FR-A10-410, FR-A10-412; clarification 2; research D2;
// SC-A10-403). The high-score table, host-free and short: insertion ranks (highest first), an equal score ranks below
// the earlier run, the tenth-entry cut (an eleventh entry drops the lowest, one equal to the tenth is not entered),
// a score of 0, a score above 9,999,999, a wave below 1 and a run below 1 refused, a duplicate or earlier run refused
// (a run is entered once, also when it did not rank), the JSON round trip with sorted keys and no other fields,
// damaged, truncated and newer JSON refused with a reason, a rule-breaking table refused as invalid, and many random
// entries leaving at most ten ordered entries with each run once.
import Foundation
import Testing
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct HighScoreTableTests {
    /// A table holding the runs 1…`count` with scores 100, 200, … (so run `count` is best).
    private func table(count: Int) -> HighScoreTable {
        var table = HighScoreTable()
        for run in 1...count { table.enter(HighScoreEntry(score: run * 100, wave: 1, run: run)) }
        return table
    }

    @Test func anEmptyTableIsValid() {
        let empty = HighScoreTable()
        #expect(empty.boardVersion == 1 && empty.entries.isEmpty && empty.lastRun == 0 && empty.best == nil)
        #expect(empty.validate().isEmpty)
        #expect(HighScoreTable.boardVersion == 1 && HighScoreTable.maxEntries == 10)
    }

    @Test func entriesAreRankedHighestFirst() {
        var table = HighScoreTable()
        #expect(table.enter(HighScoreEntry(score: 500, wave: 2, run: 1)) == 0)
        #expect(table.enter(HighScoreEntry(score: 900, wave: 3, run: 2)) == 0)
        #expect(table.enter(HighScoreEntry(score: 700, wave: 2, run: 3)) == 1)
        #expect(table.enter(HighScoreEntry(score: 100, wave: 1, run: 4)) == 3)
        #expect(table.entries.map(\.score) == [900, 700, 500, 100])
        #expect(table.best == HighScoreEntry(score: 900, wave: 3, run: 2))
        #expect(table.lastRun == 4 && table.validate().isEmpty)
    }

    @Test func anEqualScoreRanksBelowTheEarlierRun() {
        var table = HighScoreTable()
        table.enter(HighScoreEntry(score: 300, wave: 1, run: 1))
        table.enter(HighScoreEntry(score: 500, wave: 1, run: 2))
        #expect(table.enter(HighScoreEntry(score: 300, wave: 2, run: 3)) == 2)
        #expect(table.entries.map(\.run) == [2, 1, 3])
        #expect(table.validate().isEmpty)
    }

    @Test func theTenthEntryCut() {
        var full = table(count: 10)
        #expect(full.entries.count == 10 && full.entries.last?.score == 100)
        // An eleventh entry that ranks drops the lowest.
        #expect(full.enter(HighScoreEntry(score: 150, wave: 1, run: 11)) == 9)
        #expect(full.entries.count == 10 && full.entries.last?.score == 150)
        #expect(!full.entries.contains { $0.run == 1 })
        // One equal to the tenth ranks below it and is cut; one below is not entered; both are processed.
        #expect(full.enter(HighScoreEntry(score: 150, wave: 1, run: 12)) == nil)
        #expect(full.enter(HighScoreEntry(score: 50, wave: 1, run: 13)) == nil)
        #expect(full.entries.count == 10 && full.lastRun == 13 && full.validate().isEmpty)
    }

    @Test func invalidEntriesAreRefused() {
        var table = HighScoreTable()
        #expect(table.enter(HighScoreEntry(score: 0, wave: 1, run: 1)) == nil)
        #expect(table.enter(HighScoreEntry(score: -5, wave: 1, run: 2)) == nil)
        #expect(table.enter(HighScoreEntry(score: 10_000_000, wave: 1, run: 3)) == nil)
        #expect(table.enter(HighScoreEntry(score: 10, wave: 0, run: 4)) == nil)
        #expect(table.entries.isEmpty && table.lastRun == 4)
        #expect(table.enter(HighScoreEntry(score: 10, wave: 1, run: 0)) == nil)
        #expect(table.lastRun == 4)
        #expect(table.enter(HighScoreEntry(score: 9_999_999, wave: 1, run: 5)) == 0)
        #expect(HighScoreEntry(score: 0, wave: 0, run: 0).validate().count == 3)
    }

    @Test func aRunIsEnteredOnce() {
        var table = HighScoreTable()
        let entry = HighScoreEntry(score: 400, wave: 2, run: 1)
        #expect(table.enter(entry) == 0)
        #expect(table.enter(entry) == nil)                                       // seen again after a restore
        #expect(table.enter(HighScoreEntry(score: 800, wave: 3, run: 1)) == nil)
        #expect(table.entries == [entry])
        // A run that did not rank is still processed once.
        var full = self.table(count: 10)
        #expect(full.enter(HighScoreEntry(score: 1, wave: 1, run: 11)) == nil)
        #expect(full.enter(HighScoreEntry(score: 5_000, wave: 1, run: 11)) == nil)
        #expect(full.enter(HighScoreEntry(score: 5_000, wave: 1, run: 7)) == nil)  // an earlier run
        #expect(full.lastRun == 11 && full.entries.first?.run == 10)
    }

    @Test func theJSONRoundTripWithSortedKeys() throws {
        let original = table(count: 4)
        let data = original.encoded()
        #expect(HighScoreTable.decode(data) == .success(original))
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"boardVersion\":1,\"entries\":[{\"run\":4,\"score\":400,\"wave\":1}"))
        #expect(text.hasSuffix("],\"lastRun\":4}"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["boardVersion", "entries", "lastRun"])
        #expect(HighScoreTable.decode(HighScoreTable().encoded()) == .success(HighScoreTable()))
    }

    @Test func damagedTruncatedAndNewerJSONAreRefusedWithAReason() {
        let data = table(count: 3).encoded()
        #expect(HighScoreTable.decode(Data()) == .failure(.damaged))
        #expect(HighScoreTable.decode(Data("not json".utf8)) == .failure(.damaged))
        #expect(HighScoreTable.decode(data.prefix(data.count / 2)) == .failure(.damaged))
        #expect(HighScoreTable.decode(data.dropLast()) == .failure(.damaged))
        #expect(HighScoreTable.decode(Data("{\"boardVersion\":1,\"entries\":[]}".utf8)) == .failure(.damaged))
        #expect(HighScoreTable.decode(Data("{\"boardVersion\":1,\"entries\":[{\"run\":1,\"score\":1.5,\"wave\":1}],\"lastRun\":1}".utf8))
                == .failure(.damaged))
        let newer = Data("{\"boardVersion\":2,\"entries\":[],\"future\":true}".utf8)
        #expect(HighScoreTable.decode(newer) == .failure(.newerVersion(2)))
        #expect(HighScoreTableError.newerVersion(2).reason.contains("board version 2"))
        #expect(HighScoreTableError.damaged.reason == "the high-score file is damaged")
    }

    @Test func aRuleBreakingTableIsInvalid() {
        let unordered = HighScoreTable(entries: [HighScoreEntry(score: 100, wave: 1, run: 1),
                                                 HighScoreEntry(score: 200, wave: 1, run: 2)], lastRun: 2)
        let duplicate = HighScoreTable(entries: [HighScoreEntry(score: 200, wave: 1, run: 1),
                                                 HighScoreEntry(score: 100, wave: 1, run: 1)], lastRun: 1)
        let tooMany = HighScoreTable(entries: (1...11).reversed().map { HighScoreEntry(score: $0, wave: 1, run: 12 - $0) },
                                     lastRun: 11)
        let ahead = HighScoreTable(entries: [HighScoreEntry(score: 100, wave: 1, run: 5)], lastRun: 3)
        let older = HighScoreTable(boardVersion: 0, entries: [], lastRun: 0)
        let zero = HighScoreTable(entries: [HighScoreEntry(score: 0, wave: 1, run: 1)], lastRun: 1)
        let negative = HighScoreTable(entries: [], lastRun: -1)
        #expect(unordered.validate() == ["entry 1 is out of order"])
        #expect(duplicate.validate() == ["a run appears more than once"])
        #expect(tooMany.validate() == ["11 entries exceed 10"])
        #expect(ahead.validate() == ["run 5 is after the last run 3"])
        #expect(older.validate() == ["board version 0 is not 1"])
        #expect(zero.validate() == ["entry 0: score 0 is outside 1…9999999"])
        #expect(negative.validate() == ["last run -1 is negative"])
        for table in [unordered, duplicate, tooMany, ahead, older, zero, negative] {
            #expect(HighScoreTable.decode(table.encoded()) == .failure(.invalid(table.validate())))
        }
        #expect(HighScoreTableError.invalid(["entry 1 is out of order"]).reason.hasSuffix("entry 1 is out of order"))
    }

    @Test func manyEntriesKeepTheRules() {
        var random = SeededRandom(seed: 78)
        var table = HighScoreTable()
        for run in 1...300 {
            let score = random.int(0...40) * 50                  // includes 0 and many ties
            let rank = table.enter(HighScoreEntry(score: score, wave: 1 + run % 5, run: run))
            if let rank { #expect(table.entries[rank].run == run) }
            #expect(table.entries.count <= 10 && table.lastRun == run)
            // Seeing the end again changes nothing.
            let before = table
            #expect(table.enter(HighScoreEntry(score: score, wave: 1, run: run)) == nil && table == before)
        }
        #expect(table.entries.count == 10 && table.validate().isEmpty)
        #expect(HighScoreTable.decode(table.encoded()) == .success(table))
    }
}
