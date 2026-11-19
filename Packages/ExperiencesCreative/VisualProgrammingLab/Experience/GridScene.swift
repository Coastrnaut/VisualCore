// GridScene — feature 167 (A23-P02) T-A23-206 (FR-A23-201, FR-A23-206; clarification Q4; plan.md "Lifecycle"). The
// canvas background of Visual Programming Lab: one full-screen fragment shader (GLSL ES 3.00, inline source with the
// VisualCore includes, `ShaderBundle(files: [:])`) drawn by VisualCore's `FullScreenShaderScene` inside the host's
// context and registry; no context and no GL call of its own.
//
// Mapping: the drawable covers the whole canvas view, so `v_uv` (0…1, origin bottom-left) maps to the view point
// (`v_uv.x × u_width`, `(1 − v_uv.y) × u_height`) (origin top-left, y down), and that point to the canvas point
// `centre + (point − size / 2) / zoom`, exactly as `CanvasView.canvas(fromScreen:)` maps it. The parameters (bound as
// `u_<name>` floats by the scene) are `zoom` (screen points per canvas point), `panX` and `panY` (the canvas point at
// the view's middle: the pan) and `width` and `height` (the view in points). The picture therefore depends only on
// the view state, never on the drawable's pixel size beyond its sampling.
//
// Picture: a dark slate background with a soft vignette and minor lines every 32 canvas points and major lines every
// 160, each about one pixel wide (full within 0.5 pixels of the line, fading out by 1.5, through `fwidth`, so a line
// never falls between pixel centres; the vignette keeps a luma spread in every frame, as the verification runner's
// non-blank check asks). Every colour keeps a Rec. 709 luma below 40 of 255, so the whole canvas is of the colour
// class `dark` (the presenter's frame probe).
import VisualCoreRendering

/// The canvas grid as one full-screen shader.
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

    /// The full-screen scene that runs the fragment.
    let inner: FullScreenShaderScene

    /// A scene running ``fragment``, or `fragmentOverride` when given (a test seam).
    init(fragmentOverride: String? = nil) {
        inner = FullScreenShaderScene(fragment: fragmentOverride ?? Self.fragment, fragmentName: Self.fragmentName,
                                      bundle: ShaderBundle(files: [:]))
        inner.fixedTime = 0
    }

    /// The shader's first compile or link diagnostic, or nil.
    var errorMessage: String? { inner.errorMessage }

    /// The parameters of the view: `zoom`, `panX`, `panY`, `width` and `height` (see the file header).
    nonisolated static func parameters(zoom: Double, centreX: Double, centreY: Double, width: Double,
                                       height: Double) -> [String: Double] {
        ["zoom": zoom, "panX": centreX, "panY": centreY, "width": width, "height": height]
    }

    /// Sets what the next frame draws.
    func configure(_ parameters: [String: Double]) {
        inner.parameters = parameters
    }

    /// Builds the program in the host's context (again after a context loss).
    func setup(_ context: RenderContext) throws {
        try inner.setup(context)
    }

    /// Passes the new drawable size on.
    func resize(_ context: RenderContext) {
        inner.resize(context)
    }

    /// Draws the grid.
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try inner.render(context, frame: frame)
    }

    /// Releases the program.
    func teardown(_ context: RenderContext) {
        inner.teardown(context)
    }
}
