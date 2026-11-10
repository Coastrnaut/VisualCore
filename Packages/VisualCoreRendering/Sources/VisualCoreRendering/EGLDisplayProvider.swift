// EGLDisplayProvider.swift — the process-wide ANGLE Metal display (feature 003 T-F207; FR-F201, FR-F216).
// Same platform attributes and config as the audited reference ANGLERenderer.make()
// (docs/architecture/current-rendering-pipeline.md §2). Initialized once and never terminated:
// eglTerminate would invalidate every other host's context (clarification 2026-11-10).
import CVisualCoreEGL
import CVisualCoreGL

@MainActor
enum EGLDisplayProvider {
    private static var cached: (display: EGLDisplay, config: EGLConfig)?

    static func shared() throws -> (display: EGLDisplay, config: EGLConfig) {
        if let cached { return cached }
        let platform: [EGLAttrib] = [EGLAttrib(EGL_PLATFORM_ANGLE_TYPE_ANGLE), EGLAttrib(EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE),
                                     EGLAttrib(EGL_NONE)]
        guard let display = eglGetPlatformDisplay(EGLenum(EGL_PLATFORM_ANGLE_ANGLE), nil, platform),
              eglInitialize(display, nil, nil) == EGL_TRUE else {
            throw RenderHostError.unsupported("ANGLE Metal display unavailable (EGL error 0x\(String(eglGetError(), radix: 16)))")
        }
        let attributes: [EGLint] = [EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
                                    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
                                    EGL_SURFACE_TYPE, EGL_WINDOW_BIT | EGL_PBUFFER_BIT, EGL_NONE]
        var config: EGLConfig?
        var count: EGLint = 0
        guard eglChooseConfig(display, attributes, &config, 1, &count) == EGL_TRUE, count > 0, let config else {
            throw RenderHostError.unsupported("no RGBA8 OpenGL ES 3 config (EGL error 0x\(String(eglGetError(), radix: 16)))")
        }
        cached = (display, config)
        return (display, config)
    }
}
