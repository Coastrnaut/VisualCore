// SampleScenes.swift — minimal independent scenes proving the host renders (feature 003 T-F210; FR-F212).
// Since feature 004 (T-F316) the gradient compiles through the shared shader service.
import CVisualCoreGL

/// Clears the window to one color.
@MainActor
public final class ClearColorScene: RenderScene {
    public var red: Float, green: Float, blue: Float

    public init(red: Float = 0, green: Float = 0, blue: Float = 0) {
        self.red = red; self.green = green; self.blue = blue
    }

    public func setup(_ context: RenderContext) throws {}
    public func resize(_ context: RenderContext) {}
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(red, green, blue, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    public func teardown(_ context: RenderContext) {}
}

/// A full-screen triangle shaded red (left) to blue (right).
@MainActor
public final class GradientQuadScene: RenderScene {
    private var program: ShaderProgram?

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

    public func setup(_ context: RenderContext) throws {
        program = try context.resources.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    public func resize(_ context: RenderContext) {}

    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        program?.use()
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    public func teardown(_ context: RenderContext) {
        if let program { context.resources.release(program) }
        program = nil
    }
}
