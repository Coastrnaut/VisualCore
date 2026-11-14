// SegmentWindowTests — feature 055 (A07-P02) T-A07-202 (FR-A07-201; gap G-SEGMENTSTREAM).
import Testing
@testable import VisualCoreScenes

@Test func segmentWindowRefusesInvalidConfigurations() {
    #expect(SegmentWindow(behind: -1, ahead: 4, capacity: 10) == nil)
    #expect(SegmentWindow(behind: 1, ahead: -4, capacity: 10) == nil)
    #expect(SegmentWindow(behind: 1, ahead: 4, capacity: -1) == nil)
    #expect(SegmentWindow(behind: 2, ahead: 6, capacity: 8) == nil, "capacity < behind + ahead + 1")
    #expect(SegmentWindow(behind: 2, ahead: 6, capacity: 9) != nil)
    #expect(SegmentWindow(behind: 0, ahead: 0, capacity: 1) != nil)
    #expect(SegmentWindow.maxBuildsPerStep == 2)
}

@Test func segmentWindowFirstStepBuildsNearestFirst() throws {
    var w = try #require(SegmentWindow(behind: 2, ahead: 4, capacity: 8))
    let s1 = w.advance(to: 5 * 10 + 3, pieceLength: 10)   // current 5
    #expect(s1.toRetire.isEmpty)
    #expect(s1.toBuild == [5, 6], "current first, then ahead before behind on a tie")
    let s2 = w.advance(to: 53, pieceLength: 10)
    #expect(s2.toBuild == [4, 7])
    let s3 = w.advance(to: 53, pieceLength: 10)
    #expect(s3.toBuild == [3, 8])
    #expect(!w.isComplete)
    let s4 = w.advance(to: 53, pieceLength: 10)
    #expect(s4.toBuild == [9])
    #expect(w.isComplete)
    #expect(w.live == [3, 4, 5, 6, 7, 8, 9])
    #expect(w.advance(to: 53, pieceLength: 10) == SegmentWindowStep(toBuild: [], toRetire: []))
}

@Test func segmentWindowClampsAtTheStart() throws {
    var w = try #require(SegmentWindow(behind: 3, ahead: 2, capacity: 6))
    for _ in 0..<3 { _ = w.advance(to: -25, pieceLength: 10) }
    #expect(w.live == [0, 1, 2])
    #expect(w.isComplete)
}

@Test func segmentWindowLongFlightStaysBounded() throws {
    let behind = 2, ahead = 8, capacity = 12
    var w = try #require(SegmentWindow(behind: behind, ahead: ahead, capacity: capacity))
    let pieceLength = 4.0
    let pieces = 200
    let dt = 0.37   // distance per step, < pieceLength
    var buildCount: [Int: Int] = [:]
    var stepsToComplete: Int?
    var step = 0
    var distance = 0.0
    while distance < Double(pieces) * pieceLength {
        let before = Set(w.live)
        let s = w.advance(to: distance, pieceLength: pieceLength)
        step += 1
        #expect(s.toBuild.count <= SegmentWindow.maxBuildsPerStep)
        #expect(w.live.count <= capacity)
        #expect(w.live == w.live.sorted())
        #expect(Set(s.toRetire).isSubset(of: before))
        #expect(Set(s.toBuild).isDisjoint(with: before))
        for i in s.toBuild { buildCount[i, default: 0] += 1 }
        if stepsToComplete == nil, w.isComplete { stepsToComplete = step }
        distance += dt
    }
    #expect((stepsToComplete ?? .max) <= 6, "window complete within a few steps")
    #expect(buildCount.values.allSatisfy { $0 == 1 }, "each index built once while in the window")
    #expect(buildCount.count <= pieces + ahead + 1)
    #expect(buildCount.count >= pieces)
}

@Test func segmentWindowJumpFarAheadRetiresAllAndBuildsOnlyWindow() throws {
    var w = try #require(SegmentWindow(behind: 1, ahead: 3, capacity: 5))
    for _ in 0..<4 { _ = w.advance(to: 0, pieceLength: 1) }
    #expect(w.live == [0, 1, 2, 3])
    let s = w.advance(to: 100.5, pieceLength: 1)   // current 100, desired 99...103
    #expect(Set(s.toRetire) == [0, 1, 2, 3])
    #expect(s.toBuild == [100, 101])
    var built = Set(s.toBuild)
    for _ in 0..<5 {
        let n = w.advance(to: 100.5, pieceLength: 1)
        #expect(n.toRetire.isEmpty)
        built.formUnion(n.toBuild)
    }
    #expect(built == Set(99...103))
    #expect(w.live == [99, 100, 101, 102, 103])
}

@Test func segmentWindowMovesBackwards() throws {
    var w = try #require(SegmentWindow(behind: 1, ahead: 2, capacity: 4))
    for _ in 0..<3 { _ = w.advance(to: 50, pieceLength: 1) }
    #expect(w.live == [49, 50, 51, 52])
    let s = w.advance(to: 48.2, pieceLength: 1)   // desired 47...50
    #expect(Set(s.toRetire) == [51, 52])
    #expect(s.toBuild == [48, 47], "current first, then the nearer missing index")
    #expect(w.isComplete)
    for _ in 0..<3 { _ = w.advance(to: 48.2, pieceLength: 1) }
    #expect(w.live == [47, 48, 49, 50])
}

@Test func segmentWindowIgnoresInvalidInput() throws {
    var w = try #require(SegmentWindow(behind: 1, ahead: 2, capacity: 4))
    _ = w.advance(to: 10, pieceLength: 1)
    let before = w
    let empty = SegmentWindowStep(toBuild: [], toRetire: [])
    #expect(w.advance(to: .nan, pieceLength: 1) == empty)
    #expect(w.advance(to: .infinity, pieceLength: 1) == empty)
    #expect(w.advance(to: 10, pieceLength: 0) == empty)
    #expect(w.advance(to: 10, pieceLength: -1) == empty)
    #expect(w.advance(to: 10, pieceLength: .nan) == empty)
    #expect(w == before)
}
