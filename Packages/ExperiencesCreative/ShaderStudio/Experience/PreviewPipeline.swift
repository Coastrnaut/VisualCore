// PreviewPipeline — feature 160 (A22-P02) T-A22-204 (FR-A22-202–204, FR-A22-206; clarification Q2; data-model.md
// "PreviewPipeline"; research D2, D3). The compile queue and the last-good preview of Shader Studio, owned by
// `StudioPresenter` and driven only from the presenter's `setup`, `resize`, `draw` and `teardown`, so every compile
// happens in the host's context at its next frame:
//
//   - Queue: `submit(_:)` keeps the newest project as the one pending request (an older one is dropped). Nothing is
//     compiled there.
//   - Frame: `drawFrame` takes the pending request (at most one per frame). The validator runs first: a refusal shows
//     the issues and compiles nothing. Otherwise the assembly's entry (`ss/main.frag`) is compiled with
//     `FullScreenShaderScene.vertexSource` through `context.resources.program`, which gives every diagnostic. A compile
//     or link error maps the diagnostics (`DiagnosticMapper`) into the status and the live scene keeps drawing. On
//     success a new `FullScreenShaderScene` of the same entry and files is set up (a program-cache hit), replaces the
//     live one, and the old one is torn down.
//   - Program sharing: the registry's cache hands the same `ShaderProgram` to the probe and to the new scene, and it
//     does not count references. So the probe is released only when the new scene compiled a program of its own, and
//     a run whose files are those of the live scene keeps the live scene (tearing it down would delete the program
//     both hold).
//   - Rebuild: `setup` builds the live scene from the last good project (the first template's before any success),
//     again after a context loss. `teardown` tears the scenes down and drops a pending request.
//
// Feature 161 (A22-P03) T-A22-308 (FR-A22-304): a live project with texture inputs is drawn by a ``TexturedPreview``
// (VisualCore's `FieldPass` with textures made in code, sampled by the core's texture choices passed to `drawFrame`);
// a project without texture inputs is drawn by a `FullScreenShaderScene` exactly as in A22-P02. Both share the probe's
// cached program by the same rule.
//
// Feature 162 (A22-P04) T-A22-406 (FR-A22-403, FR-A22-404; clarifications Q2, Q3; research R4): the watchdog's
// fallback and stopped frame.
//
//   - Fallback: when a run swaps the live scene, the previous live scene is kept built as the fallback (the older
//     fallback is torn down), unless the watchdog had stopped it. A run whose files are the fallback's swaps the two
//     back without a new scene (the probe is the fallback's own cached program). `restoreFallback` (Reset) makes the
//     fallback live again and tears the stopped live scene down; nothing compiles. `setup` rebuilds the fallback from
//     its project after a context loss (a fallback that does not build is dropped) and `teardown` tears it down.
//   - Stopped frame: while the presenter says the preview is stopped, `drawFrame` draws ``stoppedScene``, a
//     `FullScreenShaderScene` of the flat colour ``stoppedColor``, built in `setup`, instead of the live scene.
//
// No GL call: everything is drawn by VisualCore's `FullScreenShaderScene` and `FieldPass`.
import Foundation
import ShaderStudioCore
import VisualCoreRendering
import VisualCoreShaderSource

/// What the preview shows about the last request (feature 160, data-model.md "PreviewStatus").
enum PreviewStatus: Equatable, Sendable {
    /// No request finished yet.
    case waiting
    /// The last request compiled and is drawn; the value lists its warnings (VisualCore reports none on success).
    case compiled([MappedDiagnostic])
    /// The last request failed to compile or link; the value lists its diagnostics. The last good shader is drawn.
    case failed([MappedDiagnostic])
    /// The validator refused the last request; nothing was compiled. The last good shader is drawn.
    case refused([ValidationIssue])

    /// "Waiting", "Compiled", "Compiled, N warnings", "Failed: N errors" (the error-severity diagnostics) or
    /// "Refused: <first issue code>".
    var text: String {
        switch self {
        case .waiting:
            return "Waiting"
        case .compiled(let warnings):
            if warnings.isEmpty { return "Compiled" }
            return "Compiled, \(warnings.count) " + (warnings.count == 1 ? "warning" : "warnings")
        case .failed(let diagnostics):
            let errors = diagnostics.filter { $0.severity == .error }.count
            return "Failed: \(errors) " + (errors == 1 ? "error" : "errors")
        case .refused(let issues):
            return "Refused: " + (issues.first?.code ?? "unknown")
        }
    }

