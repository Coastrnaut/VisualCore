// ComposerPresenter — feature 181 (A25-P02) T-A25-206 (FR-A25-202, FR-A25-203, FR-A25-205, FR-A25-206;
// clarifications Q2, Q4 and Q5; contracts/experience.md). Draws Effects Composer through the host only:
//
//   - `setup` builds the preview (``PreviewRenderer``: the programs, the source and the result), again after a context
//     loss; `teardown` releases all of it; `resize` needs nothing, because the preview's targets have the test image's
//     size and only the present pass depends on the drawable, which it reads at each frame.
//   - `draw` renders the core's chain when its fingerprint changed since the last render (the plan is compiled again
//     then), presents the result letterboxed and brings the mirror up to the core.
//   - Words: the status line is "Ready", the message of the last refused action (set by the controls) or the pool's
//     refusal; the diagnostics line lists "<effect title>, line <n>: <message>" for every program that did not build.
//   - Probe: while the drawn plan is the copy of the test image (no enabled effect, the opening state), the point at the
//     centre of the image's checker cell (2, 2) from the top-left (red and green 80 of 255, blue 255) has the class
//     `blue` (the top-left cell, red and green 16, is too dark for the class).
//   - Test seams: ``programOverride`` (set before the first `setup`), ``captureResult``, ``lastResult`` and
//     ``renderer``.
//
// Maximum 60 frames per second; one quality tier, `level-0`. No GL call outside the renderer's `FieldPass`es.
import EffectsComposerCore
import Foundation
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// One parameter of a node as the controls show it.
struct ParameterRow: Equatable, Sendable {
    /// The parameter's name.
    let name: String
    /// The parameter's value.
    let value: Double
    /// The parameter's definition (range, whole flag).
    let spec: ParameterSpec
}

/// One node of the chain as the controls show it.
struct NodeRow: Equatable, Sendable {
    /// The node's position in the chain, from 0.
    let index: Int
    /// The node's identifier.
    let id: Int
    /// The node's effect.
    let effect: EffectID
    /// Whether the node is enabled.
    let enabled: Bool
    /// The node's parameters in their definition order.
    let parameters: [ParameterRow]

    /// The row of `node` at `index`.
    init(node: EffectNode, index: Int) {
        self.index = index
        self.id = node.id
        self.effect = node.effect
        self.enabled = node.enabled
        self.parameters = node.definition.parameters.map { spec in
            ParameterRow(name: spec.name, value: node.values[spec.name] ?? spec.defaultValue, spec: spec)
        }
    }

    /// The effect's title.
    var title: String { EffectLibrary.definition(effect).title }
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class ComposerMirror {
    /// The chain's nodes in order.
    var rows: [NodeRow] = []
    /// Whether there is an edit to undo.
    var canUndo = false
    /// Whether there is an edit to redo.
    var canRedo = false
    /// The status line: "Ready" or the message of the last refusal.
    var status = ComposerPresenter.readyWord
    /// The diagnostics line; empty when every program built.
    var diagnostics = ""
}

/// Draws Effects Composer (see the file header).
@MainActor
final class ComposerPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = ComposerCore

    /// The status word when nothing was refused.
    nonisolated static let readyWord = "Ready"

    /// What the controls show.
    let mirror = ComposerMirror()
    /// The preview (a test seam).
    let renderer = PreviewRenderer()
    /// The pixel size of the last frame drawn; nil before the first.
    private var lastSize: (width: Int, height: Int)?

    /// Replacement program texts by effect (a test seam, read at `setup`; never set by the app).
    var programOverride: [EffectID: String] {
        get { renderer.programOverride }
        set { renderer.programOverride = newValue }
    }

    /// When true, every render reads the result back into ``lastResult`` (a test seam).
    var captureResult: Bool {
        get { renderer.captureResult }
        set { renderer.captureResult = newValue }
    }

    /// The result's pixels, rows top-down, after the last render (a test seam).
    var lastResult: RGBAImage? { renderer.lastResult }

    /// The diagnostics of the programs that did not build.
    var diagnostics: [ProgramDiagnostic] { renderer.diagnostics }

    /// 60 frames per second.
    var maxFramesPerSecond: Int { 60 }

    // MARK: Render scene

    /// Builds the preview (again after a context loss).
    func setup(_ context: RenderContext) throws {
        try renderer.setup(context)
        followRenderer()
    }

    /// Nothing depends on the drawable size but the present pass, which reads it at each frame.
    func resize(_ context: RenderContext) {}

    /// Renders the chain when it changed, presents the result and follows the core.
    func draw(_ core: ComposerCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        renderer.render(core.chain, context: context)
        renderer.present(context)
        lastSize = (context.pixelWidth, context.pixelHeight)
        follow(core)
    }

