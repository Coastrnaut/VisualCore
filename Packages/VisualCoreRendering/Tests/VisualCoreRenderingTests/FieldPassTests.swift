// FieldPassTests — feature 019 T-A02-105 (G-FIELDPASS; FR-A02-103, FR-A02-105, SC-A02-102; research R5).
import XCTest
@testable import VisualCoreRendering

@MainActor
final class FieldPassTests: XCTestCase {
    static let add = """
    precision highp float;
    uniform sampler2D uA;
    uniform sampler2D uB;
    uniform float uScale;
    uniform vec4 uBias;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = (texture(uA, v_uv) + texture(uB, v_uv)) * uScale + uBias; }
    """

    static let scale = """
    precision highp float;
    uniform sampler2D uField;
    uniform float uFactor;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = texture(uField, v_uv) * uFactor; }
    """

    private func grid(_ seed: Float) -> [Float] { (0..<64).map { Float(($0 * 7 + Int(seed * 10)) % 23) / 23 } }

    func testTwoInputPassMatchesCPU() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let r = context.resources
            let format = FloatRenderSupport.detect(in: r).storageFormat()
            let a = try r.makeRenderTarget(width: 4, height: 4, format: format, label: "a")
            let b = try r.makeRenderTarget(width: 4, height: 4, format: format, label: "b")
            let out = try r.makeRenderTarget(width: 4, height: 4, format: format, label: "out")
            defer { [a, b, out].forEach { r.release($0) } }
            let va = self.grid(1), vb = self.grid(2)
            XCTAssertTrue(a.upload(rgbaFloats: va))
            XCTAssertTrue(b.upload(rgbaFloats: vb))
            let pass = try FieldPass(registry: r, fragment: Self.add, inputs: ["uA", "uB"], label: "add")
            defer { pass.release() }
            try pass.run(output: .target(out), inputs: ["uA": a, "uB": b],
                         uniforms: ["uScale": .float(0.5), "uBias": .vec4(SIMD4(0, 0, 0, 0.25))])
            let got = out.readFloatPixels()
            let readA = a.readFloatPixels(), readB = b.readFloatPixels()
            XCTAssertEqual(got.count, 64)
            let tolerance: Float = format == .rgba16f ? 1e-3 : 1.5 / 255
            for i in 0..<64 {
                let bias: Float = i % 4 == 3 ? 0.25 : 0
                let expected = min((readA[i] + readB[i]) * 0.5 + bias, format == .rgba8 ? 1 : .infinity)
                XCTAssertEqual(got[i], expected, accuracy: tolerance, "i=\(i)")
            }
        }
    }

    func testRejectsReadingItsOutputAndBadNames() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let r = context.resources
            let pair = try PingPongTarget(registry: r, width: 4, height: 4, format: .rgba8, label: "p")
            defer { pair.release() }
            let pass = try FieldPass(registry: r, fragment: Self.scale, inputs: ["uField"], label: "scale")
            defer { pass.release() }
            XCTAssertThrowsError(try pass.run(output: .target(pair.read), inputs: ["uField": pair.read])) {
                XCTAssertEqual($0 as? FieldPassError, .inputIsOutput("uField"))
            }
            XCTAssertThrowsError(try pass.run(output: .target(pair.write), inputs: [:])) {
                XCTAssertEqual($0 as? FieldPassError, .missingInput("uField"))
            }
            XCTAssertThrowsError(try pass.run(output: .target(pair.write), inputs: ["uField": pair.read, "uOther": pair.read])) {
                XCTAssertEqual($0 as? FieldPassError, .unknownInput("uOther"))
            }
            XCTAssertThrowsError(try pass.run(output: .target(pair.write), inputs: ["uField": pair.read], uniforms: ["uNope": .float(1)])) {
                XCTAssertEqual($0 as? FieldPassError, .unknownUniform("uNope"))
            }
            XCTAssertThrowsError(try pass.run(output: .target(pair.write), inputs: ["uField": pair.read], uniforms: ["uFactor": .vec2(.zero)])) {
                XCTAssertEqual($0 as? FieldPassError, .uniformTypeMismatch("uFactor"))
            }
            XCTAssertEqual(pair.swapCount, 0, "no failed run swapped")
            XCTAssertThrowsError(try FieldPass(registry: r, fragment: "this is not glsl", inputs: [], label: "bad")) {
                guard case .compile = $0 as? FieldPassError else { return XCTFail("\($0)") }
            }
        }
    }

    func testPairStepWritesOtherTargetAndSwapsOnce() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let r = context.resources
            let pair = try PingPongTarget(registry: r, width: 4, height: 4, format: .rgba8, label: "p")
            defer { pair.release() }
            XCTAssertTrue(pair.read.upload(rgbaFloats: Array(repeating: 0.8, count: 64)))
            let pass = try FieldPass(registry: r, fragment: Self.scale, inputs: ["uField"], label: "scale")
            defer { pass.release() }
            let firstRead = pair.read
            try pass.run(pair: pair, input: "uField", uniforms: ["uFactor": .float(0.5)])
            XCTAssertEqual(pair.swapCount, 1)
            XCTAssertFalse(pair.read === firstRead, "the written target became read")
            for v in pair.read.readFloatPixels() { XCTAssertEqual(v, StoragePrecisionRound.unorm8(0.4), accuracy: 1.5 / 255) }
        }
    }

    func testStaleAfterContextRecreation() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var kept: (FieldPass, PingPongTarget)?
        try withContext(host, scene) { context in
            kept = (try FieldPass(registry: context.resources, fragment: Self.scale, inputs: ["uField"], label: "scale"),
                    try PingPongTarget(registry: context.resources, width: 4, height: 4, format: .rgba8, label: "p"))
        }
        host.recreateContext()
        let (pass, pair) = try XCTUnwrap(kept)
        try withContext(host, scene) { context in
            XCTAssertThrowsError(try pass.run(pair: pair, input: "uField")) { XCTAssertEqual($0 as? FieldPassError, .stale) }
            let fresh = try PingPongTarget(registry: context.resources, width: 4, height: 4, format: .rgba8, label: "q")
            defer { fresh.release() }
            XCTAssertThrowsError(try pass.run(pair: fresh, input: "uField")) { XCTAssertEqual($0 as? FieldPassError, .stale) }
        }
    }
}

/// Rounds like 8-bit storage (avoids importing VisualCoreSimulation into this file).
enum StoragePrecisionRound {
    static func unorm8(_ x: Float) -> Float { (min(max(x, 0), 1) * 255).rounded() / 255 }
}
