// PipelineTests — feature 204 R02-F04 T-R02F04-008 (US2; FR-R02F04-020, -021, -022, -024). Applying a pipeline sets
// every state it describes regardless of the prior state (read back with glIsEnabled/glGetIntegerv/glGetBooleanv);
// pipelines compare by program identity; stale and released programs are refused and counted as stale uses.
import CVisualCoreGL
import VisualCoreShaderSource
import XCTest
@testable import VisualCoreRendering

@MainActor
final class PipelineTests: XCTestCase {
    static let red = "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(1.0, 0.0, 0.0, 1.0); }"
    static let green = "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(0.0, 1.0, 0.0, 1.0); }"

    private func host(_ scene: ProbeScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        return h
    }

    /// Everything the pipeline controls, as read back from GL.
    private struct Readback: Equatable {
        var blend = false, srcRGB: GLint = 0, dstRGB: GLint = 0, srcAlpha: GLint = 0, dstAlpha: GLint = 0
        var equationRGB: GLint = 0, equationAlpha: GLint = 0
        var depthTest = false, depthFunc: GLint = 0, depthWrite = false
        var cull = false, cullMode: GLint = 0
        var mask: [Bool] = []
        var program: GLint = 0
    }

    private func read() -> Readback {
        func int(_ pname: Int32) -> GLint { var v: GLint = 0; vcglGetIntegerv(GLenum(pname), &v); return v }
        var r = Readback()
        r.blend = vcglIsEnabled(GLenum(GL_BLEND)) == GLboolean(GL_TRUE)
        r.srcRGB = int(GL_BLEND_SRC_RGB); r.dstRGB = int(GL_BLEND_DST_RGB)
        r.srcAlpha = int(GL_BLEND_SRC_ALPHA); r.dstAlpha = int(GL_BLEND_DST_ALPHA)
        r.equationRGB = int(GL_BLEND_EQUATION_RGB); r.equationAlpha = int(GL_BLEND_EQUATION_ALPHA)
        r.depthTest = vcglIsEnabled(GLenum(GL_DEPTH_TEST)) == GLboolean(GL_TRUE)
        r.depthFunc = int(GL_DEPTH_FUNC)
        var depthMask: GLboolean = 0
        vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &depthMask)
        r.depthWrite = depthMask == GLboolean(GL_TRUE)
        r.cull = vcglIsEnabled(GLenum(GL_CULL_FACE)) == GLboolean(GL_TRUE)
        r.cullMode = int(GL_CULL_FACE_MODE)
        var mask = [GLboolean](repeating: 0, count: 4)
        vcglGetBooleanv(GLenum(GL_COLOR_WRITEMASK), &mask)
        r.mask = mask.map { $0 == GLboolean(GL_TRUE) }
        r.program = int(GL_CURRENT_PROGRAM)
        return r
    }

    /// Three prior states: everything enabled with odd factors and masks; everything disabled; mixed.
    private func dirty(_ variant: Int, other: ShaderProgram) {
        func on(_ cap: Int32, _ enabled: Bool) { enabled ? vcglEnable(GLenum(cap)) : vcglDisable(GLenum(cap)) }
        let f = GLboolean(GL_FALSE), t = GLboolean(GL_TRUE)
        switch variant {
        case 0:
            on(GL_BLEND, true); on(GL_DEPTH_TEST, true); on(GL_CULL_FACE, true)
            vcglBlendFuncSeparate(GLenum(GL_DST_COLOR), GLenum(GL_ZERO), GLenum(GL_ZERO), GLenum(GL_DST_ALPHA))
            vcglBlendEquation(GLenum(GL_FUNC_REVERSE_SUBTRACT))
            vcglDepthFunc(GLenum(GL_GREATER)); vcglDepthMask(t)
            vcglCullFace(GLenum(GL_FRONT_AND_BACK))
            vcglColorMask(f, t, f, t)
            vcglUseProgram(other.name)
        case 1:
            on(GL_BLEND, false); on(GL_DEPTH_TEST, false); on(GL_CULL_FACE, false)
            vcglDepthMask(f)
            vcglColorMask(f, f, f, f)
            vcglUseProgram(0)
        default:
            on(GL_BLEND, true); on(GL_DEPTH_TEST, false); on(GL_CULL_FACE, true)
            vcglBlendFunc(GLenum(GL_ONE_MINUS_DST_ALPHA), GLenum(GL_SRC_COLOR))
            vcglBlendEquation(GLenum(GL_FUNC_SUBTRACT))
            vcglDepthFunc(GLenum(GL_ALWAYS)); vcglDepthMask(f)
            vcglCullFace(GLenum(GL_BACK))
            vcglColorMask(t, f, t, f)
            vcglUseProgram(other.name)
        }
    }

    /// The readback the state must produce; blend factors and equation only matter while blending is enabled.
    private func expected(_ state: RenderState, program: ShaderProgram, after actual: Readback) -> Readback {
        var r = Readback()
        switch state.blend {
        case .none:
            r.blend = false
            (r.srcRGB, r.dstRGB, r.srcAlpha, r.dstAlpha) = (actual.srcRGB, actual.dstRGB, actual.srcAlpha, actual.dstAlpha)
            (r.equationRGB, r.equationAlpha) = (actual.equationRGB, actual.equationAlpha)
        case .alpha, .premultiplied, .additive:
            r.blend = true
            let (s, d): (Int32, Int32) = switch state.blend {
            case .alpha: (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
            case .premultiplied: (GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
            default: (GL_ONE, GL_ONE)
            }
            (r.srcRGB, r.dstRGB, r.srcAlpha, r.dstAlpha) = (GLint(s), GLint(d), GLint(s), GLint(d))
            (r.equationRGB, r.equationAlpha) = (GLint(GL_FUNC_ADD), GLint(GL_FUNC_ADD))
        }
        r.depthTest = state.depthTest
        r.depthFunc = GLint(GL_LESS)   // always set, so a later depth-tested draw never inherits a foreign function
        r.depthWrite = state.depthWrite
        r.cull = state.cull != .none
        switch state.cull {
        case .none: r.cullMode = actual.cullMode
        case .back: r.cullMode = GLint(GL_BACK)
        case .front: r.cullMode = GLint(GL_FRONT)
        }
        r.mask = [state.colorMask.red, state.colorMask.green, state.colorMask.blue, state.colorMask.alpha]
        r.program = GLint(program.name)
        return r
    }

    func testEveryPresetIsAppliedExactlyAfterThreeDifferentPriorStates() throws {
        let custom = RenderState(blend: .premultiplied, depthTest: true, depthWrite: false, cull: .front,
                                 colorMask: RenderState.ColorMask(red: true, green: false, blue: true, alpha: false))
        let states: [(String, RenderState)] = [("opaque", .opaque), ("alphaBlended", .alphaBlended),
                                               ("additive", .additive), ("opaque3D", .opaque3D), ("custom", custom)]
        var checked = 0
        let scene = ProbeScene(setup: { ctx in
            let program = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red)
            let other = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.green)
            for (label, state) in states {
                for variant in 0..<3 {
                    self.dirty(variant, other: other)
                    XCTAssertTrue(GLState.apply(Pipeline(program: program, state: state), resources: ctx.resources),
                                  "\(label) after prior state \(variant) applied")
                    let actual = self.read()
                    XCTAssertEqual(actual, self.expected(state, program: program, after: actual),
                                   "\(label) after prior state \(variant)")
                    XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR), "\(label) after prior state \(variant): no GL error")
                    checked += 1
                }
            }
        })
        let h = try host(scene)
        XCTAssertEqual(checked, 15)
        XCTAssertEqual(h.resources.stats.staleRejected, 0)
    }

    func testTwoPipelinesInTurnEachLeaveExactlyTheirState() throws {
        let scene = ProbeScene(setup: { ctx in
            let a = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red)
            let b = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.green)
            let first = RenderState(blend: .alpha, depthTest: true, depthWrite: false)   // acceptance scenario 1
            XCTAssertTrue(GLState.apply(Pipeline(program: a, state: first), resources: ctx.resources))
            var r = self.read()
            XCTAssertEqual(r, self.expected(first, program: a, after: r))
            XCTAssertTrue(GLState.apply(Pipeline(program: b, state: .opaque3D), resources: ctx.resources))
            r = self.read()
            XCTAssertEqual(r, self.expected(.opaque3D, program: b, after: r))
        })
        _ = try host(scene)
    }

    func testPipelineEqualityUsesProgramIdentityAndState() throws {
        let scene = ProbeScene(setup: { ctx in
            let a = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red)
            let same = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red)   // cache hit
            let b = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.green)
            XCTAssertTrue(a === same)
            XCTAssertEqual(Pipeline(program: a, state: .additive), Pipeline(program: same, state: .additive))
            XCTAssertEqual(Pipeline(program: a, state: .additive).hashValue, Pipeline(program: same, state: .additive).hashValue)
            XCTAssertNotEqual(Pipeline(program: a, state: .additive), Pipeline(program: b, state: .additive),
                              "same state, different program objects")
            XCTAssertNotEqual(Pipeline(program: a, state: .additive), Pipeline(program: a, state: .alphaBlended))
            let set: Set<Pipeline> = [Pipeline(program: a, state: .opaque), Pipeline(program: same, state: .opaque),
                                      Pipeline(program: b, state: .opaque), Pipeline(program: a, state: .opaque3D)]
            XCTAssertEqual(set.count, 3)
        })
        _ = try host(scene)
    }

    func testReleasedProgramIsRefusedAndCountedAsStale() throws {
        var before = -1, after = -1, refused = true
        var programBefore: GLint = -1, programAfter: GLint = -2
        let scene = ProbeScene(setup: { ctx in
            let keep = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.green)
            let gone = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red)
            XCTAssertTrue(GLState.apply(Pipeline(program: keep, state: .opaque), resources: ctx.resources))
            ctx.resources.release(gone)
            vcglGetIntegerv(GLenum(GL_CURRENT_PROGRAM), &programBefore)
            before = ctx.resources.stats.staleRejected
            refused = !GLState.apply(Pipeline(program: gone, state: .additive), resources: ctx.resources)
            after = ctx.resources.stats.staleRejected
            vcglGetIntegerv(GLenum(GL_CURRENT_PROGRAM), &programAfter)
        })
        _ = try host(scene)
        XCTAssertTrue(refused, "apply returns false for a released program")
        XCTAssertEqual(after, before + 1, "the refusal is counted with the stale counter")
        XCTAssertEqual(programAfter, programBefore, "the refused pipeline did not change the current program")
    }

    func testProgramFromBeforeRecreateContextIsRefusedAndCountedAsStale() throws {
        var programs: [ShaderProgram] = []
        let scene = ProbeScene(setup: { ctx in
            programs.append(try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.red))
        })
        let h = try host(scene)
        let old = try XCTUnwrap(programs.first)
        XCTAssertTrue(GLState.apply(Pipeline(program: old, state: .opaque), resources: h.resources), "current before recreation")
        h.recreateContext()
        XCTAssertEqual(programs.count, 2)
        XCTAssertNotEqual(old.generation, h.resources.generation)
        let before = h.resources.stats.staleRejected
        XCTAssertFalse(GLState.apply(Pipeline(program: old, state: .opaque), resources: h.resources),
                       "a program from the ended context is refused")
        XCTAssertEqual(h.resources.stats.staleRejected, before + 1)
        XCTAssertTrue(GLState.apply(Pipeline(program: programs[1], state: .opaque), resources: h.resources),
                      "the recompiled program of the new generation is accepted")
        XCTAssertEqual(h.resources.stats.staleRejected, before + 1)
    }
}
