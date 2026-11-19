# Contract: VisualCoreRendering byte upload (A25-P04, U-RGBAUPLOAD)

- `RenderTarget.upload(rgba pixels: [UInt8]) -> Bool` (discardable): rows bottom-up; `.rgba8` stores the bytes as given;
  `.rgba16f` stores n/255; refuses `.r8`, a count other than width × height × 4, and a stale or released target.
- Documented with `///`; listed in `visualcore-public-api.txt`; described in both package READMEs.
