// HarmonicBridgesResonanceTests — feature 411 (R02-G12-01) T-R02G1201-003 (FR-R02G1201-002, 003, 005, 014;
// SC-R02G1201-003; clarifications Q2, Q4). The exact resonance rules against independent references written here: the
// swing table equals 4 sin²(nπk/6) derived from the exact quarter values of sin² at multiples of 30° (0, 1/4, 3/4, 1,
// period six), checked once more against floating-point sine; on 500 seeded levels (the fixtures of seed 2_411, each at
// its starting pegs, its winning pegs and a random peg assignment drawn with seed 2_411) every resonance equals
// enumerating n in 1 … 5 with n · peg == F · length (else none), every swing equals an independent sum of w · q, every
// bridge equals the threshold rule, every reachable set equals repeated relaxation to a fixed point (no queue) from
// the start, and the broken step and string equal an independent recomputation. Hand cases: mode 1 alone
// [1, 3, 4, 3, 1], modes 2 and 3 together [7, 3, 4, 3, 7], a mode above 5 and a non-multiple not resonant, the
// threshold exactly met and one quarter short. Explicit types, plain loops, short runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import HarmonicBridgesCore

struct HarmonicBridgesResonanceTests {
    /// The test seed.
    static let seed: UInt64 = 2_411
    /// The number of seeded levels.
    static let caseCount: Int = 500

    // MARK: - Independent reference

    /// 4 sin²(m · 30°) in quarters, for m = 0 … 5 (sin² has period 180°, six multiples of 30°): sin² of 0°, 30°, 60°,
    /// 90°, 120°, 150° is 0, 1/4, 3/4, 1, 3/4, 1/4.
    static let quartersByMultiple: [Int] = [0, 1, 3, 4, 3, 1]

    /// q(n, k) = 4 sin²(nπk/6) in quarters; nπk/6 is n · k multiples of 30°.
    static func referenceQuarter(_ mode: Int, _ sample: Int) -> Int {
        quartersByMultiple[(mode * sample) % 6]
    }

    /// The mode in 1 … 5 with n · peg == F · length, or nil, by enumeration.
    static func referenceMode(frequency: Int, length: Int, peg: Int) -> Int? {
        var found: Int? = nil
        for n in 1...5 where n * peg == frequency * length {
            found = n
        }
        return found
    }

    /// One string's reference resonance in one step: the modes, the swing and the bridge.
    struct Expected {
        let modes: [Int?]
        let swing: [Int]
        let bridge: Bool
    }

    static func referenceResonance(length: Int, peg: Int, tones: [HarmonicBridgesTone], threshold: Int) -> Expected {
        var modes: [Int?] = []
        var swing: [Int] = [0, 0, 0, 0, 0]
        for tone in tones {
            let mode: Int? = referenceMode(frequency: tone.frequency, length: length, peg: peg)
            modes.append(mode)
            if let mode {
                for k in 1...5 {
                    swing[k - 1] = swing[k - 1] + tone.strength * referenceQuarter(mode, k)
                }
            }
        }
        var bridge: Bool = true
        for k in 0..<5 {
            if swing[k] < threshold { bridge = false }
        }
        return Expected(modes: modes, swing: swing, bridge: bridge)
    }

    /// The islands the start reaches over the bridges, by repeated relaxation over every string until nothing changes.
    static func referenceReached(strings: [HarmonicBridgesString], bridges: [Bool], islandCount: Int,
                                 start: Int) -> [Bool] {
        var reached: [Bool] = Array(repeating: false, count: islandCount)
        reached[start] = true
        var changed: Bool = true
        while changed {
            changed = false
            for index in 0..<strings.count {
                if !bridges[index] { continue }
                let a: Int = strings[index].a
                let b: Int = strings[index].b
                if reached[a] && !reached[b] {
                    reached[b] = true
                    changed = true
                }
                if reached[b] && !reached[a] {
                    reached[a] = true
                    changed = true
                }
            }
        }
        return reached
    }

