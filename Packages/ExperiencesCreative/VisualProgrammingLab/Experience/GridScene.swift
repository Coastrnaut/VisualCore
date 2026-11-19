// GridScene — feature 167 (A23-P02) T-A23-206 (FR-A23-201, FR-A23-206; clarification Q4; plan.md "Lifecycle"); drawn
// by a field pass since feature 168 (A23-P03) T-A23-304 (FR-A23-307; research D7). The canvas background of Visual
// Programming Lab: one full-screen fragment shader (GLSL ES 3.00, inline source) drawn by VisualCore's `FieldPass`
// into the context's framebuffer at the drawable's full size, inside the host's context and registry; no context and
// no GL call of its own. A field pass sets the viewport to its output and leaves it there, so drawing the grid first
// in every frame at the full size gives every frame the whole drawable, whatever the preview's inset pass set last.
//
// Mapping: the drawable covers the whole canvas view, so `v_uv` (0…1, origin bottom-left) maps to the view point
// (`v_uv.x × u_width`, `(1 − v_uv.y) × u_height`) (origin top-left, y down), and that point to the canvas point
// `centre + (point − size / 2) / zoom`, exactly as `CanvasView.canvas(fromScreen:)` maps it. The parameters (bound as
// `u_<name>` floats, the active ones only) are `zoom` (screen points per canvas point), `panX` and `panY` (the canvas
// point at the view's middle: the pan) and `width` and `height` (the view in points). The picture therefore depends
// only on the view state, never on the drawable's pixel size beyond its sampling, nor on the frame time.
//
// Picture: a dark slate background with a soft vignette and minor lines every 32 canvas points and major lines every
// 160, each about one pixel wide (full within 0.5 pixels of the line, fading out by 1.5, through `fwidth`, so a line
// never falls between pixel centres; the vignette keeps a luma spread in every frame, as the verification runner's
// non-blank check asks). Every colour keeps a Rec. 709 luma below 40 of 255, so the whole canvas is of the colour
// class `dark` (the presenter's frame probe). A fragment that does not build sets ``errorMessage`` and draws nothing.
import VisualCoreRendering

/// The canvas grid as one full-screen field pass.
@MainActor
final class GridScene {
    /// The fragment's name in diagnostics.
    static let fragmentName = "vpl-canvas-grid.frag"
    /// The spacing of the minor lines, canvas points.
    nonisolated static let minorSpacing = 32.0
    /// The spacing of the major lines, canvas points.
    nonisolated static let majorSpacing = 160.0

    /// The fragment shader (GLSL ES 3.00, see the file header).
    static let fragment = """
    precision highp float;
    in vec2 v_uv;
    uniform float u_zoom;
    uniform float u_panX;
    uniform float u_panY;
    uniform float u_width;
    uniform float u_height;
    out vec4 color;

    // How much of a line of `spacing` canvas points covers this fragment: its distance in pixels (through `fwidth`, so
    // a line is at least one pixel wide whatever the ratio of points to pixels), full within 0.5 pixels, gone by 1.5.
    float lineCover(float c, float spacing) {
        float pixel = max(fwidth(c), 1e-4);
        float d = abs(fract(c / spacing + 0.5) - 0.5) * spacing / pixel;
        return 1.0 - smoothstep(0.5, 1.5, d);
    }

    void main() {
        float zoom = max(u_zoom, 1e-3);
        vec2 size = vec2(max(u_width, 1.0), max(u_height, 1.0));
        vec2 view = vec2(v_uv.x * size.x, (1.0 - v_uv.y) * size.y);
        vec2 canvas = vec2(u_panX, u_panY) + (view - 0.5 * size) / zoom;
        float minor = max(lineCover(canvas.x, 32.0), lineCover(canvas.y, 32.0));
        float major = max(lineCover(canvas.x, 160.0), lineCover(canvas.y, 160.0));
        // A soft vignette, brighter at the middle (luma about 26 of 255) than at the corners (about 12), so every
        // frame has a luma spread above the runner's 8 even where no line falls on a pixel centre.
        float vignette = clamp(length(v_uv - 0.5) * 1.41421356, 0.0, 1.0);
        vec3 background = mix(vec3(0.09, 0.10, 0.125), vec3(0.04, 0.045, 0.06), vignette);
        vec3 minorColour = vec3(0.10, 0.115, 0.14);
        vec3 majorColour = vec3(0.13, 0.145, 0.18);
        vec3 c = mix(background, minorColour, minor);
        c = mix(c, majorColour, major);
        color = vec4(c, 1.0);
    }
    """

    /// The fragment drawn: ``fragment`` or the test seam's override.
    let source: String
    /// The parameters of the next frame.
    private(set) var parameters: [String: Double] = [:]
    /// The field pass; nil while not set up or after a build failure.
    private(set) var pass: FieldPass?
    /// The first build diagnostic, or nil.
    private(set) var errorMessage: String?

    /// A grid running ``fragment``, or `fragmentOverride` when given (a test seam).
    init(fragmentOverride: String? = nil) {
        source = fragmentOverride ?? Self.fragment
    }

    /// The parameters of the view: `zoom`, `panX`, `panY`, `width` and `height` (see the file header).
    nonisolated static func parameters(zoom: Double, centreX: Double, centreY: Double, width: Double,
                                       height: Double) -> [String: Double] {
        ["zoom": zoom, "panX": centreX, "panY": centreY, "width": width, "height": height]
    }

    /// Sets what the next frame draws.
    func configure(_ parameters: [String: Double]) {
        self.parameters = parameters
    }

    /// Builds the program in the host's context (again after a context loss).
    func setup(_ context: RenderContext) throws {
        pass?.release()
        pass = nil
        do {
            pass = try FieldPass(registry: context.resources, fragment: source, inputs: [], label: Self.fragmentName)
            errorMessage = nil
        } catch {
            if case .compile(let message) = error { errorMessage = message } else { errorMessage = "\(error)" }
        }
    }

    /// Nothing to do: the grid reads the drawable's size from each frame's context.
    func resize(_ context: RenderContext) {}

    /// The active float uniforms `u_<name>` of the parameters.
    func uniforms(_ program: ShaderProgram) -> [String: FieldUniform] {
        var uniforms: [String: FieldUniform] = [:]
        for (name, value) in parameters where program.uniforms["u_" + name] != nil {
            uniforms["u_" + name] = .float(Float(value))
        }
        return uniforms
    }

    /// Draws the grid over the whole drawable (nothing when the program did not build).
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let pass else { return }
        try pass.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth,
                                          height: context.pixelHeight),
                     inputs: [:], uniforms: uniforms(pass.program))
    }

    /// Releases the program.
    func teardown(_ context: RenderContext) {
        pass?.release()
        pass = nil
    }
}
