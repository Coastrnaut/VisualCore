// RenderSupport — feature 180 (A25-P01) T-A25-108 (FR-A25-104, FR-A25-105, FR-A25-107; SC-A25-103, SC-A25-104;
// clarification Q4). Off-screen drawing of the effect programs for the render and order tests: `EffectHost.run` runs
// a closure inside a `RenderScene` callback on `RenderHost(scene:)` with the host's context current, and
// `EffectDrawer` compiles the five programs with `FieldPass`, uploads an `RGBAImage` into an `.rgba8` target (rows
// flipped to GL's bottom-up order), draws one node or a chain of nodes (each node into a new target of the same size)
// and reads the result back as a top-down `RGBAImage`. Every target is released after use; the programs are released
// with the drawer.
import Testing
import UIKit
import VisualCoreRendering
import EffectsComposerCore

/// Why an off-screen draw did not produce a picture.
enum EffectRenderError: Error, CustomStringConvertible {
    /// The upload into the source target failed.
    case upload
    /// The read-back returned no pixels.
    case readBack
    /// A uniform value with a float count `FieldUniform` has no case for.
    case uniformShape(String, Int)
    /// The scene callback did not run.
    case notRun

    /// A readable account of the failure.
    var description: String {
        switch self {
        case .upload: "upload failed"
        case .readBack: "read-back failed"
        case .uniformShape(let name, let n): "uniform \(name) has \(n) floats"
        case .notRun: "the scene callback did not run"
        }
    }
}

/// A scene that runs one piece of work in its first `render` callback and draws nothing else.
@MainActor
final class WorkScene: RenderScene {
    /// The work still to run, cleared when it runs.
    var work: ((RenderContext) throws -> Void)?
    /// The error the work threw, if any.
    private(set) var failure: Error?
    /// True after the work ran.
    private(set) var ran = false

    /// A scene that runs `work` once.
    init(work: @escaping (RenderContext) throws -> Void) { self.work = work }

    /// Nothing to set up.
    func setup(_ context: RenderContext) throws {}

    /// Nothing depends on the size.
    func resize(_ context: RenderContext) {}

    /// Runs the pending work, recording its error.
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let work else { return }
        self.work = nil
        ran = true
        do { try work(context) } catch { failure = error }
    }

    /// Nothing to release.
    func teardown(_ context: RenderContext) {}
}

/// Runs work inside a render host's scene callback.
@MainActor
enum EffectHost {
    /// Runs `body` in the render callback of a new host's first frame and returns its result; the host is destroyed
    /// afterwards.
    static func run<T>(_ body: @escaping (RenderContext) throws -> T) throws -> T {
        var result: T?
        let scene = WorkScene { context in result = try body(context) }
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        #expect(host.renderOneFrame(present: false), "the host rendered a frame")
        if let failure = scene.failure { throw failure }
        guard scene.ran, let result else { throw EffectRenderError.notRun }
        return result
    }
}

/// Draws effect programs off screen in a host's context.
@MainActor
final class EffectDrawer {
    /// The host's resource registry.
    let registry: ResourceRegistry
    /// One compiled pass per effect.
    let passes: [EffectID: FieldPass]

    /// Compiles every effect's program; throws `FieldPassError.compile` with the first diagnostic.
    init(registry: ResourceRegistry) throws {
        self.registry = registry
        var passes: [EffectID: FieldPass] = [:]
        for effect in EffectID.allCases {
            passes[effect] = try FieldPass(registry: registry, fragment: EffectPrograms.source(for: effect),
                                           inputs: [EffectPrograms.sourceInput], label: "a25-\(effect.rawValue).frag")
        }
        self.passes = passes
    }

    /// Releases the programs.
    func release() { for pass in passes.values { pass.release() } }