    /// Releases the preview.
    func teardown(_ context: RenderContext) {
        renderer.release(context)
    }

    // MARK: Words

    /// The sentence of a refused action's code (`action.rule.a25.<code>` or an engine code).
    nonisolated static func message(for code: String) -> String {
        let rule = code.hasPrefix("action.rule.") ? String(code.dropFirst("action.rule.".count)) : code
        switch rule {
        case "accepted": return readyWord
        case ComposerRule.notWhole: return "Only whole numbers are allowed here."
        case "a25.bad-index": return "There is no effect at that position."
        case "a25.too-many-nodes": return "The chain holds at most \(ChainLimits.maxNodes) effects."
        case "a25.nothing-to-undo": return "There is nothing to undo."
        case "a25.nothing-to-redo": return "There is nothing to redo."
        case "a25.out-of-range", "action.out-of-range": return "That value is outside its range."
        case "a25.unknown-parameter": return "That effect has no such setting."
        case PreviewRefusal.poolCap.ruleID: return PreviewRefusal.poolCap.message
        default: return "The change was refused (\(rule))."
        }
    }

    /// The diagnostics line: each diagnostic's text, joined by "; "; empty without one.
    nonisolated static func diagnosticsLine(_ diagnostics: [ProgramDiagnostic]) -> String {
        diagnostics.map(\.text).joined(separator: "; ")
    }

    /// Brings the mirror up to `core` and the renderer.
    func follow(_ core: ComposerCore) {
        let rows = core.chain.nodes.enumerated().map { NodeRow(node: $1, index: $0) }
        if mirror.rows != rows { mirror.rows = rows }
        if mirror.canUndo != core.history.canUndo { mirror.canUndo = core.history.canUndo }
        if mirror.canRedo != core.history.canRedo { mirror.canRedo = core.history.canRedo }
        followRenderer()
    }

    /// Brings the mirror's diagnostics and the pool's refusal up to the renderer.
    private func followRenderer() {
        let line = Self.diagnosticsLine(renderer.diagnostics)
        if mirror.diagnostics != line { mirror.diagnostics = line }
        if let refusal = renderer.refusal, mirror.status != refusal.message { mirror.status = refusal.message }
    }

    /// The canvas label, for example "Effects Composer, 2 effects: Color grade on, Blur off. Ready".
    func describe(_ core: ComposerCore) -> String {
        let nodes = core.chain.nodes
        var text = "Effects Composer, "
        if nodes.isEmpty {
            text += "no effect, the test image unchanged"
        } else {
            text += "\(nodes.count) " + (nodes.count == 1 ? "effect" : "effects") + ": "
            text += nodes.map { $0.definition.title + ($0.enabled ? " on" : " off") }.joined(separator: ", ")
        }
        text += ". " + mirror.status
        if !mirror.diagnostics.isEmpty { text += ". " + mirror.diagnostics }
        return text
    }

    // MARK: Probe

    /// The view point (x from the left, y from the top, both 0…1) of the centre of the test image's checker cell
    /// (2, 2) from the top-left, 5/16 of the side from the image's left and top edges, when the image of side `side`
    /// is presented in a `width × height` drawable; nil for an empty one.
    nonisolated static func probePoint(width: Int, height: Int, side: Int) -> (x: Double, y: Double)? {
        guard let rect = PreviewRenderer.presentRect(width: width, height: height, side: side) else { return nil }
        let cellCentre = Double(rect.width) * 5 / 16
        let top = Double(height - rect.y - rect.height)
        return (x: (Double(rect.x) + cellCentre) / Double(width), y: (top + cellCentre) / Double(height))
    }

    /// The probe of the frame last drawn (see the file header): `blue` at the checker cell (2, 2) while the plan is
    /// the copy of the test image; none otherwise.
    func probes(_ core: ComposerCore) -> [FrameProbe] {
        guard let plan = renderer.lastPlan, plan.passes.allSatisfy({ $0.node == nil }), !renderer.blocked,
              let size = lastSize,
              let point = Self.probePoint(width: size.width, height: size.height,
                                          side: PreviewRenderer.previewSide) else { return [] }
        return [FrameProbe(name: "test-image-blue-cell", x: point.x, y: point.y,
                           expected: FrameColorClass.blue.rawValue)].compactMap { $0 }
    }

    // MARK: Controls

    /// The actions of the native controls: all seven.
    var nativeActions: Set<String> { Set(ComposerCore.actionIDs) }

    /// The native controls (``ECControls``).
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ECControls(port: port, mirror: mirror))
    }
}
