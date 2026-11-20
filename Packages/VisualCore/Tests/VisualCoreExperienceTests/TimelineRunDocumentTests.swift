// TimelineRunDocumentTests — feature 214 R02-F14 T-R02F14-004 (FR-R02F14-006; SC-R02F14-005; clarification Q5;
// research R5). Stored runs round-trip byte for byte, migrate from schema 0, and refuse newer, tampered, truncated
// and over-limit payloads.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VisualCoreExperience

/// A small deterministic value-type simulation (integer arithmetic only).
private struct Walker: Codable, Sendable, Equatable, FixedStepSimulation {
    var x: Int64 = 1
    var v: Int64 = 7
    mutating func step(_ dt: Double) {
        x = x &+ v
        v = (v &* 31 &+ 17) % 1_000_003
    }
    func checksum() -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for word in [UInt64(bitPattern: x), UInt64(bitPattern: v)] { h = (h ^ word) &* 0x0000_0100_0000_01b3 }
        return h
    }
}

/// A command nudging the walker's velocity.
private struct Nudge: Codable, Sendable, Equatable { var value: Int }

private typealias Document = TimelineRunDocument<Walker, Nudge>

@Suite struct TimelineRunDocumentTests {
    private static let apply: @Sendable (inout Walker, Nudge) -> Void = { state, nudge in state.v &+= Int64(nudge.value) }

    /// 300 steps with 20 commands at steps 0, 15, …, 285.
    private func run() throws -> ReversibleTimeline<Walker, Nudge> {
        var timeline = try ReversibleTimeline<Walker, Nudge>(start: Walker(), apply: Self.apply)
        for i in 0..<20 { try timeline.insert(Nudge(value: i + 1), at: i * 15) }
        try timeline.advance(steps: 300)
        return timeline
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    @Test func roundTripReopensSameRunAndBytes() throws {
        let original = try run()
        let bytes = try Document(timeline: original).encoded()
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.hasPrefix("{\"capacity\":32,\"dt\":"))
        #expect(text.contains("\"schema\":1"))
        #expect(text.contains("\"hash\":\"\(original.hash.hex)\""))
        let reopened = try Document.decode(bytes, apply: Self.apply)
        #expect(reopened.state.checksum() == original.state.checksum())
        #expect(reopened.step == 300)
        #expect(reopened.hash == original.hash)
        #expect(reopened.log == original.log)
        #expect(try Document(timeline: reopened).encoded() == bytes)
    }

    @Test func schemaZeroPayloadMigratesToSameHash() throws {
        let original = try run()
        var payload = try object(try Document(timeline: original).encoded())
        let entries = try #require(payload["log"] as? [[String: Any]])
        payload["log"] = try entries.map { entry -> [Any] in [try #require(entry["step"]), try #require(entry["command"])] }
        payload["schema"] = 0
        let reopened = try Document.decode(try data(payload), apply: Self.apply)
        #expect(reopened.hash == original.hash)
        #expect(reopened.step == 300)
        #expect(reopened.log == original.log)
    }

    @Test func newerSchemaRefused() throws {
        var payload = try object(try Document(timeline: try run()).encoded())
        payload["schema"] = 2
        let bytes = try data(payload)
        #expect(throws: TimelineError.newerSchema(2)) { try Document.decode(bytes, apply: Self.apply) }
    }

    @Test func tamperedCommandRefusedHashMismatch() throws {
        var payload = try object(try Document(timeline: try run()).encoded())
        var entries = try #require(payload["log"] as? [[String: Any]])
        entries[3]["command"] = ["value": 999]
        payload["log"] = entries
        let bytes = try data(payload)
        #expect(throws: TimelineError.hashMismatch) { try Document.decode(bytes, apply: Self.apply) }
    }

    @Test func truncatedJSONRefusedMalformed() throws {
        let bytes = try Document(timeline: try run()).encoded()
        let truncated = bytes.prefix(bytes.count / 2)
        do {
            _ = try Document.decode(Data(truncated), apply: Self.apply)
            Issue.record("truncated run was accepted")
        } catch {
            #expect(error.reasonCode == "r2-f14.malformed")
        }
    }

    @Test func missingSchemaRefusedMalformed() throws {
        var payload = try object(try Document(timeline: try run()).encoded())
        payload["schema"] = nil
        let bytes = try data(payload)
        do {
            _ = try Document.decode(bytes, apply: Self.apply)
            Issue.record("run without schema was accepted")
        } catch {
            #expect(error.reasonCode == "r2-f14.malformed")
        }
    }

    @Test func logOverLimitRefused() throws {
        let count = EventLog<Nudge>.maxEntries + 1
        var text = "{\"schema\":1,\"log\":["
        text.reserveCapacity(count * 2 + 32)
        text += String(repeating: "0,", count: count - 1)
        text += "0]}"
        #expect(throws: TimelineError.logLimit) { try Document.decode(Data(text.utf8), apply: Self.apply) }
    }

    @Test func commandBeyondStepLimitRefused() throws {
        var payload = try object(try Document(timeline: try run()).encoded())
        var entries = try #require(payload["log"] as? [[String: Any]])
        entries[0]["step"] = 10_000_001
        payload["log"] = entries
        let bytes = try data(payload)
        #expect(throws: TimelineError.stepLimit(10_000_001)) { try Document.decode(bytes, apply: Self.apply) }
    }
}
