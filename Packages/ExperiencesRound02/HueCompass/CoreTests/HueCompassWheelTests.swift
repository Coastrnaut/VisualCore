// HueCompassWheelTests — feature 331 (R02-G04-01) T-R02G0401-003 (FR-R02G0401-002, 003, 011; SC-R02G0401-003;
// clarifications Q1, Q2). Host checks of the pure rule kernel: the integer sector rule agrees with an independent
// floating atan2 reference on every direction of the 33 × 33 lattice more than 10⁻⁶ rad from every boundary angle and on
// seeded large directions; every direction is in exactly one sector (boundary vectors and their clockwise neighbours);
// bands, bearing and band distances and arcs; clues equal a brute-force walk for every bearing of 500 seeded fixtures;
// the hue gap never reads fog and the depth never reads the offset. Fixtures seed 2_331. Explicit types, plain loops,
// short runs, no wall-clock asserts.
import Foundation
import Testing
@testable import HueCompassCore

@Suite struct HueCompassWheelTests {
    /// The reference bearing of (x, y): atan2 mapped to 0 ..< 2π, floor(angle · 96 / 2π), and the angle's distance to
    /// the nearest boundary angle 2πk/96.
    static func reference(x: Int, y: Int) -> (bearing: Int, margin: Double) {
        let twoPi: Double = 2 * Double.pi
        var angle: Double = atan2(Double(y), Double(x))
        if angle < 0 { angle += twoPi }
        if angle >= twoPi { angle -= twoPi }
        let step: Double = twoPi / 96
        let bearing: Int = min(95, Int((angle / step).rounded(.down)))
        var margin: Double = Double.infinity
        for k in 0...96 { margin = min(margin, abs(angle - Double(k) * step)) }
        return (bearing, margin)
    }

    /// The sectors containing (x, y) by the two cross-product conditions, counted independently of `bearing(x:y:)`.
    static func sectors(x: Int, y: Int) -> [Int] {
        var found: [Int] = []
        for k in 0..<96 {
            let a: (x: Int, y: Int) = HueCompassWheel.boundaries[k]
            let b: (x: Int, y: Int) = HueCompassWheel.boundaries[(k + 1) % 96]
            if a.x * y - a.y * x >= 0 && b.x * y - b.y * x < 0 { found.append(k) }
        }
        return found
    }

    @Test func theSectorRuleAgreesWithAtan2OnThe33By33Lattice() {
        #expect(HueCompassWheel.bearing(x: 0, y: 0) == nil)
        var compared: Int = 0
        for x in -16...16 {
            for y in -16...16 {
                if x == 0 && y == 0 { continue }
                let ref: (bearing: Int, margin: Double) = Self.reference(x: x, y: y)
                if ref.margin <= 1e-6 { continue }
                compared += 1
                #expect(HueCompassWheel.bearing(x: x, y: y) == ref.bearing, "direction (\(x), \(y))")
            }
        }
        // 1_088 non-zero directions; the 128 exactly on a boundary angle (0°, 15°-multiples and so on) are excluded.
        #expect(compared == 960)
    }

    @Test func theBoundaryTableIsTheRoundedAngles() {
        // The table is (cos, sin)(2πk/96) × 65 536 rounded once, so each stored angle is within 10⁻⁵ rad of 2πk/96.
        for k in 0..<96 {
            let angle: Double = 2 * Double.pi * Double(k) / 96
            let b: (x: Int, y: Int) = HueCompassWheel.boundaries[k]
            #expect(b.x == Int((cos(angle) * 65_536).rounded()) && b.y == Int((sin(angle) * 65_536).rounded()))
            var stored: Double = atan2(Double(b.y), Double(b.x))
            if stored < 0 { stored += 2 * Double.pi }
            var error: Double = abs(stored - angle)
            error = min(error, 2 * Double.pi - error)
            #expect(error < 1e-5, "boundary \(k)")
        }
    }

