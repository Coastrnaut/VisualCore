// VisualCoreBaselines — host performance baselines (feature 010 T-F909; FR-F905; research R6).
// `swift run -c release --package-path Packages/VisualCore VisualCoreBaselines [--json]`
// Each benchmark runs 15 times; the median, min and max of the per-operation time are reported with the host
// environment. These are host numbers for spotting regressions, NOT device evidence (constitution V).
import Foundation
import VisualCoreEffectsGraph
import VisualCoreMath
import VisualCoreScenes
import VisualCoreShaderSource
import VisualCoreSimulation

struct Measurement: Codable {
    let name: String
    let unit: String
    let operationsPerRepeat: Int
    let repeats: Int
    let medianMicroseconds: Double
    let minMicroseconds: Double
    let maxMicroseconds: Double
    let note: String
}

func measure(_ name: String, operations: Int, repeats: Int = 15, note: String, _ body: () -> Void) -> Measurement {
    body()  // warm-up
    var samples: [Double] = []
    for _ in 0..<repeats {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let ns = Double(DispatchTime.now().uptimeNanoseconds - start)
        samples.append(ns / 1000 / Double(operations))
    }
    samples.sort()
    return Measurement(name: name, unit: "µs/op", operationsPerRepeat: operations, repeats: repeats,
                       medianMicroseconds: samples[samples.count / 2], minMicroseconds: samples[0],
                       maxMicroseconds: samples[samples.count - 1], note: note)
}

var sink = 0.0

let particles = measure("particle-step-10k", operations: 60, note: "ParticleSystem.step(1/60) with 10,000 live particles, gravity + drag") {
    var system = ParticleSystem(capacity: 10_000, seed: 42)
    system.emitters = [Emitter(rate: 0, lifetime: 100...100, speed: 10...50)]
    system.forces = [.gravity(Vec2(0, -9.8)), .drag(0.2)]
    system.burst(10_000)
    for _ in 0..<60 { system.step(1.0 / 60) }
    sink += Double(system.aliveCount)
}

let chain = EffectGraphDescription(passes: (0..<16).map { i in
    EffectPassDescription(id: "p\(i)", type: i % 2 == 0 ? "blur" : "colorMatrix",
                          inputs: ["input": i == 0 ? effectSceneSource : "o\(i - 1)"], output: "o\(i)")
}, output: "o15")
let graph = measure("effect-graph-validate-16", operations: 1000, note: "EffectGraphValidator.validate: 16-pass chain at 1920×1080") {
    for _ in 0..<1000 { if let v = try? EffectGraphValidator.validate(chain, width: 1920, height: 1080) { sink += Double(v.order.count) } }
}

var library = ShaderLibrary()
library.add("noise.glsl", (0..<40).map { "float n\($0)(vec2 p) { return fract(sin(dot(p, vec2(\($0).1, 7.3))) * 43758.5); }" }.joined(separator: "\n"))
library.add("common.glsl", "#include \"noise.glsl\"\n" + (0..<40).map { "vec3 c\($0)(float h) { return vec3(h, h * 0.5, 1.0 - h); }" }.joined(separator: "\n"))
let fragment = "precision mediump float;\n#include \"common.glsl\"\nout vec4 color;\nvoid main() { color = vec4(c1(n2(gl_FragCoord.xy)), 1.0); }\n"
let shaders = measure("shader-expand-include", operations: 1000, note: "ShaderLibrary.expand: nested includes, ~85 lines, line map") {
    for _ in 0..<1000 { if let e = try? library.expand(source: fragment, named: "main.frag", defines: ["QUALITY": "2"]) { sink += Double(e.text.count) } }
}

let metrics = ViewMetrics(size: Vec2(390, 844), scale: 3)
let camera = Camera2D(center: Vec2(10, 20), zoom: 1.5, rotation: 0.3)
let coords = measure("coordinate-mapping-roundtrip", operations: 100_000, note: "ViewMetrics point → world → point through a rotated, zoomed Camera2D") {
    for i in 0..<100_000 {
        let p = Vec2(Double(i % 390), Double(i % 844))
        if let w = metrics.toWorld(p, camera: camera), let back = metrics.fromWorld(w, camera: camera) { sink += back.x }
    }
}

func sysctl(_ name: String) -> String {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "unknown" }
    return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

struct Report: Codable {
    let schema: Int
    let evidence: String
    let configuration: String
    let host: [String: String]
    let measurements: [Measurement]
}
let os = ProcessInfo.processInfo.operatingSystemVersion
#if DEBUG
let configuration = "debug"
#else
let configuration = "release"
#endif
let report = Report(schema: 1, evidence: "host baseline — not device evidence (constitution V)", configuration: configuration,
                    host: ["os": "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)", "cpu": sysctl("machdep.cpu.brand_string"),
                           "model": sysctl("hw.model"), "cores": String(ProcessInfo.processInfo.activeProcessorCount)],
                    measurements: [particles, graph, shaders, coords])
if CommandLine.arguments.contains("--json") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
} else {
    for m in report.measurements {
        print("\(m.name.padding(toLength: 30, withPad: " ", startingAt: 0)) median \(String(format: "%9.3f", m.medianMicroseconds)) µs/op "
              + "(min \(String(format: "%.3f", m.minMicroseconds)), max \(String(format: "%.3f", m.maxMicroseconds)))")
    }
}
if sink.isNaN { print("") }  // keeps the work observable
