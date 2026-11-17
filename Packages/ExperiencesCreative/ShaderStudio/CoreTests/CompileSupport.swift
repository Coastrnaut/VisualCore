// CompileSupport — feature 159 (A22-P01) T-A22-107, T-A22-111 (research D5; clarification Q5). The off-screen compile
// helper the line-mapping and template tests share: `AssemblyCompileScene` compiles an assembly's entry
// (`ss/main.frag`) with `FullScreenShaderScene.vertexSource` through `context.resources.program(...)`, the path
// `FullScreenShaderScene` uses, with a `ShaderLibrary` of `ShaderBundle.visualCoreLibrary` plus the assembly's files
// (and any test-only includes); it keeps the `ShaderError` diagnostics and the linked program. It compiles only and
// draws nothing itself: no GL call outside VisualCore (`scripts/check_app_isolation.py`). Drawing a template goes
// through `FullScreenShaderScene` (``AssemblyCompiler/drawingScene(for:)``).
import ShaderStudioCore
import UIKit
import VisualCoreRendering
import VisualCoreShaderSource

/// A render scene that compiles one ``ShaderAssembly`` and draws it over the whole target.
@MainActor
final class AssemblyCompileScene: RenderScene {
    let assembly: ShaderAssembly
    let extraFiles: [String: String]
    /// The linked program, when the compile succeeded.
    private(set) var program: ShaderProgram?
    /// The compile or link diagnostics, when the compile failed.
    private(set) var diagnostics: [ShaderDiagnostic] = []
    /// Any other failure (a source error from the expansion), described.
    private(set) var otherFailure: String?
    private var size = SIMD2<Float>(1, 1)

    init(assembly: ShaderAssembly, extraFiles: [String: String] = [:]) {
        self.assembly = assembly
        self.extraFiles = extraFiles
    }

    /// The library the entry is expanded with: the `vc/` includes, the assembly's files and the extra files.
    var library: ShaderLibrary {
        var library = ShaderLibrary()
        for (name, text) in ShaderBundle.visualCoreLibrary { library.add(name, text) }
        for (name, text) in assembly.files { library.add(name, text) }
        for (name, text) in extraFiles { library.add(name, text) }
        return library
    }

    func setup(_ context: RenderContext) throws {
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
        do {
            program = try context.resources.program(vertex: FullScreenShaderScene.vertexSource,
                                                    fragment: assembly.entryText, library: library,
                                                    vertexName: "fullscreen.vert",
                                                    fragmentName: ShaderAssembly.entryFile)
        } catch let ShaderError.compile(found) {
            diagnostics = found
        } catch let ShaderError.link(found) {
            diagnostics = found
        } catch {
            otherFailure = String(describing: error)
        }
    }

    func resize(_ context: RenderContext) {
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
    }

    /// Draws nothing: this scene only compiles (the host clears the frame).
    func render(_ context: RenderContext, frame: FrameInfo) throws {}

    func teardown(_ context: RenderContext) {
        if let program { context.resources.release(program) }
        program = nil
    }
}

/// Compiling assemblies on a small live host.
@MainActor
enum AssemblyCompiler {
    /// A host whose scene has been set up (compiled) and has drawn one frame on a 16 × 12 surface.
    static func host(_ scene: AssemblyCompileScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        _ = host.renderOneFrame(present: false)
        return host
    }

    /// A full-screen scene drawing `assembly` through VisualCore, with each declared uniform `u_<name>` set from
    /// `values` (keyed by the full uniform name, as `ParameterDefinition.name` holds it).
    static func drawingScene(for assembly: ShaderAssembly, values: [String: Double]) -> FullScreenShaderScene {
        let scene = FullScreenShaderScene(fragment: assembly.entryText, fragmentName: ShaderAssembly.entryFile,
                                          bundle: ShaderBundle(files: assembly.files))
        var parameters: [String: Double] = [:]
        for (name, value) in values where name.hasPrefix("u_") { parameters[String(name.dropFirst(2))] = value }
        scene.parameters = parameters
        return scene
    }

    /// The mapped diagnostics of compiling `source` in the template (empty when it links), with `extraFiles` as
    /// further includes; the host is destroyed before returning.
    static func mappedDiagnostics(of source: String, extraFiles: [String: String] = [:]) throws
        -> (mapped: [MappedDiagnostic], raw: [ShaderDiagnostic], otherFailure: String?, linked: Bool) {
        let scene = AssemblyCompileScene(assembly: ShaderAssembly(source: source), extraFiles: extraFiles)
        let host = try host(scene)
        defer { host.destroy() }
        let linked = scene.program != nil
        if !scene.diagnostics.isEmpty {
            print("shader-studio diagnostics: \(scene.diagnostics.map(\.description))")
        }
        return (DiagnosticMapper.map(scene.diagnostics), scene.diagnostics, scene.otherFailure, linked)
    }
}
