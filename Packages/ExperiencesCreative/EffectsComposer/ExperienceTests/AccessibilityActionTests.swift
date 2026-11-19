// AccessibilityActionTests — feature 182 (A25-P03) T-A25-307 (FR-A25-305; clarification Q5; User Story 4). The named
// accessibility actions of a node row, listed by the pure `ComposerLabels.actions(for:in:)`: "Move up" absent for the
// first node, "Move down" absent for the last, "Turn off" or "Turn on", and "Raise <name>" / "Lower <name>" for each
// parameter. Applied through the presenter (`perform(accessibilityAction:at:)`, the same core actions the buttons
// send), each changes the chain as named (a parameter by a tenth of its range) and the next frame renders it.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct AccessibilityActionTests {
    /// Color grade, Blur (off) and Vignette, with their default values.
    static let chain = EffectChain(nodes: [EffectNode(id: 1, effect: .grade), EffectNode(id: 2, effect: .blur, enabled: false),
                                           EffectNode(id: 3, effect: .vignette)])

    @Test func theActionsOfTheFirstAMiddleAndTheLastNode() {
        #expect(ComposerLabels.actions(for: 0, in: Self.chain) == [
            "Move down", "Turn off", "Raise exposure", "Lower exposure", "Raise contrast", "Lower contrast",
            "Raise saturation", "Lower saturation",
        ])
        #expect(ComposerLabels.actions(for: 1, in: Self.chain) == [
            "Move up", "Move down", "Turn on", "Raise radius", "Lower radius",
        ])
        #expect(ComposerLabels.actions(for: 2, in: Self.chain) == [
            "Move up", "Turn off", "Raise amount", "Lower amount", "Raise radius", "Lower radius", "Raise softness",
            "Lower softness",
        ])
        let single = EffectChain(nodes: [EffectNode(id: 1, effect: .posterize)])
        #expect(ComposerLabels.actions(for: 0, in: single) == ["Turn off", "Raise levels", "Lower levels"])
        #expect(ComposerLabels.actions(for: 3, in: Self.chain).isEmpty)
        #expect(ComposerLabels.command(named: "Move up", for: 0, in: Self.chain) == nil)
    }

    /// `chain` after the named action `name` on node `index`, computed from the definitions alone.
    static func expected(_ name: String, _ index: Int, _ chain: EffectChain) -> EffectChain {
        var nodes = chain.nodes
        switch name {
        case "Move up": nodes.swapAt(index, index - 1)
        case "Move down": nodes.swapAt(index, index + 1)
        case "Turn off": nodes[index].enabled = false
        case "Turn on": nodes[index].enabled = true
        default:
            let up = name.hasPrefix("Raise ")
            let parameterName = String(name.dropFirst("Raise ".count))
            let spec = nodes[index].definition.parameters.first { $0.name == parameterName }!
            let span = spec.range.upperBound - spec.range.lowerBound
            let old = nodes[index].values[parameterName] ?? spec.defaultValue
            var value = min(max(old + (up ? span : -span) / 10, spec.range.lowerBound), spec.range.upperBound)
            if spec.whole { value = value.rounded() }
            nodes[index].values[parameterName] = value
        }
        return EffectChain(nodes: nodes)
    }

    /// Whether `a` and `b` have the same nodes, flags and values within 1e-9.
    static func close(_ a: EffectChain, _ b: EffectChain) -> Bool {
        guard a.nodes.count == b.nodes.count else { return false }
        for (x, y) in zip(a.nodes, b.nodes) {
            guard x.id == y.id, x.effect == y.effect, x.enabled == y.enabled,
                  Set(x.values.keys) == Set(y.values.keys) else { return false }
            for (name, value) in x.values where abs(value - (y.values[name] ?? .nan)) > 1e-9 { return false }
        }
        return true
    }

    @Test func applyingEachChangesTheChainAsNamedAndRedraws() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let presenter = shell.presenter
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.enable", [1, 0])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        let start = try ComposerTest.core(shell).chain
        #expect(start == Self.chain)
        #expect(presenter.perform(accessibilityAction: "Move up", at: 0) == nil, "not offered for the first node")
        var applied = 0
        for index in start.nodes.indices {
            for name in ComposerLabels.actions(for: index, in: start) {
                let renders = presenter.renderer.renderCount
                #expect(presenter.perform(accessibilityAction: name, at: index) == ActionResult.accepted.code,
                        "\(name) of node \(index)")
                let chain = try ComposerTest.core(shell).chain
                #expect(Self.close(chain, Self.expected(name, index, start)), "\(name) of node \(index): \(chain)")
                try ComposerTest.draw(session)
                #expect(presenter.renderer.renderCount == renders + 1, "\(name) redraws")
                #expect(presenter.mirror.status == ComposerPresenter.readyWord)
                ComposerTest.accept(shell, "edit.undo")
                #expect(try ComposerTest.core(shell).chain == start)
                applied += 1
            }
        }
        #expect(applied == 21)
    }
}
