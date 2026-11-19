// VCGLLoadFromEGL.c — fills the generated GL table from ANGLE's eglGetProcAddress (feature 003 T-F208).
// Hand-written companion of the generated CVisualCoreGL.c; no dlsym (Constitution I).
// Feature 175 T-A24-303: optional GL_EXT_disjoint_timer_query entry points, never counted as missing.
#include "CVisualCoreGL.h"
#include "CVisualCoreGLLoad.h"
#include "CVisualCoreEGL.h"

static void *vcglEGLLoader(const char *name, void *user) {
    return vcEGLLoadProc(name, user);
}

typedef void (*VCGLGetQueryObjectui64vEXTProc)(GLuint id, GLenum pname, GLuint64 *params);

static VCGLGetQueryObjectui64vEXTProc vcglGetQueryObjectui64vEXTPtr;
static int vcglTimerQueryResolved;

static void vcglLoadTimerQuery(void) {
    vcglGetQueryObjectui64vEXTPtr = (VCGLGetQueryObjectui64vEXTProc)vcglEGLLoader("glGetQueryObjectui64vEXT", 0);
    static const char *const core[] = {
        "glGenQueries", "glBeginQuery", "glEndQuery", "glGetQueryObjectuiv", "glDeleteQueries", "glGetIntegerv"
    };
    int resolved = vcglGetQueryObjectui64vEXTPtr != 0;
    for (size_t i = 0; resolved && i < sizeof(core) / sizeof(core[0]); i++) {
        if (!vcglEGLLoader(core[i], 0)) resolved = 0;
    }
    vcglTimerQueryResolved = resolved;
}

int vcglLoadFromEGL(void) {
    int missing = vcglLoad(vcglEGLLoader, 0);
    vcglLoadTimerQuery();
    return missing;
}

int vcglHasDisjointTimerQuery(void) {
    return vcglTimerQueryResolved;
}

void vcglGetQueryObjectui64vEXT(GLuint id, GLenum pname, GLuint64 *params) {
    if (vcglGetQueryObjectui64vEXTPtr) vcglGetQueryObjectui64vEXTPtr(id, pname, params);
}
