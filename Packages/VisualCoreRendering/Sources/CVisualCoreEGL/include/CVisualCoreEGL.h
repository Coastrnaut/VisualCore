// CVisualCoreEGL — the EGL subset used by the VisualCore render host (feature 003 T-F201; ADR-0002).
//
// Types, prototypes and constant values are those of ANGLE's include/EGL/egl.h and eglext_angle.h at
// the pinned ANGLE commit 29d1823 (owner fork Coastrnaut/angle, ios branch), declared here so no copy of
// the Khronos headers is needed. Same approach and values as the owner's reference
// External/projectm-ios/Packages/ANGLERendering/Sources/CANGLE/include/CANGLE.h (MIT), extended with the
// query and error constants the host reports in diagnostics. Implemented by the prebuilt libEGL.
#ifndef CVISUALCOREEGL_H
#define CVISUALCOREEGL_H

#include <stdint.h>

typedef void *_Nullable EGLDisplay;
typedef void *_Nullable EGLConfig;
typedef void *_Nullable EGLContext;
typedef void *_Nullable EGLSurface;
typedef void *_Nullable EGLNativeWindowType;
typedef int32_t EGLint;
typedef unsigned int EGLBoolean;
typedef unsigned int EGLenum;
typedef intptr_t EGLAttrib;
typedef void (*_Nullable __eglMustCastToProperFunctionPointerType)(void);

#define EGL_FALSE 0
#define EGL_TRUE 1
#define EGL_NONE 0x3038
// Errors (eglGetError)
#define EGL_SUCCESS 0x3000
#define EGL_NOT_INITIALIZED 0x3001
#define EGL_BAD_ACCESS 0x3002
#define EGL_BAD_ALLOC 0x3003
#define EGL_BAD_ATTRIBUTE 0x3004
#define EGL_BAD_CONFIG 0x3005
#define EGL_BAD_CONTEXT 0x3006
#define EGL_BAD_CURRENT_SURFACE 0x3007
#define EGL_BAD_DISPLAY 0x3008
#define EGL_BAD_MATCH 0x3009
#define EGL_BAD_NATIVE_PIXMAP 0x300A
#define EGL_BAD_NATIVE_WINDOW 0x300B
#define EGL_BAD_PARAMETER 0x300C
#define EGL_BAD_SURFACE 0x300D
#define EGL_CONTEXT_LOST 0x300E
// Config attributes
#define EGL_ALPHA_SIZE 0x3021
#define EGL_BLUE_SIZE 0x3022
#define EGL_GREEN_SIZE 0x3023
#define EGL_RED_SIZE 0x3024
#define EGL_DEPTH_SIZE 0x3025
#define EGL_STENCIL_SIZE 0x3026
#define EGL_SURFACE_TYPE 0x3033
#define EGL_RENDERABLE_TYPE 0x3040
#define EGL_PBUFFER_BIT 0x0001
#define EGL_WINDOW_BIT 0x0004
#define EGL_OPENGL_ES3_BIT 0x00000040
// Surface attributes and query strings
#define EGL_HEIGHT 0x3056
#define EGL_WIDTH 0x3057
#define EGL_DRAW 0x3059
#define EGL_READ 0x305A
#define EGL_VENDOR 0x3053
#define EGL_VERSION 0x3054
#define EGL_EXTENSIONS 0x3055
// Context attributes
#define EGL_CONTEXT_MAJOR_VERSION 0x3098
#define EGL_CONTEXT_MINOR_VERSION 0x30FB
// EGL_ANGLE_platform_angle, EGL_ANGLE_platform_angle_metal
#define EGL_PLATFORM_ANGLE_ANGLE 0x3202
#define EGL_PLATFORM_ANGLE_TYPE_ANGLE 0x3203
#define EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE 0x3489

EGLDisplay eglGetPlatformDisplay(EGLenum platform, void *_Nullable native_display, const EGLAttrib *_Nullable attrib_list);
EGLBoolean eglInitialize(EGLDisplay dpy, EGLint *_Nullable major, EGLint *_Nullable minor);
EGLBoolean eglChooseConfig(EGLDisplay dpy, const EGLint *_Nullable attrib_list, EGLConfig *_Nullable configs,
                           EGLint config_size, EGLint *_Nonnull num_config);
EGLContext eglCreateContext(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *_Nullable attrib_list);
EGLBoolean eglDestroyContext(EGLDisplay dpy, EGLContext ctx);
EGLSurface eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config, EGLNativeWindowType win,
                                  const EGLint *_Nullable attrib_list);
EGLSurface eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config, const EGLint *_Nullable attrib_list);
EGLBoolean eglDestroySurface(EGLDisplay dpy, EGLSurface surface);
EGLBoolean eglQuerySurface(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *_Nonnull value);
EGLBoolean eglMakeCurrent(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx);
EGLBoolean eglSwapBuffers(EGLDisplay dpy, EGLSurface surface);
EGLContext eglGetCurrentContext(void);
EGLint eglGetError(void);
const char *_Nullable eglQueryString(EGLDisplay dpy, EGLint name);
__eglMustCastToProperFunctionPointerType eglGetProcAddress(const char *_Nonnull procname);

/// GL load proc over ANGLE's documented resolver (no dlsym). Pass to `vcglLoad`.
void *_Nullable vcEGLLoadProc(const char *_Nonnull name, void *_Nullable user);

/// Shim version, bumped with the declaration set.
int vcEGLShimVersion(void);

#endif
