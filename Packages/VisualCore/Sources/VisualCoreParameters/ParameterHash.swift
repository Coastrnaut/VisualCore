// ParameterHash.swift — a stable, process-independent cache key for a parameterized visual (feature 012 T-A01-102;
// research R1: FNV-1a 64 over a canonical string; Swift's Hasher is seeded per process and unsuitable).
import Foundation

/// Stable 64-bit FNV-1a hash of a scope (for example a scene id), seed, palette and parameter values.
public enum ParameterHash {
    /// The canonical string hashed: `scope|seed|palette|name=value;…` with names sorted and values in `%.9g`.
    public static func canonical(scope: String, seed: UInt64, paletteID: String, values: [String: Double]) -> String {
        let body = values.keys.sorted().map { "\($0)=\(String(format: "%.9g", values[$0]!))" }.joined(separator: ";")
        return "\(scope)|\(seed)|\(paletteID)|\(body)"
    }

    /// 16 lowercase hex digits; equal inputs give equal hashes on every run and platform.
    public static func of(scope: String, seed: UInt64, paletteID: String, values: [String: Double]) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in canonical(scope: scope, seed: seed, paletteID: paletteID, values: values).utf8 {
            h ^= UInt64(byte)
            h &*= 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", h)
    }
}
