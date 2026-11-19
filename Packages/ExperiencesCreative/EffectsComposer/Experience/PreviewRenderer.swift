// PreviewRenderer — feature 181 (A25-P02) T-A25-206 (FR-A25-202, FR-A25-205, FR-A25-206; clarifications Q2 and Q4;
// data-model.md "ProgramDiagnostic", "Pool cap"; contracts/experience.md "Presenter seams"). The preview of the chain,
// drawn through VisualCore inside the host's context:
//
//   - Setup (`setup(_:)`, again after a context loss): one `FieldPass` per effect from `EffectPrograms` (or the test
//     seam ``programOverride``), a `copy` pass and a `present` pass. An effect program that does not build becomes a
//     ``ProgramDiagnostic`` (effect, line, message) parsed from `FieldPassError.compile("<file>:<line>: <message>")`;
//     the copy and present programs are the renderer's own and a failure of theirs is thrown. Then the test image
//     (`TestImage.make(size: 256)`) is uploaded into an `.rgba8` source target (rows flipped to GL's bottom-up order)
//     and a result target of the same size is taken; both come from the ``PreviewPool``.
//   - Render (`render(_:context:)`, each frame): when the chain's fingerprint differs from the one last rendered, the
//     chain is compiled (`PassPlan.compile`) and its passes are run in order. A slot's target is taken from the pool
//     when its writer runs and returned (`recycle`) as soon as its single reader ran, so at most four targets are held:
//     the source, the result and two slots. A plan that uses an effect without a built program is not run: the result
//     keeps the last good picture (FR-A25-205).
//   - Present (`present(_:)`, each frame): the result is drawn into the framebuffer, letterboxed in the drawable at the
//     largest whole multiple of its side that fits (or scaled down to fit a smaller drawable), sampled nearest.
//   - Pool (``PreviewPool``): at most 4 targets of at most 2,048 × 2,048 are held; a larger or a fifth request is
//     refused with `a25.pool-cap` and "The picture is larger than the preview allows." before anything is made.
//   - Release (`release(_:)`): every program and target is released and the free pooled targets trimmed, so nothing is
//     live after `teardown`; the next `setup` builds everything again and the next render draws the chain anew.
//   - Test seams: ``programOverride`` (an effect's program text replaced, set before `setup`), ``captureResult`` with
//     ``lastResult`` (the result's pixels, rows top-down, read after each render that ran), ``renderCount`` and
//     ``lastPlan``.
//
// Feature 182 (A25-P03) T-A25-305, T-A25-306 (clarifications Q1, Q4): `present(_:compare:)` draws the source target
// instead of the result while compare is on (the result is still rendered whenever the chain changes, so turning
// compare off shows it at once). Test seams: ``presentedTargetIsSource`` (what the last present drew),
// ``lastPresentSize`` (the drawable of the last present) and ``sourceTextureName`` (the source's colour texture,
// which no pass may write).
//
// Choice recorded here: the result target is held across frames (taken at setup, given back at release) rather than
// taken and recycled each frame, so that a broken program keeps the last good picture in it; the slots come from the
// pool and go back to it within each render. No GL call: programs, targets and draws are VisualCore's (`FieldPass`,
// `RenderTarget`, `ResourceRegistry`).
import EffectsComposerCore
import Foundation
import VisualCoreExperience
import VisualCoreRendering

/// A program of an effect that did not build: the effect, the line of the first problem and its message.
public struct ProgramDiagnostic: Equatable, Sendable {
    /// The effect whose program failed.
    public let effect: EffectID
    /// The line of the first problem (0 when the text named none).
    public let line: Int
    /// The compiler's message.
    public let message: String

    /// A diagnostic of `effect` at `line` with `message`.
    public init(effect: EffectID, line: Int, message: String) {
        self.effect = effect
        self.line = line
        self.message = message
    }

    /// The diagnostic of `effect` parsed from a `FieldPassError.compile` text "<file>:<line>: <message>"; a text of
    /// another shape gives line 0 and the whole text as the message.
    public static func parse(_ text: String, effect: EffectID) -> ProgramDiagnostic {
        let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        if parts.count == 3, let line = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return ProgramDiagnostic(effect: effect, line: line,
                                     message: parts[2].trimmingCharacters(in: .whitespaces))
        }
        return ProgramDiagnostic(effect: effect, line: 0, message: text)
    }

    /// The line the controls show: "<effect title>, line <n>: <message>".
    public var text: String {
        EffectLibrary.definition(effect).title + ", line \(line): " + message
    }
}

