// SandScene — feature 146 (A20-P02) T-A20-204 (FR-A20-202, FR-A20-203, FR-A20-207; clarification Q1; data-model.md
// "SandScene"; contracts/experience.md "Sand"; gaps G-SAND and G-RELIEF). The drawn sand of Digital Zen Garden:
//
//   - Field: a 480 × 360 `SandField` on the CPU. The committed strokes are stamped once into the base field; the
//     stroke in progress is stamped over a copy of the base (the shown field) whenever it changes, and on commit the
//     stroke is stamped into the base itself. `rebuild(from:)` replays the strokes into a fresh base (after undo,
//     redo, restore, resize or a lost context); `sync(strokes:pending:)` decides between a commit and a rebuild.
//   - Target: one render target of the field's size in the format `FloatRenderSupport.storageFormat(forceFallback:)`
//     picks: `rgba16f` holds the height itself, the `rgba8` fallback holds height × 0.5 + 0.5. The shown field is
//     uploaded with `RenderTarget.upload(rgbaFloats:)` (rows bottom-up) only when it changed.
//     A read-back target matches the shown field within 1/1024 (`rgba16f`) or 1/255 (`rgba8`) in stored values.
//   - Relief: one `FieldPass` over the framebuffer. Inside the tray (4:3, fitted to the view with a margin, `TrayFit`)
//     the height is read exactly (`vc_fieldBilinear`), the normal comes from the height differences of the
//     neighbouring cells, one light falls from the upper left, the sand tone (linear light) is the albedo and at
//     level-0 (the full level) a `vc_fbm` grain varies it; outside the tray a dark neutral. Equal inputs give identical pixels.
//
// Feature 147 (A20-P03) T-A20-303 (FR-A20-302, FR-A20-306; clarification Q1; contracts/stones.md "Drawing"; gaps
// G-STONES, G-SHADOWS). The stones are a second CPU layer drawn by the same pass:
//
//   - Stone layer: a 480 × 360 `StoneLayer` of the garden's stones (rasterized in ascending depth), rebuilt by
//     `syncStones(_:)` whenever the stones differ from the ones it holds and by `rebuildStones(from:)` (after undo, redo,
//     restore, resize or a lost context).
//   - Stone target: a second render target of the same size and format, holding per cell (height, (kind + 1)/5, 0, 1)
//     in both formats (every value lies in 0…1, so the `rgba8` fallback needs no offset); uploaded only when the layer
//     changed. A read-back matches the layer within 1/1024 (`rgba16f`) or 1/255 (`rgba8`).
//   - Relief: where a stone lies (kind > 0) the pixel takes the kind's colour (five calm stone colours, linear light),
//     lit by the same light from the normal of the stone's height; elsewhere the sand is darkened by a soft shadow of
//     five taps toward the light (2, 4, …, 10 cells), each occluded when the stone height there times 12 cells reaches
//     beyond the tap, so a taller stone casts a longer shadow.
//
// Feature 149 (A20-P05) T-A20-503 (FR-A20-502, FR-A20-503; clarification Q2; data-model.md "Drift"; gap G-QUIET).
// The sand drift moves the grain only: `grainOffset` (tray widths, set by the presenter: 0.01 per second of frame time
// with `calm.drift` on and Reduce Motion off, otherwise 0) shifts the `vc_fbm` grain sideways by `u_grainOffset` tray
// widths. The relief, the stones and their shadows never move, nothing flashes, and with the offset at 0 the picture is
// exactly the A20-P04 one. The step of mean luminance between two drift frames stays below `maxFrameLuminanceStep`.
//
// No GL call: the target, the upload and the pass are VisualCoreRendering's, used inside the host's scene callbacks.
import Foundation
import DigitalZenGardenCore
import VisualCoreMath
import VisualCoreRendering

/// The 4:3 tray fitted inside a view: the largest 4:3 rectangle inside the view less a margin, centred.
enum TrayFit {
    /// The margin around the tray as a share of the view's shorter side.
    static let marginShare = 0.04

