// SampleScenes.swift — minimal independent scenes proving the host renders (feature 003 T-F210; FR-F212).
// Since feature 004 (T-F316) the gradient compiles through the shared shader service.
import CVisualCoreGL

/// Clears the window to one color.
@MainActor
public final class ClearColorScene: RenderScene {
    /// Clear color components (0…1); alpha is always 1.
    public var red: Float, green: Float, blue: Float

    /// Creates the scene with the given clear color (black by default).
    public init(red: Float = 0, green: Float = 0, blue: Float = 0) {
        self.red = red; self.green = green; self.blue = blue
    }

    /// No GPU objects to create.
    public func setup(_ context: RenderContext) throws {}
    /// Nothing depends on size.
    public func resize(_ context: RenderContext) {}
    /// Clears the bound framebuffer to the clear color.
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(red, green, blue, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    /// No GPU objects to release.
    public func teardown(_ context: RenderContext) {}
}

/// A full-screen triangle shaded red (left) to blue (right).
@MainActor
public final class GradientQuadScene: RenderScene {
    private var program: ShaderProgram?

    /// Creates the scene; its program is compiled in `setup`.
    public init() {}

    static let vertexSource = """
    out vec2 uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec2 uv;
    out vec4 color;
    void main() { color = vec4(mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), clamp(uv.x, 0.0, 1.0)), 1.0); }
    """

    /// Compiles (or reuses from the cache) the gradient program.
    public func setup(_ context: RenderContext) throws {
        program = try context.resources.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    /// Nothing depends on size; the triangle covers any viewport.
    public func resize(_ context: RenderContext) {}

    /// Clears to black and draws the full-screen gradient triangle.
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        program?.use()
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    /// Releases the gradient program to the registry.
    public func teardown(_ context: RenderContext) {
        if let program { context.resources.release(program) }
        program = nil
    }
}
