// StudioPresenter — feature 160 (A22-P02) T-A22-204 (FR-A22-201–206; clarifications Q1–Q4; contracts/experience.md).
// Draws Shader Studio through the host only and owns its presentation state:
//
//   - Document: the `ShaderProject` a run compiles. It is the selected template's project when the core's template
//     changes, and `setSource(_:)` replaces its source and keeps its uniforms (the A22-P03 editor's entry point; the
//     tests' seam here). Neither compiles anything.
//   - Runs: at each `draw` the presenter compares the core's run count with the last one it saw; when it grew, the
//     newest document goes to the ``PreviewPipeline`` as the one pending request, which compiles it in the same draw
//     (at most one compile per frame). A template change is followed first, so a run counted by `template.select`
//     compiles the new template.
//   - Uniforms: each draw sets the live scene's `parameters` from the core's normalized values, denormalized by the
//     live project's `ParameterDefinition`s (`value(normalized:)`), keyed by the name without its `u_` prefix. No
//     recompile.
//   - Lifecycle: `setup` builds the live scene (the first template's before any success, the last good one after a
//     context loss); `resize` passes the size on; `teardown` tears the scenes down and drops a pending request.
//   - Words: the canvas label, for example "Shader Studio, Gradient, Compiled". Probes: none here (the picture
//     depends on the person's shader). `maxFramesPerSecond` 30; one quality tier, `level-0`.
//
// Feature 161 (A22-P03) T-A22-304, T-A22-306, T-A22-307 (FR-A22-301–303; clarifications Q1–Q3) adds what the editor
// and the inspector need: the mirror carries the document's source and its `EditorDocument` (lines, tokens and the
// last run's diagnostics, so the marked lines), and its uniforms are the live project's (a uniform dropped by a
// successful recompile leaves the inspector). `setSource(_:)` updates the mirror and never compiles;
// `replaceDocument(_:)` is the oversized-project test seam; `setUniform`/`resetUniforms` send through the port with
// the inspector's clamping. The controls get the editor's `setSource` through `makeControls`.
//
// Feature 162 (A22-P04) T-A22-404, T-A22-406 (FR-A22-401–404; clarifications Q1–Q3; contracts/limits.md):
//
//   - Guidance: the mirror's `guidance` is one sentence of the core's `Guidance` (``guidance(for:limits:)``): a
//     refusal's first issue, a failure's first error message, the stop's advice, or nothing.
//   - Watchdog: every draw feeds `frame.delta` to a `FrameWatchdog` (rearmed at setup and resize; reset by a Run or a
//     `preview.reset`, which also rearm it). When it stops, the pipeline draws its flat dark frame instead of the live
//     shader, the status is ``stoppedStatus`` and the controls show `preview-reset`. A context loss keeps it stopped.
//   - Reset (`preview.reset`, applied at the next draw like a run): the pipeline swaps its fallback (the previous
//     live scene the watchdog had not stopped) back without a compile, or, without one, the template's starter is
//     submitted. The editor's document is kept. `feedWatchdog(_:)` is the tests' seam.
//
// No GL call: everything is drawn through VisualCore's `FullScreenShaderScene` and `FieldPass`.
import Foundation
import Observation
import ShaderStudioCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class StudioMirror {
    /// The selected template's index in `ShaderTemplates.all`.
    var template = 0
    /// The uniforms of the live project (the last good one), in order: the inspector's rows.
    var uniforms: [ParameterDefinition] = ShaderTemplates.all.first?.uniforms ?? []
    /// The core's normalized values (16 entries).
    var values: [Double] = StudioCore.defaultValues(template: 0)
    /// The texture inputs of the live project, in order (feature 161): the inspector's texture rows.
    var textureInputs: [String] = ShaderTemplates.all.first?.textureInputs ?? []
    /// The core's texture choices (recipe indices, 2 entries).
    var textures: [Int] = StudioCore.defaultTextures
    /// The status line (``PreviewStatus/text``).
    var status = PreviewStatus.waiting.text
    /// The diagnostics shown, outside-source ones first.
    var diagnostics: [MappedDiagnostic] = []
    /// The document's source, as the editor shows it.
    var source: String = ShaderTemplates.all.first?.source ?? ""
    /// The editor model of ``source`` with ``diagnostics`` attached (its `markedLines` are the gutter's markers).
    var editor = EditorDocument(source: ShaderTemplates.all.first?.source ?? "")
    /// The guidance sentence under the status (feature 162); empty when there is nothing to change.
    var guidance = ""
    /// Whether the watchdog stopped the preview (feature 162): the controls then show `preview-reset`.
    var stopped = false
}

