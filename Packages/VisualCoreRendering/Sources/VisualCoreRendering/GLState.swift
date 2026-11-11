// GLState.swift — hand GL state back to VisualCore after a foreign renderer drew in the same context
// (feature 008 T-F704; FR-F704; migration-log boundary 2a; research R2 in specs/008-projectm-integration).
// App-neutral: any third-party GL engine sharing a VisualCore context (ProjectM in the reference harness, a
// video decoder, a game engine) may leave state VisualCore's renderers assume to be default. Resetting those
// assumptions is cheaper than saving/restoring every state with glGet* each frame.
import CVisualCoreGL

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