    /// One seeded case: a level and a peg assignment.
    struct Case {
        let level: HarmonicBridgesLevel
        let pegs: [Int]
    }

    /// The seeded cases: each of the 500 fixtures at its starting pegs, its winning pegs and random pegs, and the hand
    /// level at its starting pegs and at its winning pegs.
    static func cases() -> [Case] {
        var random = SeededRandom(seed: seed)
        var result: [Case] = []
        let fixtures: [HarmonicBridgesFixture] = HarmonicBridgesFixtures.fixtures(caseCount, from: seed)
        for fixture in fixtures {
            result.append(Case(level: fixture.level, pegs: fixture.level.startingPegs))
            result.append(Case(level: fixture.level, pegs: fixture.winningPegs))
            var pegs: [Int] = []
            for _ in 0..<fixture.level.strings.count { pegs.append(random.int(1...12)) }
            result.append(Case(level: fixture.level, pegs: pegs))
        }
        let hand: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        result.append(Case(level: hand, pegs: hand.startingPegs))
        result.append(Case(level: hand, pegs: [2, 4, 3, 1]))
        return result
    }

    // MARK: - Tests

    /// The swing table equals 4 sin²(nπk/6) from exact quarter values, agrees with floating-point sine, and is 0
    /// outside n, k in 1 … 5.
    @Test func swingTableEqualsExactQuarters() {
        for n in 1...5 {
            for k in 1...5 {
                let expected: Int = Self.referenceQuarter(n, k)
                #expect(HarmonicBridgesSwing.quarter(mode: n, sample: k) == expected)
                let angle: Double = Double(n * k) * Double.pi / 6.0
                let sine: Double = sin(angle)
                let floating: Double = 4.0 * sine * sine
                #expect(abs(floating - Double(expected)) < 1e-9)
                #expect([0, 1, 3, 4].contains(expected))
            }
        }
        let outside: [(Int, Int)] = [(0, 1), (6, 1), (1, 0), (1, 6), (-1, 3), (3, 7)]
        for (n, k) in outside {
            #expect(HarmonicBridgesSwing.quarter(mode: n, sample: k) == 0)
        }
        #expect(HarmonicBridgesSwing.samples == 5)
        #expect(HarmonicBridgesSwing.maxMode == 5)
    }

    /// The mode of every (F, L, p) in range equals the enumeration of n in 1 … 5.
    @Test func modeEqualsEnumerationOverEveryValue() {
        var resonant: Int = 0
        for length in 1...6 {
            for peg in 1...12 {
                let string = HarmonicBridgesString(a: 0, b: 1, length: length, peg: peg)
                for frequency in 1...72 {
                    let tone = HarmonicBridgesTone(frequency: frequency, strength: 1)
                    let expected: Int? = Self.referenceMode(frequency: frequency, length: length, peg: peg)
                    #expect(string.mode(of: tone, peg: peg) == expected)
                    if expected != nil { resonant += 1 }
                }
            }
        }
        #expect(resonant > 0)
    }

