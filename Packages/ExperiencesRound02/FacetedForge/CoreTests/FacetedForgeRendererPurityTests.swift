// FacetedForgeRendererPurityTests — feature 373 (R02-G08-03) T-R02G0803-005 (FR-R02G0803-002, 003, 005; clarification
// Q5, renderer purity). Everything the renderer may do with the adapter — read snapshots with any preview choice at any
// presentation time (non-finite ones included), change the quality tier, step the host — leaves the adapter's digest,
// its state and the kernel's verdict (stage and failure) unchanged, over 200 seeded snapshots (seed 2_373: random cuts,
// misses, undo and redo on certified levels 1, 21, 41, 61 and 81); every snapshot copies the kernel's fields exactly;
// two snapshots of equal states with the same choice at different times differ only in `time`. The five levels are
// generated once and reused, so the run stays short. Explicit types, plain loops.
@testable import FacetedForgeCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct FacetedForgeRendererPurityTests {
    typealias Core = FacetedForgeExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The kernel's verdict for `core`: the play's stage and, when it failed, why.
    static func verdict(_ core: Core) -> String {
        var text: String = core.play.stage.rawValue + "/"
        switch core.play.failure {
        case .sliver(let piece, let cut): text += "sliver \(piece) \(cut)"
        case .budget: text += "budget"
        case nil: text += "-"
        }
        return text
    }

    /// Checks that `snapshot` copies the kernel's state of `core` and the preview `choice` exactly.
    static func expectMirrors(_ snapshot: FacetedForgeSceneSnapshot, _ core: Core,
                              choice: FacetedForgePreviewChoice) {
        let play: FacetedForgePlay = core.play
        #expect(snapshot.levelNumber == core.levelNumber && snapshot.choice == choice)
        #expect(snapshot.pieces.count == play.pieces.count)
        for index in play.pieces.indices where index < snapshot.pieces.count {
            let piece: FacetedForgeSceneSnapshot.Piece = snapshot.pieces[index]
            #expect(piece.corners.count == play.pieces[index].corners.count)
            #expect(piece.faces.count == play.pieces[index].faceCount && piece.cutFaces.count == piece.faces.count)
        }
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        if case .sliver(let piece, _) = play.failure {
            #expect(snapshot.failurePiece == piece)
        } else {
            #expect(snapshot.failurePiece == nil)
        }
        #expect(snapshot.cuts == play.cuts && snapshot.budget == play.level.budget)
        #expect(snapshot.scale > 0 && snapshot.time.isFinite)
    }

    /// Checks that `a` and `b` agree in every field but `time`.
    static func expectSameButTime(_ a: FacetedForgeSceneSnapshot, _ b: FacetedForgeSceneSnapshot) {
        #expect(a.pieces == b.pieces && a.scale == b.scale && a.choice == b.choice && a.preview == b.preview)
        #expect(a.stage == b.stage && a.failure == b.failure && a.failurePiece == b.failurePiece)
        #expect(a.cuts == b.cuts && a.budget == b.budget && a.levelNumber == b.levelNumber)
    }

    @Test func testFacetedForgeRendererpurityBoundary() async throws {
        // Direct example: a prepared level read at the boundary times, every tier (clamped ones included) and odd
        // preview choices (a piece the play does not have, extreme directions and depths).
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(ExperienceAction(control: "piece.cut", values: [0, 0, 0], step: 0)) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let copy: Core = core
        let expected: String = Self.verdict(core)
        let times: [Double] = [0, 1, 2, -1, .infinity, -.infinity, .nan, 1e12]
        let choices: [FacetedForgePreviewChoice] = [FacetedForgePreviewChoice.initial(core.play),
                                                    FacetedForgePreviewChoice(piece: 1, direction: 3, depth: 0),
                                                    FacetedForgePreviewChoice(piece: 9, direction: 99, depth: -99)]
        for time in times {
            for choice in choices {
                let snapshot: FacetedForgeSceneSnapshot = core.snapshot(choice: choice, time: time)
                Self.expectMirrors(snapshot, core, choice: choice)
                #expect(snapshot.time == (time.isFinite ? time : 0))
                #expect(try Self.digest(core) == before && core == copy)
            }
        }
        // Non-finite times read as time 0; a piece the play does not have has no preview section.
        #expect(core.snapshot(time: .nan) == core.snapshot(time: 0))
        #expect(core.snapshot(time: .infinity) == core.snapshot(time: 0))
        #expect(core.snapshot(choice: choices[2], time: 0).preview.isEmpty)
        #expect(!core.snapshot(choice: choices[1], time: 0).preview.isEmpty)
        let tiers: [Int] = [0, 1, 2, 3, -1]
        for tier in tiers {
            core.setQualityTier(tier)
            _ = core.snapshot(time: 1)
            #expect(try Self.digest(core) == before && core == copy)
        }
        #expect(Self.verdict(core) == expected)
    }

    @Test func twoHundredSeededSnapshotsNeverChangeTheDigestOrTheVerdict() async throws {
        // Five certified levels, generated once.
        let numbers: [Int] = [1, 21, 41, 61, 81]
        var openings: [Core] = []
        for number in numbers { openings.append(try Core.opening(number: number)) }
        var random = SeededRandom(seed: 2_373)
        var accepted: Int = 0
        var playing: Int = 0
        var ended: Int = 0
        for _ in 0..<200 {
            var core: Core = openings[random.int(0...(openings.count - 1))]
            // Seeded actions so the snapshots differ from the start; refused ones change nothing.
            for _ in 0..<random.int(0...12) {
                let play: FacetedForgePlay = core.play
                let kind: Int = random.int(0...9)
                let action: ExperienceAction
                switch kind {
                case 0...5:
                    // A cut through a crossing depth of a random piece (or the middle depth when none crosses).
                    let piece: Int = random.int(0...(play.pieces.count - 1))
                    let direction: Int = random.int(0...12)
                    let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[piece], direction: direction)
                    let depth: Int = crossing.isEmpty ? 0 : crossing[random.int(0...(crossing.count - 1))]
                    let values: [Double] = [Double(piece), Double(direction), Double(depth)]
                    action = ExperienceAction(control: "piece.cut", values: values, step: 0)
                case 6:
                    // Any depth: often a miss.
                    let values: [Double] = [0, Double(random.int(0...12)), Double(random.int(-24...24))]
                    action = ExperienceAction(control: "piece.cut", values: values, step: 0)
                case 7, 8:
                    action = ExperienceAction(control: "play.undo", step: 0)
                default:
                    action = ExperienceAction(control: "play.redo", step: 0)
                }
                if core.apply(action).isAccepted { accepted += 1 }
            }
            if core.play.stage == .playing { playing += 1 } else { ended += 1 }
            let before: StateDigest = try Self.digest(core)
            let copy: Core = core
            let expected: String = Self.verdict(core)
            let time: Double = Double(random.int(0...100_000)) / 7
            let choice: FacetedForgePreviewChoice = FacetedForgePreviewChoice(piece: random.int(0...21),
                                                                              direction: random.int(0...12),
                                                                              depth: random.int(-24...24))
            var first: FacetedForgeSceneSnapshot? = nil
            for tier in 0..<Core.qualityTiers {
                core.setQualityTier(tier)
                let snapshot: FacetedForgeSceneSnapshot = core.snapshot(choice: choice, time: time + Double(tier))
                Self.expectMirrors(snapshot, core, choice: choice)
                #expect(snapshot.time == time + Double(tier))
                if let first {
                    // Equal states at different times: only `time` differs.
                    Self.expectSameButTime(first, snapshot)
                    #expect(first != snapshot)
                } else {
                    first = snapshot
                }
                core.update(step: 1)
            }
            // Another choice, the opening choice and odd times change nothing either.
            let other: FacetedForgePreviewChoice = choice.clamped(to: core.play)
            Self.expectMirrors(core.snapshot(choice: other, time: time), core, choice: other)
            _ = core.snapshot(time: time)
            let odd: [Double] = [.nan, .infinity, -.infinity]
            _ = core.snapshot(choice: choice, time: odd[random.int(0...2)])
            core.setQualityTier(random.int(0...2))
            #expect(try Self.digest(core) == before)
            #expect(core == copy)
            #expect(Self.verdict(core) == expected)
        }
        #expect(accepted > 200 && playing > 30 && ended > 5, "accepted \(accepted) playing \(playing) ended \(ended)")
    }
}
