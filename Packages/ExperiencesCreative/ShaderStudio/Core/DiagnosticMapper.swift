// DiagnosticMapper — feature 159 (A22-P01) T-A22-106 (FR-A22-104; clarifications Q1, Q4; contracts/core.md). Turns
// the compiler's diagnostics (already mapped to file and line by `InfoLogParser` through the `ShaderLibrary`
// expansion of a ``ShaderAssembly``) into ``MappedDiagnostic``s for the editor:
//
//   - a diagnostic of `ss/shader.frag` with a line above 0 keeps that line, the line the person wrote;
//   - a diagnostic of any other named file (the prelude, the entry, a `vc/` include) keeps its file and line, and is
//     "outside the source" for the editor, which decides by file;
//   - a diagnostic of `unknown` or `<generated>`, or with line 0, has no line.
//
// The order of the diagnostics is kept. Pure: no GL call.
import Foundation
import VisualCoreShaderSource

/// One compile diagnostic as the editor shows it: on a line of the person's source when ``file`` is
/// ``ShaderAssembly/personFile`` and ``line`` is set, otherwise outside the source.
public struct MappedDiagnostic: Sendable, Equatable {
    /// The file the diagnostic names (`ss/shader.frag`, `ss/prelude.glsl`, a `vc/` include, or `unknown`).
    public let file: String
    /// The 1-based line within ``file``; nil when the compiler gave no usable line.
    public let line: Int?
    /// Error or warning.
    public let severity: ShaderDiagnostic.Severity
    /// The stage that reported it.
    public let stage: ShaderStage
    /// The compiler's message, unchanged.
    public let message: String

    /// A diagnostic with the values as given.
    public init(file: String, line: Int?, severity: ShaderDiagnostic.Severity, stage: ShaderStage, message: String) {
        self.file = file
        self.line = line
        self.severity = severity
        self.stage = stage
        self.message = message
    }
}

/// Maps compile diagnostics of an assembled shader to editor diagnostics (feature 159, clarification Q1).
public enum DiagnosticMapper {
    /// File names that carry no source line (`InfoLogParser`'s raw messages and generated lines).
    public static let unnamedFiles: Set<String> = ["unknown", SourceOrigin.generated.file]

    /// Each diagnostic in order: a named file keeps its line when it is above 0; `unknown` and `<generated>` have
    /// no line.
    public static func map(_ diagnostics: [ShaderDiagnostic]) -> [MappedDiagnostic] {
        diagnostics.map { d in
            let line: Int? = unnamedFiles.contains(d.file) || d.line <= 0 ? nil : d.line
            return MappedDiagnostic(file: d.file, line: line, severity: d.severity, stage: d.stage, message: d.message)
        }
    }

    /// Whether `diagnostic` lies on a line of the person's source (``ShaderAssembly/personFile`` with a line).
    public static func isInPersonSource(_ diagnostic: MappedDiagnostic) -> Bool {
        diagnostic.file == ShaderAssembly.personFile && diagnostic.line != nil
    }
}