    /// The tray rectangle inside a view of `width` × `height` (any unit), origin top-left: x, y, width, height.
    /// A view that is not positive gives a zero rectangle.
    static func rect(width: Double, height: Double) -> (x: Double, y: Double, width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return (0, 0, 0, 0) }
        let margin = marginShare * min(width, height)
        let available = (max(width - 2 * margin, 0), max(height - 2 * margin, 0))
        let aspect = GardenPalette.smallTray.aspect
        let trayWidth: Double
        let trayHeight: Double
        if available.0 / max(available.1, .leastNonzeroMagnitude) > aspect {
            trayHeight = available.1
            trayWidth = trayHeight * aspect
        } else {
            trayWidth = available.0
            trayHeight = trayWidth / aspect
        }
        return ((width - trayWidth) / 2, (height - trayHeight) / 2, trayWidth, trayHeight)
    }

    /// The normalized tray position (0…1 each when inside) of the view point `point` (origin top-left) in a view of
    /// `size`; nil when the tray is empty.
    static func trayPoint(_ point: Vec2, viewSize size: Vec2) -> Vec2? {
        let tray = rect(width: size.x, height: size.y)
        guard tray.width > 0, tray.height > 0 else { return nil }
        return Vec2((point.x - tray.x) / tray.width, (point.y - tray.y) / tray.height)
    }

    /// Whether `point` lies inside the tray (0…1 on both axes).
    static func isInside(_ point: Vec2) -> Bool {
        point.isFinite && (0...1).contains(point.x) && (0...1).contains(point.y)
    }

    /// `point` clamped to the tray (0…1 on both axes).
    static func clamped(_ point: Vec2) -> Vec2 {
        Vec2(min(max(point.x, 0), 1), min(max(point.y, 0), 1))
    }
}

/// Draws the sand of the garden (see the file header).
@MainActor
final class SandScene: RenderScene {
    /// The number of columns of the drawn field.
    static let columns = 480
    /// The number of rows of the drawn field.
    static let rows = 360
    /// The colour outside the tray (sRGB): a dark neutral.
    static let surround = SIMD3<Float>(0.075, 0.075, 0.08)

    /// The five stone colours (sRGB), by index of `GardenPalette.stones`: a grey pebble, a blue-grey slate, a warm
    /// light granite, a dark basalt and a muted moss green (feature 147).
    static let stoneColors: [SIMD3<Float>] = [SIMD3(0.56, 0.56, 0.54), SIMD3(0.37, 0.40, 0.43),
                                              SIMD3(0.67, 0.63, 0.58), SIMD3(0.23, 0.23, 0.25),
                                              SIMD3(0.43, 0.48, 0.37)]
    /// The distance between shadow taps, in cells (feature 147).
    static let shadowTapCells = 2.0
    /// The shadow length of a stone of height 1, in cells (feature 147).
    static let shadowLengthCells = 12.0
    /// How much a full shadow darkens the sand (feature 147).
    static let shadowStrength = 0.4

