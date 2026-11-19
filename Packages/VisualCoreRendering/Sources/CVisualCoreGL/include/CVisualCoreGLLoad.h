// CVisualCoreGLLoad.h — load the generated GL table from ANGLE's EGL resolver (hand-written).
#ifndef CVISUALCOREGLLOAD_H
#define CVISUALCOREGLLOAD_H
#include "CVisualCoreGL.h"

/// Returns the number of ES 3.0 entry points that could not be resolved (0 = complete).
/// Also resolves the optional extension entry points below; those are never counted as missing.
int vcglLoadFromEGL(void);

// MARK: GL_EXT_disjoint_timer_query (feature 175 T-A24-303; hand-written, never in the generated header)

/// `GL_TIME_ELAPSED_EXT`: the query target that measures the GPU time of the commands between begin and end.
#define GL_TIME_ELAPSED_EXT 0x88BF
/// `GL_GPU_DISJOINT_EXT`: read with `vcglGetIntegerv`; nonzero when a timer result may be invalid (and clears it).
#define GL_GPU_DISJOINT_EXT 0x8FBB

/// Returns 1 when `glGetQueryObjectui64vEXT` and the core query calls it needs (`glGenQueries`, `glBeginQuery`,
/// `glEndQuery`, `glGetQueryObjectuiv`, `glDeleteQueries`, `glGetIntegerv`) were resolved by the last
/// `vcglLoadFromEGL`, otherwise 0. The extension must also be listed by the context before it is used.
int vcglHasDisjointTimerQuery(void);

/// Calls `glGetQueryObjectui64vEXT`; does nothing (leaves `params` unchanged) when the entry point was not resolved.
void vcglGetQueryObjectui64vEXT(GLuint id, GLenum pname, GLuint64 *params);
#endif