    /// The diagnostics shown (the warnings of a compile or the errors of a failure); empty otherwise.
    var diagnostics: [MappedDiagnostic] {
        switch self {
        case .compiled(let list), .failed(let list): return list
        case .waiting, .refused: return []
        }
    }
}

/// The compile queue and the last-good preview (see the file header).
@MainActor
final class PreviewPipeline {
    /// The name the vertex shader carries in diagnostics.
    static let vertexName = "fullscreen.vert"

    /// The newest request not yet compiled; nil when there is none.
    private(set) var pending: ShaderProject?
    /// The scene drawn; nil while not set up.
    private(set) var live: (any PreviewScene)?
    /// The project the live scene draws: the last good one (the first template's before any success).
    private(set) var liveProject: ShaderProject
    /// How many compiles were attempted (one per request that passed the validator).
    private(set) var compileCount = 0
    /// What the preview shows about the last request.
    private(set) var status: PreviewStatus = .waiting
    /// How many times `setup` built the live scene.
    private(set) var setupCount = 0
    /// The previous live scene the watchdog had not stopped, kept built for Reset; nil when there is none.
    private(set) var fallback: (any PreviewScene)?
    /// The project ``fallback`` draws; kept across a context loss so the fallback is rebuilt.
    private(set) var fallbackProject: ShaderProject?
    /// The flat frame drawn while the preview is stopped; nil while not set up.
    private(set) var stoppedScene: FullScreenShaderScene?
    /// The colour of the stopped frame (linear RGB, as written by the fragment).
    static let stoppedColor: SIMD3<Float> = SIMD3(0.05, 0.05, 0.07)
    /// The fragment of the stopped frame.
    static let stoppedFragment = """
    precision mediump float;
    out vec4 fragColor;
    void main() { fragColor = vec4(0.05, 0.05, 0.07, 1.0); }
    """

    /// A pipeline whose first live scene draws `initial`.
    init(initial: ShaderProject) {
        liveProject = initial
    }

    /// Whether the live scene is set up.
    var isSetUp: Bool { live != nil }

    /// Keeps `project` as the one pending request (replacing an older one); nothing is compiled here.
    func submit(_ project: ShaderProject) {
        pending = project
    }

    /// The scene of `project`'s assembly: a ``TexturedPreview`` when it has texture inputs, otherwise the
    /// `FullScreenShaderScene` of A22-P02.
    static func scene(for project: ShaderProject) -> any PreviewScene {
        if !project.textureInputs.isEmpty { return TexturedPreview(project: project) }
        let assembly = ShaderAssembly(project: project)
        return FullScreenShaderScene(fragment: assembly.entryText, fragmentName: ShaderAssembly.entryFile,
                                     bundle: ShaderBundle(files: assembly.files))
    }

