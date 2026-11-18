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
    func drawFrame(_ context: RenderContext, frame: FrameInfo, textures: [Int] = StudioCore.defaultTextures,
                   parameters: (ShaderProject) -> [String: Double]) throws {
        if let request = pending {
            pending = nil
            process(request, context: context)
        }
        guard let live else { return }
        live.parameters = parameters(liveProject)
        if let textured = live as? TexturedPreview { textured.choices = textures }
        try live.render(context, frame: frame)
    }

    /// Validates and compiles `request`; swaps the live scene only on success.
    private func process(_ request: ShaderProject, context: RenderContext) {
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
        live?.teardown(context)
        live = scene
        liveProject = request
        status = .compiled([])
    }

    /// Tears the scenes down and drops a pending request; the last good project stays for the next `setup`.
    func teardown(_ context: RenderContext) {
        pending = nil
        live?.teardown(context)
        live = nil
    }
}
