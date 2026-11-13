// GLState.swift — hand GL state back to VisualCore after a foreign renderer drew in the same context
// (feature 008 T-F704; FR-F704; migration-log boundary 2a; research R2 in specs/008-projectm-integration).
// App-neutral: any third-party GL engine sharing a VisualCore context (ProjectM in the reference harness, a
// video decoder, a game engine) may leave state VisualCore's renderers assume to be default. Resetting those
// assumptions is cheaper than saving/restoring every state with glGet* each frame.
import CVisualCoreGL

/// Resets shared GL state after a foreign renderer drew in a VisualCore context.
public enum GLState {
    /// Restores the state VisualCore renderers rely on: vertex array 0, program 0, array/element buffers 0,
    /// blending/depth/stencil/culling/scissor disabled, full color mask, texture unit 0 with no 2D texture,
    /// unpack alignment 4, and the given framebuffer and viewport.
    @MainActor
    public static func resetForVisualCore(framebuffer: UInt32, width: Int, height: Int) {
        vcglBindVertexArray(0)
        vcglUseProgram(0)
        vcglBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        vcglBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        for cap in [GL_BLEND, GL_DEPTH_TEST, GL_STENCIL_TEST, GL_CULL_FACE, GL_SCISSOR_TEST, GL_POLYGON_OFFSET_FILL] {
            vcglDisable(GLenum(cap))
        }
        vcglColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        vcglActiveTexture(GLenum(GL_TEXTURE0))
        vcglBindTexture(GLenum(GL_TEXTURE_2D), 0)
        vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 4)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        vcglViewport(0, 0, GLsizei(max(0, width)), GLsizei(max(0, height)))
    }
}

// MARK: Pipeline application (feature 204 R02-F04 T-R02F04-009; FR-R02F04-021, -022)

extension GLState {
    /// Applies `pipeline` as one unit: sets blending (enable, factors and the add equation), depth test (with the
    /// less-than function) and depth write, face culling (enable and face), the colour mask and the program, so the
    /// resulting state depends only on the pipeline, never on what a previous draw left behind.
    ///
    /// A pipeline whose program belongs to an ended context generation, or was released, is refused without any GL
    /// call: the method returns false and the refusal is counted once in `resources.stats.staleRejected`.
    /// Blend factors: alpha = SRC_ALPHA, ONE_MINUS_SRC_ALPHA; premultiplied = ONE, ONE_MINUS_SRC_ALPHA;
    /// additive = ONE, ONE. While blending, depth testing or culling is disabled its factors, function or face are
    /// left untouched (except the depth function, which is always set to LESS).
    /// - Returns: true when the state was applied and the draw may proceed.
    @MainActor
    @discardableResult
    public static func apply(_ pipeline: Pipeline, resources: ResourceRegistry) -> Bool {
        let program = pipeline.program
        // A stale generation is counted by `accept(generation:)` itself.
        guard resources.accept(generation: program.generation) else { return false }
        guard !program.released else {
            // Released but from the current generation: counted as a stale use (FR-R02F04-022).
            resources.noteStale()
            return false
        }
        let state = pipeline.state
        func toggle(_ cap: Int32, _ enabled: Bool) {
            enabled ? vcglEnable(GLenum(cap)) : vcglDisable(GLenum(cap))
        }
        func flag(_ value: Bool) -> GLboolean { GLboolean(value ? GL_TRUE : GL_FALSE) }

        switch state.blend {
        case .none:
            toggle(GL_BLEND, false)
        case .alpha:
            toggle(GL_BLEND, true)
            vcglBlendEquation(GLenum(GL_FUNC_ADD))
            vcglBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        case .premultiplied:
            toggle(GL_BLEND, true)
            vcglBlendEquation(GLenum(GL_FUNC_ADD))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        case .additive:
            toggle(GL_BLEND, true)
            vcglBlendEquation(GLenum(GL_FUNC_ADD))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE))
        }

        toggle(GL_DEPTH_TEST, state.depthTest)
        vcglDepthFunc(GLenum(GL_LESS))
        vcglDepthMask(flag(state.depthWrite))

        switch state.cull {
        case .none:
            toggle(GL_CULL_FACE, false)
        case .back:
            toggle(GL_CULL_FACE, true)
            vcglCullFace(GLenum(GL_BACK))
        case .front:
            toggle(GL_CULL_FACE, true)
            vcglCullFace(GLenum(GL_FRONT))
        }

        let mask = state.colorMask
        vcglColorMask(flag(mask.red), flag(mask.green), flag(mask.blue), flag(mask.alpha))
        vcglUseProgram(program.name)
        return true
    }
}