    /// The relief fragment (see the file header). Uniforms: `u_sand` (the field), `u_tray` (x, y, width, height in
    /// framebuffer pixels, origin bottom-left), `u_tone` (the sand tone, sRGB, alpha 1), `u_decode` (scale and
    /// offset from the stored value to the height), `u_grain` (0 or 1) and `u_grainOffset` (the drift of the grain in
    /// tray widths; feature 149).
    static let reliefFragment = """
    precision highp float;
    #include "vc/hash.glsl"
    #include "vc/noise.glsl"
    #include "vc/field.glsl"
    #include "vc/color.glsl"
    in vec2 v_uv;
    uniform sampler2D u_sand;
    uniform sampler2D u_stones;
    uniform vec4 u_tray;
    uniform vec4 u_tone;
    uniform vec2 u_decode;
    uniform float u_grain;
    uniform float u_grainOffset;
    out vec4 color;

    float zg_height(vec2 cell) {
        return vc_fieldBilinear(u_sand, cell).r * u_decode.x + u_decode.y;
    }

    float zg_stoneHeight(vec2 cell) {
        return vc_fieldBilinear(u_stones, cell).r;
    }

    vec3 zg_stoneColor(int kind) {
        if (kind == 0) return vec3(\(SandScene.stoneColors[0].x), \(SandScene.stoneColors[0].y), \(SandScene.stoneColors[0].z));
        if (kind == 1) return vec3(\(SandScene.stoneColors[1].x), \(SandScene.stoneColors[1].y), \(SandScene.stoneColors[1].z));
        if (kind == 2) return vec3(\(SandScene.stoneColors[2].x), \(SandScene.stoneColors[2].y), \(SandScene.stoneColors[2].z));
        if (kind == 3) return vec3(\(SandScene.stoneColors[3].x), \(SandScene.stoneColors[3].y), \(SandScene.stoneColors[3].z));
        return vec3(\(SandScene.stoneColors[4].x), \(SandScene.stoneColors[4].y), \(SandScene.stoneColors[4].z));
    }

    void main() {
        vec2 t = (gl_FragCoord.xy - u_tray.xy) / max(u_tray.zw, vec2(1.0));
        if (t.x < 0.0 || t.y < 0.0 || t.x > 1.0 || t.y > 1.0) {
            color = vec4(\(SandScene.surround.x), \(SandScene.surround.y), \(SandScene.surround.z), 1.0);
            return;
        }
        vec2 size = vec2(textureSize(u_sand, 0));
        vec2 cell = t * size;
        vec3 light = normalize(vec3(-0.55, 0.6, 0.58));
        float facing = light.z;
        float edge = min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y) * 0.75);
        float rim = 0.82 + 0.18 * smoothstep(0.0, 0.012, edge);
        vec4 stone = vc_fieldTexel(u_stones, ivec2(floor(cell)));
        int kind = int(floor(stone.g * 5.0 + 0.5)) - 1;
        if (kind >= 0) {
            float sh = zg_stoneHeight(cell);
            float sx = zg_stoneHeight(cell + vec2(1.0, 0.0)) - zg_stoneHeight(cell - vec2(1.0, 0.0));
            float sy = zg_stoneHeight(cell + vec2(0.0, 1.0)) - zg_stoneHeight(cell - vec2(0.0, 1.0));
            vec3 sn = normalize(vec3(-6.0 * sx, -6.0 * sy, 1.0));
            float stoneShade = 0.32 + 0.68 * clamp(dot(sn, light), 0.0, 1.0) / facing;
            vec3 stoneAlbedo = vc_srgbDecode(zg_stoneColor(kind)) * (0.86 + 0.14 * sh);
            vec3 stoneLit = clamp(stoneAlbedo * stoneShade * rim, 0.0, 1.0);
            color = vec4(clamp(vc_srgbEncode(stoneLit), 0.0, 1.0), 1.0);
            return;
        }
        float h = zg_height(cell);
        float dx = zg_height(cell + vec2(1.0, 0.0)) - zg_height(cell - vec2(1.0, 0.0));
        float dy = zg_height(cell + vec2(0.0, 1.0)) - zg_height(cell - vec2(0.0, 1.0));
        vec3 n = normalize(vec3(-0.45 * dx, -0.45 * dy, 1.0));
        float shade = 0.3 + 0.7 * clamp(dot(n, light), 0.0, 1.0) / facing;
        vec2 toLight = normalize(light.xy);
        float occlusion = 0.0;
        for (int k = 1; k <= 5; k++) {
            float d = float(k) * \(SandScene.shadowTapCells);
            float tapHeight = zg_stoneHeight(cell + toLight * d);
            occlusion += smoothstep(0.0, 2.0, tapHeight * \(SandScene.shadowLengthCells) - d);
        }
        shade *= 1.0 - \(SandScene.shadowStrength) * occlusion / 5.0;
        vec3 albedo = vc_srgbDecode(u_tone.rgb) * (0.94 + 0.06 * clamp(h, -1.0, 1.0));
        float grain = vc_fbm((gl_FragCoord.xy + vec2(u_grainOffset * u_tray.z, 0.0)) * 0.45, 3, 2.0, 0.5);
        albedo *= 1.0 + u_grain * 0.08 * grain;
        vec3 lit = clamp(albedo * shade * rim, 0.0, 1.0);
        color = vec4(clamp(vc_srgbEncode(lit), 0.0, 1.0), 1.0);
    }
    """

