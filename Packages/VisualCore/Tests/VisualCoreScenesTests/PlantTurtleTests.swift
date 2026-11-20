// PlantTurtleTests — feature 219 (R02-F19) T-R02F19-003 (FR-R02F19-001, 002; SC-R02F19-001, 005; clarifications Q1, Q2).
// Hand-derived words and branch counts, known turtle positions and frames, seeded repeatability, the stored form growing
// the identical skeleton, and the bracket, word and branch limits.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreScenes
import VisualCoreMath

fileprivate func near(_ a: Vec3, _ b: Vec3, _ tolerance: Double = 1e-12) -> Bool {
    abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
}

fileprivate func orthonormal(_ h: Vec3, _ l: Vec3, _ u: Vec3) -> Bool {
    let unit: Bool = abs(h.length - 1) <= 1e-12 && abs(l.length - 1) <= 1e-12 && abs(u.length - 1) <= 1e-12
    let orthogonal: Bool = abs(h.dot(l)) <= 1e-12 && abs(h.dot(u)) <= 1e-12 && abs(l.dot(u)) <= 1e-12
    return unit && orthogonal && near(h.cross(l), u)
}

fileprivate func weighted(seed: UInt64, generations: Int = 5) throws -> PlantGrammar {
    let x: PlantRule = try PlantRule("X", weighted: [("F[+X]FX", 1), ("F[-X]X", 2), ("F[&X][^X]L", 1.5)])
    let f: PlantRule = try PlantRule("F", weighted: [("F", 3), ("F!F", 1)])
    return try PlantGrammar(start: "X", rules: [x, f], generations: generations, angle: 0.43, step: 0.25,
                            radius: 0.04, radiusFactor: 0.85, seed: seed)
}

@Suite struct PlantTurtleTests {
    @Test func algae() throws {
        let a: PlantRule = try PlantRule("A", "AB")
        let b: PlantRule = try PlantRule("B", "A")
        let grammar: PlantGrammar = try PlantGrammar(start: "A", rules: [a, b], generations: 5, angle: 0.5, step: 1)
        let word: String = try LSystem.derive(grammar)
        #expect(word == "ABAABABAABAAB")
        let skeleton: PlantSkeleton = try PlantTurtle.grow(grammar)
        #expect(skeleton.branches.isEmpty)
        #expect(skeleton.markers.isEmpty)
    }