/// Why the preview refused to take a target.
public enum PreviewRefusal: Error, Equatable, Sendable {
    /// More than ``PreviewPool/maxTargets`` targets, or a side above ``PreviewPool/maxSide``.
    case poolCap

    /// The rule id: `a25.pool-cap`.
    public var ruleID: String { "a25.pool-cap" }
    /// The message shown: "The picture is larger than the preview allows."
    public var message: String { "The picture is larger than the preview allows." }
}

/// Why the preview could not be set up.
enum PreviewSetupError: Error, Equatable {
    /// The test image could not be uploaded into the source target.
    case upload
}

/// The preview's bounded share of the registry's target pool (see the file header).
@MainActor
final class PreviewPool {
    /// The most targets the preview holds at once (source, result, two slots).
    nonisolated static let maxTargets = 4
    /// The largest side of a target, pixels.
    nonisolated static let maxSide = 2_048

    /// The registry the targets come from.
    let registry: ResourceRegistry
    /// How many targets the preview holds now.
    private(set) var held = 0

    /// A pool over `registry`'s targets.
    init(registry: ResourceRegistry) {
        self.registry = registry
    }

    /// The refusal of a `width × height` request while `held` targets are held, or nil when it is allowed.
    nonisolated static func check(width: Int, height: Int, held: Int) -> PreviewRefusal? {
        guard held < maxTargets, width > 0, height > 0, width <= maxSide, height <= maxSide else { return .poolCap }
        return nil
    }

    /// A pooled `.rgba8` target of `width × height`; throws ``PreviewRefusal/poolCap`` before anything is made when
    /// the request is above the cap, or the registry's error.
    func acquire(width: Int, height: Int) throws -> RenderTarget {
        if let refusal = Self.check(width: width, height: height, held: held) { throw refusal }
        let target = try registry.acquireTarget(width: width, height: height, format: .rgba8)
        held += 1
        return target
    }

    /// Gives `target` back to the registry's pool for reuse.
    func recycle(_ target: RenderTarget) {
        held = max(0, held - 1)
        registry.recycle(target)
    }

    /// Releases `target` for good.
    func release(_ target: RenderTarget) {
        held = max(0, held - 1)
        registry.release(target)
    }
}

/// Draws the chain's preview (see the file header).
@MainActor
final class PreviewRenderer {
    /// The side of the test image and of the result, pixels.
    nonisolated static let previewSide = 256
    /// The colour around the letterboxed picture.
    nonisolated static let background: SIMD4<Float> = SIMD4(0.06, 0.06, 0.07, 1)

    /// The fragment program of the copy pass: the source's texel at the fragment, exactly.
    nonisolated static let copyProgram = """
    precision highp float;
    uniform highp sampler2D u_source;
    out vec4 color;
    void main() {
        color = texelFetch(u_source, ivec2(gl_FragCoord.xy), 0);
    }
    """

    /// The fragment program of the present pass: the result in the rectangle `u_rect` (x, y, width, height in
    /// framebuffer pixels from the bottom-left), sampled nearest; `u_background` around it.
    nonisolated static let presentProgram = """
    precision highp float;
    uniform highp sampler2D u_source;
    uniform vec4 u_rect;
    uniform vec4 u_background;
    out vec4 color;
    void main() {
        vec2 p = gl_FragCoord.xy - u_rect.xy;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= u_rect.z || p.y >= u_rect.w) {
            color = u_background;
            return;
        }
        ivec2 n = textureSize(u_source, 0);
        ivec2 t = clamp(ivec2(floor(p / u_rect.zw * vec2(n))), ivec2(0), n - ivec2(1));
        color = vec4(texelFetch(u_source, t, 0).rgb, 1.0);
    }
    """

    /// The rectangle (x, y from the bottom-left, width, height, pixels) the result of side `side` takes in a
    /// `width × height` drawable: the largest whole multiple of `side` that fits, or, in a smaller drawable, the
    /// shorter side; centred. Nil for an empty drawable.
    nonisolated static func presentRect(width: Int, height: Int, side: Int) -> (x: Int, y: Int, width: Int, height: Int)? {
        guard width > 0, height > 0, side > 0 else { return nil }
        let shorter = min(width, height)
        let drawn = shorter >= side ? (shorter / side) * side : shorter
        return ((width - drawn) / 2, (height - drawn) / 2, drawn, drawn)
    }