    /// Builds the live scene from ``liveProject`` (again after a context loss). The status becomes Compiled when no
    /// request finished yet; a live scene that fails to build reports the failure.
    func setup(_ context: RenderContext) throws {
        let scene = Self.scene(for: liveProject)
        try scene.setup(context)
        live = scene
        setupCount += 1
        let stopped = FullScreenShaderScene(fragment: Self.stoppedFragment, fragmentName: "ss/stopped.frag",
                                            bundle: ShaderBundle(files: [:]))
        try stopped.setup(context)
        stoppedScene = stopped
        if let project = fallbackProject {
            let kept = Self.scene(for: project)
            if (try? kept.setup(context)) != nil, kept.errorMessage == nil {
                fallback = kept
            } else {
                kept.teardown(context)
                fallback = nil
                fallbackProject = nil
            }
        }
        if let message = scene.errorMessage {
            status = .failed([MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .fragment,
                                               message: message)])
        } else if status == .waiting {
            status = .compiled([])
        }
    }

    /// Passes the drawable size to the live scene.
    func resize(_ context: RenderContext) {
        live?.resize(context)
    }

    /// Compiles the pending request (at most one per frame, see the file header), then draws the live scene with
    /// `parameters` (keyed by the uniform name without its `u_` prefix) and, for a textured scene, the recipe
    /// `textures[k]` on texture input `k`.
    /// `liveWasStopped` says the watchdog had stopped the live scene, so a swap does not keep it as the fallback;
    /// `stopped` draws the flat stopped frame instead of the live scene.
    func drawFrame(_ context: RenderContext, frame: FrameInfo, textures: [Int] = StudioCore.defaultTextures,
                   liveWasStopped: Bool = false, stopped: Bool = false,
                   parameters: (ShaderProject) -> [String: Double]) throws {
        if let request = pending {
            pending = nil
            process(request, context: context, liveWasStopped: liveWasStopped)
        }
        if stopped {
            try stoppedScene?.render(context, frame: frame)
            return
        }
        guard let live else { return }
        live.parameters = parameters(liveProject)
        if let textured = live as? TexturedPreview { textured.choices = textures }
        try live.render(context, frame: frame)
    }

    /// Validates and compiles `request`; swaps the live scene only on success.
    private func process(_ request: ShaderProject, context: RenderContext, liveWasStopped: Bool) {
        let issues = ShaderValidator.validate(request)
        guard issues.isEmpty else {
            status = .refused(issues)
            return
        }
        compileCount += 1
        let assembly = ShaderAssembly(project: request)
        let bundle = ShaderBundle(files: assembly.files)
        let probe: ShaderProgram
        do {
            probe = try context.resources.program(vertex: FullScreenShaderScene.vertexSource,
                                                  fragment: assembly.entryText, library: bundle.library,
                                                  vertexName: Self.vertexName, fragmentName: ShaderAssembly.entryFile)
        } catch let ShaderError.compile(found) {
            status = .failed(DiagnosticMapper.map(found))
            return
        } catch let ShaderError.link(found) {
            status = .failed(DiagnosticMapper.map(found))
            return
        } catch {
            status = .failed([MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .fragment,
                                               message: String(describing: error))])
            return
        }
        if live != nil, assembly == ShaderAssembly(project: liveProject) {
            // The same files as the live scene: the probe is the live scene's own cached program.
            liveProject = request
            status = .compiled([])
            return
        }
        if let kept = fallback, let keptProject = fallbackProject, assembly == ShaderAssembly(project: keptProject) {
            // The fallback's files: the probe is the fallback's own cached program; the two scenes change places.
            fallback = nil
            fallbackProject = nil
            retire(context, keep: !liveWasStopped)
            live = kept
            liveProject = request
            status = .compiled([])
            return
        }
        let compilesBefore = context.resources.compileCount
        let scene = Self.scene(for: request)
        do {
            try scene.setup(context)
        } catch {
            scene.teardown(context)
            context.resources.release(probe)
            status = .failed([MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .fragment,
                                               message: String(describing: error))])
            return
        }
        if context.resources.compileCount > compilesBefore {
            context.resources.release(probe)   // the scene compiled its own program; the probe is not shared
        }
        if let message = scene.errorMessage {
            scene.teardown(context)
            status = .failed([MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .fragment,
                                               message: message)])
            return
        }
        if !liveWasStopped {
            fallback?.teardown(context)
            fallback = nil
            fallbackProject = nil
        }
        retire(context, keep: !liveWasStopped)
        live = scene
        liveProject = request
        status = .compiled([])
    }

    /// Moves the live scene into the fallback slot (with `keep`; the caller has emptied the slot) or tears it down
    /// (a live scene the watchdog stopped is never a fallback; the older fallback then stays).
    private func retire(_ context: RenderContext, keep: Bool) {
        if keep, let current = live {
            fallback = current
            fallbackProject = liveProject
        } else {
            live?.teardown(context)
        }
        live = nil
    }

    /// Reset (feature 162): makes the fallback live again and tears the current live scene down, with no compile.
    /// Returns false, changing nothing, when there is no fallback.
    @discardableResult
    func restoreFallback(_ context: RenderContext) -> Bool {
        guard let kept = fallback, let keptProject = fallbackProject else { return false }
        live?.teardown(context)
        live = kept
        liveProject = keptProject
        fallback = nil
        fallbackProject = nil
        status = .compiled([])
        return true
    }

    /// Tears the scenes down and drops a pending request; the last good project stays for the next `setup`.
    func teardown(_ context: RenderContext) {
        pending = nil
        live?.teardown(context)
        live = nil
        fallback?.teardown(context)
        fallback = nil
        stoppedScene?.teardown(context)
        stoppedScene = nil
    }
}
