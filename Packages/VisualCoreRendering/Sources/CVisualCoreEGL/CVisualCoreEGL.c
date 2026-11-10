// CVisualCoreEGL.c — GL load proc over ANGLE's eglGetProcAddress (feature 003 T-F201). No dlsym.
#include "CVisualCoreEGL.h"

void *vcEGLLoadProc(const char *name, void *user) {
    (void)user;
    return (void *)eglGetProcAddress(name);
}

int vcEGLShimVersion(void) { return 2; }