    /// Replacement program texts by effect (a test seam, read at `setup`; never set by the app).
    var programOverride: [EffectID: String] = [:]
    /// When true, every render that runs reads the result back into ``lastResult`` (a test seam).
    var captureResult = false
    /// The result's pixels, rows top-down, after the last render that ran with ``captureResult`` on (a test seam).
    private(set) var lastResult: RGBAImage?
    /// The plan last run (a test seam); nil before the first and after a refused render.
    private(set) var lastPlan: PassPlan?
    /// How many renders ran their plan (a test seam).
    private(set) var renderCount = 0
    /// The diagnostics of the effect programs that did not build at the last `setup`, in effect order.
    private(set) var diagnostics: [ProgramDiagnostic] = []
    /// Why the last setup or render was refused; nil when it was not.
    private(set) var refusal: PreviewRefusal?
    /// The message of a pass that failed on the driver at the last render; nil when none failed.
    private(set) var runFailure: String?
    /// The error of the last present pass that failed on the driver; nil after one that ran (a test seam).
    private(set) var presentFailure: String?
    /// Whether the last present drew the source (compare on) rather than the result (a test seam).
    private(set) var presentedTargetIsSource = false
    /// The drawable size (pixels) of the last present that ran; nil before the first (a test seam).
    private(set) var lastPresentSize: (width: Int, height: Int)?
    /// The colour texture name of the source target; nil without one (a test seam for the aliasing audit).
    var sourceTextureName: UInt32? { source?.colorTexture }

    /// Whether the chain last seen uses an effect whose program did not build (its picture is not drawn).
    private(set) var blocked = false

    /// The effect programs that built.
    private var passes: [EffectID: FieldPass] = [:]
    /// The copy program.
    private var copyPass: FieldPass?
    /// The present program.
    private var presentPass: FieldPass?
    /// The targets' pool of the current context.
    private(set) var pool: PreviewPool?
    /// The source target holding the test image.
    private var source: RenderTarget?
    /// The result target holding the last good picture.
    private var result: RenderTarget?
    /// The fingerprint (hex) of the chain last rendered or refused; nil when the next render must draw.
    private var renderedKey: String?

    /// The uniforms of `values` that `pass`'s program keeps, as `FieldUniform` (1 → float, 2 → vec2, 4 → vec4).
    static func uniforms(_ values: [String: [Float]], for pass: FieldPass) -> [String: FieldUniform] {
        var uniforms: [String: FieldUniform] = [:]
        for (name, v) in values where pass.program.uniforms[name] != nil {
            switch v.count {
            case 1: uniforms[name] = .float(v[0])
            case 2: uniforms[name] = .vec2(SIMD2(v[0], v[1]))
            case 4: uniforms[name] = .vec4(SIMD4(v[0], v[1], v[2], v[3]))
            default: continue
            }
        }
        return uniforms
    }

    /// Builds the programs, uploads the test image and takes the result target (see the file header). Throws only
    /// when the renderer's own copy or present program does not build or a target cannot be made.
    func setup(_ context: RenderContext) throws {
        release(context)
        let registry = context.resources
        var found: [ProgramDiagnostic] = []
        for effect in EffectID.allCases {
            do {
                passes[effect] = try FieldPass(registry: registry,
                                               fragment: programOverride[effect] ?? EffectPrograms.source(for: effect),
                                               inputs: [EffectPrograms.sourceInput],
                                               label: "a25-\(effect.rawValue).frag")
            } catch let FieldPassError.compile(text) {
                found.append(.parse(text, effect: effect))
            } catch {
                found.append(ProgramDiagnostic(effect: effect, line: 0, message: "\(error)"))
            }
        }
        diagnostics = found
        copyPass = try FieldPass(registry: registry, fragment: Self.copyProgram, inputs: [EffectPrograms.sourceInput],
                                 label: "a25-copy.frag")
        presentPass = try FieldPass(registry: registry, fragment: Self.presentProgram,
                                    inputs: [EffectPrograms.sourceInput], label: "a25-present.frag")
        let pool = PreviewPool(registry: registry)
        self.pool = pool
        let side = Self.previewSide
        do {
            let source = try pool.acquire(width: side, height: side)
            self.source = source
            guard source.upload(rgbaFloats: Self.bottomUpFloats(TestImage.make(size: side))) else {
                throw PreviewSetupError.upload
            }
            result = try pool.acquire(width: side, height: side)
        } catch let refused as PreviewRefusal {
            refusal = refused
        }
    }

