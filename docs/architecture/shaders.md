# Shaders: safe compilation, variants, precision and uniforms

Shared feature R02-F06 (feature 206, `specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation`). This
page states the rules every shader of the one app follows; the code is the truth and the tests prove each rule.

## One pipeline

Shader text lives in code (Swift strings) or in the bundled VisualCore include library (`vc/*.glsl`). It is expanded by
`ShaderLibrary` (VisualCoreShaderSource, pure), compiled and linked by `ResourceRegistry.program(...)`
(VisualCoreRendering) inside the render host's callbacks, and cached by a hash of the expanded texts (64 programs;
an evicted program is retired, never deleted while in use). There is no second pipeline and no second context.

## Expansion

- `#version 300 es` is the only version; it is written by the expander when absent.
- `#include "name"` pastes a library file once per expansion; a later include of the same file is skipped. A cycle,
  an unknown file or a depth above 8 is refused.
- The expanded text is at most 64 KiB, counted in bytes while expanding.
- Defines (`DefineSet`) are validated before expansion: a name matches `[A-Za-z_][A-Za-z0-9_]*` and does not start with
  `GL_` or `__`; a value is one line of at most 256 characters (empty allowed); at most 32 defines.
- Every expanded line keeps its origin (file and line), so diagnostics name what the author wrote.

## Variants

A shader's variants are declared as a `ShaderVariantSet`: at most 6 switches, each a define name with 1–8 values, at
most 64 combinations, enumerated in a fixed order with keys `name=value;…`. `ResourceRegistry.prewarm(...)` compiles
every combination through the same cache and reports each one as compiled, cached or failed with its diagnostics;
one failure never stops the others. A prewarm is valid for the current context; after a rebuild it is run again.

## Precision

A fragment shader without a `precision … float;` statement gets one as a generated line: `highp` when the device
reports high fragment precision (`RenderCapabilities.fragmentHighp`), otherwise `mediump` (`PrecisionPolicy`). A shader
that asks for `highp` under the medium policy is reported with its file and line. Vertex shaders are unchanged.

## Diagnostics

Compile and link logs are read whole (up to 64 KiB). Warnings of a successful compile stay with the program
(`ShaderProgram.warnings`). Link diagnostics name both stages' files. Every refusal carries a stable reason code
(`ShaderReasonCode`, `shader.*`) and a failure report (`ShaderFailureReport`) carries the feature id `R2-F06`, the code,
the diagnostics and, when the caller gives them, the experience id, seed, tick and capability tier.

## Uniforms and parameters

A shader may declare its uniforms (`UniformLayout`: names and types). After linking, the declared layout is checked
against the program's active uniforms: an active uniform not declared, or of another type, is an error naming it; a
declared uniform the compiler removed is reported as unused. A parameter schema (`ParameterSchema`) binds to a
program's `u_<name>` float uniforms (`ParameterUniformBinding`): values are clamped to their ranges, a non-finite value
is refused before anything is set, and a parameter without a uniform is reported once. Bindings hold no GPU object
across a context rebuild; they are made again from the new program and give the same uniform values.

## Emissive pass and mobile-safe bloom (R02-F07, feature 207)

The effect graph's `emissive` pass gives glowing looks that behave like light, cheaply enough for phones:
- the input (an 8-bit sRGB-encoded scene) is decoded to linear light, without clamping above 1 in the intermediates;
- light above a threshold (linear units, quadratic soft knee) is extracted while the picture is reduced to half or a
  quarter of its size, blurred there with a separable 9-tap Gaussian, and added back with one bilinear upsample —
  four draws (prefilter, horizontal and vertical blur, composite), two small targets from the pool, returned every frame;
- an exposure in stops and a tone map (none by default, Reinhard, or the Narkowicz ACES fit) are applied before the
  result is encoded to sRGB; the input's alpha is kept;
- the blur targets are half-float where the device can draw into them; otherwise they are 8-bit, the glow is limited
  to 1, and the renderer warns once;
- `composite` mode 2 is premultiplied "over" and `RenderState.premultipliedBlended` draws premultiplied layers, so soft
  edges have no fringes;
- when flashing is reduced, the flash limiter still runs last and, for graphs that contain an emissive pass, measures
  brightness in linear light. Existing graphs measure as before.
The formulas live once on the CPU (`EmissiveReference`, VisualCoreEffectsGraph) and the GPU passes are tested against
them.

## Out of scope

Uniform blocks, shader binaries on disk, shaders downloaded at run time. The device drivers' behaviour is checked in
the device campaign after ImplementationLock-100.