    /// Whether the 8-bit fallback is used even where half floats render (tests).
    let forceFallback: Bool
    /// The base field: every committed stroke, in order.
    private(set) var base = SandField(columns: SandScene.columns, rows: SandScene.rows)
    /// The shown field: the base with the stroke in progress stamped over it.
    private(set) var shown = SandField(columns: SandScene.columns, rows: SandScene.rows)
    /// The strokes the base field holds.
    private(set) var baseStrokes: [RakeStroke] = []
    /// The stroke in progress stamped into the shown field; nil when none is.
    private(set) var shownPending: RakeStroke?
    /// The render target of the field; nil before `setup` and after `teardown`.
    private(set) var target: RenderTarget?
    /// The stone layer drawn (feature 147).
    private(set) var stones = StoneLayer()
    /// The stones the stone layer holds (feature 147).
    private(set) var baseStones: [Stone] = []
    /// The render target of the stone layer; nil before `setup` and after `teardown` (feature 147).
    private(set) var stoneTarget: RenderTarget?
    /// How many times the stone layer was rasterized (feature 147).
    private(set) var stoneRebuildCount = 0
    /// How many times the stone layer was uploaded (feature 147).
    private(set) var stoneUploadCount = 0
    /// Whether the stone layer must be uploaded before the next draw (feature 147).
    private var needsStoneUpload = true
    /// The format of `target` (`rgba16f` or `rgba8`).
    private(set) var format: TextureFormat = .rgba8
    /// The sand tone drawn (sRGB).
    var tone = SIMD3<Float>(0.93, 0.89, 0.80)
    /// Whether the grain is drawn (level-0, the full level).
    var grain = false
    /// The sideways drift of the grain in tray widths (0 without drift; feature 149). Only the grain moves.
    var grainOffset: Float = 0
    /// The largest step of mean luminance (a share of full scale) allowed between two consecutive frames: 0.02, a
    /// fiftieth of full scale, far below a flash (WCAG's general flash threshold is a tenth of full luminance), so
    /// nothing flashes. The drift only moves the fine grain, whose mean over the tray hardly changes (feature 149).
    static let maxFrameLuminanceStep = 0.02
    /// The fitted tray of the last frame drawn, in framebuffer pixels (origin bottom-left).
    private(set) var trayPixels = SIMD4<Float>(0, 0, 0, 0)
    /// Grows with every change of the shown field.
    private(set) var revision = 0
    /// How many times the field was replayed from strokes.
    private(set) var replayCount = 0
    /// How many times a committed stroke was stamped into the base.
    private(set) var commitCount = 0
    /// How many times the shown field was uploaded.
    private(set) var uploadCount = 0
    /// How many relief passes were drawn.
    private(set) var drawCount = 0
    /// Whether the shown field must be uploaded before the next draw.
    private var needsUpload = true
    /// The relief pass; nil before `setup` and after `teardown`.
    private var pass: FieldPass?
    /// The registry that made `target` and `pass`.
    private weak var registry: ResourceRegistry?

    /// A scene with an empty field; `forceFallback` stores the field in `rgba8` even where `rgba16f` renders.
    init(forceFallback: Bool = false) {
        self.forceFallback = forceFallback
    }

    // MARK: Field

    /// Replays `strokes` into a fresh base field and restamps the stroke in progress over it.
    func rebuild(from strokes: [RakeStroke]) {
        base = SandField.replay(strokes, columns: Self.columns, rows: Self.rows)
        baseStrokes = strokes
        replayCount += 1
        restamp()
    }

    /// Stamps the committed `stroke` into the base field; `pending` (none by default) is the stroke in progress
    /// stamped over it afterwards.
    func commit(_ stroke: RakeStroke, pending: RakeStroke? = nil) {
        base.apply(stroke)
        baseStrokes.append(stroke)
        commitCount += 1
        shownPending = pending
        restamp()
    }

    /// Stamps `stroke` (the stroke in progress, or nil for none) over a copy of the base field when it changed.
    func stampInProgress(_ stroke: RakeStroke?) {
        guard stroke != shownPending else { return }
        shownPending = stroke
        restamp()
    }