    /// The bytes of `image` as floats 0…1 with the rows flipped to bottom-up (GL's order).
    nonisolated static func bottomUpFloats(_ image: RGBAImage) -> [Float] {
        var floats = [Float](repeating: 0, count: image.bytes.count)
        let rowBytes = image.width * 4
        for y in 0..<image.height {
            let from = y * rowBytes, to = (image.height - 1 - y) * rowBytes
            for i in 0..<rowBytes { floats[to + i] = Float(image.bytes[from + i]) / 255 }
        }
        return floats
    }

    /// `pixels` (rows bottom-up, as GL reads them) as a top-down picture of `width × height`; nil for a wrong count.
    nonisolated static func topDown(_ pixels: [UInt8], width: Int, height: Int) -> RGBAImage? {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return nil }
        var bytes = [UInt8](repeating: 0, count: pixels.count)
        let rowBytes = width * 4
        for y in 0..<height {
            let from = y * rowBytes, to = (height - 1 - y) * rowBytes
            bytes[to..<(to + rowBytes)] = pixels[from..<(from + rowBytes)]
        }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }

    /// Renders `chain` into the result when its fingerprint changed since the last render (see the file header).
    func render(_ chain: EffectChain, context: RenderContext) {
        let key = chain.fingerprint().hex
        guard key != renderedKey else { return }
        renderedKey = key
        guard let pool, let source, let result, let copyPass else { return }
        let plan = PassPlan.compile(chain)
        blocked = plan.passes.contains { pass in pass.node.map { passes[$0.effect] == nil } ?? false }
        guard !blocked else { return }
        runFailure = nil
        var slots: [Int: RenderTarget] = [:]
        defer { for target in slots.values { pool.recycle(target) } }
        for planned in plan.passes {
            let input: RenderTarget
            switch planned.input {
            case .source: input = source
            case .result: input = result
            case .slot(let s):
                guard let target = slots[s] else { runFailure = "slot \(s) missing"; return }
                input = target
            }
            let output: RenderTarget
            switch planned.output {
            case .result, .source: output = result
            case .slot(let s):
                do {
                    let target = try pool.acquire(width: source.width, height: source.height)
                    slots[s] = target
                    output = target
                } catch let refused as PreviewRefusal {
                    refusal = refused
                    return
                } catch {
                    runFailure = "\(error)"
                    return
                }
            }
            let program: FieldPass
            var values: [String: [Float]] = [:]
            if let node = planned.node, let pass = passes[node.effect] {
                program = pass
                values = EffectPrograms.uniforms(for: node, width: output.width, height: output.height)
            } else {
                program = copyPass
            }
            do {
                try program.run(output: .target(output), inputs: [EffectPrograms.sourceInput: input],
                                uniforms: Self.uniforms(values, for: program))
            } catch {
                runFailure = "\(error)"
                return
            }
            if case .slot(let s) = planned.input, let target = slots.removeValue(forKey: s) { pool.recycle(target) }
        }
        lastPlan = plan
        renderCount += 1
        if captureResult {
            lastResult = Self.topDown(result.readPixels(), width: result.width, height: result.height)
        }
    }

    /// Draws the result, or the source while `compare` is on, letterboxed into the context's framebuffer (see the
    /// file header).
    func present(_ context: RenderContext, compare: Bool = false) {
        guard let presentPass, let result, let shown = compare ? source : result,
              let rect = Self.presentRect(width: context.pixelWidth, height: context.pixelHeight,
                                          side: result.width) else { return }
        let values: [String: [Float]] = [
            "u_rect": [Float(rect.x), Float(rect.y), Float(rect.width), Float(rect.height)],
            "u_background": [Self.background.x, Self.background.y, Self.background.z, Self.background.w],
        ]
        do {
            try presentPass.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth,
                                                     height: context.pixelHeight),
                                inputs: [EffectPrograms.sourceInput: shown],
                                uniforms: Self.uniforms(values, for: presentPass))
            presentFailure = nil
            presentedTargetIsSource = compare
            lastPresentSize = (context.pixelWidth, context.pixelHeight)
        } catch {
            presentFailure = "\(error)"
        }
    }

    /// Releases every program and target and trims the free pooled targets (see the file header); the next render
    /// draws the chain anew.
    func release(_ context: RenderContext) {
        for pass in passes.values { pass.release() }
        passes = [:]
        copyPass?.release()
        copyPass = nil
        presentPass?.release()
        presentPass = nil
        if let pool {
            if let source { pool.release(source) }
            if let result { pool.release(result) }
        }
        source = nil
        result = nil
        pool = nil
        context.resources.trimPools()
        renderedKey = nil
        refusal = nil
        blocked = false
    }
}
