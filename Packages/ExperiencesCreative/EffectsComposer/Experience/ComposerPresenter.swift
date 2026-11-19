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
// Feature 182 (A25-P03) T-A25-304, T-A25-305, T-A25-307 (clarifications Q1, Q3, Q5; contracts/presets.md):
//   - Compare: `draw` presents the source while the core's `compare` is on (the result is still rendered when the
//     chain changes); the status line then says "Original" unless a refusal is shown.
//   - Presets: the presenter holds the ``LookLibrary`` over the launch's storage (nil without storage, then every
//     library action is refused as `unavailable`) and the library actions `save(name:)`, `open(file:)`,
//     `rename(file:to:)` and `remove(file:)`. Opening sends the preset's nodes to the core (`chain.stage`) and commits
//     them with `chain.replace`, so opening is one undoable edit; the mirror carries the library's last sentence
//     ("Saved <name>.", "Opened <name>.", "Renamed <old> to <new>.", "Removed <name>." or the refusal's message) and
//     its entries.
//   - Accessibility actions: ``perform(accessibilityAction:at:)`` applies a named action of
//     ``ComposerLabels/actions(for:in:)`` through the port, the same core action the button sends.
//
// Feature 183 (A25-P04) T-A25-406 (clarification Q4; contracts/import.md):
//   - `importPicture(data:)`: the status reads "Reading the picture…"; the data is decoded off the main actor
//     (`Task.detached`, ``ImageImport/decode(_:limit:)`` with the renderer's ``PreviewRenderer/importLimit``); back on
//     the main actor the outcome is applied only when it belongs to the latest request (a request counter, so the
//     latest pick wins and an earlier one finishing later is dropped). A picture becomes the source
//     (``PreviewRenderer/setSource(_:)``, at the next frame) and the status reads "Your picture"; a refusal leaves the
//     source and shows its sentence. ``startImport(data:)`` is the same request as a task (the controls and tests).
//   - `useTestPicture()` returns to the built-in test picture (and cancels a pending import) and the status reads
//     "Ready".
//   - The picture is the presenter's, not the core's: it is in neither the digest nor the snapshot, so a restored
//     session shows the test picture. Test seam: ``decoder`` (the decoding function, replaced to order two imports).
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
    /// The chain as last drawn (for the named accessibility actions).
    var chain = EffectChain.empty
    /// Whether the preview shows the source (`view.compare` on).
    var compare = false
    /// The presets as the library lists them.
    var presets: [LookLibraryEntry] = []
    /// Whether the library is read only (written by a newer version).
    var presetsReadOnly = false
    /// Whether the experience has a library (made with storage).
    var hasLibrary = false
    /// The library's last sentence; nil before the first library action.
    var libraryMessage: String?

    /// The status word shown: "Original" while compare is on and nothing was refused, else ``status``.
    var shownStatus: String {
        compare && status == ComposerPresenter.readyWord ? ComposerPresenter.originalWord : status
    }
}

/// Draws Effects Composer (see the file header).
@MainActor
final class ComposerPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = ComposerCore

    /// The status word when nothing was refused.
    nonisolated static let readyWord = "Ready"
    /// The status word while compare shows the source.
    nonisolated static let originalWord = "Original"
    /// The status while a picked picture is decoded.
    nonisolated static let readingWord = "Reading the picture…"
    /// The status once a picked picture is the source.
    nonisolated static let yourPictureWord = "Your picture"

    /// What the controls show.
    let mirror = ComposerMirror()
    /// The preview (a test seam).
    let renderer = PreviewRenderer()
    /// The pixel size of the last frame drawn; nil before the first.
    private var lastSize: (width: Int, height: Int)?
    /// The named chains in the launch's storage; nil when the experience was made without storage.
    let library: LookLibrary?
    /// The shell's port, set by the factory (the library's open and the accessibility actions send through it).
    var port: ExperienceActionPort?
    /// The shell's current core, set by the factory (saving reads the chain from it).
    var currentCore: (@MainActor () -> ComposerCore?)?
    /// The decoding function of an import, run off the main actor (a test seam; ``ImageImport/decode(_:limit:)``).
    var decoder: @Sendable (Data, Int) async -> Result<ImportedPicture, ImportRefusal> = { data, limit in
        ImageImport.decode(data, limit: limit)
    }
    /// The number of the latest import request; an outcome of an earlier one is dropped.
    private(set) var importRequest = 0

    /// A presenter with a library over `storage` (none without storage).
    init(storage: ExperienceStorage? = nil) {
        library = storage.map { LookLibrary(storage: $0) }
        mirror.hasLibrary = library != nil
        followLibrary()
    }

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

    /// Nothing depends on the drawable size but the present pass, which reads it at each frame (the targets have the
    /// source picture's size).
    func resize(_ context: RenderContext) {}

    /// Renders the chain when it changed, presents the result and follows the core.
    func draw(_ core: ComposerCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        renderer.render(core.chain, context: context)
        renderer.present(context, compare: core.compare)
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
        if mirror.chain != core.chain { mirror.chain = core.chain }
        if mirror.compare != core.compare { mirror.compare = core.compare }
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
        text += ". " + mirror.shownStatus
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
        guard renderer.pictureSource.isTestPicture,
              let plan = renderer.lastPlan, plan.passes.allSatisfy({ $0.node == nil }), !renderer.blocked,
              let size = lastSize,
              let point = Self.probePoint(width: size.width, height: size.height,
                                          side: PreviewRenderer.previewSide) else { return [] }
        return [FrameProbe(name: "test-image-blue-cell", x: point.x, y: point.y,
                           expected: FrameColorClass.blue.rawValue)].compactMap { $0 }
    }

    // MARK: Controls

    /// The actions of the native controls: all ten.
    var nativeActions: Set<String> { Set(ComposerCore.actionIDs) }

    /// The native controls (``ECControls``).
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ECControls(port: port, mirror: mirror, presets: ComposerPresetActions(presenter: self)))
    }
}

