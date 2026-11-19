# Contract: VisualCoreRendering additions (A24-P03, U-RENDERINFO and U-GPUTIMER)

- `ResourceRegistry.renderCapabilities: RenderCapabilities { get }` — the current context generation's capabilities,
  set by `RenderHost` whenever it queries them; `RenderCapabilities()` before the first context.
- `@MainActor public final class GPUFrameTimer`:
  - `public static let extensionName = "GL_EXT_disjoint_timer_query"`;
  - `public init?(context: RenderContext)` — nil unless the extension is listed in
    `context.resources.renderCapabilities.extensions` and its entry points resolved;
  - `public func begin(frame: Int)`, `public func end()` — bracket one frame's GL work (at most one open query);
  - `public func poll() -> [GPUFrameTime]` — finished, available, non-disjoint results in frame order; a disjoint read
    discards every pending query and increments `disjointCount`;
  - `public private(set) var disjointCount: Int`; `public func release()`.
- `public struct GPUFrameTime: Sendable, Equatable { public let frame: Int; public let milliseconds: Double }`.
- Loader: `int vcglHasDisjointTimerQuery(void)`, `void vcglGetQueryObjectui64vEXT(GLuint, GLenum, GLuint64*)`,
  `GL_TIME_ELAPSED_EXT 0x88BF`, `GL_GPU_DISJOINT_EXT 0x8FBB`; resolved optionally after `vcglLoadFromEGL`.
- Every addition carries `///` docs, is listed in the API baseline and both READMEs.