    @Test func theSectorRuleAgreesWithAtan2OnSeededLargeDirections() {
        // The boundaries are rounded to 1/65 536, which moves their angles by up to 8.62 × 10⁻⁶ rad
        // (theBoundaryTableIsTheRoundedAngles), so far from the lattice the margin is 10⁻⁵ rad.
        var random: HueCompassRandom = HueCompassRandom(seed: 2_331)
        var compared: Int = 0
        for _ in 0..<4_000 {
            let x: Int = random.int(-1_000_000...1_000_000)
            let y: Int = random.int(-1_000_000...1_000_000)
            if x == 0 && y == 0 { continue }
            let ref: (bearing: Int, margin: Double) = Self.reference(x: x, y: y)
            if ref.margin <= 1e-5 { continue }
            compared += 1
            #expect(HueCompassWheel.bearing(x: x, y: y) == ref.bearing, "direction (\(x), \(y))")
        }
        #expect(compared > 3_900)
        #expect(HueCompassWheel.bearing(x: 1_000_000, y: 0) == 0)
        #expect(HueCompassWheel.bearing(x: 0, y: 1_000_000) == 24)
        #expect(HueCompassWheel.bearing(x: -1_000_000, y: 0) == 48)
        #expect(HueCompassWheel.bearing(x: 0, y: -1_000_000) == 72)
        #expect(HueCompassWheel.bearing(x: 1_000_000, y: -1) == 95)
    }

    @Test func everyDirectionIsInExactlyOneSector() {
        for k in 0..<96 {
            let b: (x: Int, y: Int) = HueCompassWheel.boundaries[k]
            #expect(Self.sectors(x: b.x, y: b.y) == [k], "boundary \(k)")
            #expect(HueCompassWheel.bearing(x: b.x, y: b.y) == k)
            // Just clockwise of boundary k: 1 000 × boundary k minus the counter-clockwise perpendicular (−y, x).
            let cwX: Int = 1_000 * b.x + b.y
            let cwY: Int = 1_000 * b.y - b.x
            let previous: Int = (k + 95) % 96
            #expect(Self.sectors(x: cwX, y: cwY) == [previous], "clockwise of boundary \(k)")
            #expect(HueCompassWheel.bearing(x: cwX, y: cwY) == previous)
            // Just counter-clockwise of boundary k stays in sector k.
            let ccwX: Int = 1_000 * b.x - b.y
            let ccwY: Int = 1_000 * b.y + b.x
            #expect(Self.sectors(x: ccwX, y: ccwY) == [k], "counter-clockwise of boundary \(k)")
            #expect(HueCompassWheel.bearing(x: ccwX, y: ccwY) == k)
        }
        for x in -16...16 {
            for y in -16...16 {
                if x == 0 && y == 0 { continue }
                let found: [Int] = Self.sectors(x: x, y: y)
                #expect(found.count == 1 && HueCompassWheel.bearing(x: x, y: y) == found.first, "(\(x), \(y))")
            }
        }
    }

    @Test func bandsFollowTheFormula() {
        for offset in 0..<24 {
            for b in 0..<96 {
                let expected: Int = (b / 4 + offset) % 24
                #expect(HueCompassWheel.band(of: b, offset: offset) == expected)
                #expect(HueCompassWheel.band(of: b + 96, offset: offset) == expected)
                #expect(HueCompassWheel.band(of: b - 96, offset: offset) == expected)
            }
        }
        #expect(HueCompassWheel.band(of: -1, offset: 0) == 23)
        #expect(HueCompassWheel.band(of: 95, offset: 1) == 0)
    }

    @Test func bearingAndBandDistances() {
        for a in 0..<96 {
            for b in 0..<96 {
                let d: Int = HueCompassWheel.bearingDistance(a, b)
                #expect((0...48).contains(d))
                #expect(d == HueCompassWheel.bearingDistance(b, a))
                #expect((d == 0) == (a == b))
                let raw: Int = abs(a - b)
                #expect(d == min(raw, 96 - raw))
            }
        }
        for a in 0..<24 {
            for b in 0..<24 {
                let d: Int = HueCompassWheel.bandDistance(a, b)
                #expect((0...12).contains(d))
                #expect(d == HueCompassWheel.bandDistance(b, a))
                #expect((d == 0) == (a == b))
                let raw: Int = abs(a - b)
                #expect(d == min(raw, 24 - raw))
            }
        }
        #expect(HueCompassWheel.bearingDistance(0, 95) == 1 && HueCompassWheel.bearingDistance(0, 48) == 48)
        #expect(HueCompassWheel.bandDistance(0, 23) == 1 && HueCompassWheel.bandDistance(3, 15) == 12)
    }