// MARK: Picture source

extension ComposerPresenter {
    /// Imports the picture in `data` (see the file header) and returns once its outcome was applied or dropped.
    func importPicture(data: Data) async {
        await startImport(data: data).value
    }

    /// Starts importing the picture in `data`: the request is numbered and the status reads "Reading the picture…"
    /// now; the returned task decodes off the main actor and applies the outcome only if no later request was made.
    @discardableResult
    func startImport(data: Data) -> Task<Void, Never> {
        importRequest += 1
        let request = importRequest
        let limit = renderer.importLimit
        let decoder = self.decoder
        if mirror.status != Self.readingWord { mirror.status = Self.readingWord }
        return Task { @MainActor [weak self] in
            let outcome = await Task.detached { await decoder(data, limit) }.value
            self?.apply(outcome, request: request)
        }
    }

    /// Applies the outcome of import `request` when it is still the latest: a picture becomes the source ("Your
    /// picture"); a refusal leaves the source and shows its sentence. Returns whether it was applied.
    @discardableResult
    func apply(_ outcome: Result<ImportedPicture, ImportRefusal>, request: Int) -> Bool {
        guard request == importRequest else { return false }
        let status: String
        switch outcome {
        case .success(let picture):
            renderer.setSource(.imported(picture))
            status = Self.yourPictureWord
        case .failure(let refusal):
            status = refusal.message
        }
        if mirror.status != status { mirror.status = status }
        return true
    }

    /// Returns to the built-in test picture; a pending import is dropped and the status reads "Ready".
    func useTestPicture() {
        importRequest += 1
        renderer.setSource(.testPicture)
        if mirror.status != Self.readyWord { mirror.status = Self.readyWord }
    }
}

// MARK: Presets and named actions

