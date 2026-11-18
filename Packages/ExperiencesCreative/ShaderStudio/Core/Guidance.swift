// Guidance — feature 162 (A22-P04) T-A22-402 (FR-A22-401, FR-A22-402; clarification Q1; data-model.md "Guidance").
// One plain sentence that says what to change, for each refusal of ``ShaderValidator`` and for a compiler diagnostic:
//
//   - a refusal gets one distinct sentence per code, naming the limit or the name, and the line where the issue
//     carries one (only `version-line` does);
//   - a compiler message is matched case-insensitively on the compiler's own words: "undeclared identifier" (the name
//     is the first quoted word, as ANGLE writes 'name'), "syntax error", and "cannot convert" / "wrong operand types" /
//     "no matching overloaded function" (and ANGLE's "dimension mismatch", which it reports before "cannot convert"
//     for a vector assigned to a float); anything else gets the general sentence, and the caller keeps the raw
//     message beside it.
//
// Pure Foundation; no UI, GPU or clock.
import Foundation

/// The sentence shown under the status and with each diagnostic: what the person should change.
public enum Guidance {
    /// The sentence for a compiler message that matches none of the known patterns.
    public static let general = "Check this line for a typing mistake."
    /// The sentence for a compiler syntax error.
    public static let syntax = "A semicolon or bracket is missing on or just before this line."
    /// The sentence for a compiler type mismatch.
    public static let typeMismatch = "The types do not match: write 1.0 for a float, and match vec sizes."

    /// The words of a compiler message that mean a type mismatch, lowercased. "dimension mismatch" is the first
    /// message ANGLE gives for a vector assigned to a float (observed on the simulator, research R1).
    static let typeMismatchWords = [
        "cannot convert", "wrong operand types", "no matching overloaded function", "dimension mismatch",
    ]

    /// The sentence for `issue`, naming the limit of `limits` or the name, and the line where the issue has one.
    public static func forIssue(_ issue: ValidationIssue, limits: ShaderLimits = .standard) -> String {
        switch issue {
        case .sourceTooLarge(let bytes):
            return "Shorten the source: it is \(bytes) bytes and the limit is \(limits.maxSourceBytes) bytes."
        case .tooManyLines(let count):
            return "Remove some lines: the source has \(count) lines and the limit is \(limits.maxLines)."
        case .tooManyUniforms(let count):
            return "Remove some uniforms from the inspector: there are \(count) and the limit is "
                + "\(limits.maxUniforms)."
        case .tooManyTextureInputs(let count):
            return "Remove some texture inputs: there are \(count) and the limit is \(limits.maxTextureInputs)."
        case .noMain:
            return "Add a `void main() { … }` function that sets fragColor."
        case .versionLine(let line):
            return "Remove the #version line on line \(line): Shader Studio supplies GLSL ES 3.00 itself."
        case .reservedName(let name):
            return "Rename \(name): Shader Studio declares it already, so use it without declaring it."
        case .duplicateName(let name):
            return "Rename one of the two uniforms called \(name) in the inspector: each name must be different."
        case .undeclaredInSource(let name):
            return "Declare \(name) as `uniform float \(name);` above main."
        case .undeclaredInProject(let name):
            return "Add \(name) in the inspector, or remove `uniform … \(name);` from the source."
        }
    }

    /// The sentence for the compiler's `message`, matched case-insensitively; the general sentence when no pattern
    /// matches.
    public static func forDiagnostic(message: String) -> String {
        let lowered = message.lowercased()
        if lowered.contains("undeclared identifier") {
            let name = quotedName(in: message) ?? "it"
            return "Declare \(name) before it is used, for example `uniform float \(name);`."
        }
        if lowered.contains("syntax error") { return syntax }
        if typeMismatchWords.contains(where: lowered.contains) { return typeMismatch }
        return general
    }

    /// The first word of `message` between single (or double) quotes that is a GLSL identifier, if any.
    static func quotedName(in message: String) -> String? {
        for quote in ["'", "\""] {
            let parts = message.components(separatedBy: quote)
            var index = 1
            while index < parts.count - 1 {
                let candidate = parts[index]
                if candidate.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil {
                    return candidate
                }
                index += 2
            }
        }
        return nil
    }
}
