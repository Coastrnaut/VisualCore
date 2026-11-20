// AuroraLoomHarmonyTests — feature 301 (R02-G01-01) T-R02G0101-003 (FR-R02G0101-002, 003; SC-R02G0101-001;
// clarifications Q1, Q2). On 1,000 seeded levels the constructed setting wins; on the first 150 (bounded for debug run
// time, see `sweepFixtures`) every single-control change from it gets the same win verdict (and on the first 20 the same
// worst mismatch) as an independent reference written here from the clarification's formula; the tolerance boundary
// is inclusive (exactly ±tolerance inside, one unit beyond outside); the signed wrap at ±2,048; the tie order of the
// worst mismatch; a drifting ribbon (ω ≠ Ω) judged over the two periods; phase, target and residual ranges.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite struct AuroraLoomHarmonyTests {
    // MARK: - Independent reference (clarification Q1, Q2); never calls AuroraLoomHarmony.

    /// The reference verdict: whether every |residual| ≤ tolerance, and the largest |residual| (ties: lowest ribbon,
    /// then gate, then tick).
    struct Verdict: Equatable {
        let wins: Bool
        let ribbon: Int
        let gate: Int
        let tick: Int
        let residual: Int
    }

    /// `value` modulo 4,096 wrapped into −2,048 … 2,047.
    static func referenceSigned(_ value: Int) -> Int {
        var m: Int = value % 4_096
        if m < 0 { m += 4_096 }
        if m >= 2_048 { m -= 4_096 }
        return m
    }

    /// The reference residual of ribbon `r` at gate `g` and tick `n`.
    static func referenceResidual(_ r: Int, _ g: Int, _ n: Int, wave: [Int], phase: [Int],
                                  level: AuroraLoomLevel) -> Int {
        let s: Int = level.gates[g].position
        let ribbonPhase: Int = wave[r] * s * 16 + phase[r] * 256 + level.ribbons[r].omega * n
        let target: Int = level.gates[g].target + level.omega * n
        return referenceSigned(ribbonPhase - target)
    }

    /// The reference verdict over ticks 0 … 2 · (4,096 / Ω) − 1.
    static func reference(wave: [Int], phase: [Int], level: AuroraLoomLevel) -> Verdict {
        let ticks: Int = 2 * (4_096 / level.omega)
        var wins: Bool = true
        var bestR: Int = -1
        var bestG: Int = -1
        var bestN: Int = -1
        var bestValue: Int = 0
        for r in 0..<3 {
            for g in 0..<4 {
                for n in 0..<ticks {
                    let value: Int = referenceResidual(r, g, n, wave: wave, phase: phase, level: level)
                    let magnitude: Int = value < 0 ? -value : value
                    if magnitude > level.tolerance { wins = false }
                    let bestMagnitude: Int = bestValue < 0 ? -bestValue : bestValue
                    if bestR < 0 || magnitude > bestMagnitude {
                        bestR = r
                        bestG = g
                        bestN = n
                        bestValue = value
                    }
                }
            }
        }
        return Verdict(wins: wins, ribbon: bestR, gate: bestG, tick: bestN, residual: bestValue)
    }

    /// The kernel's verdict in the reference's shape.
    static func kernel(_ steps: AuroraLoomSteps, level: AuroraLoomLevel) -> Verdict {
        let worst: AuroraLoomMismatch = AuroraLoomHarmony.worst(steps, level: level)
        return Verdict(wins: AuroraLoomHarmony.wins(steps, level: level), ribbon: worst.ribbon, gate: worst.gate,
                       tick: worst.tick, residual: worst.residual)
    }

    // MARK: - Hand-built levels

    /// A level with all ribbons starting at wave 1, phase 1 (unless given), gates at 1 … 4 sixteenths.
    static func level(targets: [Int], omega: Int = 64, ribbonOmegas: [Int] = [64, 64, 64], tolerance: Int,
                      startWave: Int = 1, startPhase: Int = 1) throws -> AuroraLoomLevel {
        var ribbons: [AuroraLoomRibbon] = []
        for r in 0..<3 {
            ribbons.append(try AuroraLoomRibbon(wave: startWave, phase: startPhase, omega: ribbonOmegas[r]))
        }
        var gates: [AuroraLoomGate] = []
        for g in 0..<4 {
            gates.append(try AuroraLoomGate(position: g + 1, target: targets[g]))
        }
        return try AuroraLoomLevel(id: "hand-built", seed: 2_301, band: 1, ribbons: ribbons, gates: gates, omega: omega,
                                   tolerance: tolerance, allowance: 8)
    }

    /// Every ribbon at wave 0, phase 0: phase 0 at every gate at tick 0.
    static let zero: AuroraLoomSteps = AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0])

    // MARK: - SC-R02G0101-001: seeded levels

    /// Levels whose 90 single-control changes are checked for the win verdict. Every level of the 1,000 is checked for
    /// its winning setting (`constructedSettingWinsOnOneThousandSeededLevels`); the 90-change sweep calls the kernel's
    /// `wins` (a full scan of up to 512 ticks × 12 ribbon-gate pairs whenever the change still wins or breaks a late
    /// ribbon) and `worst` (always a full scan). Over all 1,000 levels the sweep took about 70 s in a debug build
    /// (19 s for the win verdict alone), so it is bounded to the first 150 levels for the win verdict (13,500 settings)
    /// and the first 20 of them for the full worst mismatch (1,800 settings), alternating exact and offset targets.
    static let sweepFixtures: Int = 150
    /// Of the swept levels, the first ones whose 90 changes are also checked for the full worst mismatch.
    static let worstSweepFixtures: Int = 20

    /// The reference win verdict alone, stopping at the first residual outside the tolerance.
    static func referenceWins(wave: [Int], phase: [Int], level: AuroraLoomLevel) -> Bool {
        let ticks: Int = 2 * (4_096 / level.omega)
        for r in 0..<3 {
            for g in 0..<4 {
                for n in 0..<ticks {
                    let value: Int = referenceResidual(r, g, n, wave: wave, phase: phase, level: level)
                    if value > level.tolerance || value < -level.tolerance { return false }
                }
            }
        }
        return true
    }

    @Test func constructedSettingWinsOnOneThousandSeededLevels() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for index in 0..<1_000 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random, offset: index % 2 == 1)
            #expect(AuroraLoomHarmony.wins(fixture.winning, level: fixture.level), "fixture \(index)")
            let ref: Verdict = Self.reference(wave: fixture.winning.wave, phase: fixture.winning.phase,
                                              level: fixture.level)
            #expect(ref.wins, "reference, fixture \(index)")
            #expect(!AuroraLoomHarmony.wins(fixture.level.startSteps, level: fixture.level), "start, fixture \(index)")
        }
    }

    @Test func everySingleControlChangeAgreesWithTheReference() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var checked: Int = 0
        var winningChanges: Int = 0
        var worstChecked: Int = 0
        for index in 0..<Self.sweepFixtures {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random, offset: index % 2 == 1)
            for r in 0..<3 {
                for control in 0..<2 {
                    for step in 0..<16 {
                        var steps: AuroraLoomSteps = fixture.winning
                        if control == 0 {
                            if step == steps.wave[r] { continue }
                            steps.wave[r] = step
                        } else {
                            if step == steps.phase[r] { continue }
                            steps.phase[r] = step
                        }
                        let refWins: Bool = Self.referenceWins(wave: steps.wave, phase: steps.phase,
                                                               level: fixture.level)
                        if AuroraLoomHarmony.wins(steps, level: fixture.level) != refWins {
                            Issue.record("wins: fixture \(index) ribbon \(r) control \(control) step \(step)")
                        }
                        if index < Self.worstSweepFixtures {
                            let ref: Verdict = Self.reference(wave: steps.wave, phase: steps.phase,
                                                              level: fixture.level)
                            let got: Verdict = Self.kernel(steps, level: fixture.level)
                            if got != ref {
                                let location: String = "fixture \(index) ribbon \(r) control \(control) step \(step)"
                                Issue.record("worst: \(location): \(got) vs \(ref)")
                            }
                            if ref.wins != refWins { Issue.record("reference disagrees with itself, fixture \(index)") }
                            worstChecked += 1
                        }
                        if refWins { winningChanges += 1 }
                        checked += 1
                    }
                }
            }
        }
        #expect(checked == Self.sweepFixtures * 90)
        #expect(worstChecked == Self.worstSweepFixtures * 90)
        // Most changes lose; a small wave change can still win when every gate sits low on the ribbon and the
        // tolerance is wide. Both outcomes are exercised.
        #expect(winningChanges > 0)
        #expect(winningChanges < checked)
    }

    // MARK: - Boundary: inclusive tolerance, sign and wrap

    @Test func positiveToleranceIsInsideAndOneUnitBeyondIsOutside() throws {
        let tolerance: Int = 100
        // Residual = 0 − target; target 4,096 − t gives +t.
        let inside: AuroraLoomLevel = try Self.level(targets: [4_096 - tolerance, 0, 0, 0], tolerance: tolerance)
        #expect(AuroraLoomHarmony.residual(ribbon: 0, gate: 0, tick: 0, steps: Self.zero, level: inside) == tolerance)
        #expect(AuroraLoomHarmony.wins(Self.zero, level: inside))
        #expect(AuroraLoomHarmony.worst(Self.zero, level: inside)
                == AuroraLoomMismatch(ribbon: 0, gate: 0, tick: 0, residual: tolerance))
        let outside: AuroraLoomLevel = try Self.level(targets: [4_096 - tolerance - 1, 0, 0, 0], tolerance: tolerance)
        #expect(AuroraLoomHarmony.residual(ribbon: 0, gate: 0, tick: 0, steps: Self.zero, level: outside)
                == tolerance + 1)
        #expect(!AuroraLoomHarmony.wins(Self.zero, level: outside))
        #expect(!Self.reference(wave: Self.zero.wave, phase: Self.zero.phase, level: outside).wins)
    }

    @Test func negativeToleranceIsInsideAndOneUnitBeyondIsOutside() throws {
        let tolerance: Int = 37
        // Residual = 0 − target; target t gives −t (ribbon phase minus target, not the reverse).
        let inside: AuroraLoomLevel = try Self.level(targets: [0, 0, tolerance, 0], tolerance: tolerance)
        #expect(AuroraLoomHarmony.residual(ribbon: 1, gate: 2, tick: 5, steps: Self.zero, level: inside) == -tolerance)
        #expect(AuroraLoomHarmony.wins(Self.zero, level: inside))
        #expect(AuroraLoomHarmony.worst(Self.zero, level: inside)
                == AuroraLoomMismatch(ribbon: 0, gate: 2, tick: 0, residual: -tolerance))
        let outside: AuroraLoomLevel = try Self.level(targets: [0, 0, tolerance + 1, 0], tolerance: tolerance)
        #expect(AuroraLoomHarmony.residual(ribbon: 2, gate: 2, tick: 0, steps: Self.zero, level: outside)
                == -(tolerance + 1))
        #expect(!AuroraLoomHarmony.wins(Self.zero, level: outside))
    }

    @Test func boundaryHoldsAtTheLargestTolerance() throws {
        let inside: AuroraLoomLevel = try Self.level(targets: [0, 512, 0, 0], tolerance: 512, startWave: 8,
                                                     startPhase: 8)
        #expect(AuroraLoomHarmony.wins(Self.zero, level: inside))
        let outside: AuroraLoomLevel = try Self.level(targets: [0, 513, 0, 0], tolerance: 512, startWave: 8,
                                                      startPhase: 8)
        #expect(!AuroraLoomHarmony.wins(Self.zero, level: outside))
    }

    @Test func residualWrapsIntoMinus2048Through2047() throws {
        // Residual 0 − 2,048 stays −2,048; 0 − 2,049 wraps to +2,047.
        let wrap: AuroraLoomLevel = try Self.level(targets: [2_049, 2_048, 0, 0], tolerance: 10)
        #expect(AuroraLoomHarmony.residual(ribbon: 0, gate: 0, tick: 0, steps: Self.zero, level: wrap) == 2_047)
        #expect(AuroraLoomHarmony.residual(ribbon: 0, gate: 1, tick: 0, steps: Self.zero, level: wrap) == -2_048)
        // |−2,048| > |2,047|, so the worst is gate 1 even though gate 0 comes first.
        #expect(AuroraLoomHarmony.worst(Self.zero, level: wrap)
                == AuroraLoomMismatch(ribbon: 0, gate: 1, tick: 0, residual: -2_048))
        #expect(Self.referenceSigned(-2_048) == -2_048)
        #expect(Self.referenceSigned(2_048) == -2_048)
        #expect(Self.referenceSigned(-2_049) == 2_047)
        #expect(AuroraLoomHarmony.signed(2_048) == -2_048)
        #expect(AuroraLoomHarmony.signed(-2_049) == 2_047)
        #expect(AuroraLoomHarmony.signed(4_096 * 3 + 5) == 5)
        #expect(AuroraLoomHarmony.signed(-4_096 * 3 - 5) == -5)
    }

    // MARK: - Tie order of the worst mismatch

    @Test func worstTiesGoToTheLowestGateThenRibbon() throws {
        // Gate 1 has −300 and gate 2 has +300; every ribbon is alike, so the tie goes to ribbon 0, gate 1, tick 0.
        let level: AuroraLoomLevel = try Self.level(targets: [0, 300, 4_096 - 300, 0], tolerance: 10)
        let expected: AuroraLoomMismatch = AuroraLoomMismatch(ribbon: 0, gate: 1, tick: 0, residual: -300)
        #expect(AuroraLoomHarmony.worst(Self.zero, level: level) == expected)
        let ref: Verdict = Self.reference(wave: Self.zero.wave, phase: Self.zero.phase, level: level)
        #expect(ref == Verdict(wins: false, ribbon: 0, gate: 1, tick: 0, residual: -300))
    }

    @Test func worstTiesGoToTheLowestRibbon() throws {
        // Targets 0; ribbon 0 at phase 0 (residual 0), ribbon 1 at phase 1 (+256), ribbon 2 at phase 15 (−256).
        let level: AuroraLoomLevel = try Self.level(targets: [0, 0, 0, 0], tolerance: 10, startWave: 3)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 1, 15])
        #expect(AuroraLoomHarmony.worst(steps, level: level)
                == AuroraLoomMismatch(ribbon: 1, gate: 0, tick: 0, residual: 256))
        #expect(Self.kernel(steps, level: level) == Self.reference(wave: steps.wave, phase: steps.phase, level: level))
    }

    // MARK: - Drift (ω ≠ Ω) over two periods

    @Test func driftingRibbonIsJudgedOverTwoPeriods() throws {
        let omega: Int = 64
        let period: Int = 4_096 / omega
        let lastTick: Int = 2 * period - 1
        // Ribbon 0 turns 65 units per tick against Ω = 64: residual n at tick n, matching exactly at tick 0.
        let wins: AuroraLoomLevel = try Self.level(targets: [0, 0, 0, 0], omega: omega, ribbonOmegas: [65, 64, 64],
                                                   tolerance: lastTick)
        #expect(wins.period == period)
        #expect(AuroraLoomHarmony.wins(Self.zero, level: wins))
        #expect(AuroraLoomHarmony.worst(Self.zero, level: wins)
                == AuroraLoomMismatch(ribbon: 0, gate: 0, tick: lastTick, residual: lastTick))
        let loses: AuroraLoomLevel = try Self.level(targets: [0, 0, 0, 0], omega: omega, ribbonOmegas: [65, 64, 64],
                                                    tolerance: lastTick - 1)
        #expect(!AuroraLoomHarmony.wins(Self.zero, level: loses))
        #expect(AuroraLoomHarmony.worst(Self.zero, level: loses)
                == AuroraLoomMismatch(ribbon: 0, gate: 0, tick: lastTick, residual: lastTick))
        #expect(Self.kernel(Self.zero, level: loses)
                == Self.reference(wave: Self.zero.wave, phase: Self.zero.phase, level: loses))
        // A ribbon turning slower (ω = 62 against Ω = 64) drifts by −2 per tick; the worst is its last tick.
        let slow: AuroraLoomLevel = try Self.level(targets: [0, 0, 0, 0], omega: omega, ribbonOmegas: [64, 64, 62],
                                                   tolerance: 200)
        #expect(!AuroraLoomHarmony.wins(Self.zero, level: slow))
        #expect(AuroraLoomHarmony.worst(Self.zero, level: slow)
                == AuroraLoomMismatch(ribbon: 2, gate: 0, tick: lastTick, residual: -2 * lastTick))
    }

    @Test func randomDriftLevelsAgreeWithTheReference() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var built: Int = 0
        while built < 200 {
            let omega: Int = 1 << random.int(4...8)
            var ribbons: [AuroraLoomRibbon] = []
            for _ in 0..<3 {
                let ribbonOmega: Int = random.int(0...2) == 0 ? random.int(0...256) : omega
                ribbons.append(try! AuroraLoomRibbon(wave: random.int(0...15), phase: random.int(0...15),
                                                     omega: ribbonOmega))
            }
            var positions: [Int] = []
            while positions.count < 4 {
                let p: Int = random.int(1...15)
                if !positions.contains(p) { positions.append(p) }
            }
            var gates: [AuroraLoomGate] = []
            for p in positions {
                gates.append(try! AuroraLoomGate(position: p, target: random.int(0...4_095)))
            }
            let level: AuroraLoomLevel
            do {
                level = try AuroraLoomLevel(id: "drift-\(built)", seed: random.next(), band: 3, ribbons: ribbons,
                                            gates: gates, omega: omega, tolerance: random.int(1...512), allowance: 10)
            } catch {
                continue
            }
            built += 1
            for _ in 0..<5 {
                var wave: [Int] = []
                var phase: [Int] = []
                for _ in 0..<3 {
                    wave.append(random.int(0...15))
                    phase.append(random.int(0...15))
                }
                let steps: AuroraLoomSteps = AuroraLoomSteps(wave: wave, phase: phase)
                #expect(Self.kernel(steps, level: level) == Self.reference(wave: wave, phase: phase, level: level))
            }
        }
    }

    // MARK: - Ranges

    @Test func phaseTargetAndResidualStayInRange() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for index in 0..<200 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random, offset: index % 2 == 1)
            for _ in 0..<50 {
                var wave: [Int] = []
                var phase: [Int] = []
                for _ in 0..<3 {
                    wave.append(random.int(0...15))
                    phase.append(random.int(0...15))
                }
                let steps: AuroraLoomSteps = AuroraLoomSteps(wave: wave, phase: phase)
                let r: Int = random.int(0...2)
                let g: Int = random.int(0...3)
                let n: Int = random.int(0...100_000)
                let p: Int = AuroraLoomHarmony.phase(ribbon: r, gate: g, tick: n, steps: steps, level: fixture.level)
                let t: Int = AuroraLoomHarmony.target(gate: g, tick: n, level: fixture.level)
                let residual: Int = AuroraLoomHarmony.residual(ribbon: r, gate: g, tick: n, steps: steps,
                                                               level: fixture.level)
                #expect((0...4_095).contains(p))
                #expect((0...4_095).contains(t))
                #expect((-2_048...2_047).contains(residual))
                #expect(residual == Self.referenceResidual(r, g, n, wave: wave, phase: phase, level: fixture.level))
            }
        }
    }
}