    @Test func kochLike() throws {
        let f: PlantRule = try PlantRule("F", "F+F-F-F+F")
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [f], generations: 2, angle: Double.pi / 2, step: 1)
        let word: String = try LSystem.derive(grammar)
        #expect(word == "F+F-F-F+F+F+F-F-F+F-F+F-F-F+F-F+F-F-F+F+F+F-F-F+F")
        let skeleton: PlantSkeleton = try PlantTurtle.interpret(word, grammar: grammar)
        #expect(skeleton.branches.count == 25)
        // The quadratic Koch curve of order 2 spans 9 steps along the start heading.
        let last: PlantBranch = skeleton.branches[24]
        #expect(near(last.end, Vec3(0, 9, 0), 1e-9))
    }

    @Test func bracketedPlant() throws {
        let x: PlantRule = try PlantRule("X", "F[+X][-X]FX")
        let f: PlantRule = try PlantRule("F", "FF")
        let grammar: PlantGrammar = try PlantGrammar(start: "X", rules: [x, f], generations: 2, angle: 0.4, step: 1)
        let word: String = try LSystem.derive(grammar)
        #expect(word == "FF[+F[+X][-X]FX][-F[+X][-X]FX]FFF[+X][-X]FX")
        let skeleton: PlantSkeleton = try PlantTurtle.interpret(word, grammar: grammar)
        #expect(skeleton.branches.count == 10)
        var depths: [Int] = []
        for branch in skeleton.branches { depths.append(branch.depth) }
        #expect(depths == [0, 0, 1, 1, 1, 1, 0, 0, 0, 0])
    }

    @Test func turnLeft() throws {
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [], generations: 0, angle: Double.pi / 2, step: 1)
        let skeleton: PlantSkeleton = try PlantTurtle.interpret("F+F", grammar: grammar)
        #expect(skeleton.branches.count == 2)
        #expect(near(skeleton.branches[0].start, Vec3(0, 0, 0)))
        #expect(near(skeleton.branches[0].end, Vec3(0, 1, 0)))
        #expect(near(skeleton.branches[1].start, Vec3(0, 1, 0)))
        #expect(near(skeleton.branches[1].end, Vec3(-1, 1, 0)))
        let right: PlantSkeleton = try PlantTurtle.interpret("F-F\u{2212}F", grammar: grammar)
        #expect(near(right.branches[1].end, Vec3(1, 1, 0)))
        #expect(near(right.branches[2].end, Vec3(1, 0, 0)))
    }

    @Test func pitchRollAndTurnAround() throws {
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [], generations: 0, angle: Double.pi / 2, step: 1)
        let pitch: PlantSkeleton = try PlantTurtle.interpret("F[&F]F", grammar: grammar)
        #expect(pitch.branches.count == 3)
        #expect(near(pitch.branches[1].start, Vec3(0, 1, 0)))
        #expect(near(pitch.branches[1].end, Vec3(0, 1, -1)))
        #expect(pitch.branches[1].depth == 1)
        #expect(near(pitch.branches[2].end, Vec3(0, 2, 0)))
        #expect(pitch.branches[2].depth == 0)
        let up: PlantSkeleton = try PlantTurtle.interpret("^F", grammar: grammar)
        #expect(near(up.branches[0].end, Vec3(0, 0, 1)))
        // Roll left moves L to U = +z; then a left turn heads towards +z.
        let roll: PlantSkeleton = try PlantTurtle.interpret("\\+F", grammar: grammar)
        #expect(near(roll.branches[0].end, Vec3(0, 0, 1)))
        let rollRight: PlantSkeleton = try PlantTurtle.interpret("/+F", grammar: grammar)
        #expect(near(rollRight.branches[0].end, Vec3(0, 0, -1)))
        let around: PlantSkeleton = try PlantTurtle.interpret("|F", grammar: grammar)
        #expect(near(around.branches[0].end, Vec3(0, -1, 0)))
        let move: PlantSkeleton = try PlantTurtle.interpret("fF", grammar: grammar)
        #expect(move.branches.count == 1)
        #expect(near(move.branches[0].start, Vec3(0, 1, 0)))
    }

    @Test func radiusFactor() throws {
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [], generations: 0, angle: 0.3, step: 1,
                                                     radius: 0.05, radiusFactor: 0.8)
        let skeleton: PlantSkeleton = try PlantTurtle.interpret("F![!F]F", grammar: grammar)
        #expect(skeleton.branches[0].radius == 0.05)
        #expect(skeleton.branches[1].radius == 0.05 * 0.8 * 0.8)
        #expect(skeleton.branches[2].radius == 0.05 * 0.8)
    }

    @Test func markers() throws {
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [], generations: 0, angle: Double.pi / 2, step: 0.5)
        let skeleton: PlantSkeleton = try PlantTurtle.interpret("F[+P]C&L", grammar: grammar)
        #expect(skeleton.markers.count == 3)
        let petal: PlantMarker = skeleton.markers[0]
        #expect(petal.kind == .petal)
        #expect(near(petal.position, Vec3(0, 0.5, 0)))
        #expect(near(petal.heading, Vec3(-1, 0, 0)))
        #expect(near(petal.left, Vec3(0, -1, 0)))
        #expect(near(petal.up, Vec3(0, 0, 1)))
        #expect(petal.size == 0.5)
        let cap: PlantMarker = skeleton.markers[1]
        #expect(cap.kind == .cap)
        #expect(cap.position == Vec3(0, 0.5, 0))
        #expect(cap.heading == Vec3(0, 1, 0))
        #expect(cap.left == Vec3(-1, 0, 0))
        #expect(cap.up == Vec3(0, 0, 1))
        let leaf: PlantMarker = skeleton.markers[2]
        #expect(leaf.kind == .leaf)
        #expect(near(leaf.position, Vec3(0, 0.5, 0)))
        #expect(near(leaf.heading, Vec3(0, 0, -1)))
        #expect(near(leaf.left, Vec3(-1, 0, 0)))
        #expect(near(leaf.up, Vec3(0, 1, 0)))
        #expect(PlantPart.allCases.count == 3)
    }

    @Test func framesStayOrthonormal() throws {
        let x: PlantRule = try PlantRule("X", weighted: [("F[+&X\\L]F/[-^XP]", 1), ("F|[&\\XC]+X", 1), ("F[^^X]&L", 0.5)])
        let grammar: PlantGrammar = try PlantGrammar(start: "X", rules: [x], generations: 8, angle: 0.37, step: 0.3,
                                                     seed: 77)
        let skeleton: PlantSkeleton = try PlantTurtle.grow(grammar)
        #expect(skeleton.markers.count > 100)
        var bad: Int = 0
        for marker in skeleton.markers where !orthonormal(marker.heading, marker.left, marker.up) { bad += 1 }
        #expect(bad == 0)
        // A long unbracketed run of turns of every kind ends with an orthonormal frame.
        var run: String = ""
        for _ in 0..<5_000 { run += "+&\\-^/|" }
        run += "L"
        let long: PlantSkeleton = try PlantTurtle.interpret(run, grammar: grammar)
        let end: PlantMarker = long.markers[0]
        #expect(orthonormal(end.heading, end.left, end.up))
    }

    @Test func seededRepeatabilityAndVariety() throws {
        var differing: Int = 0
        for k in 0..<100 {
            let seed: UInt64 = 2_019 + UInt64(k)
            let first: PlantSkeleton = try PlantTurtle.grow(try weighted(seed: seed))
            let second: PlantSkeleton = try PlantTurtle.grow(try weighted(seed: seed))
            #expect(first == second)
            #expect(try LSystem.derive(try weighted(seed: seed)) == LSystem.derive(try weighted(seed: seed)))
            let other: PlantSkeleton = try PlantTurtle.grow(try weighted(seed: seed + 10_000))
            if other != first { differing += 1 }
        }
        #expect(differing >= 95)
    }

    @Test func storedFormGrowsTheSamePlant() throws {
        let grammar: PlantGrammar = try weighted(seed: 4_242, generations: 6)
        let reopened: PlantGrammar = try PlantGrammar.decode(grammar.encoded())
        #expect(reopened == grammar)
        #expect(reopened.encoded() == grammar.encoded())
        let original: PlantSkeleton = try PlantTurtle.grow(grammar)
        #expect(!original.branches.isEmpty)
        #expect(try PlantTurtle.grow(reopened) == original)
    }

    @Test func zeroGenerationsAndUnknownSymbols() throws {
        let a: PlantRule = try PlantRule("A", "AxB")
        let zero: PlantGrammar = try PlantGrammar(start: "zA[F]", rules: [a], generations: 0, angle: 0.5, step: 1)
        #expect(try LSystem.derive(zero) == "zA[F]")
        let two: PlantGrammar = try PlantGrammar(start: "zA", rules: [a], generations: 2, angle: 0.5, step: 1)
        #expect(try LSystem.derive(two) == "zAxBxB")
        let skeleton: PlantSkeleton = try PlantTurtle.grow(two)
        #expect(skeleton.branches.isEmpty)
    }

    @Test func unbalancedBracketsRefused() throws {
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [], generations: 0, angle: 0.5, step: 1)
        #expect(throws: PlantError.brackets) { try PlantTurtle.interpret("F]", grammar: grammar) }
        #expect(throws: PlantError.brackets) { try PlantTurtle.interpret("[F", grammar: grammar) }
        #expect(throws: PlantError.brackets) { try PlantTurtle.interpret("][", grammar: grammar) }
        let open: PlantGrammar = try PlantGrammar(start: "[F", rules: [], generations: 0, angle: 0.5, step: 1)
        #expect(throws: PlantError.brackets) { try PlantTurtle.grow(open) }
        #expect(PlantError.brackets.reasonCode == "r2-f19.brackets")
    }

    @Test func wordLimitRefused() throws {
        let f: PlantRule = try PlantRule("F", "FFFF")
        let atLimit: PlantGrammar = try PlantGrammar(start: "F", rules: [f], generations: 10, angle: 0.5, step: 1)
        let clock: ContinuousClock = ContinuousClock()
        let started: ContinuousClock.Instant = clock.now
        let word: String = try LSystem.derive(atLimit)
        let elapsed: Duration = clock.now - started
        print("PlantTurtleTests: derive of \(word.utf8.count) symbols took \(elapsed)")
        #expect(word.utf8.count == PlantGrammar.maxWord)
        let over: PlantGrammar = try PlantGrammar(start: "F", rules: [f], generations: 11, angle: 0.5, step: 1)
        #expect(throws: PlantError.wordLimit(4_194_304)) { try LSystem.derive(over) }
        #expect(PlantError.wordLimit(0).reasonCode == "r2-f19.word-limit")
    }

    @Test func branchLimitRefused() throws {
        let f: PlantRule = try PlantRule("F", "FFFF")
        let grammar: PlantGrammar = try PlantGrammar(start: "F", rules: [f], generations: 9, angle: 0.5, step: 1)
        let clock: ContinuousClock = ContinuousClock()
        let started: ContinuousClock.Instant = clock.now
        #expect(throws: PlantError.branchLimit(262_144)) { try PlantTurtle.grow(grammar) }
        print("PlantTurtleTests: branch-limit refusal took \(clock.now - started)")
        let atLimit: String = String(repeating: "F", count: PlantGrammar.maxBranches)
        let skeleton: PlantSkeleton = try PlantTurtle.interpret(atLimit, grammar: grammar)
        #expect(skeleton.branches.count == PlantGrammar.maxBranches)
        #expect(PlantError.branchLimit(0).reasonCode == "r2-f19.branch-limit")
    }
}