    /// On the seeded levels every resonance, swing, bridge, reachable set and break equals the reference.
    @Test func seededLevelsEqualTheReference() {
        let all: [Case] = Self.cases()
        #expect(all.count == 3 * Self.caseCount + 2)
        var bridgesSeen: Int = 0
        var nonBridgesSeen: Int = 0
        var breaksSeen: Int = 0
        var winsSeen: Int = 0
        for item in all {
            let level: HarmonicBridgesLevel = item.level
            let report: HarmonicBridgesReport = level.report(pegs: item.pegs)
            #expect(report.swings.count == level.steps.count)
            #expect(report.bridges.count == level.steps.count)
            #expect(report.reached.count == level.steps.count)
            var expectedReached: [[Bool]] = []
            var expectedBridges: [[Bool]] = []
            for step in 0..<level.steps.count {
                var stepBridges: [Bool] = []
                for index in 0..<level.strings.count {
                    let string: HarmonicBridgesString = level.strings[index]
                    let expected: Expected = Self.referenceResonance(length: string.length, peg: item.pegs[index],
                                                                     tones: level.steps[step],
                                                                     threshold: level.threshold)
                    let resonance: HarmonicBridgesResonance = level.resonance(index, step: step,
                                                                              peg: item.pegs[index])
                    #expect(resonance.modes == expected.modes)
                    #expect(resonance.swing == expected.swing)
                    #expect(resonance.bridge == expected.bridge)
                    #expect(resonance.string == index)
                    #expect(resonance.step == step)
                    #expect(resonance.peg == item.pegs[index])
                    #expect(report.swings[step][index] == expected.swing)
                    #expect(report.bridges[step][index] == expected.bridge)
                    stepBridges.append(expected.bridge)
                    if expected.bridge { bridgesSeen += 1 } else { nonBridgesSeen += 1 }
                }
                expectedBridges.append(stepBridges)
                let reached: [Bool] = Self.referenceReached(strings: level.strings, bridges: stepBridges,
                                                            islandCount: level.islands.count, start: level.start)
                #expect(report.reached[step] == reached)
                expectedReached.append(reached)
            }
            // The break: the first step whose goal is missed; the lowest-index non-bridge string across the cut.
            var expectedBreak: HarmonicBridgesBreak? = nil
            var step: Int = 0
            while step < level.steps.count && expectedBreak == nil {
                if !expectedReached[step][level.goal] {
                    var broken: Int? = nil
                    var index: Int = level.strings.count - 1
                    while index >= 0 {
                        let string: HarmonicBridgesString = level.strings[index]
                        let crosses: Bool = expectedReached[step][string.a] != expectedReached[step][string.b]
                        if crosses && !expectedBridges[step][index] { broken = index }
                        index -= 1
                    }
                    expectedBreak = HarmonicBridgesBreak(step: step, string: broken)
                }
                step += 1
            }
            #expect(level.firstBreak(report) == expectedBreak)
            #expect(report.goalReachedInEveryStep == (expectedBreak == nil))
            var expectedCounts: [Int] = []
            for stepBridges in expectedBridges {
                var count: Int = 0
                for bridge in stepBridges {
                    if bridge { count += 1 }
                }
                expectedCounts.append(count)
            }
            #expect(report.bridgeCounts == expectedCounts)
            if expectedBreak == nil { winsSeen += 1 } else { breaksSeen += 1 }
        }
        #expect(bridgesSeen > 0)
        #expect(nonBridgesSeen > 0)
        #expect(winsSeen >= Self.caseCount)
        #expect(breaksSeen >= Self.caseCount)
    }

