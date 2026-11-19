// SafeCompileTests — feature 206 T-R02F06-007 (US1, US2; SC-R02F06-001…003, FR-R02F06-002…005, FR-R02F06-008;
// analyze C1, C2): planted mistakes on real ANGLE with their reason codes and file:line, whole long logs, warnings,
// a six-variant prewarm through the program cache, a failing combination, inserted default precision and a program
// evicted from a warm set compiling again.
//
// Warnings: ANGLE reports an unsupported `#extension … : enable` as a `WARNING:` line in a successful compile log;
// `testWarningsAreKeptOnASuccessfulCompile` pins that. A clean shader produces an empty log, so `warnings` is empty.
import CVisualCoreGL
import VisualCoreShaderSource
import XCTest
@testable import VisualCoreRendering

@MainActor
final class SafeCompileTests: XCTestCase {
    static let vertex = ShaderProgramTests.vertex
    /// A fragment shader without a precision statement; `MODE` and `LEVEL` select the variant.
    static let variantFragment = """
    in vec2 uv;
    out vec4 c;
    void main() {
    #if MODE == 1
        c = vec4(uv, float(LEVEL) / 2.0, 1.0);
    #else
        c = vec4(float(LEVEL) / 2.0, uv, 1.0);
    #endif
    }
    """

    private func variants() throws -> ShaderVariantSet {
        try ShaderVariantSet([VariantSwitch(name: "MODE", values: ["0", "1"]),
                              VariantSwitch(name: "LEVEL", values: ["0", "1", "2"])])
    }

    // MARK: Planted mistakes (SC-R02F06-001, GL side)

    func testCompileErrorInsideAnIncludeIsReportedAtTheIncludesFileAndLine() throws {
        var library = ShaderLibrary()
        library.add("lib/shade.glsl", "// helper\nfloat shade(vec2 p) {\n    return missingFunction(p);\n}")
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var caught: ShaderError?
        try withContext(host, scene) { context in
            do {
                _ = try context.resources.program(vertex: Self.vertex,
                                                  fragment: "#include \"lib/shade.glsl\"\nin vec2 uv;\nout vec4 c;\nvoid main() { c = vec4(shade(uv)); }",
                                                  defines: .empty, precision: .high, library: library,
                                                  vertexName: "quad.vert", fragmentName: "shade.frag")
            } catch let error as ShaderError { caught = error }
        }
        let error = try XCTUnwrap(caught)
        XCTAssertEqual(error.reasonCode, .compile)
        guard case .compile(let diagnostics) = error else { return XCTFail("expected compile, got \(error)") }
        let first = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual(first.file, "lib/shade.glsl")
        XCTAssertEqual(first.line, 3)
        XCTAssertEqual(first.stage, .fragment)
        XCTAssertEqual(first.severity, .error)
    }

