// LissajousLabyrinthFixtures — feature 311 (R02-G02-01) T-R02G0201-002. Seeded test levels with a known safe setting: the
// checkpoints are balls around samples of the safe lap at increasing ticks (so the safe lap visits them in order), the
// obstacles are random balls kept only when no segment of the safe lap touches them, and the start dials differ so the
// start does not win. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import VisualCoreSimulation

/// A seeded level and the dials that win it.
struct LissajousLabyrinthFixture {
    let level: LissajousLabyrinthLevel
    let safe: LissajousLabyrinthDials

    /// Random valid dials (coprime frequencies).
    static func dials(_ random: inout SeededRandom) -> LissajousLabyrinthDials {
        while true {
            let d = LissajousLabyrinthDials(frequencyA: random.int(1...9), frequencyB: random.int(1...9),
                                            phaseA: random.int(0...15), phaseC: random.int(0...15))
            if d.isValid { return d }
        }
    }

    /// A seeded fixture; nil only when the random start happens to win (callers draw again).
    static func make(_ random: inout SeededRandom, allowance: Int = 12) -> LissajousLabyrinthFixture? {
        let amplitudes: [Int] = [random.int(1...4), random.int(1...4), random.int(1...4)]
        let frequencyC: Int = random.int(1...9)
        let safe = dials(&random)
        // A provisional level only to sample the safe lap (its start is the safe setting with no obstacles; a far
        // checkpoint keeps the start from winning).
        guard let far = try? LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64),
              let probe = try? LissajousLabyrinthLevel(id: "probe", seed: 0, band: 1, amplitudes: amplitudes,
                                                       frequencyC: frequencyC, start: safe, checkpoints: [far],
                                                       obstacles: [], allowance: allowance) else { return nil }
        let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(safe, level: probe)
        let count: Int = random.int(1...4)
        var ticks: [Int] = []
        while ticks.count < count {
            let t: Int = random.int(0...4_095)
            if !ticks.contains(t) { ticks.append(t) }
        }
        ticks.sort()
        var checkpoints: [LissajousLabyrinthBall] = []
        for t in ticks {
            let radius: Int = random.int(128...512)
            let spread: Int = radius / 4
            let p = points[t]
            guard let ball = try? LissajousLabyrinthBall(x: p.x + random.int(-spread...spread),
                                                         y: p.y + random.int(-spread...spread),
                                                         z: p.z + random.int(-spread...spread), radius: radius) else {
                return nil
            }
            checkpoints.append(ball)
        }
        var obstacles: [LissajousLabyrinthBall] = []
        let wanted: Int = random.int(0...4)
        var attempts = 0
        while obstacles.count < wanted && attempts < 40 {
            attempts += 1
            guard let ball = try? LissajousLabyrinthBall(x: random.int(-4_500...4_500), y: random.int(-4_500...4_500),
                                                         z: random.int(-4_500...4_500),
                                                         radius: random.int(64...512)) else { continue }
            var touches = false
            for n in 0..<LissajousLabyrinthLap.ticks
            where LissajousLabyrinthLap.segmentTouches(points[n], points[(n + 1) % LissajousLabyrinthLap.ticks],
                                                       ball: ball) {
                touches = true
                break
            }
            if !touches { obstacles.append(ball) }
        }
        var start = dials(&random)
        while start == safe { start = dials(&random) }
        guard let level = try? LissajousLabyrinthLevel(id: "fixture", seed: random.next(), band: random.int(1...5),
                                                       amplitudes: amplitudes, frequencyC: frequencyC, start: start,
                                                       checkpoints: checkpoints, obstacles: obstacles,
                                                       allowance: allowance) else { return nil }
        return LissajousLabyrinthFixture(level: level, safe: safe)
    }

    /// The next fixture from `random`, drawing again when the start happens to win.
    static func next(_ random: inout SeededRandom, allowance: Int = 12) -> LissajousLabyrinthFixture {
        while true {
            if let fixture = make(&random, allowance: allowance) { return fixture }
        }
    }
}
