// BenchTestSupport — feature 174 (A24-P02) T-A24-206, T-A24-209 (SC-A24-201, SC-A24-204). Shared helpers of the
// workload tests: a render scene that owns one `WorkloadRenderer` and draws a chosen workload frame, off-screen stills of it
// through `RenderHost.renderOffscreen` (128 × 96 pixels by default), the luma spread of a picture and the resource
// level of a host. The helper types carry the `WorkloadHarness` prefix. Short runs only (no sleep, no wall-clock
// assertion); every picture is a function of the case and the frame number.
import Foundation
import Testing
import VisualCoreRendering
import GraphicsBenchmarkLabCore
@testable import GraphicsBenchmarkLabExperience

/// A render scene that owns one workload of `benchmarkCase` and draws workload frame ``frame`` on every render. The
/// workload is built in `setup` (a refusal is recorded in ``setupError`` with the resource level before and after,
/// and the scene draws nothing) and released in `teardown`.
@MainActor
final class WorkloadHarnessScene: RenderScene {
    /// The case drawn.
    let benchmarkCase: BenchmarkCase
    /// The texture-size limit handed to the workload (nil: the registry's limit alone).
    let textureLimit: Int?
    /// The workload frame drawn by the next render.
    var frame = 0
    /// The workload while set up.
    private(set) var workload: WorkloadRenderer?
    /// How many times `setup` ran (once per context).
    private(set) var setupCount = 0
    /// How many times `teardown` ran.
    private(set) var teardownCount = 0
    /// The refusal of the last `setup`, if any.
    private(set) var setupError: WorkloadError?
    /// The host's resource level when the last `setup` began.
    private(set) var levelBeforeSetup: WorkloadHarnessLevel?
    /// The host's resource level when the last `setup` ended.
    private(set) var levelAfterSetup: WorkloadHarnessLevel?

    /// A scene drawing `benchmarkCase`, its workload limited to `textureLimit` when given.
    init(_ benchmarkCase: BenchmarkCase, textureLimit: Int? = nil) {
        self.benchmarkCase = benchmarkCase
        self.textureLimit = textureLimit
    }

    /// Builds the workload; a `WorkloadError` is recorded rather than thrown.
    func setup(_ context: RenderContext) throws {
        setupCount += 1
        levelBeforeSetup = WorkloadHarnessLevel(context.resources)
        defer { levelAfterSetup = WorkloadHarnessLevel(context.resources) }
        do throws(WorkloadError) {
            workload = try WorkloadRenderer(benchmarkCase: benchmarkCase, context: context, textureLimit: textureLimit)
            setupError = nil
        } catch {
            workload = nil
            setupError = error
        }
    }

    /// Hands the new drawable size to the workload.
    func resize(_ context: RenderContext) { workload?.resize(context) }

    /// Draws workload frame ``frame``.
    func render(_ context: RenderContext, frame _: FrameInfo) throws {
        try workload?.draw(frame: frame, context: context)
    }

    /// Releases the workload.
    func teardown(_ context: RenderContext) {
        teardownCount += 1
        workload?.release()
        workload = nil
    }
}

/// A host's resource level: live objects per kind (keyed by the kind's name), live bytes and leaked objects.
struct WorkloadHarnessLevel: Equatable, CustomStringConvertible {
    /// Live objects per resource kind, keyed by the kind's name.
    var liveCount: [String: Int]
    /// Live bytes across all kinds.
    var totalBytes: Int
    /// Objects still live when a context ended.
    var leaked: Int

    /// The level of `registry` now.
    @MainActor
    init(_ registry: ResourceRegistry) {
        let stats = registry.stats
        var counts: [String: Int] = [:]
        for (kind, count) in stats.liveCount { counts[String(describing: kind)] = count }
        liveCount = counts
        totalBytes = stats.totalBytes
        leaked = stats.leaked
    }

    /// "kind=n …, bytes=n, leaked=n", in kind-name order.
    var description: String {
        liveCount.keys.sorted().map { "\($0)=\(liveCount[$0, default: 0])" }.joined(separator: " ")
            + " bytes=\(totalBytes) leaked=\(leaked)"
    }
}

/// Hosts, stills and picture measures of the workload tests.
@MainActor
enum WorkloadHarness {
    /// The default still size: 128 × 96 pixels.
    static let width = 128, height = 96

    /// The built-in case with `id`; records an issue and returns the quads case when there is none.
    static func builtIn(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) -> BenchmarkCase {
        let found = BenchmarkCase.builtIn.first { $0.id == id }
        #expect(found != nil, "built-in case \(id)", sourceLocation: sourceLocation)
        return found ?? BenchmarkCase.quads
    }

    /// The built-in quads case at resolution scale 0.5 (a scaled target between the workload and the framebuffer).
    static var halfScaleQuads: BenchmarkCase {
        var benchmarkCase = BenchmarkCase.quads
        benchmarkCase.id = "quads-half"
        benchmarkCase.config.resolutionScale = 0.5
        return benchmarkCase
    }

    /// A host over `scene` (no view layout: stills are drawn off screen).
    static func makeHost(_ scene: WorkloadHarnessScene) throws -> RenderHost {
        try RenderHost(scene: scene)
    }

    /// Workload frame `frame` of `scene` drawn off screen on `host` at `width` × `height`: RGBA bytes, rows top-down.
    static func still(_ host: RenderHost, _ scene: WorkloadHarnessScene, frame: Int,
                      width: Int = WorkloadHarness.width, height: Int = WorkloadHarness.height) throws -> [UInt8] {
        scene.frame = frame
        return try host.renderOffscreen(width: width, height: height, time: 0).rgba
    }

    /// Frames `frames` of `benchmarkCase` drawn off screen on a new host, which is destroyed afterwards.
    static func stills(_ benchmarkCase: BenchmarkCase, frames: [Int], width: Int = WorkloadHarness.width,
                       height: Int = WorkloadHarness.height) throws -> [[UInt8]] {
        let scene = WorkloadHarnessScene(benchmarkCase)
        let host = try makeHost(scene)
        defer { host.destroy() }
        var result: [[UInt8]] = []
        for frame in frames {
            result.append(try still(host, scene, frame: frame, width: width, height: height))
        }
        return result
    }

    /// The integer luma (0…255, Rec. 601 weights) of each pixel of `rgba`.
    static func lumas(_ rgba: [UInt8]) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(rgba.count / 4)
        var i = 0
        while i + 3 < rgba.count {
            let r = Int(rgba[i]), g = Int(rgba[i + 1]), b = Int(rgba[i + 2])
            result.append((299 * r + 587 * g + 114 * b) / 1_000)
            i += 4
        }
        return result
    }

    /// The luma spread of `rgba`: the largest luma minus the smallest (0 for an empty picture).
    static func lumaSpread(_ rgba: [UInt8]) -> Int {
        let values = lumas(rgba)
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }

    /// How many bytes of `a` and `b` differ (the longer one's extra bytes count as differing).
    static func differingBytes(_ a: [UInt8], _ b: [UInt8]) -> Int {
        var count = abs(a.count - b.count)
        for i in 0..<min(a.count, b.count) where a[i] != b[i] { count += 1 }
        return count
    }
}
