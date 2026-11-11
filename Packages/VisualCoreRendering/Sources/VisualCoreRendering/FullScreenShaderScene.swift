// FullScreenShaderScene.swift — draws one fragment shader over the whole view with standard uniforms bound from a
// value snapshot (feature 012 T-A01-104; FR-A01-108; research R4/R8).
import CVisualCoreGL
import VisualCoreShaderSource

/// A RenderScene that runs a fragment shader over the full view. Binds, when the shader declares them:
/// `u_time` (`fixedTime`, else frame time × `timeScale`), `u_resolution` (pixels), `u_seed` (vec4 offsets),
/// `u_palette[8]`/`u_paletteCount` (linear-light stops) and one float `u_<name>` per entry of `parameters`.
/// The vertex shader provides `in vec2 v_uv` (0…1, origin bottom-left). Compile errors set `errorMessage`
/// (`file:line: message`) and the scene clears to dark gray instead of throwing.
@MainActor
public final class FullScreenShaderScene: RenderScene {
    /// Maximum palette stops passed to the shader.
    public static let maxPaletteStops = 8
    /// The built-in full-screen triangle vertex shader.
    public static let vertexSource = """
    out vec2 v_uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        v_uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """

    /// Parameter values bound as `u_<name>` floats.
    public var parameters: [String: Double] = [:]
    /// Palette stops in linear light (at most 8 are used).
    public var palette: [SIMD3<Float>] = []
    /// Seed-derived offsets bound as `u_seed`.
    public var seedOffsets: SIMD4<Float> = .zero
    /// When set, the time every frame renders at (deterministic previews and tests).
    public var fixedTime: Double?
    /// Multiplier on frame time when `fixedTime` is nil (for example 0.5 under Reduce Motion).
    public var timeScale: Double = 1
    /// The first compile or link diagnostic as `file:line: message`, or nil.
    public private(set) var errorMessage: String?

    private let fragment: String
    private let fragmentName: String
    private let bundle: ShaderBundle
    private var program: ShaderProgram?
    private var size = SIMD2<Float>(1, 1)

    /// A scene running `fragment` (named `fragmentName` in diagnostics) with includes from `bundle`.
    public init(fragment: String, fragmentName: String, bundle: ShaderBundle) {
        self.fragment = fragment
        self.fragmentName = fragmentName
        self.bundle = bundle
    }

    /// A scene running the bundle file `fragmentName`; a missing file is reported through `errorMessage`.
    public convenience init(fragmentName: String, bundle: ShaderBundle) {
        self.init(fragment: bundle.source(fragmentName) ?? "", fragmentName: fragmentName, bundle: bundle)
    }

    /// Compiles the program; failures go to `errorMessage`.
    public func setup(_ context: RenderContext) throws {
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
        guard !fragment.isEmpty else { errorMessage = "\(fragmentName): shader file not found"; return }
        do {
            program = try context.resources.program(vertex: Self.vertexSource, fragment: fragment, library: bundle.library,
                                                    vertexName: "fullscreen.vert", fragmentName: fragmentName)
            errorMessage = nil
        } catch let ShaderError.compile(diagnostics) {
            errorMessage = diagnostics.first.map { "\($0.file):\($0.line): \($0.message)" } ?? "\(fragmentName): compile failed"
        } catch {
            errorMessage = "\(fragmentName): \(error)"
        }
    }

    /// Records the new pixel size for `u_resolution`.
    public func resize(_ context: RenderContext) {
        size = SIMD2(Float(max(1, context.pixelWidth)), Float(max(1, context.pixelHeight)))
    }

    /// Draws the shader, or clears to dark gray when it failed to build.
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let program else {
            vcglClearColor(0.1, 0.1, 0.1, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            return
        }
        program.use()
        let has = program.uniforms
        if has["u_time"] != nil { program.set("u_time", Float(fixedTime ?? frame.time * timeScale)) }
        if has["u_resolution"] != nil { program.set("u_resolution", size) }
        if has["u_seed"] != nil { program.set("u_seed", seedOffsets) }
        if has["u_palette"] != nil, !palette.isEmpty {
            let stops = Array(palette.prefix(Self.maxPaletteStops))
            program.set("u_palette", vec3Array: stops)
            if has["u_paletteCount"] != nil { program.set("u_paletteCount", Int32(stops.count)) }
        }
        for (name, value) in parameters where has["u_" + name] != nil { program.set("u_" + name, Float(value)) }
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    /// Releases the program.
    public func teardown(_ context: RenderContext) {
        if let program { context.resources.release(program) }
        program = nil
    }
}