/// Draws Shader Studio and owns its presentation state (see the file header).
@MainActor
final class StudioPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = StudioCore

    /// What the controls show.
    let mirror = StudioMirror()
    /// The port of the shell, for the controls; set by the factory.
    var port: ExperienceActionPort?
    /// The compile queue and the live scene.
    let pipeline: PreviewPipeline
    /// The project a run compiles (see the file header).
    private(set) var document: ShaderProject
    /// The template index the document was last taken from.
    private(set) var documentTemplate = 0
    /// The run count last seen at a draw.
    private(set) var seenRuns = 0
    /// The reset count last seen at a draw (feature 162).
    private(set) var seenResets = 0
    /// The frame watchdog (feature 162), fed each drawn frame's interval.
    private(set) var watchdog = FrameWatchdog()
    /// The status shown while the watchdog has stopped the preview.
    static let stoppedStatus = "Stopped: frames took longer than 0.25 s"
    /// The guidance shown while the watchdog has stopped the preview.
    static let stoppedGuidance = "The shader is too slow to draw. Reset goes back to the last shader that ran well, "
        + "or edit the source and Run."
    /// How many times `draw` ran.
    private(set) var drawCount = 0
    /// The frame cap: 30 frames per second.
    var maxFramesPerSecond: Int { 30 }

    /// A presenter whose document and first live scene are the first template's.
    init() {
        let first = ShaderTemplates.all.first?.project ?? Self.emptyProject
        document = first
        pipeline = PreviewPipeline(initial: first)
    }

    /// A project used only if no template could be built (the core tests prove all three are).
    private static var emptyProject: ShaderProject {
        (try? ShaderProject(name: "Shader", source: "void main() { fragColor = vec4(0.0, 0.0, 0.0, 1.0); }\n"))
            ?? ShaderTemplates.all[0].project
    }

    // MARK: Document

    /// Replaces the document's source and keeps its uniforms, limits and texture inputs; nothing is compiled (a run
    /// does that at the next frame). Returns false, with the document unchanged, when the project is refused.
    @discardableResult
    func setSource(_ source: String) -> Bool {
        guard let next = try? ShaderProject(name: document.name, source: source, uniforms: document.uniforms,
                                            limits: document.limits, textureInputs: document.textureInputs) else {
            return false
        }
        document = next
        noteDocument()
        return true
    }

    /// Test seam (feature 161, T-A22-306): replaces the whole document, for example with a project of more uniforms
    /// than the limits allow, which no template or edit can produce. Nothing is compiled; a run submits it.
    func replaceDocument(_ project: ShaderProject) {
        document = project
        noteDocument()
    }

    /// Brings the mirror's source and editor model up to the document.
    private func noteDocument() {
        guard mirror.source != document.source else { return }
        mirror.source = document.source
        mirror.editor = EditorDocument(source: document.source, diagnostics: mirror.diagnostics)
    }

    // MARK: Inspector

    /// Sends uniform `k` at the normalized `normalized` through the port, clamped to 0…1; a non-finite value or a
    /// missing port sends nothing and gives nil (``StudioInspector/send(_:normalized:port:)``).
    @discardableResult
    func setUniform(_ k: Int, normalized: Double) -> ActionResult? {
        guard let port else { return nil }
        return StudioInspector.send(k, normalized: normalized, port: port)
    }

    /// Sends uniform `k` at `value` in its own range (clamped to the live uniform's range, then normalized); nil when
    /// `k` is not a live uniform, the value is not finite or there is no port.
    @discardableResult
    func setUniform(_ k: Int, value: Double) -> ActionResult? {
        guard let port, mirror.uniforms.indices.contains(k) else { return nil }
        return StudioInspector.send(k, value: value, definition: mirror.uniforms[k], port: port)
    }

    /// Sends `texture.set [input, recipe]` through the port (the inspector's texture picker); nil without a port.
    @discardableResult
    func setTexture(_ input: Int, recipe: Int) -> ActionResult? {
        guard let port else { return nil }
        return StudioInspector.sendTexture(input, recipe: recipe, port: port)
    }

    /// Sends every live uniform's default (the inspector's Reset); the results in order.
    @discardableResult
    func resetUniforms() -> [ActionResult] {
        guard let port else { return [] }
        return StudioInspector.reset(mirror.uniforms, port: port)
    }

    /// Takes the core's template as the document when it changed.
    private func followTemplate(_ core: StudioCore) {
        guard core.template != documentTemplate else { return }
        documentTemplate = core.template
        if let template = core.selectedTemplate { document = template.project }
        noteDocument()
    }

    /// The live scene's parameters: each of `project`'s uniforms at the core's value, denormalized, keyed by the name
    /// without its `u_` prefix.
    static func parameters(_ project: ShaderProject, values: [Double]) -> [String: Double] {
        var parameters: [String: Double] = [:]
        for (k, definition) in project.uniforms.enumerated() {
            let normalized = values.indices.contains(k) ? values[k] : definition.normalized(definition.defaultValue)
            let key = definition.name.hasPrefix("u_") ? String(definition.name.dropFirst(2)) : definition.name
            parameters[key] = definition.value(normalized: normalized)
        }
        return parameters
    }

    // MARK: Render scene

    /// Builds the live scene (again after a context loss).
    func setup(_ context: RenderContext) throws {
        try pipeline.setup(context)
        watchdog.rearm()
        noteStatus()
    }

    /// Passes the new drawable size to the live scene; the next interval is not counted by the watchdog.
    func resize(_ context: RenderContext) {
        pipeline.resize(context)
        watchdog.rearm()
    }

    /// Follows the template, submits the document when the run count grew, applies a reset when the reset count
    /// grew, feeds the watchdog, compiles a request (at most once) and draws the live scene with the core's values,
    /// or the flat stopped frame while the watchdog has stopped it.
    func draw(_ core: StudioCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        drawCount += 1
        followTemplate(core)
        let wasStopped = watchdog.state == .stopped
        if core.runs > seenRuns {
            pipeline.submit(document)
            watchdog.reset()
        }
        seenRuns = core.runs
        if core.resets > seenResets {
            if !pipeline.restoreFallback(context), let starter = core.selectedTemplate?.project {
                pipeline.submit(starter)
            }
            watchdog.reset()
        }
        seenResets = core.resets
        watchdog.record(frame.delta)
        let values = core.values
        try pipeline.drawFrame(context, frame: frame, textures: core.textures, liveWasStopped: wasStopped,
                               stopped: watchdog.state == .stopped) { Self.parameters($0, values: values) }
        follow(core)
        noteStatus()
    }

    /// Test seam (feature 162, T-A22-406): records `intervals` in the watchdog as if they were drawn frames'
    /// intervals; the next draw follows the state they leave.
    func feedWatchdog(_ intervals: [Double]) {
        for interval in intervals { watchdog.record(interval) }
        noteStatus()
    }

    /// Tears the scenes down and drops a pending request.
    func teardown(_ context: RenderContext) {
        pipeline.teardown(context)
    }

    // MARK: Mirror and words

    /// Brings the mirror's template, uniforms (the live project's) and values up to `core` and the pipeline.
    func follow(_ core: StudioCore) {
        if mirror.template != core.template { mirror.template = core.template }
        let uniforms = pipeline.liveProject.uniforms
        if mirror.uniforms != uniforms { mirror.uniforms = uniforms }
        if mirror.values != core.values { mirror.values = core.values }
        let inputs = pipeline.liveProject.textureInputs
        if mirror.textureInputs != inputs { mirror.textureInputs = inputs }
        if mirror.textures != core.textures { mirror.textures = core.textures }
    }

    /// The diagnostics in display order: outside the person's source first, then by line; the order is otherwise
    /// kept.
    static func ordered(_ diagnostics: [MappedDiagnostic]) -> [MappedDiagnostic] {
        let outside = diagnostics.filter { !DiagnosticMapper.isInPersonSource($0) }
        let inside = diagnostics.enumerated().filter { DiagnosticMapper.isInPersonSource($0.element) }
            .sorted { ($0.element.line ?? 0, $0.offset) < ($1.element.line ?? 0, $1.offset) }.map(\.element)
        return outside + inside
    }

    /// Brings the mirror's status and diagnostics up to the pipeline.
    private func noteStatus() {
        let stopped = watchdog.state == .stopped
        if mirror.stopped != stopped { mirror.stopped = stopped }
        let text = statusText
        if mirror.status != text { mirror.status = text }
        let guidance = stopped ? Self.stoppedGuidance : Self.guidance(for: pipeline.status, limits: document.limits)
        if mirror.guidance != guidance { mirror.guidance = guidance }
        let diagnostics = Self.ordered(pipeline.status.diagnostics)
        if mirror.diagnostics != diagnostics {
            mirror.diagnostics = diagnostics
            mirror.editor = EditorDocument(source: mirror.source, diagnostics: diagnostics)
        }
    }

    /// The selected template's title of `core`.
    static func templateTitle(_ core: StudioCore) -> String { core.selectedTemplate?.title ?? "Shader" }

    /// The canvas label, for example "Shader Studio, Gradient, Compiled".
    func describe(_ core: StudioCore) -> String {
        "Shader Studio, " + Self.templateTitle(core) + ", " + statusText
    }

    /// The status line: ``stoppedStatus`` while the watchdog has stopped the preview, else the pipeline's.
    var statusText: String { watchdog.state == .stopped ? Self.stoppedStatus : pipeline.status.text }

    /// The guidance sentence of `status` (feature 162): a refusal's first issue (with `limits`), a failure's first
    /// error message (or its first diagnostic), nothing otherwise.
    static func guidance(for status: PreviewStatus, limits: ShaderLimits) -> String {
        switch status {
        case .refused(let issues):
            return issues.first.map { Guidance.forIssue($0, limits: limits) } ?? ""
        case .failed(let diagnostics):
            let first = diagnostics.first { $0.severity == .error } ?? diagnostics.first
            return first.map { Guidance.forDiagnostic(message: $0.message) } ?? ""
        case .waiting, .compiled:
            return ""
        }
    }

    /// The frame probes of the verification runner: for the opening template (Gradient), the top-right corner is red
    /// at every time. There the mix towards the warm colour stays between 0.475 and 1, so red leads green and blue by
    /// more than 30 of 255. Other templates declare none.
    func probes(_ core: StudioCore) -> [FrameProbe] {
        guard core.template == 0 else { return [] }
        return [FrameProbe(name: "warm-corner", x: 0.95, y: 0.05, expected: FrameColorClass.red.rawValue)]
            .compactMap { $0 }
    }

    /// The actions of the native controls: all five.
    var nativeActions: Set<String> { Set(StudioCore.actionIDs) }

    /// The native controls (``StudioControls``, with ``StudioEditor`` and ``StudioInspector``), sending through
    /// `port`; the editor's edits reach ``setSource(_:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(StudioControls(port: port, mirror: mirror, edit: { [weak self] source in
            self?.setSource(source)
        }))
    }
}
