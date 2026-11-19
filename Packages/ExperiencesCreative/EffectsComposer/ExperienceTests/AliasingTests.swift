// AliasingTests — feature 182 (A25-P03) T-A25-306 (FR-A25-304; clarification Q4; User Story 3). Every pass the preview
// runs, seen through `FieldPass.runObserver` (set only around each synchronous frame and edit, so no other test's
// passes are seen, and cleared after): over 50 edits of every kind (add, set, enable, move, remove, undo, redo) with
// compare toggled every 5 and a frame after each, no pass reads the texture it writes and no pass writes the source
// target's texture. The pure plan check of A25-P02 (no planned pass reads its output) stays in `PassPlanTests`.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct AliasingTests {
    /// The edit of step `step` on `core`: the kinds in turn (add, set, enable, move, remove, undo, redo), each replaced
    /// by an add (or a remove at the cap) where the chain does not allow it.
    static func edit(_ step: Int, _ core: ComposerCore) -> (String, [Double]) {
        let count = core.chain.nodes.count
        let add: (String, [Double]) = count < ChainLimits.maxNodes
            ? ("chain.add", [Double(step % ComposerCore.effects.count), Double(count / 2)])
            : ("chain.remove", [0])
        switch step % 7 {
        case 1 where count > 0: return ("chain.set", [Double(step % count), 0, Double(step % 10) / 10])
        case 2 where count > 0: return ("chain.enable", [Double(step % count), core.chain.nodes[step % count].enabled ? 0 : 1])
        case 3 where count > 1: return ("chain.move", [0, Double(count - 1)])
        case 4 where count > 2: return ("chain.remove", [Double(count - 1)])
        case 5 where core.history.canUndo: return ("edit.undo", [])
        case 6 where core.history.canRedo: return ("edit.redo", [])
        default: return add
        }
    }

    @Test func noPassReadsItsOutputOrWritesTheSource() async throws {
        let session = ExperienceSession()
        defer {
            FieldPass.runObserver = nil
            session.close()
        }
        let shell = try await ComposerTest.open(session)
        var runs: [FieldPass.Run] = []
        var kinds = Set<String>()
        var compare = false
        for step in 0..<50 {
            let (control, values) = Self.edit(step, try ComposerTest.core(shell))
            kinds.insert(control)
            FieldPass.runObserver = { runs.append($0) }
            ComposerTest.accept(shell, control, values)
            if step % 5 == 4 {
                compare.toggle()
                ComposerTest.accept(shell, "view.compare", [compare ? 1 : 0])
            }
            try ComposerTest.draw(session)
            FieldPass.runObserver = nil
        }
        #expect(kinds == ["chain.add", "chain.set", "chain.enable", "chain.move", "chain.remove", "edit.undo",
                          "edit.redo"])
        let sourceName = try #require(shell.presenter.renderer.sourceTextureName)
        let ours = runs.filter { $0.label.hasPrefix("a25-") }
        #expect(ours.count >= 100, "\(ours.count) runs")
        #expect(ours.contains { $0.label == "a25-present.frag" && $0.inputs.values.contains(sourceName) },
                "compare presented the source")
        for run in ours {
            if !run.outputIsFramebuffer {
                #expect(!run.inputs.values.contains(run.output), "\(run.label) reads its output \(run.output)")
                #expect(run.output != sourceName, "\(run.label) writes the source")
            }
        }
        print("AliasingTests: \(ours.count) runs over 50 edits")
    }
}