extension ComposerPresenter {
    /// Saves the current chain as `name` and shows "Saved <name>." or the refusal.
    @discardableResult
    func save(name: String) -> Result<LookLibraryEntry, LookLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        guard let core = currentCore?() else { return refuse(.unavailable) }
        let result = library.save(name: name, chain: core.chain)
        switch result {
        case .success(let entry): report("Saved \(entry.name).")
        case .failure(let failure): report(failure.message)
        }
        return result
    }

    /// Opens the preset `file` as one undoable edit (its nodes staged in the core, then `chain.replace`) and shows
    /// "Opened <name>." or the refusal; a refused open changes nothing in the chain or its history.
    @discardableResult
    func open(file: String) -> Result<LookLibraryEntry, LookLibraryFailure> {
        guard let library, let port else { return refuse(.unavailable) }
        guard let entry = library.entry(file: file) else { return refuse(.missing) }
        switch library.open(file: file) {
        case .success(let chain):
            let code = Self.replace(with: chain, through: port)
            guard code == ActionResult.accepted.code else { return refuse(.chain(code)) }
            report("Opened \(entry.name).")
            return .success(entry)
        case .failure(let failure):
            return refuse(failure)
        }
    }

    /// Renames the preset `file` to `name` and shows "Renamed <old> to <new>." or the refusal.
    @discardableResult
    func rename(file: String, to name: String) -> Result<LookLibraryEntry, LookLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let old = library.entry(file: file)?.name ?? file
        let result = library.rename(file: file, to: name)
        switch result {
        case .success(let entry): report("Renamed \(old) to \(entry.name).")
        case .failure(let failure): report(failure.message)
        }
        return result
    }

    /// Removes the preset `file` (the chain stays as it is) and shows "Removed <name>." or the refusal.
    @discardableResult
    func remove(file: String) -> Result<LookLibraryEntry, LookLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        guard let entry = library.entry(file: file) else { return refuse(.missing) }
        switch library.remove(file: file) {
        case .success:
            report("Removed \(entry.name).")
            followLibrary()
            return .success(entry)
        case .failure(let failure):
            return refuse(failure)
        }
    }

    /// Sends `chain` to the core through `port`: each node staged (`chain.stage`), then `chain.replace`; returns the
    /// code of the first refusal or `accepted`.
    static func replace(with chain: EffectChain, through port: ExperienceActionPort) -> String {
        for (index, node) in chain.nodes.enumerated() {
            let code = port.send("chain.stage", stageValues(node, at: index)).code
            guard code == ActionResult.accepted.code else { return code }
        }
        return port.send("chain.replace", [Double(chain.nodes.count)]).code
    }

    /// The values of `chain.stage` for `node` at `index`: the position, identifier, effect index, enabled flag and
    /// the raw values of its parameters in definition order, 0 in the slots beyond them.
    nonisolated static func stageValues(_ node: EffectNode, at index: Int) -> [Double] {
        var values = [Double(index), Double(node.id), Double(ComposerCore.effects.firstIndex(of: node.effect) ?? 0),
                      node.enabled ? 1 : 0]
        let parameters = node.definition.parameters
        for slot in 0..<ComposerCore.maxParameters {
            values.append(slot < parameters.count ? node.values[parameters[slot].name] ?? 0 : 0)
        }
        return values
    }

    /// Applies the named accessibility action `name` of the node at `index` (``ComposerLabels/actions(for:in:)``)
    /// through the port, as the matching button does; returns the action's result code, or nil for a name the node
    /// does not offer.
    @discardableResult
    func perform(accessibilityAction name: String, at index: Int) -> String? {
        guard let port, let core = currentCore?(),
              let command = ComposerLabels.command(named: name, for: index, in: core.chain) else { return nil }
        let code = port.send(command.control, command.values).code
        let message = Self.message(for: code)
        if mirror.status != message { mirror.status = message }
        return code
    }

    /// Brings the mirror's presets up to the library.
    func followLibrary() {
        let entries = library?.entries ?? []
        if mirror.presets != entries { mirror.presets = entries }
        let readOnly = library?.isReadOnly ?? false
        if mirror.presetsReadOnly != readOnly { mirror.presetsReadOnly = readOnly }
    }

    /// Shows `failure`'s sentence and returns it.
    private func refuse(_ failure: LookLibraryFailure) -> Result<LookLibraryEntry, LookLibraryFailure> {
        report(failure.message)
        return .failure(failure)
    }

    /// Shows `text` as the library's message and brings the presets up to the library.
    private func report(_ text: String) {
        if mirror.libraryMessage != text { mirror.libraryMessage = text }
        followLibrary()
    }
}

/// What the presets and picture sections of the controls act with: the presenter's library and picture actions, held
/// weakly (each library action refused as `unavailable`, each picture action doing nothing, once the presenter is
/// gone).
@MainActor
struct ComposerPresetActions {
    /// Saves the current chain under a name (``ComposerPresenter/save(name:)``).
    let save: @MainActor (String) -> Result<LookLibraryEntry, LookLibraryFailure>
    /// Opens a preset (``ComposerPresenter/open(file:)``).
    let open: @MainActor (String) -> Result<LookLibraryEntry, LookLibraryFailure>
    /// Removes a preset (``ComposerPresenter/remove(file:)``).
    let remove: @MainActor (String) -> Result<LookLibraryEntry, LookLibraryFailure>
    /// Applies a named accessibility action of a node (``ComposerPresenter/perform(accessibilityAction:at:)``).
    let perform: @MainActor (String, Int) -> Void
    /// Imports picked picture data (``ComposerPresenter/startImport(data:)``).
    let importPicture: @MainActor (Data) -> Void
    /// Returns to the built-in test picture (``ComposerPresenter/useTestPicture()``).
    let useTestPicture: @MainActor () -> Void

    /// The actions of `presenter`, held weakly.
    init(presenter: ComposerPresenter) {
        importPicture = { [weak presenter] data in presenter?.startImport(data: data) }
        useTestPicture = { [weak presenter] in presenter?.useTestPicture() }
        save = { [weak presenter] name in presenter?.save(name: name) ?? .failure(.unavailable) }
        open = { [weak presenter] file in presenter?.open(file: file) ?? .failure(.unavailable) }
        remove = { [weak presenter] file in presenter?.remove(file: file) ?? .failure(.unavailable) }
        perform = { [weak presenter] name, index in presenter?.perform(accessibilityAction: name, at: index) }
    }
}
