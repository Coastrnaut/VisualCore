// HueCompassPanelWinTests — feature 334 (R02-G04-04) T-R02G0404-004 (FR-R02G0404-005; SC-R02G0404-004; clarification
// Q4). The control panel's path wins every certified level: for each of the 100 levels the adapter is prepared at that
// level (seed = level − 1), and the level's certified witness actions (`HueCompassWitness.actions(for:level:)`) are sent
// exactly as the panel sends them — a turn of k bearings becomes ⌊|k|/4⌋ presses of `compass.turn [±4]` then |k| mod 4
// presses of `compass.turn [±1]` (the sign of k), a probe is `compass.probe` and the selection is
// `compass.select [bearing, band]`. Every action is accepted and the outcome is won. The levels are split by band into
// five tests so each stays short; one more test checks the decomposition of every witness turn −47 … 48 directly.
// Explicit types, plain loops.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreExperience

@Suite struct HueCompassPanelWinTests {
    typealias Core = HueCompassExperienceCore

    /// The panel's turn presses for a turn of `k` bearings: ⌊|k|/4⌋ presses of ±4, then |k| mod 4 presses of ±1, each
    /// with the sign of `k`.
    static func panelTurns(_ k: Int) -> [Int] {
        let sign: Int = k < 0 ? -1 : 1
        let magnitude: Int = abs(k)
        var presses: [Int] = []
        for _ in 0..<(magnitude / 4) { presses.append(4 * sign) }
        for _ in 0..<(magnitude % 4) { presses.append(sign) }
        return presses
    }

    /// The panel actions for one witness action.
    static func panelActions(_ action: HueCompassAction) -> [ExperienceAction] {
        var result: [ExperienceAction] = []
        switch action {
        case .turn(let k):
            for press in panelTurns(k) {
                result.append(ExperienceAction(control: "compass.turn", values: [Double(press)], step: 0))
            }
        case .probe:
            result.append(ExperienceAction(control: "compass.probe", values: [], step: 0))
        case .select(let bearing, let band):
            result.append(ExperienceAction(control: "compass.select", values: [Double(bearing), Double(band)],
                                           step: 0))
        }
        return result
    }

    /// Wins every certified level of `band` (1 … 5) through the panel's actions.
    func winBand(_ band: Int) async throws {
        var checked: Int = 0
        for entry in HueCompassManifest.entries where entry.band == band {
            let number: Int = entry.number
            let generated: HueCompassGenerated = try Core.generated(number: number)
            let witness: [HueCompassAction] = HueCompassWitness.actions(for: generated.solution, level: generated.level)
            var core: Core = try await Core.prepare(seed: UInt64(number - 1))
            #expect(core.levelNumber == number, "level \(number)")
            #expect(core.outcome == nil, "level \(number)")
            for action in witness {
                for panel in Self.panelActions(action) {
                    #expect(core.apply(panel) == .accepted, "level \(number) \(panel.control) \(panel.values)")
                }
            }
            #expect(core.outcome == ExperienceOutcome(code: Core.wonCode), "level \(number)")
            #expect(core.play.stage == .won, "level \(number)")
            checked += 1
        }
        #expect(checked == 20)
    }

    @Test func certifiedLevelsBand1WonThroughPanel() async throws { try await winBand(1) }
    @Test func certifiedLevelsBand2WonThroughPanel() async throws { try await winBand(2) }
    @Test func certifiedLevelsBand3WonThroughPanel() async throws { try await winBand(3) }
    @Test func certifiedLevelsBand4WonThroughPanel() async throws { try await winBand(4) }
    @Test func certifiedLevelsBand5WonThroughPanel() async throws { try await winBand(5) }

    /// Every witness turn −47 … 48 decomposes into panel presses that sum to it, each ±4 or ±1 with its sign, at most
    /// 12 presses of 4 and 3 presses of 1.
    @Test func turnDecompositionSumsAndStaysShort() {
        for k in -47...48 {
            let presses: [Int] = Self.panelTurns(k)
            var sum: Int = 0
            var fours: Int = 0
            var ones: Int = 0
            for press in presses {
                sum += press
                if abs(press) == 4 { fours += 1 } else if abs(press) == 1 { ones += 1 }
                #expect(k == 0 || (press > 0) == (k > 0), "k \(k) press \(press)")
            }
            #expect(sum == k, "k \(k)")
            #expect(fours + ones == presses.count, "k \(k)")
            #expect(fours <= 12, "k \(k)")
            #expect(ones <= 3, "k \(k)")
            #expect(fours == abs(k) / 4 && ones == abs(k) % 4, "k \(k)")
        }
    }
}
