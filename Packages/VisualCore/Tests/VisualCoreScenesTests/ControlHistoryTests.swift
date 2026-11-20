// ControlHistoryTests — feature 222 (R02-F22) T-R02F22-005 (FR-R02F22-004, 006; SC-R02F22-004, 006).
import Foundation
import Testing
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64) for seeded edit sequences.
fileprivate struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A double in lower ..< upper.
    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        let unit: Double = Double(next() >> 11) / Double(UInt64(1) << 53)
        return lower + (upper - lower) * unit
    }
    /// An integer in lower ... upper.
    mutating func int(_ lower: Int, _ upper: Int) -> Int {
        let span: UInt64 = UInt64(upper - lower + 1)
        return lower + Int(next() % span)
    }
}

/// A small edited value: a handle position.
fileprivate struct Pose: Sendable, Equatable, Codable {
    var x: Double
    var y: Double
    var z: Double
}

@Suite struct ControlHistoryTests {
    /// Decodes and returns the refusal, or nil when decoding succeeded.
    static func refusal(_ json: String) -> SpatialControlError? {
        do {
            _ = try ControlHistory<Double>.decode(Data(json.utf8))
            return nil
        } catch {
            return error
        }
    }

    /// A random pose near `p`.
    fileprivate static func nudge(_ p: Pose, _ rng: inout SplitMix64) -> Pose {
        Pose(x: p.x + rng.double(-1, 1), y: p.y + rng.double(-1, 1), z: p.z + rng.double(-1, 1))
    }

    @Test func seededSequencesUndoToStartAndRedoToEnd() throws {
        var rng: SplitMix64 = SplitMix64(seed: 2_022)
        for sequence in 0 ..< 50 {
            var history: ControlHistory<Pose> = try ControlHistory<Pose>(depth: 1_000)
            let start: Pose = Pose(x: rng.double(-5, 5), y: rng.double(-5, 5), z: rng.double(-5, 5))
            var current: Pose = start
            let operations: Int = rng.int(10, 60)
            for _ in 0 ..< operations {
                let choice: Int = rng.int(0, 9)
                if choice < 3 {
                    let next: Pose = Self.nudge(current, &rng)
                    history.record("Move", before: current, after: next)
                    current = next
                } else if choice < 6 {
                    let key: String = "handle-\(rng.int(0, 2))"
                    let events: Int = rng.int(1, 8)
                    for _ in 0 ..< events {
                        let next: Pose = Self.nudge(current, &rng)
                        history.record("Drag", before: current, after: next, coalescing: key)
                        current = next
                    }
                    if rng.int(0, 1) == 0 { history.endCoalescing() }
                } else if choice < 8 {
                    if let value: Pose = history.undo() { current = value }
                } else {
                    if let value: Pose = history.redo() { current = value }
                }
                #expect(history.undoCount + history.redoCount <= history.depth)
            }
            let end: Pose = current
            // The newest recorded value: `end` itself, or what the redo left by the sequence reaches.
            var tip: ControlHistory<Pose> = history
            var newest: Pose = end
            while let value: Pose = tip.redo() { newest = value }
            if history.redoCount == 0 { #expect(newest == end) }
            let pendingRedo: Int = history.redoCount
            var undos: Int = 0
            while let value: Pose = history.undo() {
                current = value
                undos += 1
            }
            #expect(current == start, "sequence \(sequence): undo all")
            #expect(!history.canUndo)
            #expect(history.redoCount == undos + pendingRedo)
            while let value: Pose = history.redo() { current = value }
            #expect(current == newest, "sequence \(sequence): redo all")
            #expect(history.redoCount == 0)
        }
    }

    @Test func redoAllReturnsExactEndWithoutTrailingRedo() throws {
        var rng: SplitMix64 = SplitMix64(seed: 2_022)
        for sequence in 0 ..< 50 {
            var history: ControlHistory<Double> = try ControlHistory<Double>()
            let start: Double = rng.double(-10, 10)
            var current: Double = start
            let edits: Int = rng.int(1, 40)
            for _ in 0 ..< edits {
                let next: Double = current + rng.double(0.5, 2)
                let keyed: Bool = rng.int(0, 1) == 0
                history.record("Edit", before: current, after: next, coalescing: keyed ? "k" : nil)
                current = next
                if rng.int(0, 3) == 0 { history.endCoalescing() }
            }
            let end: Double = current
            while let value: Double = history.undo() { current = value }
            #expect(current == start, "sequence \(sequence)")
            while let value: Double = history.redo() { current = value }
            #expect(current == end, "sequence \(sequence)")
            #expect(history.undoCount > 0)
        }
    }

    @Test func fiveHundredEventDragIsOneStep() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        var current: Double = 0
        for index in 1 ... 500 {
            let next: Double = Double(index) * 0.01
            history.record("Drag handle", before: current, after: next, coalescing: "h1")
            current = next
        }
        #expect(history.undoCount == 1)
        #expect(history.undo() == 0)
        #expect(history.redo() == 5)
        #expect(history.undoCount == 1)
    }

