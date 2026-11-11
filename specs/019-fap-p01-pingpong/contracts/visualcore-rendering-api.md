# Contract: VisualCoreRendering additions (G-PINGPONG, G-FLOATRT, G-FIELDPASS)

All types are `@MainActor` and used with the host's context current (the `RenderScene` callbacks). Public symbols
carry `///` docs and appear in the API baseline.

## FloatRenderSupport (G-FLOATRT)

```swift
public struct FloatRenderSupport: Sendable, Equatable {
    public let extensionReported: Bool   // EXT_color_buffer_half_float or EXT_color_buffer_float
    public let probeComplete: Bool       // 4x4 RGBA16F target complete, clear + readback finite
    public var supported: Bool { extensionReported && probeComplete }
    public static func detect(in registry: ResourceRegistry) -> FloatRenderSupport   // cached per generation
    public func storageFormat(forceFallback: Bool = false) -> TextureFormat          // .rgba16f or .rgba8
}
extension RenderCapabilities { public var reportsColorBufferHalfFloat: Bool { get } }
```

- The probe target is released before `detect` returns, so the ledger is unchanged.
- **Test**: `detect` agrees with an independent probe on both simulator runtimes. `forceFallback` → `.rgba8`.

## RenderTarget transfer

```swift
extension RenderTarget {
    public func upload(rgbaFloats: [Float]) -> Bool   // count == w*h*4; rgba16f: GL_FLOAT; rgba8: quantized unorm8
    public func readFloatPixels() -> [Float]          // rows bottom-up; [] on failure/stale/released or r8
}
```

## PingPongTarget (G-PINGPONG)

```swift
public final class PingPongTarget {
    public init(registry: ResourceRegistry, width: Int, height: Int, format: TextureFormat, label: String) throws
    public private(set) var read: RenderTarget
    public private(set) var write: RenderTarget
    public let width: Int, height: Int, format: TextureFormat
    public private(set) var swapCount: Int
    public var bytes: Int { get }                // both targets
    public var isValid: Bool { get }             // not released and current generation
    public func swap()
    public func release()                        // idempotent; stale release is ignored
}
```

- Invariant: `read !== write` and both are the same size and format.
- If creating the second target fails, the first is released before the error is rethrown, so nothing leaks.
- **Test**: swap alternates; the bytes equal 2·w·h·bpp in the ledger; release returns the ledger to its prior state;
  a context loss makes `isValid` false and the stale use is rejected.

## FieldPass (G-FIELDPASS)

```swift
public enum FieldUniform: Sendable, Equatable { case float(Float), vec2(SIMD2<Float>), vec4(SIMD4<Float>), int(Int32) }
public enum FieldPassError: Error, Equatable, Sendable {
    case inputIsOutput(String), missingInput(String), unknownInput(String), unknownUniform(String),
         uniformTypeMismatch(String), stale, compile(String)
}
public final class FieldPass {
    public enum Output { case target(RenderTarget), framebuffer(name: UInt32, width: Int, height: Int) }
    public init(registry: ResourceRegistry, fragment: String, inputs: [String], label: String) throws(FieldPassError)
    public let inputs: [String]
    public func run(output: Output, inputs: [String: RenderTarget], uniforms: [String: FieldUniform] = [:]) throws(FieldPassError)
    public func run(pair: PingPongTarget, input: String, extraInputs: [String: RenderTarget] = [:],
                    uniforms: [String: FieldUniform] = [:]) throws(FieldPassError)   // swaps on success only
    public func release()
}
```

- Each fragment receives `in vec2 v_uv` from `FullScreenShaderScene.vertexSource`. Samplers are bound to units in the
  order of `inputs`. The pass sets the viewport to the output size, and blending is disabled for the pass (GLState
  restored).
- Checks happen before any draw:
  - every name in `inputs` must be supplied, and no other;
  - no input may share a GL texture with the output;
  - uniform names must be active uniforms of the program (the compiler removes unused ones);
  - each uniform's type must match its declaration (`uniformTypeMismatch`).
- Passes built from identical sources share one cached program, so create one pass per source and release it once.
- **Test**: an additive pass of two inputs matches a CPU result on a 4×4 grid; `inputIsOutput` is thrown when
  `pair.read` is passed as the output; `unknownUniform`; `stale` after a context recreation.
