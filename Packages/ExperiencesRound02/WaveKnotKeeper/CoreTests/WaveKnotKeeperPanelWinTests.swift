// WaveKnotKeeperPanelWinTests — feature 324 (R02-G03-04) T-R02G0304-004 (FR-R02G0304-006; SC-R02G0304-004). The
// control panel's path wins every certified level: for each of the 100 levels the adapter is prepared at that level
// (seed = level − 1), and for each certified solution move exactly what the panel sends is applied through the
// adapter — `point.select [point]`, then `point.move [point, direction index]` with the index into
// `WaveKnotKeeperDirection.allCases`. Every action is accepted, a select never changes the digest, and the outcome is
// won after exactly the certified shortest number of moves. The levels are split by band into five tests so each stays
// short. Explicit types, plain loops.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct WaveKnotKeeperPanelWinTests {
    typealias Core = WaveKnotKeeperExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Wins every certified level of `band` (1 … 5) through the panel's select-then-move actions.
    func winBand(_ band: Int) async throws {
        var checked: Int = 0
        for entry in WaveKnotKeeperManifest.entries where entry.band == band {
            let number: Int = entry.number
            let generated: WaveKnotKeeperGenerated = try Core.generated(number: number)
            var core: Core = try await Core.prepare(seed: UInt64(number - 1))
            #expect(core.levelNumber == number, "level \(number)")
            #expect(core.outcome == nil, "level \(number)")
            #expect(generated.solution.moves.count == generated.solution.shortest, "level \(number)")
            for move in generated.solution.moves {
                let before: StateDigest = try Self.digest(core)
                let select: ExperienceAction = ExperienceAction(control: "point.select",
                                                                values: [Double(move.point)], step: 0)
                #expect(core.apply(select) == .accepted, "level \(number) select \(move.point)")
                #expect(core.selected == move.point, "level \(number)")
                #expect(try Self.digest(core) == before, "level \(number): select changed the digest")
                let index: Int = try #require(Core.directionOrder.firstIndex(of: move.direction))
                let step: ExperienceAction = ExperienceAction(control: "point.move",
                                                              values: [Double(move.point), Double(index)], step: 0)
                #expect(core.apply(step) == .accepted, "level \(number) move \(move.point) \(index)")
            }
            #expect(core.outcome == ExperienceOutcome(code: Core.wonCode), "level \(number)")
            #expect(core.play.stage == .won, "level \(number)")
            #expect(core.play.spent == generated.solution.shortest, "level \(number)")
            checked += 1
        }
        #expect(checked == 20)
    }

    @Test func certifiedLevelsBand1WonThroughPanel() async throws { try await winBand(1) }
    @Test func certifiedLevelsBand2WonThroughPanel() async throws { try await winBand(2) }
    @Test func certifiedLevelsBand3WonThroughPanel() async throws { try await winBand(3) }
    @Test func certifiedLevelsBand4WonThroughPanel() async throws { try await winBand(4) }
    @Test func certifiedLevelsBand5WonThroughPanel() async throws { try await winBand(5) }
}
