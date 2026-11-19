// PrecisionPolicy.swift — default fragment float precision and highp findings (feature 206 T-R02F06-003;
// FR-R02F06-004, research R5). Contract:
// specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// GLSL ES fragment shaders have no default float precision. When a fragment shader has no
// `precision (highp|mediump|lowp) float;` statement the expander inserts one as a generated line after the defines;
// when the device lacks fragment highp (policy `.medium`) every `highp` the fragment source requests is a finding.
//
import Foundation

/// The default float precision of a fragment shader, chosen from the device report.
public enum PrecisionPolicy: String, Sendable, CaseIterable {
    /// `precision highp float;` (the device supports fragment highp).
    case high
    /// `precision mediump float;` (the device lacks fragment highp).
    case medium

    /// `.high` when the device reports fragment highp support, otherwise `.medium`.
    public init(fragmentHighpSupported: Bool) { self = fragmentHighpSupported ? .high : .medium }

    /// The precision statement the expander inserts.
    public var statement: String {
        switch self {
        case .high: "precision highp float;"
        case .medium: "precision mediump float;"
        }
    }
}

/// A `highp` request in a fragment source that the device cannot honour (a warning, not a refusal).
public struct PrecisionFinding: Equatable, Hashable, Sendable {
    /// The original source file.
    public let file: String
    /// The 1-based line in `file`.
    public let line: Int
    /// What was found.
    public let message: String
    /// Creates a finding.
    public init(file: String, line: Int, message: String) { self.file = file; self.line = line; self.message = message }
}

enum PrecisionScan {
    /// Identifier tokens of `line` with any `//` comment removed.
    static func tokens(_ line: String) -> [Substring] {
        let code = line.range(of: "//").map { line[..<$0.lowerBound] } ?? Substring(line)
        return code.split { !($0.isLetter || $0.isNumber || $0 == "_") }
    }

    /// Whether `line` is a `precision (highp|mediump|lowp) float;` statement.
    static func isFloatPrecisionStatement(_ line: String) -> Bool {
        let code = line.range(of: "//").map { line[..<$0.lowerBound] } ?? Substring(line)
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(";") else { return false }
        let parts = trimmed.dropLast().split { $0 == " " || $0 == "\t" }
        return parts.count == 3 && parts[0] == "precision" && ["highp", "mediump", "lowp"].contains(parts[1])
            && parts[2] == "float"
    }

    /// The finding for `line` when it requests `highp`, or nil.
    static func finding(_ line: String, origin: SourceOrigin) -> PrecisionFinding? {
        let words = tokens(line)
        guard words.contains("highp") else { return nil }
        let message = words.first == "precision"
            ? "highp precision statement, but the device lacks fragment highp"
            : "highp qualifier, but the device lacks fragment highp"
        return PrecisionFinding(file: origin.file, line: origin.line, message: message)
    }
}
