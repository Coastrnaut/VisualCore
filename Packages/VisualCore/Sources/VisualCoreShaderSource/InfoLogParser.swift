// InfoLogParser.swift — turns GL compile/link info logs into diagnostics mapped to the original
// file and line (feature 004 T-F307; FR-F304). ANGLE's translator writes
// `ERROR: <string>:<line>: <message>` / `WARNING: ...`; anything else is kept as a raw message.
import Foundation

/// Pipeline step that produced an info log: vertex compile, fragment compile or program link.
public enum ShaderStage: String, Sendable, Codable { case vertex, fragment, link }

/// One compiler or linker message mapped back to its original source file and line.
public struct ShaderDiagnostic: Sendable, Equatable, Codable, CustomStringConvertible {
    /// Whether the message is an `ERROR:` or a `WARNING:`.
    public enum Severity: String, Sendable, Codable { case error, warning }
    /// Original source name, `<generated>` for synthesized lines, or `unknown` when unmapped.
    public let file: String
    /// 1-based line in `file`; 0 when unknown.
    public let line: Int
    /// Stage whose info log produced the message.
    public let stage: ShaderStage
    /// Error or warning; unstructured log lines are reported as errors.
    public let severity: Severity
    /// Message text without the severity and location prefix.
    public let message: String

    /// Creates a diagnostic from its parts.
    public init(file: String, line: Int, stage: ShaderStage, severity: Severity, message: String) {
        self.file = file; self.line = line; self.stage = stage; self.severity = severity; self.message = message
    }

    /// `file:line: severity [stage]: message`.
    public var description: String { "\(file):\(line): \(severity.rawValue) [\(stage.rawValue)]: \(message)" }
}

/// Parses GL/ANGLE compile and link info logs into `ShaderDiagnostic`s.
public enum InfoLogParser {
    /// Splits `log` into diagnostics, mapping `ERROR:`/`WARNING: <string>:<line>:` lines through `map` (file `unknown` and the expanded line when nil); skips translator summary lines and reports other lines as `unknown:0` errors.
    public static func parse(_ log: String, stage: ShaderStage, map: ExpandedShader?) -> [ShaderDiagnostic] {
        var out: [ShaderDiagnostic] = []
        for raw in log.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let d = structured(line, stage: stage, map: map) {
                out.append(d)
            } else if isSummary(line) {
                continue
            } else {
                out.append(ShaderDiagnostic(file: "unknown", line: 0, stage: stage, severity: .error, message: line))
            }
        }
        return out
    }

    /// `ERROR: 0:12: message` → diagnostic; returns nil when the line has another shape.
    private static func structured(_ line: String, stage: ShaderStage, map: ExpandedShader?) -> ShaderDiagnostic? {
        let severity: ShaderDiagnostic.Severity
        let rest: Substring
        if line.hasPrefix("ERROR: ") { severity = .error; rest = line.dropFirst(7) }
        else if line.hasPrefix("WARNING: ") { severity = .warning; rest = line.dropFirst(9) }
        else { return nil }
        let parts = rest.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, Int(parts[0].trimmingCharacters(in: .whitespaces)) != nil,
              let expandedLine = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        let message = parts[2].trimmingCharacters(in: .whitespaces)
        if let map {
            let origin = map.origin(ofExpandedLine: expandedLine)
            return ShaderDiagnostic(file: origin.file, line: origin.line, stage: stage, severity: severity, message: message)
        }
        return ShaderDiagnostic(file: "unknown", line: expandedLine, stage: stage, severity: severity, message: message)
    }

    /// Translator summary lines such as "ERROR: 1 compilation errors.  No code generated."
    private static func isSummary(_ line: String) -> Bool {
        line.contains("compilation errors") || line.contains("No code generated")
    }
}