    /// Brings the fields up to the garden's `strokes` and the stroke in progress `pending`: one stroke more than the
    /// base is a commit, any other difference a rebuild; then the stroke in progress is stamped when it changed.
    func sync(strokes: [RakeStroke], pending: RakeStroke?) {
        if strokes != baseStrokes {
            let count = baseStrokes.count
            if strokes.count == count + 1, strokes.prefix(count).elementsEqual(baseStrokes), let last = strokes.last {
                commit(last, pending: pending)
                return
            }
            shownPending = pending
            rebuild(from: strokes)
            return
        }
        stampInProgress(pending)
    }

    /// The shown field becomes the base with `shownPending` stamped over it; it is uploaded before the next draw.
    private func restamp() {
        var field = base
        if let shownPending { field.apply(shownPending) }
        shown = field
        revision += 1
        needsUpload = true
    }

    /// The values uploaded for `field` in `format`: four equal channels per cell, rows bottom-up; the height itself
    /// for `rgba16f`, height × 0.5 + 0.5 for `rgba8`.
    static func uploadValues(_ field: SandField, format: TextureFormat) -> [Float] {
        let encode = format != .rgba16f
        var values = [Float](repeating: 0, count: field.columns * field.rows * 4)
        var index = 0
        for glRow in 0..<field.rows {
            let row = field.rows - 1 - glRow
            for column in 0..<field.columns {
                let height = field[column, row]
                let value = encode ? height * 0.5 + 0.5 : height
                values[index] = value
                values[index + 1] = value
                values[index + 2] = value
                values[index + 3] = 1
                index += 4
            }
        }
        return values
    }

    /// The scale and offset from a stored value to the height: (1, 0) for `rgba16f`, (2, −1) for `rgba8`.
    static func decode(_ format: TextureFormat) -> SIMD2<Float> {
        format == .rgba16f ? SIMD2(1, 0) : SIMD2(2, -1)
    }

    /// The largest difference between the stored values `values` read back from the target (rows bottom-up, the
    /// first channel of each pixel) and the values `field` stores in `format` (the height for `rgba16f`, height ×
    /// 0.5 + 0.5 for `rgba8`); infinity for a wrong count.
    static func maxDifference(_ values: [Float], field: SandField, format: TextureFormat) -> Float {
        guard values.count == field.columns * field.rows * 4 else { return .infinity }
        let encode = format != .rgba16f
        var largest: Float = 0
        for glRow in 0..<field.rows {
            let row = field.rows - 1 - glRow
            for column in 0..<field.columns {
                let height = field[column, row]
                let expected = encode ? height * 0.5 + 0.5 : height
                largest = max(largest, abs(values[(glRow * field.columns + column) * 4] - expected))
            }
        }
        return largest
    }

    // MARK: Stones

    /// Rasterizes `stones` into a fresh stone layer (feature 147).
    func rebuildStones(from stones: [Stone]) {
        self.stones = StoneLayer(stones: stones, columns: Self.columns, rows: Self.rows)
        baseStones = stones
        stoneRebuildCount += 1
        revision += 1
        needsStoneUpload = true
    }

    /// Rebuilds the stone layer when `stones` differ from the ones it holds (feature 147).
    func syncStones(_ stones: [Stone]) {
        guard stones != baseStones else { return }
        rebuildStones(from: stones)
    }

    /// The values uploaded for `layer`: per cell (height, (kind + 1)/5, 0, 1), rows bottom-up (feature 147).
    static func stoneUploadValues(_ layer: StoneLayer) -> [Float] {
        var values = [Float](repeating: 0, count: layer.columns * layer.rows * 4)
        var index = 0
        for glRow in 0..<layer.rows {
            let row = layer.rows - 1 - glRow
            for column in 0..<layer.columns {
                values[index] = layer.height(column: column, row: row)
                values[index + 1] = Float(layer.kind(column: column, row: row)) / 5
                values[index + 3] = 1
                index += 4
            }
        }
        return values
    }