    /// A new `.rgba8` target holding `image` (rows flipped to bottom-up).
    func upload(_ image: RGBAImage) throws -> RenderTarget {
        let target = try registry.makeRenderTarget(width: image.width, height: image.height, format: .rgba8,
                                                   label: "a25-source")
        var floats = [Float](repeating: 0, count: image.bytes.count)
        let rowBytes = image.width * 4
        for y in 0..<image.height {
            let from = y * rowBytes, to = (image.height - 1 - y) * rowBytes
            for i in 0..<rowBytes { floats[to + i] = Float(image.bytes[from + i]) / 255 }
        }
        guard target.upload(rgbaFloats: floats) else {
            registry.release(target)
            throw EffectRenderError.upload
        }
        return target
    }

    /// The picture in `target`, rows flipped to top-down.
    func read(_ target: RenderTarget) throws -> RGBAImage {
        let pixels = target.readPixels()
        guard pixels.count == target.width * target.height * 4 else { throw EffectRenderError.readBack }
        var bytes = [UInt8](repeating: 0, count: pixels.count)
        let rowBytes = target.width * 4
        for y in 0..<target.height {
            let from = y * rowBytes, to = (target.height - 1 - y) * rowBytes
            bytes[to..<(to + rowBytes)] = pixels[from..<(from + rowBytes)]
        }
        return RGBAImage(width: target.width, height: target.height, bytes: bytes)
    }

    /// `FieldUniform` values for packed floats: 1 → float, 2 → vec2, 4 → vec4.
    static func fieldUniforms(_ packed: [String: [Float]]) throws -> [String: FieldUniform] {
        var uniforms: [String: FieldUniform] = [:]
        for (name, v) in packed {
            switch v.count {
            case 1: uniforms[name] = .float(v[0])
            case 2: uniforms[name] = .vec2(SIMD2(v[0], v[1]))
            case 4: uniforms[name] = .vec4(SIMD4(v[0], v[1], v[2], v[3]))
            default: throw EffectRenderError.uniformShape(name, v.count)
            }
        }
        return uniforms
    }

    /// Draws `node` reading `input` into a new target of the same size and returns it (the caller releases it).
    func draw(_ node: EffectNode, input: RenderTarget) throws -> RenderTarget {
        let output = try registry.makeRenderTarget(width: input.width, height: input.height, format: .rgba8,
                                                   label: "a25-output")
        do {
            let uniforms = try Self.fieldUniforms(EffectPrograms.uniforms(for: node, width: input.width,
                                                                          height: input.height))
            try passes[node.effect]!.run(output: .target(output), inputs: [EffectPrograms.sourceInput: input],
                                         uniforms: uniforms)
        } catch {
            registry.release(output)
            throw error
        }
        return output
    }

    /// The picture the enabled `nodes` make of `image`, drawn in order (one pass per enabled node).
    func draw(_ nodes: [EffectNode], on image: RGBAImage) throws -> RGBAImage {
        var current = try upload(image)
        defer { registry.release(current) }
        for node in nodes where node.enabled {
            let next = try draw(node, input: current)
            registry.release(current)
            current = next
        }
        return try read(current)
    }

    /// The picture `node` makes of `image`.
    func draw(_ node: EffectNode, on image: RGBAImage) throws -> RGBAImage { try draw([node], on: image) }
}

/// Picture comparisons for the tests.
enum PictureCompare {
    /// The largest colour-channel difference (alpha included) over the pixels `include` accepts, in 8-bit steps,
    /// and the number of pixels compared.
    static func maxDifference(_ a: RGBAImage, _ b: RGBAImage,
                              include: (Int, Int) -> Bool = { _, _ in true }) -> (max: Int, compared: Int) {
        guard a.width == b.width, a.height == b.height else { return (.max, 0) }
        var largest = 0, compared = 0
        for y in 0..<a.height {
            for x in 0..<a.width where include(x, y) {
                compared += 1
                for c in 0..<4 { largest = max(largest, abs(Int(a[x, y, c]) - Int(b[x, y, c]))) }
            }
        }
        return (largest, compared)
    }
}
