// ExportHistoryTests — feature 141 (A19-P04) T-A19-402 (FR-A19-404; SC-A19-403; clarification Q3). The default is
// empty; adding 25 entries keeps the newest 20, newest first; the encoded file decodes to an equal history and
// re-encodes to the same bytes; `cleared()` empties it; each refusal (damaged, a wrong kind, newer-version, too-large,
// a non-finite `madeAt`, a non-positive size) comes from one JSON sample and has its code and sentence.
import Foundation
import Testing
@testable import LivingWallpapersCore

@Suite struct ExportHistoryTests {
    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<ExportHistory, HistoryRefusal>) -> HistoryRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// A distinct entry for index `index`.
    private static func entry(_ index: Int) -> ExportHistory.Entry {
        ExportHistory.Entry(scene: "aurora-bands", template: "iphone-16-pro",
                            orientation: index % 2 == 0 ? .portrait : .landscape,
                            format: ExportFormat.allCases[index % ExportFormat.allCases.count],
                            width: 1206 + index, height: 2622, madeAt: 1_800_000_000 + Double(index) * 0.25)
    }

    /// A history file with the given kind, schema and one entry's `madeAt`, width and height.
    private static func sample(kind: String = ExportHistory.kind, schema: Int = 1, madeAt: String = "1800000000.5",
                               width: Int = 1206, height: Int = 2622) -> Data {
        let json = "{\"entries\":[{\"format\":\"png\",\"height\":\(height),\"madeAt\":\(madeAt),"
            + "\"orientation\":\"portrait\",\"scene\":\"aurora-bands\",\"template\":\"iphone-16-pro\","
            + "\"width\":\(width)}],\"kind\":\"\(kind)\",\"schemaVersion\":\(schema)}"
        return Data(json.utf8)
    }

    @Test func theDefaultIsEmpty() {
        #expect(ExportHistory().entries.isEmpty)
        #expect(ExportHistory.kind == "a19.export-history")
        #expect(ExportHistory.schemaVersion == 1)
        #expect(ExportHistory.maxBytes == 16_384)
        #expect(ExportHistory.bound == 20)
    }

    @Test func addingKeepsTheNewestTwentyNewestFirst() {
        var history = ExportHistory()
        for index in 0..<25 { history = history.adding(Self.entry(index)) }
        #expect(history.entries.count == ExportHistory.bound)
        for position in 0..<ExportHistory.bound {
            #expect(history.entries[position] == Self.entry(24 - position))
        }
        var many: [ExportHistory.Entry] = []
        for index in 0..<25 { many.append(Self.entry(index)) }
        #expect(ExportHistory(entries: many).entries == Array(many.prefix(20)))
    }

    @Test func theFileRoundTripsExactly() throws {
        var history = ExportHistory()
        for index in 0..<7 { history = history.adding(Self.entry(index)) }
        let data = try history.encoded()
        let decoded = try ExportHistory.decode(data).get()
        #expect(decoded == history)
        #expect(try decoded.encoded() == data)
        #expect(try ExportHistory.decode(ExportHistory().encoded()).get() == ExportHistory())
        #expect(try ExportHistory.decode(Self.sample()).get().entries.count == 1)
    }

    @Test func clearedEmptiesTheHistory() {
        var history = ExportHistory()
        for index in 0..<3 { history = history.adding(Self.entry(index)) }
        #expect(history.cleared().entries.isEmpty)
        #expect(history.cleared() == ExportHistory())
    }

    @Test func eachRefusalHasItsCodeAndSentence() {
        let damaged: [Data] = [
            Data("not json".utf8),
            Data("{\"kind\":\"a19.export-history\",\"schemaVersion\":1}".utf8),
            Self.sample(kind: "a19.wallpaper-project"),
            Self.sample(schema: 0),
            Self.sample(madeAt: "1e999"),
            Self.sample(width: 0),
            Self.sample(height: -4),
        ]
        for data in damaged {
            #expect(Self.refusal(ExportHistory.decode(data)) == .damaged)
        }
        #expect(Self.refusal(ExportHistory.decode(Self.sample(schema: 2))) == .newerVersion(2))
        let large = Data(repeating: 0x20, count: ExportHistory.maxBytes + 1)
        #expect(Self.refusal(ExportHistory.decode(large)) == .tooLarge(ExportHistory.maxBytes + 1))

        let refusals: [HistoryRefusal] = [.damaged, .newerVersion(2), .tooLarge(16_385)]
        let codes = ["damaged", "newer-version", "too-large"]
        for (refusal, code) in zip(refusals, codes) {
            #expect(refusal.code == code)
            #expect(refusal.sentence.hasSuffix("."))
        }
        #expect(HistoryRefusal.newerVersion(2).sentence.contains("2"))
        #expect(HistoryRefusal.tooLarge(16_385).sentence.contains("16385"))
    }
}