    @Test func newRecordAfterUndoClearsRedo() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        history.record("A", before: 0, after: 1)
        history.record("B", before: 1, after: 2)
        #expect(history.undo() == 1)
        #expect(history.canRedo)
        history.record("C", before: 1, after: 5)
        #expect(!history.canRedo)
        #expect(history.redo() == nil)
        #expect(history.undoCount == 2)
        #expect(history.undo() == 1)
        #expect(history.undo() == 0)
    }

    @Test func endCoalescingSplitsTwoDragsWithTheSameKey() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        history.record("Drag", before: 0, after: 1, coalescing: "h")
        history.record("Drag", before: 1, after: 2, coalescing: "h")
        history.endCoalescing()
        history.record("Drag", before: 2, after: 3, coalescing: "h")
        history.record("Drag", before: 3, after: 4, coalescing: "h")
        #expect(history.undoCount == 2)
        #expect(history.undo() == 2)
        #expect(history.undo() == 0)
        // Without endCoalescing the same key merges; a different key or no key does not.
        var merged: ControlHistory<Double> = try ControlHistory<Double>()
        merged.record("Drag", before: 0, after: 1, coalescing: "h")
        merged.record("Drag", before: 1, after: 2, coalescing: "h")
        merged.record("Drag", before: 2, after: 3, coalescing: "g")
        merged.record("Set", before: 3, after: 4, coalescing: nil)
        merged.record("Set", before: 4, after: 5, coalescing: nil)
        #expect(merged.undoCount == 4)
        // An undo also closes the entry: a following record with the old key starts a new one.
        var reopened: ControlHistory<Double> = try ControlHistory<Double>()
        reopened.record("Drag", before: 0, after: 1, coalescing: "h")
        reopened.record("Other", before: 1, after: 2)
        _ = reopened.undo()
        reopened.record("Drag", before: 1, after: 3, coalescing: "h")
        #expect(reopened.undoCount == 2)
        #expect(reopened.undo() == 1)
    }

    @Test func mergeBackToOriginalRemovesTheEntry() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        history.record("Set", before: -1, after: 0)
        history.record("Drag", before: 0, after: 1, coalescing: "h")
        history.record("Drag", before: 1, after: 2, coalescing: "h")
        history.record("Drag", before: 2, after: 0, coalescing: "h")
        #expect(history.undoCount == 1)
        #expect(history.undoLabel == "Set")
        // The drag continuing after the removal starts a new entry from the original.
        history.record("Drag", before: 0, after: 4, coalescing: "h")
        history.record("Drag", before: 4, after: 5, coalescing: "h")
        #expect(history.undoCount == 2)
        #expect(history.undo() == 0)
        #expect(history.undo() == -1)
        // A record with before == after is ignored.
        var ignored: ControlHistory<Double> = try ControlHistory<Double>()
        ignored.record("Nothing", before: 3, after: 3)
        ignored.record("Nothing", before: 3, after: 3, coalescing: "h")
        #expect(ignored == (try ControlHistory<Double>()))
    }

    @Test func depthThreeKeepsThreeAndCountsDropped() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>(depth: 3)
        var current: Double = 0
        for index in 1 ... 7 {
            let next: Double = Double(index)
            history.record("Edit \(index)", before: current, after: next)
            current = next
            #expect(history.undoCount <= 3)
        }
        #expect(history.undoCount == 3)
        #expect(history.dropped == 4)
        #expect(history.undo() == 6)
        #expect(history.undo() == 5)
        #expect(history.undo() == 4)
        #expect(history.undo() == nil)
        #expect(history.redoCount == 3)
        // Undone entries count toward the bound; a new record clears them first.
        history.record("New", before: 4, after: 9)
        #expect(history.undoCount == 1)
        #expect(history.redoCount == 0)
        #expect(history.dropped == 4)
    }

    @Test func emptyUndoAndRedoGiveNilAndLeaveHistoryUnchanged() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        let empty: ControlHistory<Double> = history
        #expect(history.undo() == nil)
        #expect(history.redo() == nil)
        #expect(history == empty)
        history.record("A", before: 0, after: 1)
        let one: ControlHistory<Double> = history
        #expect(history.redo() == nil)
        #expect(history == one)
        _ = history.undo()
        let undone: ControlHistory<Double> = history
        #expect(history.undo() == nil)
        #expect(history == undone)
        #expect(!history.canUndo)
        #expect(history.canRedo)
    }

    @Test func labelsNameTheNextUndoAndRedo() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        #expect(history.undoLabel == nil)
        #expect(history.redoLabel == nil)
        history.record("Move light", before: 0, after: 1, coalescing: "light")
        history.record("Renamed", before: 1, after: 2, coalescing: "light")
        #expect(history.undoLabel == "Move light")
        history.endCoalescing()
        history.record("Rotate camera", before: 2, after: 3)
        #expect(history.undoLabel == "Rotate camera")
        _ = history.undo()
        #expect(history.undoLabel == "Move light")
        #expect(history.redoLabel == "Rotate camera")
        _ = history.undo()
        #expect(history.undoLabel == nil)
        #expect(history.redoLabel == "Move light")
    }

    @Test func roundTripIsByteForByte() throws {
        var rng: SplitMix64 = SplitMix64(seed: 2_022)
        var history: ControlHistory<Pose> = try ControlHistory<Pose>(depth: 5)
        var current: Pose = Pose(x: 0.1, y: -0.2, z: 0.3)
        for index in 0 ..< 9 {
            let next: Pose = Self.nudge(current, &rng)
            history.record("Edit \(index)", before: current, after: next, coalescing: index % 3 == 0 ? "h" : nil)
            current = next
        }
        _ = history.undo()
        _ = history.undo()
        #expect(history.redoCount == 2)
        #expect(history.dropped > 0)
        let data: Data = try history.encoded()
        let decoded: ControlHistory<Pose> = try ControlHistory<Pose>.decode(data)
        #expect(decoded == history)
        #expect(try decoded.encoded() == data)
        // The open flag survives: a keyed record after decoding merges as it would have before.
        var open: ControlHistory<Double> = try ControlHistory<Double>()
        open.record("Drag", before: 0, after: 1, coalescing: "h")
        var reopened: ControlHistory<Double> = try ControlHistory<Double>.decode(try open.encoded())
        reopened.record("Drag", before: 1, after: 2, coalescing: "h")
        #expect(reopened.undoCount == 1)
        // JSONEncoder and JSONDecoder use the same stored form.
        let viaCodable: ControlHistory<Pose> = try JSONDecoder().decode(ControlHistory<Pose>.self, from: data)
        #expect(viaCodable == history)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"depth\":5,\"dropped\":"))
        #expect(text.contains("\"schema\":1"))
    }

    @Test func nonFiniteValueIsRefusedOnEncode() throws {
        var history: ControlHistory<Double> = try ControlHistory<Double>()
        history.record("Bad", before: 0, after: Double.infinity)
        var refused: SpatialControlError? = nil
        do {
            _ = try history.encoded()
        } catch {
            refused = error
        }
        #expect(refused?.reasonCode == "r2-f22.malformed")
    }

    @Test func newerSchemaIsRefused() throws {
        let json: String = "{\"schema\":2,\"depth\":10,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false,\"x\":1}"
        #expect(Self.refusal(json) == .newerSchema(2))
        #expect(Self.refusal("{\"schema\":7}") == .newerSchema(7))
        #expect(Self.refusal(json)?.reasonCode == "r2-f22.newer-schema")
    }

    @Test func damagedFormsAreRefused() throws {
        let entry: String = "{\"after\":1,\"before\":0,\"label\":\"A\"}"
        let cases: [String] = [
            "not json",
            "{}",
            "{\"schema\":1,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[{\"before\":0,\"label\":\"A\"}],\"undone\":0,\"open\":false}",
            "{\"schema\":0,\"depth\":10,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":0,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":1001,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":1,\"dropped\":0,\"entries\":[\(entry),\(entry)],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":-1,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[\(entry)],\"undone\":2,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[\(entry)],\"undone\":-1,\"open\":false}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":true}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[\(entry)],\"undone\":1,\"open\":true}",
            "{\"schema\":1,\"depth\":10,\"dropped\":0,\"entries\":[{\"after\":1,\"before\":1,\"label\":\"A\"}],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":\"ten\",\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
        ]
        for json in cases {
            let error: SpatialControlError? = Self.refusal(json)
            #expect(error?.reasonCode == "r2-f22.malformed", "\(json)")
        }
        let valid: String = "{\"schema\":1,\"depth\":10,\"dropped\":3,\"entries\":[\(entry)],\"undone\":1,\"open\":false}"
        #expect(Self.refusal(valid) == nil)
    }

    @Test func jsonDecoderPathThrowsDecodingError() throws {
        let bad: [String] = [
            "{\"schema\":1,\"depth\":0,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":2,\"depth\":10,\"dropped\":0,\"entries\":[],\"undone\":0,\"open\":false}",
            "{\"schema\":1,\"depth\":10}",
        ]
        let reasons: [String?] = ["r2-f22.malformed", "r2-f22.newer-schema", nil]
        for index in 0 ..< bad.count {
            var caught: DecodingError? = nil
            do {
                _ = try JSONDecoder().decode(ControlHistory<Double>.self, from: Data(bad[index].utf8))
            } catch let error as DecodingError {
                caught = error
            }
            #expect(caught != nil, "\(bad[index])")
            if let reason: String = reasons[index], case .dataCorrupted(let context)? = caught {
                #expect(context.debugDescription == reason)
            } else if reasons[index] != nil {
                Issue.record("expected dataCorrupted for \(bad[index])")
            }
        }
    }

    @Test func initRefusesDepthsOutsideTheRange() throws {
        let refused: [Int] = [0, -1, 1_001, Int.max, Int.min]
        for depth in refused {
            #expect(throws: SpatialControlError.historyDepth) { try ControlHistory<Double>(depth: depth) }
        }
        #expect(SpatialControlError.historyDepth.reasonCode == "r2-f22.history-depth")
        let accepted: [Int] = [1, 100, 1_000]
        for depth in accepted {
            let history: ControlHistory<Double> = try ControlHistory<Double>(depth: depth)
            #expect(history.depth == depth)
            #expect(history.dropped == 0)
        }
        #expect(try ControlHistory<Double>().depth == 100)
        #expect(ControlHistory<Double>.schema == 1)
        #expect(ControlHistory<Double>.maxDepth == 1_000)
    }
}