    /// The largest difference between the values `values` read back from the stone target (rows bottom-up) and the
    /// values `layer` stores (height and (kind + 1)/5); infinity for a wrong count (feature 147).
    static func stoneMaxDifference(_ values: [Float], layer: StoneLayer) -> Float {
        guard values.count == layer.columns * layer.rows * 4 else { return .infinity }
        var largest: Float = 0
        for glRow in 0..<layer.rows {
            let row = layer.rows - 1 - glRow
            for column in 0..<layer.columns {
                let base = (glRow * layer.columns + column) * 4
                largest = max(largest, abs(values[base] - layer.height(column: column, row: row)))
                largest = max(largest, abs(values[base + 1] - Float(layer.kind(column: column, row: row)) / 5))
            }
        }
        return largest
    }

    // MARK: Render scene

    /// Makes the field's render target in the context's storage format and the relief pass; the field is uploaded
    /// before the next draw. A compile error throws `FieldPassError.compile`.
    func setup(_ context: RenderContext) throws {
        releaseObjects()
        let resources = context.resources
        format = FloatRenderSupport.detect(in: resources).storageFormat(forceFallback: forceFallback)
        let made = try resources.makeRenderTarget(width: Self.columns, height: Self.rows, format: format,
                                                  label: "zg.sand")
        let madeStones: RenderTarget
        do {
            madeStones = try resources.makeRenderTarget(width: Self.columns, height: Self.rows, format: format,
                                                        label: "zg.stones")
        } catch {
            resources.release(made)
            throw error
        }
        do {
            pass = try FieldPass(registry: resources, fragment: Self.reliefFragment, inputs: ["u_sand", "u_stones"],
                                 label: "zg.relief")
        } catch {
            resources.release(made)
            resources.release(madeStones)
            throw error
        }
        target = made
        stoneTarget = madeStones
        registry = resources
        needsUpload = true
        needsStoneUpload = true
    }

    /// The field does not depend on the drawable size; the tray is fitted again at the next draw.
    func resize(_ context: RenderContext) {}

    /// Uploads the shown field when it changed, then draws the relief over the whole framebuffer.
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let target, let stoneTarget, let pass else { return }
        if needsUpload {
            guard target.upload(rgbaFloats: Self.uploadValues(shown, format: format)) else {
                throw SandSceneError.uploadFailed
            }
            needsUpload = false
            uploadCount += 1
        }
        if needsStoneUpload {
            guard stoneTarget.upload(rgbaFloats: Self.stoneUploadValues(stones)) else {
                throw SandSceneError.uploadFailed
            }
            needsStoneUpload = false
            stoneUploadCount += 1
        }
        let tray = TrayFit.rect(width: Double(context.pixelWidth), height: Double(context.pixelHeight))
        trayPixels = SIMD4(Float(tray.x), Float(Double(context.pixelHeight) - tray.y - tray.height),
                           Float(tray.width), Float(tray.height))
        try pass.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth,
                                          height: context.pixelHeight),
                     inputs: ["u_sand": target, "u_stones": stoneTarget],
                     uniforms: ["u_tray": .vec4(trayPixels), "u_tone": .vec4(SIMD4(tone, 1)),
                                "u_decode": .vec2(Self.decode(format)), "u_grain": .float(grain ? 1 : 0),
                                "u_grainOffset": .float(grainOffset)])
        drawCount += 1
    }

    /// Releases the targets and the pass.
    func teardown(_ context: RenderContext) {
        releaseObjects()
    }

    /// Releases the targets and the pass to their registry (objects of an ended generation are only forgotten).
    private func releaseObjects() {
        if let target, let registry, target.handle.generation == registry.generation { registry.release(target) }
        if let stoneTarget, let registry, stoneTarget.handle.generation == registry.generation {
            registry.release(stoneTarget)
        }
        pass?.release()
        target = nil
        stoneTarget = nil
        pass = nil
    }
}

/// Why the sand could not be drawn (feature 146).
enum SandSceneError: Error, Equatable, CustomStringConvertible {
    /// The field could not be uploaded to its render target.
    case uploadFailed

    /// "The sand field could not be uploaded."
    var description: String {
        switch self {
        case .uploadFailed: return "The sand field could not be uploaded."
        }
    }
}
