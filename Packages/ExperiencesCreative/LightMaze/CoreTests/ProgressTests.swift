// ProgressTests — feature 098 (A13-P03) T-A13-302 (FR-A13-301, FR-A13-321; SC-A13-301, SC-A13-302; clarifications Q2,
// Q4; contracts/progress.md). The level progression, host-free and short: fresh progress opens only level 1; solving a
// level opens the next and keeps the fewest moves (at least 1); the sorted-key JSON round trip is exact; damaged,
// truncated, oversized, newer, unknown-id, wrong-count and inconsistent documents are refused with their reason.
import Foundation
import LightMazeCore
import Testing

@Suite struct ProgressTests {
    private func level(_ id: String, open: Bool, solved: Bool, best: String) -> String {
        #"{"best":\#(best),"id":"\#(id)","open":\#(open),"solved":\#(solved)}"#
    }

    /// A document with the 20 catalog levels, level 1 open, after `change` edits the level strings.
    private func document(schema: Int = 1, _ change: (inout [String]) -> Void = { _ in }) -> Data {
        var levels: [String] = []
        for index in 0..<20 {
            let id: String = LevelCatalog.bundled.levels[index].id
            levels.append(level(id, open: index == 0, solved: false, best: "null"))
        }
        change(&levels)
        return Data((#"{"levels":["# + levels.joined(separator: ",") + #"],"schema":\#(schema)}"#).utf8)
    }

    @Test func freshProgressOpensOnlyTheFirstLevel() {
        let progress: LightMazeCore.Progress = .fresh()
        #expect(progress.levels.count == 20)
        for index in 0..<20 {
            let entry: LevelProgress = progress.levels[index]
            #expect(entry.id == LevelCatalog.bundled.levels[index].id)
            #expect(entry.open == (index == 0) && !entry.solved && entry.best == nil, "level \(index + 1)")
            #expect(progress.isOpen(index) == (index == 0))
        }
        #expect(!progress.isOpen(-1) && !progress.isOpen(20) && !progress.isSolved(0) && progress.best(0) == nil)
        #expect(LightMazeCore.Progress.schemaVersion == 1 && LightMazeCore.Progress.maxBytes == 16_384)
    }

    @Test func solvingOpensTheNextLevelAndKeepsTheFewestMoves() {
        var progress: LightMazeCore.Progress = .fresh()
        var changed: Bool = progress.recordSolved(levelIndex: 0, moves: 3)
        #expect(changed && progress.isSolved(0) && progress.best(0) == 3 && progress.isOpen(1) && !progress.isOpen(2))
        changed = progress.recordSolved(levelIndex: 0, moves: 5)
        #expect(!changed && progress.best(0) == 3, "a worse solve changes nothing")
        changed = progress.recordSolved(levelIndex: 0, moves: 2)
        #expect(changed && progress.best(0) == 2)
        changed = progress.recordSolved(levelIndex: 0, moves: 0)
        #expect(changed && progress.best(0) == 1, "at least 1")
        changed = progress.recordSolved(levelIndex: 1, moves: 2000)
        #expect(changed && progress.best(1) == 999 && progress.isOpen(2), "at most 999")
        changed = progress.recordSolved(levelIndex: 20, moves: 1) || progress.recordSolved(levelIndex: -1, moves: 1)
        #expect(!changed)
        changed = progress.recordSolved(levelIndex: 19, moves: 4)
        #expect(changed && progress.isSolved(19) && progress.isOpen(19), "the last level opens nothing more")
        for index in 0..<20 {
            #expect(progress.levels[index].isValid, "level \(index + 1)")
        }
        #expect(!progress.isOpen(3))
    }

    @Test func theJSONRoundTripIsExactAndSorted() {
        var progress: LightMazeCore.Progress = .fresh()
        progress.recordSolved(levelIndex: 0, moves: 1)
        progress.recordSolved(levelIndex: 1, moves: 4)
        let data: Data = progress.encoded()
        #expect(LightMazeCore.Progress.decode(data) == .success(progress))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"levels":[{"best":1,"id":"lm-01","open":true,"solved":true},"#), "\(text)")
        #expect(text.contains(#"{"best":null,"id":"lm-03","open":true,"solved":false}"#))
        #expect(text.hasSuffix(#"{"best":null,"id":"lm-20","open":false,"solved":false}],"schema":1}"#))
        #expect(data.count <= LightMazeCore.Progress.maxBytes)
        let fresh: LightMazeCore.Progress = .fresh()
        #expect(LightMazeCore.Progress.decode(fresh.encoded()) == .success(fresh))
        #expect(LightMazeCore.Progress.decode(document()) == .success(fresh))
    }

    @Test func damagedDocumentsAreRefused() {
        let fresh: Data = LightMazeCore.Progress.fresh().encoded()
        var payloads: [Data] = [
            Data("not json".utf8),
            Data(),
            fresh.prefix(fresh.count / 2),
            Data(#"{"levels":[]}"#.utf8),
            Data(#"{"levels":[],"schema":"1"}"#.utf8),
            Data(#"{"levels":[],"schema":0}"#.utf8),
            Data(#"{"levels":[],"schema":1}"#.utf8),
            Data(#"{"schema":1}"#.utf8),
        ]
        payloads.append(document { $0.removeLast() })
        payloads.append(document { $0.append($0[19]) })
        payloads.append(document { $0[4] = self.level("lm-99", open: false, solved: false, best: "null") })
        payloads.append(document { $0.swapAt(2, 3) })
        payloads.append(document { $0[0] = self.level("lm-01", open: false, solved: false, best: "null") })
        payloads.append(document { $0[0] = self.level("lm-01", open: true, solved: true, best: "null") })
        payloads.append(document { $0[0] = self.level("lm-01", open: true, solved: true, best: "0") })
        payloads.append(document { $0[0] = self.level("lm-01", open: true, solved: true, best: "1000") })
        payloads.append(document { $0[1] = self.level("lm-02", open: false, solved: true, best: "3") })
        payloads.append(document { $0[1] = self.level("lm-02", open: true, solved: false, best: "3") })
        payloads.append(document { $0[1] = self.level("lm-02", open: true, solved: false, best: "\"3\"") })
        payloads.append(document { $0[1] = #"{"id":"lm-02","open":false,"solved":false}"# })
        payloads.append(document { $0[1] = #"{"best":null,"id":"lm-02","solved":false}"# })
        for payload in payloads {
            let text = String(decoding: payload, as: UTF8.self)
            #expect(LightMazeCore.Progress.decode(payload) == .failure(.damaged), "\(text.prefix(120))")
        }
    }

    @Test func oversizedAndNewerDocumentsAreRefused() {
        var oversized: Data = LightMazeCore.Progress.fresh().encoded()
        oversized.append(Data(repeating: 0x20, count: LightMazeCore.Progress.maxBytes + 1 - oversized.count))
        #expect(oversized.count == 16_385)
        #expect(LightMazeCore.Progress.decode(oversized) == .failure(.tooLarge))
        var limit: Data = LightMazeCore.Progress.fresh().encoded()
        limit.append(Data(repeating: 0x20, count: LightMazeCore.Progress.maxBytes - limit.count))
        #expect(LightMazeCore.Progress.decode(limit) == .success(.fresh()), "16 KB exactly is accepted")
        #expect(LightMazeCore.Progress.decode(Data(repeating: 0x7B, count: 20_000)) == .failure(.tooLarge))
        #expect(LightMazeCore.Progress.decode(document(schema: 2)) == .failure(.newerVersion))
        #expect(LightMazeCore.Progress.decode(Data(#"{"schema":9}"#.utf8)) == .failure(.newerVersion))
        #expect(ProgressRefusal.allCases.map(\.rawValue) == ["damaged", "too-large", "newer-version"])
    }

    @Test func aDocumentForAnotherCatalogIsRefused() {
        let short = LevelCatalog(levels: Array(LevelCatalog.bundled.levels.prefix(3)))
        let progress: LightMazeCore.Progress = .fresh(short)
        #expect(progress.levels.count == 3 && progress.isOpen(0) && !progress.isOpen(1))
        #expect(LightMazeCore.Progress.decode(progress.encoded(), catalog: short) == .success(progress))
        #expect(LightMazeCore.Progress.decode(progress.encoded()) == .failure(.damaged))
    }
}
