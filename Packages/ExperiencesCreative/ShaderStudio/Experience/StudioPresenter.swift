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
// No GL call: everything is drawn through VisualCore's `FullScreenShaderScene`.
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
    /// The uniforms of the document, in order.
    var uniforms: [ParameterDefinition] = ShaderTemplates.all.first?.uniforms ?? []
    /// The core's normalized values (16 entries).
    var values: [Double] = StudioCore.defaultValues(template: 0)
    /// The status line (``PreviewStatus/text``).
    var status = PreviewStatus.waiting.text
    /// The diagnostics shown, outside-source ones first.
    var diagnostics: [MappedDiagnostic] = []
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
        return true
    }

    /// Takes the core's template as the document when it changed.
    private func followTemplate(_ core: StudioCore) {
        guard core.template != documentTemplate else { return }
        documentTemplate = core.template
        if let template = core.selectedTemplate { document = template.project }
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
        noteStatus()
    }

    /// Passes the new drawable size to the live scene.
    func resize(_ context: RenderContext) {
        pipeline.resize(context)
    }

    /// Follows the template, submits the document when the run count grew, compiles it (at most once) and draws the
    /// live scene with the core's values.
    func draw(_ core: StudioCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        drawCount += 1
        followTemplate(core)
        if core.runs > seenRuns { pipeline.submit(document) }
        seenRuns = core.runs
        let values = core.values
        try pipeline.drawFrame(context, frame: frame) { Self.parameters($0, values: values) }
        follow(core)
        noteStatus()
    }

    /// Tears the scenes down and drops a pending request.
    func teardown(_ context: RenderContext) {
        pipeline.teardown(context)
    }

    // MARK: Mirror and words

    /// Brings the mirror's template, uniforms and values up to `core` and the document.
    func follow(_ core: StudioCore) {
        if mirror.template != core.template { mirror.template = core.template }
        if mirror.uniforms != document.uniforms { mirror.uniforms = document.uniforms }
        if mirror.values != core.values { mirror.values = core.values }
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
        let text = pipeline.status.text
        if mirror.status != text { mirror.status = text }
        let diagnostics = Self.ordered(pipeline.status.diagnostics)
        if mirror.diagnostics != diagnostics { mirror.diagnostics = diagnostics }
    }

    /// The selected template's title of `core`.
    static func templateTitle(_ core: StudioCore) -> String { core.selectedTemplate?.title ?? "Shader" }

    /// The canvas label, for example "Shader Studio, Gradient, Compiled".
    func describe(_ core: StudioCore) -> String {
        "Shader Studio, " + Self.templateTitle(core) + ", " + pipeline.status.text
    }

    /// The actions of the native controls: all three.
    var nativeActions: Set<String> { Set(StudioCore.actionIDs) }

    /// The native controls (``StudioControls``), sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(StudioControls(port: port, mirror: mirror))
    }
}
