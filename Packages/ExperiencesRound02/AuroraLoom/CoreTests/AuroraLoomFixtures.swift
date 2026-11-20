// AuroraLoomFixtures — feature 301 (R02-G01-01) T-R02G0101-002. Seeded test levels with a known winning setting: every
// ribbon set to the same (wave, phase) steps meets each gate's target exactly at tick 0 (offset by at most the tolerance
// when asked), every ribbon turns with the harmony (ω = Ω), and the start steps differ so the start does not win.
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import AuroraLoomCore
import VisualCoreSimulation

/// A seeded level and the steps that win it.
struct AuroraLoomFixture {
    let level: AuroraLoomLevel
    let winning: AuroraLoomSteps

    /// A seeded fixture; returns nil only if the random start happens to win (callers draw again).
    static func make(_ random: inout SeededRandom, offset: Bool = false) -> AuroraLoomFixture? {
        let wave: Int = random.int(0...15)
        let phase: Int = random.int(0...15)
        let omegaExponent: Int = random.int(4...8)
        let omega: Int = 1 << omegaExponent             // 16 … 256, so a period is 16 … 256 ticks
        let tolerance: Int = random.int(1...200)
        var positions: [Int] = []
        while positions.count < 4 {
            let p: Int = random.int(1...15)
            if !positions.contains(p) { positions.append(p) }
        }
        var gates: [AuroraLoomGate] = []
        for p in positions {
            var target: Int = wave * p * 16 + phase * 256
            if offset { target += random.int(-tolerance...tolerance) }
            target = ((target % 4_096) + 4_096) % 4_096
            gates.append(try! AuroraLoomGate(position: p, target: target))
        }
        var ribbons: [AuroraLoomRibbon] = []
        for _ in 0..<3 {
            var startWave: Int = random.int(0...15)
            let startPhase: Int = random.int(0...15)
            if startWave == wave && startPhase == phase { startWave = (startWave + 1) % 16 }
            ribbons.append(try! AuroraLoomRibbon(wave: startWave, phase: startPhase, omega: omega))
        }
        let level: AuroraLoomLevel
        do {
            level = try AuroraLoomLevel(id: "fixture-\(random.int(0...999_999))", seed: random.next(),
                                        band: random.int(1...5), ribbons: ribbons, gates: gates, omega: omega,
                                        tolerance: tolerance, allowance: random.int(6...64),
                                        tutorial: random.int(0...1) == 1)
        } catch {
            return nil
        }
        let winning = AuroraLoomSteps(wave: [wave, wave, wave], phase: [phase, phase, phase])
        return AuroraLoomFixture(level: level, winning: winning)
    }

    /// The next seeded fixture, drawing again when a start happens to win.
    static func next(_ random: inout SeededRandom, offset: Bool = false) -> AuroraLoomFixture {
        while true {
            if let fixture = make(&random, offset: offset) { return fixture }
        }
    }
}
