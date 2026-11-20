// EventLogTests — feature 214 R02-F14 T-R02F14-002 (FR-R02F14-001, FR-R02F14-007; clarifications Q2, Q5).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Test func eventLogOrdersByStepThenInsertion() throws {
    var log = EventLog<Int>()
    let inserts = [(5, 50), (1, 10), (5, 51), (0, 0), (1, 11), (5, 52), (3, 30)]
    for (step, value) in inserts { try log.insert(value, at: step) }
    #expect(log.count == 7)
    #expect(log.entries.map(\.step) == [0, 1, 1, 3, 5, 5, 5])
    #expect(log.entries.map(\.command) == [0, 10, 11, 30, 50, 51, 52])
    #expect(log.commands(at: 5) == [50, 51, 52])
    #expect(log.commands(at: 2) == [])
    #expect(log.steps == [0, 1, 3, 5])
}

@Test func eventLogRemoveAndReplaceByStepAndIndex() throws {
    var log = EventLog<Int>()
    for value in 0..<4 { try log.insert(value, at: 7) }
    #expect(try log.remove(at: 7, index: 1) == 1)
    #expect(log.commands(at: 7) == [0, 2, 3])
    try log.replace(at: 7, index: 2, with: 99)
    #expect(log.commands(at: 7) == [0, 2, 99])
    for (step, index) in [(7, 3), (7, -1), (6, 0), (8, 0)] {
        #expect(throws: TimelineError.noSuchCommand(step: step, index: index)) { try log.remove(at: step, index: index) }
        #expect(throws: TimelineError.noSuchCommand(step: step, index: index)) { try log.replace(at: step, index: index, with: 1) }
    }
    #expect(log.commands(at: 7) == [0, 2, 99])
}

@Test func eventLogRefusesStepsOutsideTheRange() throws {
    var log = EventLog<Int>()
    #expect(throws: TimelineError.negativeStep) { try log.insert(1, at: -1) }
    #expect(throws: TimelineError.stepLimit(10_000_001)) { try log.insert(1, at: 10_000_001) }
    try log.insert(1, at: 0)
    try log.insert(2, at: EventLog<Int>.maxStep)
    #expect(log.count == 2)
    #expect(EventLog<Int>.maxEntries == 1_048_576)
    #expect(TimelineError.negativeStep.reasonCode == "r2-f14.negative-step")
    #expect(TimelineError.stepLimit(1).reasonCode == "r2-f14.step-limit")
    #expect(TimelineError.logLimit.reasonCode == "r2-f14.log-limit")
    #expect(TimelineError.noSuchCommand(step: 0, index: 0).reasonCode == "r2-f14.no-such-command")
    #expect(TimelineError.ringSize(0).reasonCode == "r2-f14.ring-size")
    #expect(TimelineError.interval(0).reasonCode == "r2-f14.interval")
    #expect(TimelineError.hashMismatch.reasonCode == "r2-f14.hash-mismatch")
    #expect(TimelineError.newerSchema(2).reasonCode == "r2-f14.newer-schema")
    #expect(TimelineError.malformed("x").reasonCode == "r2-f14.malformed")
}

@Test func eventLogRefusesTheCommandAfterTheLimit() throws {
    var log = EventLog<UInt8>()
    for _ in 0..<EventLog<UInt8>.maxEntries { try log.insert(0, at: 3) }
    #expect(throws: TimelineError.logLimit) { try log.insert(0, at: 3) }
    #expect(log.count == 1_048_576)
}

@Test func eventLogCodableRoundTripKeepsOrderAndRefusesBadSteps() throws {
    var log = EventLog<Int>()
    for (step, value) in [(2, 20), (0, 1), (2, 21), (9, 90)] { try log.insert(value, at: step) }
    let data = try JSONEncoder().encode(log)
    #expect(String(decoding: data, as: UTF8.self).hasPrefix("[{"))
    #expect(try JSONDecoder().decode(EventLog<Int>.self, from: data) == log)
    for bad in [#"[{"step":-1,"command":1}]"#, #"[{"step":10000001,"command":1}]"#] {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(EventLog<Int>.self, from: Data(bad.utf8)) }
    }
}
