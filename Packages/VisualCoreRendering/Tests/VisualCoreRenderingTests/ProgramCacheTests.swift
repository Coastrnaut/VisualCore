// ProgramCacheTests — feature 004 T-F314 (US3; SC-F304, FR-F306, FR-F307); feature 204 T-R02F04-003
// (US1; FR-R02F04-010…014, SC-R02F04-001): eviction retires a program instead of deleting it.
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
        // Amended by feature 204 (FR-R02F04-014): eviction used to delete the program while its holder could still
        // draw with it (a black frame). It now only leaves the cache and is retired, alive until its holder releases
        // it or the context ends (FR-R02F04-010, 011); the cache itself stays bounded at 64 (FR-R02F04-012).
        XCTAssertEqual(h.resources.cachedProgramCount, 64)
        XCTAssertEqual(h.resources.retiredProgramCount, 1)
        XCTAssertEqual(h.resources.evictionCount, 1)
        XCTAssertEqual(h.resources.stats.liveCount[.program], 65, "the evicted program is retired, not deleted")
        XCTAssertFalse(try XCTUnwrap(first).released, "the least recently used program left the cache but stays alive")
    }

    // MARK: Feature 204 story 1 (FR-R02F04-010…013)

    static let solid = "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(1.0, 0.0, 1.0, 1.0); }"

    /// Creates `held` as variant V0, then 64 further variants so that V0 is evicted.
    private func fillCache(_ ctx: RenderContext) throws -> ShaderProgram {
        let held = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.solid, defines: ["V": "0"])
        for i in 1...64 {
            _ = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.solid, defines: ["V": "\(i)"])
        }
        return held
    }

    private static func drawFullScreen(_ program: ShaderProgram?) {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        program?.use()
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    private func assertMagenta(_ p: [UInt8], _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard p.count >= 4 else { return XCTFail("no pixels: \(message)", file: file, line: line) }
        XCTAssertGreaterThan(Int(p[0]), 250, message, file: file, line: line)
        XCTAssertLessThan(Int(p[1]), 5, message, file: file, line: line)
        XCTAssertGreaterThan(Int(p[2]), 250, message, file: file, line: line)
    }

    func testEvictedProgramStillDrawsUntilItsHolderReleasesIt() throws {
        var held: ShaderProgram?
        var releaseNow = false
        let scene = ProbeScene(setup: { ctx in
            if held == nil { held = try self.fillCache(ctx) }
        }, render: { ctx in
            if releaseNow, let p = held { ctx.resources.release(p) } else { Self.drawFullScreen(held) }
        })
        let h = try host(scene)
        XCTAssertEqual(h.resources.evictionCount, 1)
        XCTAssertEqual(h.resources.retiredProgramCount, 1)
        XCTAssertTrue(h.renderOneFrame(present: false))
        assertMagenta(h.readPixels(), "the evicted program still draws its colour, not black")
        XCTAssertEqual(h.resources.stats.liveCount[.program], 65)
        releaseNow = true
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertTrue(try XCTUnwrap(held).released)
        XCTAssertEqual(h.resources.stats.liveCount[.program], 64, "releasing the holder deletes the retired program")
        XCTAssertEqual(h.resources.retiredProgramCount, 0)
        XCTAssertEqual(h.resources.cachedProgramCount, 64)
    }

    func testRetiredProgramsAreReleasedWhenTheContextEnds() throws {
        var held: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            if held == nil { held = try self.fillCache(ctx) }
        })
        let h = try host(scene)
        XCTAssertEqual(h.resources.retiredProgramCount, 1)
        h.recreateContext()
        XCTAssertTrue(try XCTUnwrap(held).released, "the registry released the retired program with the context")
        XCTAssertEqual(h.resources.retiredProgramCount, 0)
        XCTAssertEqual(h.resources.cachedProgramCount, 0)
        XCTAssertEqual(h.resources.stats.liveCount[.program], 0)
        XCTAssertEqual(h.resources.stats.leaked, 0, "retired programs are registry-owned, not scene leaks")
    }

    func testRequestingAnEvictedVariantCompilesANewProgramAndBothDraw() throws {
        var held: ShaderProgram?, again: ShaderProgram?
        var compilesBefore = 0
        var drawWith: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            guard held == nil else { return }
            held = try self.fillCache(ctx)
            compilesBefore = ctx.resources.compileCount
            again = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.solid, defines: ["V": "0"])
        }, render: { _ in Self.drawFullScreen(drawWith) })
        let h = try host(scene)
        XCTAssertEqual(h.resources.compileCount, compilesBefore + 1, "the evicted variant is compiled again")
        XCTAssertFalse(try XCTUnwrap(held) === XCTUnwrap(again))
        XCTAssertEqual(h.resources.evictionCount, 2, "inserting the new program evicted the next least recently used")
        drawWith = held
        XCTAssertTrue(h.renderOneFrame(present: false))
        assertMagenta(h.readPixels(), "the retired original draws")
        drawWith = again
        XCTAssertTrue(h.renderOneFrame(present: false))
        assertMagenta(h.readPixels(), "the recompiled program draws")
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