    /// Mode 1 alone gives [1, 3, 4, 3, 1]; strength scales it.
    @Test func modeOneAlone() {
        let string = HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 2)
        let tones: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 2, strength: 1)]
        let resonance = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: tones, peg: 2, threshold: 1)
        #expect(resonance.modes == [1])
        #expect(resonance.resonatingModes == [1])
        #expect(resonance.swing == [1, 3, 4, 3, 1])
        #expect(resonance.bridge)
        let strong: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 2, strength: 2)]
        let doubled = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: strong, peg: 2, threshold: 1)
        #expect(doubled.swing == [2, 6, 8, 6, 2])
    }

    /// Modes 2 and 3 together add to [7, 3, 4, 3, 7] (n = F · L / p), whatever the tone order.
    @Test func modesTwoAndThreeTogether() {
        let string = HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)
        let tones: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 2, strength: 1),
                                            HarmonicBridgesTone(frequency: 3, strength: 1)]
        let resonance = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: tones, peg: 1, threshold: 1)
        #expect(resonance.modes == [2, 3])
        #expect(resonance.resonatingModes == [2, 3])
        #expect(resonance.swing == [7, 3, 4, 3, 7])
        // The same pair on a longer string: length 2, peg 4 gives F · 2 / 4, so F = 4 is mode 2 and F = 6 is mode 3.
        let longer = HarmonicBridgesString(a: 0, b: 1, length: 2, peg: 4)
        let longerTones: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 6, strength: 1),
                                                  HarmonicBridgesTone(frequency: 4, strength: 1)]
        let other = HarmonicBridgesResonance(string: longer, index: 0, step: 0, tones: longerTones, peg: 4,
                                             threshold: 1)
        #expect(other.modes == [3, 2])
        #expect(other.resonatingModes == [2, 3])
        #expect(other.swing == [7, 3, 4, 3, 7])
    }

    /// A mode above 5 and a frequency that is not a multiple do not resonate; the swing is 0 and no bridge forms.
    @Test func modeAboveFiveIsNotResonant() {
        let string = HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)
        let tones: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 6, strength: 3),
                                            HarmonicBridgesTone(frequency: 72, strength: 3)]
        let resonance = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: tones, peg: 1, threshold: 1)
        #expect(resonance.modes == [nil, nil])
        #expect(resonance.resonatingModes.isEmpty)
        #expect(resonance.swing == [0, 0, 0, 0, 0])
        #expect(!resonance.bridge)
        // Mode 5 is the highest allowed: F = 5 on length 1, peg 1 resonates.
        let five: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 5, strength: 1)]
        let top = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: five, peg: 1, threshold: 1)
        #expect(top.modes == [5])
        #expect(top.swing == [1, 3, 4, 3, 1])
        // F · L not a multiple of p: length 2, peg 3, F = 1 gives 2 / 3.
        let odd = HarmonicBridgesString(a: 0, b: 1, length: 2, peg: 3)
        let one: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 1, strength: 1)]
        let none = HarmonicBridgesResonance(string: odd, index: 0, step: 0, tones: one, peg: 3, threshold: 1)
        #expect(none.modes == [nil])
        #expect(!none.bridge)
    }

    /// The threshold exactly met forms a bridge; one quarter short does not.
    @Test func thresholdExactlyMetAndOneQuarterShort() {
        let string = HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)
        let tones: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 2, strength: 1),
                                            HarmonicBridgesTone(frequency: 3, strength: 1)]
        // Swing [7, 3, 4, 3, 7]: the smallest sample is 3.
        let met = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: tones, peg: 1, threshold: 3)
        #expect(met.bridge)
        let short = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: tones, peg: 1, threshold: 4)
        #expect(!short.bridge)
        // Mode 1 at strength 2, swing [2, 6, 8, 6, 2]: threshold 2 met, 3 one quarter short.
        let strong: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 1, strength: 2)]
        let edgeMet = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: strong, peg: 1, threshold: 2)
        #expect(edgeMet.bridge)
        let edgeShort = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: strong, peg: 1,
                                                 threshold: 3)
        #expect(!edgeShort.bridge)
        // A zero sample never forms a bridge: mode 3 alone has [4, 0, 4, 0, 4].
        let three: [HarmonicBridgesTone] = [HarmonicBridgesTone(frequency: 3, strength: 3)]
        let gap = HarmonicBridgesResonance(string: string, index: 0, step: 0, tones: three, peg: 1, threshold: 1)
        #expect(gap.swing == [12, 0, 12, 0, 12])
        #expect(!gap.bridge)
    }

    /// On the hand level the reference gives the documented break (step 1, string 0) and the winning tuning holds.
    @Test func handLevelAgainstTheReference() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let report: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
        #expect(report.reached[0] == [true, true, false, true])
        #expect(report.reached[1] == [true, false, true, false])
        #expect(report.swings[1][2] == [5, 3, 8, 3, 5])
        #expect(level.firstBreak(report) == HarmonicBridgesBreak(step: 1, string: 0))
        let won: HarmonicBridgesReport = level.report(pegs: [2, 4, 3, 1])
        #expect(won.goalReachedInEveryStep)
        #expect(level.firstBreak(won) == nil)
    }
}
