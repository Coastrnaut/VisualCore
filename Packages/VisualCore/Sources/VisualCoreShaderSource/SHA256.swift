// SHA256.swift — SHA-256 for program cache keys (feature 004 T-F303; FR-F306). Since feature 188 (T-U02-003) the
// implementation lives in VisualCoreMath as `StableHash`; this file keeps the module's own names.
import VisualCoreMath

enum SHA256 {
    static func digest(_ message: [UInt8]) -> [UInt8] { StableHash.sha256(message) }
    static func hex(of message: [UInt8]) -> String { StableHash.sha256Hex(message) }
}

/// Program cache keys (FR-F306): SHA-256 over both expanded stages, whose text already contains the
/// sorted `#define` lines, so variants with different defines get different keys.
public enum ShaderCacheKey {
    /// Lowercase SHA-256 hex over the vertex text, a NUL separator and the fragment text.
    public static func make(vertex: ExpandedShader, fragment: ExpandedShader) -> String {
        SHA256.hex(of: Array(vertex.text.utf8) + [0] + Array(fragment.text.utf8))
    }

    /// SHA-256 hex of arbitrary text (fixtures, reports).
    public static func sha256Hex(_ text: String) -> String { SHA256.hex(of: Array(text.utf8)) }
}