    func testVaryingMismatchIsALinkErrorLabelledWithBothFiles() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var caught: ShaderError?
        try withContext(host, scene) { context in
            do {
                _ = try context.resources.program(vertex: "out vec3 v_color;\nvoid main() { v_color = vec3(1); gl_Position = vec4(0); }",
                                                  fragment: "in vec4 v_color;\nout vec4 c;\nvoid main() { c = v_color; }",
                                                  defines: .empty, precision: .medium,
                                                  vertexName: "mesh.vert", fragmentName: "mesh.frag")
            } catch let error as ShaderError { caught = error }
        }
        let error = try XCTUnwrap(caught)
        XCTAssertEqual(error.reasonCode, .link)
        guard case .link(let diagnostics) = error else { return XCTFail("expected link, got \(error)") }
        XCTAssertFalse(diagnostics.isEmpty)
        for d in diagnostics {
            XCTAssertEqual(d.file, "mesh.vert+mesh.frag")
            XCTAssertEqual(d.stage, .link)
        }
    }

    func testSourceRefusalsCarryTheirReasonCodes() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var codes: [ShaderReasonCode] = []
        var library = ShaderLibrary()
        library.add("a.glsl", "#include \"b.glsl\"")
        library.add("b.glsl", "#include \"a.glsl\"")
        let fragments = ["#include \"nowhere.glsl\"\nout vec4 c;\nvoid main() { c = vec4(1); }",
                         "#include \"a.glsl\"\nout vec4 c;\nvoid main() { c = vec4(1); }",
                         "#version 310 es\nout vec4 c;\nvoid main() { c = vec4(1); }"]
        try withContext(host, scene) { context in
            for fragment in fragments {
                do {
                    _ = try context.resources.program(vertex: Self.vertex, fragment: fragment, defines: .empty,
                                                      precision: .high, library: library)
                } catch let error as ShaderError { codes.append(error.reasonCode) }
            }
        }
        XCTAssertEqual(codes, [.unknownInclude, .includeCycle, .unsupportedVersion])
        XCTAssertEqual(host.resources.stats.liveCount[.shader], 0, "source refusals never reach the GPU")
    }

    func testALogLongerThan4096BytesIsKeptWhole() throws {
        let count = 120
        let body = (0..<count).map { "    float x\($0) = undefinedFunction\($0)(uv.x);" }.joined(separator: "\n")
        let fragment = "precision mediump float;\nin vec2 uv;\nout vec4 c;\nvoid main() {\n\(body)\n    c = vec4(1);\n}"
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var caught: ShaderError?
        try withContext(host, scene) { context in
            do { _ = try context.resources.program(vertex: Self.vertex, fragment: fragment) }
            catch let error as ShaderError { caught = error }
        }
        XCTAssertGreaterThan(ShaderProgram.lastFailureLog.utf8.count, 4096, "the log exceeds the old fixed buffer")
        XCTAssertLessThanOrEqual(ShaderProgram.lastFailureLog.utf8.count, ShaderProgram.maxInfoLogBytes)
        guard case .compile(let diagnostics)? = caught else { return XCTFail("expected compile, got \(String(describing: caught))") }
        let lines = Set(diagnostics.filter { $0.file == "fragment" }.map(\.line))
        // Body line i sits on fragment line 5 + i; the last planted mistake proves the tail of the log was read.
        XCTAssertTrue(lines.contains(5), "first planted mistake reported")
        XCTAssertTrue(lines.contains(5 + count - 1), "last planted mistake reported (log not truncated)")
    }

    func testWarningsAreKeptOnASuccessfulCompile() throws {
        let clean = "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(1); }"
        let warned = "#extension GL_EXT_vc_not_a_real_extension : enable\nprecision mediump float;\nout vec4 c;\nvoid main() { c = vec4(1); }"
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var cleanProgram: ShaderProgram?
        var warnedProgram: ShaderProgram?
        try withContext(host, scene) { context in
            cleanProgram = try context.resources.program(vertex: Self.vertex, fragment: clean)
            warnedProgram = try context.resources.program(vertex: Self.vertex, fragment: warned, fragmentName: "warn.frag")
        }
        XCTAssertEqual(try XCTUnwrap(cleanProgram).warnings, [], "a clean shader has no warnings")
        let warnings = try XCTUnwrap(warnedProgram).warnings
        print("ANGLE warnings on success: \(warnings)")
        let first = try XCTUnwrap(warnings.first, "ANGLE warns about an unsupported extension on enable")
        XCTAssertEqual(first.severity, .warning)
        XCTAssertEqual(first.file, "warn.frag")
        XCTAssertEqual(first.line, 1)
        XCTAssertEqual(first.stage, .fragment)
    }

    // MARK: Variants in advance (SC-R02F06-002)

    func testSixVariantsPrewarmIntoSixProgramsThenServeSixCacheHits() throws {
        let set = try variants()
        XCTAssertEqual(set.combinations.count, 6)
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let registry = context.resources
            let compiles = registry.compileCount, hits = registry.cacheHits
            let report = registry.prewarm(set, vertex: Self.vertex, fragment: Self.variantFragment, precision: .high)
            XCTAssertEqual(report.entries.map(\.key), set.combinations.map(\.key))
            XCTAssertEqual(Set(report.entries.map(\.key)).count, 6)
            XCTAssertEqual(report.compiledCount, 6, "\(report.entries)")
            XCTAssertEqual(registry.compileCount, compiles + 6)
            var keys = Set<String>()
            for combination in set.combinations {
                let program = try registry.program(vertex: Self.vertex, fragment: Self.variantFragment,
                                                   defines: combination.defines, precision: .high)
                keys.insert(program.cacheKey)
            }
            XCTAssertEqual(keys.count, 6, "six distinct cache keys")
            XCTAssertEqual(registry.cacheHits, hits + 6, "six later requests are cache hits")
            XCTAssertEqual(registry.compileCount, compiles + 6, "no further compile")
            let again = registry.prewarm(set, vertex: Self.vertex, fragment: Self.variantFragment, precision: .high)
            XCTAssertEqual(again.cachedCount, 6)
        }
    }

    func testAFailingCombinationIsReportedWhileTheOthersCompile() throws {
        let set = try ShaderVariantSet([VariantSwitch(name: "GAIN", values: ["0.5", "1.0", "broken_value"])])
        let fragment = "in vec2 uv;\nout vec4 c;\nvoid main() {\n    c = vec4(uv * GAIN, 0.0, 1.0);\n}"
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var report: PrewarmReport?
        try withContext(host, scene) { context in
            report = context.resources.prewarm(set, vertex: Self.vertex, fragment: fragment, precision: .medium,
                                               fragmentName: "gain.frag")
        }
        let r = try XCTUnwrap(report)
        XCTAssertEqual(r.entries.count, 3)
        XCTAssertEqual(r.compiledCount, 2)
        XCTAssertEqual(r.failedCount, 1)
        let failed = try XCTUnwrap(r.entries.first { $0.key == "GAIN=broken_value" })
        XCTAssertEqual(failed.reasonCode, .compile)
        guard case .failed(let diagnostics) = failed.outcome else { return XCTFail("expected failure") }
        XCTAssertEqual(diagnostics.first?.file, "gain.frag")
        XCTAssertEqual(diagnostics.first?.line, 4)
    }

    // MARK: Precision (SC-R02F06-003)

    func testDefaultPrecisionIsInsertedAndCompilesUnderBothPolicies() throws {
        let fragment = "in vec2 uv;\nout vec4 c;\nvoid main() { c = vec4(uv, 0.0, 1.0); }"
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var noPolicy: ShaderError?
        try withContext(host, scene) { context in
            for policy in PrecisionPolicy.allCases {
                let program = try context.resources.program(vertex: Self.vertex, fragment: fragment, defines: .empty,
                                                            precision: policy)
                XCTAssertNotEqual(program.name, 0, "\(policy)")
            }
            do { _ = try context.resources.program(vertex: Self.vertex, fragment: fragment, defines: .empty, precision: nil) }
            catch let error as ShaderError { noPolicy = error }
        }
        XCTAssertEqual(noPolicy?.reasonCode, .compile, "without a policy GLSL ES has no default float precision")
    }

    // MARK: Eviction from a warm set (analyze C2)

    func testAProgramEvictedFromAWarmSetCompilesAgainAndCountsAMiss() throws {
        let set = try variants()
        let filler = "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(float(FILL) / 64.0); }"
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let registry = context.resources
            XCTAssertEqual(registry.prewarm(set, vertex: Self.vertex, fragment: Self.variantFragment, precision: .high).compiledCount, 6)
            for i in 0..<ResourceRegistry.maxCachedPrograms {
                _ = try registry.program(vertex: Self.vertex, fragment: filler, defines: DefineSet(["FILL": "\(i)"]), precision: .high)
            }
            XCTAssertEqual(registry.cachedProgramCount, ResourceRegistry.maxCachedPrograms)
            let compiles = registry.compileCount, hits = registry.cacheHits
            let first = try XCTUnwrap(set.combinations.first)
            _ = try registry.program(vertex: Self.vertex, fragment: Self.variantFragment, defines: first.defines, precision: .high)
            XCTAssertEqual(registry.compileCount, compiles + 1, "the evicted variant compiles again")
            XCTAssertEqual(registry.cacheHits, hits, "and counts a miss, not a hit")
            let report = registry.prewarm(set, vertex: Self.vertex, fragment: Self.variantFragment, precision: .high)
            XCTAssertEqual(report.entries.first?.outcome, .cached)
            XCTAssertEqual(report.compiledCount, 5, "the other five were evicted too and compile again")
        }
    }
}
