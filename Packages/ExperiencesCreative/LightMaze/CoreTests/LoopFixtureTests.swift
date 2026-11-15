// LoopFixtureTests — feature 097 (A13-P02) T-A13-202 (FR-A13-220; clarification Q5; research D3; SC-A13-205).
// Three committed boards whose beams could repeat, each proving the trace ends within its budgets: a mirror-only board
// whose path comes back to the emitter (ends "emitter"), a prism board whose branches meet again (the two straight-on
// branches of the second passes start in traced states and end "loop"), and a long winding mirror path (the "mirror
// spiral" of research D3, 43 mirrors on a 12 × 12 board) that reaches the bounce cap (ends "bounce-cap"). For every
// branch the bounce count stays at or below 64 and the whole trace at or below 256 segments; each board traces
// identically twice. The boards use `mapBoard` (BeamTracerTests): north row first, `.` empty, `T` target, `>` emitter
// east, `/` and `\` mirrors, `P` a slash prism.
import Foundation
import LightMazeCore
import Testing
import VisualCoreMath

@Suite struct LoopFixtureTests {
    /// A mirror-only board: east from (1, 1), north at (5, 1), west at (5, 3), north at (3, 3), west at (3, 5), south at
    /// (1, 5) and down column 1 into the emitter's top edge.
    static let returnToEmitter: [String] = [".......",
                                            #"./.\..."#,
                                            ".......",
                                            #"...\.\."#,
                                            ".......",
                                            ".>.../.",
                                            "......T"]

    /// A prism board: the prism at (2, 1) sends branch 0 north round the mirrors (clockwise) and branch 1 straight on
    /// round them the other way; each comes back through the prism, branch 0 leaving the board to the south and branch 1
    /// ending at the emitter, and the straight-on branches of those passes start in states already traced.
    static let prismBranchesMeet: [String] = ["......T",
                                              #"../..\."#,
                                              ".......",
                                              ".......",
                                              ">.P../.",
                                              "......."]

    /// A mirror-only board whose single path winds through its mirrors, meeting many of them on both sides, until the
    /// 65th mirror hit finds 64 bounces made.
    static let mirrorSpiral: [String] = [#"//\........T"#,
                                         #"\/\....\...."#,
                                         #".../\/.\...\"#,
                                         #"//\/\..\.../"#,
                                         #"..\\\/......"#,
                                         #"............"#,
                                         #"\\.\/..\.\.."#,
                                         #".\.//.././\."#,
                                         #"............"#,
                                         #"...\\..\.//."#,
                                         #"............"#,
                                         #">.../..\./.."#]

    /// Checks the budgets of one trace: every branch at most 64 bounces, the trace at most 256 segments, one end reason
    /// per branch and every segment on a branch that has an end reason.
    func expectWithinBudgets(_ beam: Beam, _ name: String) {
        #expect(beam.segments.count <= BeamTracer.maxSegments, "\(name) segments")
        #expect(beam.endReasons.count == beam.branchCount, "\(name) one end per branch")
        var bounces: [Int] = Array(repeating: 0, count: beam.branchCount)
        for segment in beam.segments {
            #expect(segment.branch >= 0 && segment.branch < beam.branchCount, "\(name) branch index")
            guard segment.branch >= 0 && segment.branch < beam.branchCount else { continue }
            if segment.bounce > bounces[segment.branch] { bounces[segment.branch] = segment.bounce }
        }
        for branch in 0..<bounces.count {
            #expect(bounces[branch] <= BeamTracer.maxBounces, "\(name) branch \(branch) bounces")
        }
    }

    @Test func theBudgetsAreSixtyFourBouncesAndTwoHundredFiftySixSegments() {
        #expect(BeamTracer.maxBounces == 64)
        #expect(BeamTracer.maxSegments == 256)
    }

    @Test func aMirrorPathBackToTheEmitterEndsThere() {
        let board: Board = mapBoard(Self.returnToEmitter)
        #expect(board.problem == nil)
        let beam: Beam = BeamTracer.trace(board)
        #expect(beam.endReasons == [.emitter])
        #expect(beam.segments.count == 6)
        #expect(beam.segments.last?.end == Vec2(1.5, 2))
        #expect(beam.droppedBranches == 0 && !beam.isSolved)
        expectWithinBudgets(beam, "return")
        #expect(BeamTracer.trace(board) == beam)
    }

    @Test func prismBranchesThatMeetEndWithLoop() {
        let board: Board = mapBoard(Self.prismBranchesMeet)
        #expect(board.problem == nil)
        let beam: Beam = BeamTracer.trace(board)
        let expected: [BeamEnd] = [.leftBoard, .emitter, .loop, .loop]
        #expect(beam.endReasons == expected)
        #expect(beam.segments.count == 11)
        #expect(beam.droppedBranches == 0 && !beam.isSolved)
        var loopBranchSegments: Int = 0
        for segment in beam.segments where segment.branch >= 2 { loopBranchSegments += 1 }
        #expect(loopBranchSegments == 0, "a loop branch ends before it casts")
        expectWithinBudgets(beam, "prism")
        #expect(BeamTracer.trace(board) == beam)
    }

    @Test func aMirrorSpiralReachesTheBounceCap() {
        let board: Board = mapBoard(Self.mirrorSpiral)
        #expect(board.problem == nil)
        var prisms: Int = 0
        for tile in board.tiles where tile.kind == .prism { prisms += 1 }
        #expect(prisms == 0, "mirror-only")
        let beam: Beam = BeamTracer.trace(board)
        #expect(beam.endReasons == [.bounceCap])
        #expect(beam.segments.count == BeamTracer.maxBounces + 1)
        #expect(beam.segments.last?.bounce == BeamTracer.maxBounces)
        expectWithinBudgets(beam, "spiral")
        #expect(BeamTracer.trace(board) == beam)
    }
}
