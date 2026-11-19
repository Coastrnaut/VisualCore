// CodedStateTests — feature 210 (R02-F10) T-R02F10-004 (FR-R02F10-007, FR-R02F10-008, FR-R02F10-011; SC-R02F10-005).
// Fixtures for coded-state sets (empty, one, the full 32, one too many, a shared clue, a repeated name and id, a blank
// and an over-long name, a NaN and an out-of-range colour, a bad id), their reason codes, a Codable round trip, and the
// clue reference: every shape is inside at its centre and outside at the cell corner, patterns put ink and gaps where
// stated, and coverage stays in 0…1.
import Foundation
import Testing
@testable import VisualCoreParameters

@Suite struct CodedStateTests {
    static func state(_ i: Int, shape: ClueShape = .circle, pattern: CluePattern = .solid, name: String? = nil,
                      color: SIMD3<Double> = SIMD3(0.5, 0.5, 0.5)) -> CodedState {
        CodedState(id: "state-\(i)", color: color, shape: shape, pattern: pattern, name: name ?? "State \(i)")
    }

    /// All 32 (shape, pattern) pairs, one state each.
    static func full() -> [CodedState] {
        var out: [CodedState] = []
        for shape in ClueShape.allCases {
            for pattern in CluePattern.allCases {
                out.append(state(out.count, shape: shape, pattern: pattern))
            }
        }
        return out
    }

    @Test func emptyOneAndFullSetsAreAccepted() throws {
        #expect(try CodedStateSet([]).states.isEmpty)
        #expect(try CodedStateSet([Self.state(0)]).states.count == 1)
        let all = try CodedStateSet(Self.full())
        #expect(all.states.count == 32)
        #expect(CodedStateSet.maxStates == 32)
    }

    @Test func oneTooManyIsRefused() {
        var states = Self.full()
        states.append(Self.state(32, shape: .circle, pattern: .solid))
        #expect(throws: ColorAccessError.tooManyStates(count: 33, limit: 32)) { _ = try CodedStateSet(states) }
        #expect(ColorAccessError.tooManyStates(count: 33, limit: 32).reasonCode == "r2-f10.too-many-states")
    }

    @Test func aSharedClueIsRefusedNamingBoth() {
        let states = [Self.state(0, shape: .star, pattern: .dots), Self.state(1, shape: .ring),
                      Self.state(2, shape: .star, pattern: .dots)]
        #expect(throws: ColorAccessError.sameClue("state-0", "state-2")) { _ = try CodedStateSet(states) }
        #expect(ColorAccessError.sameClue("a", "b").reasonCode == "r2-f10.same-clue")
    }

    @Test func repeatedNamesAndIDsAreRefused() {
        let names = [Self.state(0, name: "Lit"), Self.state(1, shape: .square, name: "  Lit ")]
        #expect(throws: ColorAccessError.duplicateName("Lit")) { _ = try CodedStateSet(names) }
        var twin = Self.state(1, shape: .square)
        twin.id = "state-0"
        #expect(throws: ColorAccessError.duplicateID("state-0")) { _ = try CodedStateSet([Self.state(0), twin]) }
        var bad = Self.state(0)
        bad.id = "Bad ID"
        #expect(throws: ColorAccessError.duplicateID("Bad ID")) { _ = try CodedStateSet([bad]) }
        #expect(ColorAccessError.duplicateName("x").reasonCode == "r2-f10.duplicate-name")
        #expect(ColorAccessError.duplicateID("x").reasonCode == "r2-f10.duplicate-id")
    }

    @Test func blankAndOverLongNamesAreRefused() throws {
        let blank = [Self.state(0), Self.state(1, shape: .square, name: " \n\t ")]
        #expect(throws: ColorAccessError.emptyName(index: 1)) { _ = try CodedStateSet(blank) }
        let long = [Self.state(0, name: String(repeating: "a", count: 41))]
        #expect(throws: ColorAccessError.emptyName(index: 0)) { _ = try CodedStateSet(long) }
        #expect(try CodedStateSet([Self.state(0, name: String(repeating: "a", count: 40))]).states.count == 1)
        #expect(ColorAccessError.emptyName(index: 0).reasonCode == "r2-f10.empty-name")
    }

    @Test func badColoursAreRefused() {
        let nan = [Self.state(0), Self.state(1, shape: .square, color: SIMD3(0.2, .nan, 0.2))]
        #expect(throws: ColorAccessError.nonFinite(index: 1)) { _ = try CodedStateSet(nan) }
        let high = [Self.state(0, color: SIMD3(1.01, 0, 0))]
        #expect(throws: ColorAccessError.outOfRange(index: 0)) { _ = try CodedStateSet(high) }
    }

    @Test func codableRoundTrip() throws {
        let original = Self.state(3, shape: .hexagon, pattern: .crosshatch, color: SIMD3(0.1, 0.6, 0.9))
        let decoded = try JSONDecoder().decode(CodedState.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func separationIssuesAreAdviceOnly() throws {
        let twins = [Self.state(0, color: SIMD3(0.5, 0.5, 0.5)), Self.state(1, shape: .square, color: SIMD3(0.5, 0.5, 0.5))]
        let set = try CodedStateSet(twins)
        #expect(!set.separationIssues.isEmpty, "identical colours are reported, but the set is accepted")
    }

    @Test func shapesAreInsideAtTheCentreAndOutsideAtTheCorner() {
        for shape in ClueShape.allCases {
            let centre = shape == .ring ? SIMD2(0.6, 0.0) : SIMD2(0.0, 0.0)
            #expect(ClueReference.distance(shape: shape, at: centre) < 0, "\(shape) inside")
            #expect(ClueReference.distance(shape: shape, at: SIMD2(0.99, 0.99)) > 0, "\(shape) outside")
        }
        #expect(ClueReference.distance(shape: .ring, at: SIMD2(0, 0)) > 0, "the ring is hollow")
        #expect(abs(ClueReference.distance(shape: .circle, at: SIMD2(0.8, 0))) < 1e-12)
        #expect(abs(ClueReference.distance(shape: .square, at: SIMD2(0.7, 0.3))) < 1e-12)
    }

    @Test func patternsPutInkWhereStated() {
        #expect(ClueReference.pattern(.solid, at: SIMD2(0.37, -0.2)) < 0)
        #expect(ClueReference.pattern(.dots, at: SIMD2(0.5 / 3, 0.5 / 3)) < 0, "a dot at the cell centre")
        #expect(ClueReference.pattern(.dots, at: SIMD2(0, 0)) > 0, "a gap at the cell corner")
        let onStripe = 0.5 / 3 * 2.0.squareRoot() / 2
        #expect(ClueReference.pattern(.stripes, at: SIMD2(onStripe, onStripe)) < 0)
        #expect(ClueReference.pattern(.stripes, at: SIMD2(0, 0)) > 0)
        #expect(ClueReference.pattern(.crosshatch, at: SIMD2(onStripe, onStripe)) < 0)
        for shape in ClueShape.allCases {
            for pattern in CluePattern.allCases {
                for i in 0..<41 {
                    let p = SIMD2(-1 + Double(i) * 0.05, 0.3 - Double(i) * 0.02)
                    let c = ClueReference.coverage(shape: shape, pattern: pattern, at: p, antialias: 0.03)
                    #expect((0...1).contains(c))
                }
            }
        }
        #expect(ClueReference.outline(shape: .circle, at: SIMD2(0.8, 0), width: 0.1, antialias: 0.01) == 1)
        #expect(ClueReference.outline(shape: .circle, at: SIMD2(0, 0), width: 0.1, antialias: 0.01) == 0)
    }
}
