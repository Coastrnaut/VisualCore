// MagneticFieldTests — feature 220 (R02-F20) T-R02F20-002 (FR-R02F20-003, 006; SC-R02F20-003; clarification Q4).
// Refusals and reason codes; pole forces within their bound over 1,000 seeded positions, including on the pole; an
// attracting pole pulls inward and a repelling one pushes out; the uniform turn keeps length within 1e-12; coding
// re-validates. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Suite struct MagneticFieldTests {
    @Test func refusalsAndCodes() throws {
        #expect(throws: SwarmError.field("position")) { try MagneticPole(position: Vec2(.nan, 0), strength: 1) }
        #expect(throws: SwarmError.field("strength")) { try MagneticPole(position: .zero, strength: 1_000.5) }
        #expect(throws: SwarmError.field("strength")) { try MagneticPole(position: .zero, strength: .infinity) }
        #expect(throws: SwarmError.field("softening")) { try MagneticPole(position: .zero, strength: 1, softening: 1e-7) }
        #expect(throws: SwarmError.field("softening")) { try MagneticPole(position: .zero, strength: 1, softening: .nan) }
        #expect(throws: SwarmError.field("uniform")) { try MagneticField(uniform: 100.01) }
        #expect(throws: SwarmError.field("uniform")) { try MagneticField(uniform: -.infinity) }
        let pole = try MagneticPole(position: .zero, strength: 1)
        let many: [MagneticPole] = Array(repeating: pole, count: 65)
        #expect(throws: SwarmError.field("poles")) { try MagneticField(poles: many) }
        _ = try MagneticField(uniform: -100, poles: Array(repeating: pole, count: 64))
        _ = try MagneticPole(position: .zero, strength: -1_000, softening: 1e-6)
        let codes: [(SwarmError, String)] = [
            (.agentLimit(1), "r2-f20.agent-limit"), (.bounds, "r2-f20.bounds"), (.step, "r2-f20.step"),
            (.parameter("x"), "r2-f20.parameter"), (.field("x"), "r2-f20.field"),
            (.rasterSize, "r2-f20.raster-size"), (.newerSchema(2), "r2-f20.newer-schema"),
            (.malformed("x"), "r2-f20.malformed"),
        ]
        for (error, code) in codes { #expect(error.reasonCode == code) }
        #expect(MagneticField.none.uniform == 0 && MagneticField.none.poles.isEmpty)
    }

    @Test func poleForcesStayWithinTheirBound() throws {
        var random = SeededRandom(seed: 2_020)
        var poles: [MagneticPole] = []
        for _ in 0..<4 {
            let p = Vec2(random.double() * 10 - 5, random.double() * 10 - 5)
            let s: Double = (random.double() * 2 - 1) * 1_000
            let e: Double = 1e-3 + random.double()
            poles.append(try MagneticPole(position: p, strength: s, softening: e))
        }
        let field = try MagneticField(poles: poles)
        var worst: Double = 0
        for k in 0..<1_000 {
            let q: Double = (random.double() * 2 - 1) * 100
            let position: Vec2
            if k < 4 {
                position = poles[k].position   // on a pole
            } else if k < 200 {
                let pole = poles[k % 4]
                let r: Double = pole.softening * random.double() * 3
                let a: Double = random.double() * 2 * Double.pi
                position = pole.position + Vec2(r * cos(a), r * sin(a))
            } else {
                position = Vec2(random.double() * 20 - 10, random.double() * 20 - 10)
            }
            let f = field.poleForce(at: position, charge: q)
            #expect(f.isFinite)
            let bound = field.poleForceBound(charge: q)
            #expect(f.length <= bound * (1 + 1e-12))
            for pole in poles {
                let single = pole.force(at: position, charge: q).length
                #expect(single <= pole.forceBound(charge: q) * (1 + 1e-12))
                if pole.forceBound(charge: q) > 0 { worst = max(worst, single / pole.forceBound(charge: q)) }
            }
        }
        print("MagneticFieldTests SC-R02F20-003: largest single-pole force / bound \(worst)")
        // The peak at |r| = ε / √2 is reached exactly.
        let pole = try MagneticPole(position: .zero, strength: 3, softening: 0.5)
        let peak = pole.force(at: Vec2(0.5 / 2.0.squareRoot(), 0), charge: 2).length
        #expect(abs(peak - pole.forceBound(charge: 2)) <= 1e-12 * peak)
        #expect(pole.force(at: .zero, charge: 2) == .zero)
        #expect(pole.force(at: Vec2(.nan, 0), charge: 2) == .zero)
        #expect(field.poleForce(at: .zero, charge: .infinity) == .zero)
        #expect(MagneticField.none.poleForce(at: .zero, charge: 1) == .zero)
    }

    @Test func attractingAndRepellingPoles() throws {
        let attract = try MagneticField(poles: [MagneticPole(position: Vec2(1, 1), strength: 5)])
        let repel = try MagneticField(poles: [MagneticPole(position: Vec2(1, 1), strength: -5)])
        let at = Vec2(4, 5)
        let inward = Vec2(1, 1) - at
        #expect(attract.poleForce(at: at, charge: 2).dot(inward) > 0)
        #expect(repel.poleForce(at: at, charge: 2).dot(inward) < 0)
        // A negative charge swaps the roles.
        #expect(attract.poleForce(at: at, charge: -2).dot(inward) < 0)
    }

    @Test func uniformTurnKeepsLength() throws {
        var random = SeededRandom(seed: 2_020)
        let field = try MagneticField(uniform: 37.5)
        for _ in 0..<1_000 {
            let v = Vec2(random.double() * 10 - 5, random.double() * 10 - 5)
            let q: Double = (random.double() * 2 - 1) * 100
            let h: Double = random.double() * 0.1
            let w = field.turned(v, charge: q, step: h)
            #expect(abs(w.length - v.length) <= 1e-12 * max(1, v.length))
        }
        // Quarter turn: angle −q B h = −π/2 turns +x to −y.
        let quarter = try MagneticField(uniform: 1)
        let w = quarter.turned(Vec2(1, 0), charge: Double.pi / 2, step: 1)
        #expect(abs(w.x) < 1e-15 && abs(w.y + 1) < 1e-15)
        #expect(MagneticField.none.turned(Vec2(3, 4), charge: 5, step: 0.1) == Vec2(3, 4))
    }

    @Test func codingRevalidates() throws {
        let field = try MagneticField(uniform: 2, poles: [MagneticPole(position: Vec2(1, 2), strength: -3, softening: 0.25)])
        let data = try JSONEncoder().encode(field)
        #expect(try JSONDecoder().decode(MagneticField.self, from: data) == field)
        let bad = Data(#"{"uniform":2,"poles":[{"position":[1,2],"strength":5000,"softening":0.25}]}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(MagneticField.self, from: bad) }
        let badUniform = Data(#"{"uniform":500,"poles":[]}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(MagneticField.self, from: badUniform) }
    }
}
