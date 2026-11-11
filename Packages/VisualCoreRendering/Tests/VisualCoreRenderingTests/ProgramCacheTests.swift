// ProgramCacheTests — feature 004 T-F314 (US3; SC-F304, FR-F306, FR-F307).
import CVisualCoreGL
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ProgramCacheTests: XCTestCase {
    static let fragment = "precision mediump float;\nuniform vec3 uColor;\nuniform float uTime;\nout vec4 c;\nvoid main() { c = vec4(uColor * uTime, 1.0); }"

    private func host(_ scene: RenderScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        return h
    }

    func testIdenticalRequestsCompileOncePerGeneration() throws {
        var programs: [ShaderProgram] = []
        let scene = ProbeScene(setup: { ctx in
            programs.append(try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment))
            programs.append(try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment))
            programs.append(try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment, defines: ["HQ": "1"]))
        })
        let h = try host(scene)
        XCTAssertTrue(programs[0] === programs[1], "cache hit returns the same program")
        XCTAssertFalse(programs[0] === programs[2], "a different define is a different variant")
        XCTAssertEqual(h.resources.compileCount, 2)
        XCTAssertEqual(h.resources.cacheHits, 1)
        h.recreateContext()                     // setup runs again on the new generation
        XCTAssertEqual(h.resources.compileCount, 4, "cache cleared on recreation: both variants recompile")
        XCTAssertEqual(h.resources.cacheHits, 2)
        XCTAssertEqual(programs[3].generation, 2)
    }

    func testCacheIsBoundedToSixtyFourWithLRUEviction() throws {
        var first: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            first = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment, defines: ["V": "0"])
            for i in 1...64 {
                _ = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment, defines: ["V": "\(i)"])
            }
        })
        let h = try host(scene)
        XCTAssertEqual(h.resources.cachedProgramCount, 64)
        XCTAssertEqual(h.resources.stats.liveCount[.program], 64, "the evicted program was deleted")
        XCTAssertTrue(try XCTUnwrap(first).released, "the least recently used program was evicted")
    }

    func testUniformTypeMismatchIsReportedOnceAndNotApplied() throws {
        var program: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            let p = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.fragment)
            program = p
            p.use()
            p.set("uColor", SIMD3<Float>(0.1, 0.2, 0.3))
            p.set("uColor", Float(5))          // mismatch: vec3 set as float
            p.set("uColor", Float(6))          // same mismatch again: reported once
            p.set("uMissing", Float(1))        // not an active uniform
        })
        let h = try host(scene)
        let p = try XCTUnwrap(program)
        var value = [GLfloat](repeating: 0, count: 3)
        vcglGetUniformfv(p.name, p.uniforms["uColor"]!.location, &value)
        XCTAssertEqual(value[0], 0.1, accuracy: 1e-6, "the mismatched write was not applied")
        let warnings = h.resources.stats.warnings
        XCTAssertEqual(warnings.filter { $0.contains("uColor") }.count, 1)
        XCTAssertEqual(warnings.filter { $0.contains("uMissing") }.count, 1)
    }
}
