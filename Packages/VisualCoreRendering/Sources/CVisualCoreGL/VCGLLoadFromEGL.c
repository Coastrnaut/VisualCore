// VCGLLoadFromEGL.c — fills the generated GL table from ANGLE's eglGetProcAddress (feature 003 T-F208).
// Hand-written companion of the generated CVisualCoreGL.c; no dlsym (Constitution I).
#include "CVisualCoreGL.h"
#include "CVisualCoreEGL.h"

static void *vcglEGLLoader(const char *name, void *user) {
    return vcEGLLoadProc(name, user);
}

int vcglLoadFromEGL(void) {
    return vcglLoad(vcglEGLLoader, 0);
}