    @Test func arcsAreTheShorterOpenArc() {
        for from in 0..<96 {
            for to in 0..<96 {
                let arc: [Int] = HueCompassWheel.arc(from: from, to: to)
                let d: Int = HueCompassWheel.bearingDistance(from, to)
                if d <= 1 {
                    #expect(arc.isEmpty, "arc \(from) → \(to)")
                    continue
                }
                #expect(arc.count == d - 1, "arc \(from) → \(to)")
                let ccw: Int = ((to - from) % 96 + 96) % 96
                let step: Int = ccw <= 48 ? 1 : -1
                var expected: Int = from
                for element in arc {
                    expected = ((expected + step) % 96 + 96) % 96
                    #expect(element == expected, "arc \(from) → \(to)")
                    #expect(element != from && element != to)
                    #expect(HueCompassWheel.bearingDistance(from, element) < d
                            && HueCompassWheel.bearingDistance(element, to) < d)
                }
            }
        }
        // A 48 tie runs counter-clockwise from `from`.
        #expect(HueCompassWheel.arc(from: 0, to: 48).first == 1)
        #expect(HueCompassWheel.arc(from: 48, to: 0).first == 49)
        #expect(HueCompassWheel.arc(from: 95, to: 47).first == 0)
        #expect(HueCompassWheel.arc(from: 2, to: 94) == [1, 0, 95])
    }

    /// The brute-force clue: walk one bearing at a time the shorter way (counter-clockwise on a tie) summing fog; the
    /// band gap from (⌊b/4⌋ + offset) mod 24.
    static func bruteForceClue(level: HueCompassLevel, bearing: Int) -> (hueGap: Int, depth: Int) {
        let ccw: Int = ((level.target - bearing) % 96 + 96) % 96
        let step: Int = ccw <= 48 ? 1 : -1
        var depth: Int = 0
        var position: Int = bearing
        while position != level.target {
            position = ((position + step) % 96 + 96) % 96
            if position != level.target { depth += level.fog[position] }
        }
        let probed: Int = (bearing / 4 + level.offset) % 24
        let target: Int = (level.target / 4 + level.offset) % 24
        let raw: Int = abs(probed - target)
        return (min(raw, 24 - raw), depth)
    }

    @Test func cluesEqualABruteForceWalkOn500Fixtures() {
        for index in 0..<500 {
            let level: HueCompassLevel = HueCompassFixtures.fixture(index).level
            for bearing in 0..<96 {
                let clue: HueCompassClue = level.clue(at: bearing)
                let brute: (hueGap: Int, depth: Int) = Self.bruteForceClue(level: level, bearing: bearing)
                #expect(clue.bearing == bearing, "fixture \(index) bearing \(bearing)")
                #expect(clue.hueGap == brute.hueGap, "fixture \(index) bearing \(bearing)")
                #expect(clue.depth == brute.depth, "fixture \(index) bearing \(bearing)")
                #expect((0...12).contains(clue.hueGap) && (0...423).contains(clue.depth))
            }
            #expect(level.clue(at: level.target + 96) == level.clue(at: level.target))
            #expect(level.clue(at: -1) == level.clue(at: 95))
        }
    }

    @Test func theHueGapNeverReadsFogAndTheDepthNeverReadsTheOffset() throws {
        var random: HueCompassRandom = HueCompassRandom(seed: 2_331)
        for index in 0..<40 {
            let base: HueCompassLevel = HueCompassFixtures.fixture(index).level
            var fog: [Int] = []
            for _ in 0..<96 { fog.append(random.int(0...9)) }
            let refogged: HueCompassLevel = try HueCompassLevel(
                id: base.id, seed: base.seed, band: base.band, offset: base.offset, fog: fog, target: base.target,
                start: base.start, bearingTolerance: base.bearingTolerance, bandTolerance: base.bandTolerance,
                allowance: base.allowance, tutorial: base.tutorial)
            for bearing in 0..<96 {
                #expect(refogged.clue(at: bearing).hueGap == base.clue(at: bearing).hueGap,
                        "fixture \(index) bearing \(bearing)")
            }
            for offset in 0..<24 {
                let shifted: HueCompassLevel = try HueCompassLevel(
                    id: base.id, seed: base.seed, band: base.band, offset: offset, fog: base.fog, target: base.target,
                    start: base.start, bearingTolerance: base.bearingTolerance, bandTolerance: base.bandTolerance,
                    allowance: base.allowance, tutorial: base.tutorial)
                for bearing in 0..<96 {
                    #expect(shifted.clue(at: bearing).depth == base.clue(at: bearing).depth,
                            "fixture \(index) offset \(offset) bearing \(bearing)")
                }
            }
        }
    }
}
