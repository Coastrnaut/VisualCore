// ShaderValidator — feature 159 (A22-P01) T-A22-104 (FR-A22-103; clarification Q2; data-model.md "ValidationIssue").
// The checks made before a project is compiled: the size, line, uniform and texture-input limits; a `void main`;
// no `#version` line (the library inserts it); no reserved name (`u_time`, `u_resolution`, declared by the prelude);
// no duplicate name; every declared uniform present in the source as `uniform float <name>;` and every texture input
// as `uniform sampler2D <name>;`; and every such source declaration declared by the project.
// Choices recorded here: comments (`//` to the end of the line and `/* … */`, an unclosed one to the end) are blanked
// before matching, so a commented-out declaration, `void main` or `#version` does not count. Lines are split on `\n`,
// `\r\n` and `\r` and numbered from 1; a final line break does not start a new line, and an empty source has 0 lines.
// `void main` may span lines. A declaration may carry a precision qualifier (`lowp`, `mediump`, `highp`) and any whitespace. Issues come in this
// order: the four limits, then the project's names in declaration order (uniforms, then texture inputs), then the
// source in line order (a `#version` line, a reserved or undeclared source declaration), then a missing `void main`,
// then the project's names missing from the source. A source declaration of a reserved name is reported as
// `reserved-name`, not `undeclared-in-project`. Pure Foundation; no UI, GPU or clock.
import Foundation

/// One reason a project may not compile. The code is the kebab-case case name.
public enum ValidationIssue: Equatable, Sendable {
    /// The source is larger than ``ShaderLimits/maxSourceBytes``; the value is its UTF-8 size in bytes.
    case sourceTooLarge(Int)
    /// The source has more than ``ShaderLimits/maxLines`` lines; the value is its line count.
    case tooManyLines(Int)
    /// The project declares more than ``ShaderLimits/maxUniforms`` uniforms; the value is the count.
    case tooManyUniforms(Int)
    /// The project declares more than ``ShaderLimits/maxTextureInputs`` texture inputs; the value is the count.
    case tooManyTextureInputs(Int)
    /// The source has no `void main`.
    case noMain
    /// The source has a `#version` line; the value is its 1-based line number.
    case versionLine(Int)
    /// A name is reserved by the prelude (``ShaderValidator/reservedNames``); the value is the name.
    case reservedName(String)
    /// A name is declared twice by the project; the value is the name.
    case duplicateName(String)
    /// A project uniform or texture input has no matching declaration in the source; the value is the name.
    case undeclaredInSource(String)
    /// A source `uniform float` or `uniform sampler2D` is not declared by the project; the value is the name.
    case undeclaredInProject(String)

    /// The stable code: `source-too-large`, `too-many-lines`, `too-many-uniforms`, `too-many-texture-inputs`,
    /// `no-main`, `version-line`, `reserved-name`, `duplicate-name`, `undeclared-in-source` or
    /// `undeclared-in-project`.
    public var code: String {
        switch self {
        case .sourceTooLarge: return "source-too-large"
        case .tooManyLines: return "too-many-lines"
        case .tooManyUniforms: return "too-many-uniforms"
        case .tooManyTextureInputs: return "too-many-texture-inputs"
        case .noMain: return "no-main"
        case .versionLine: return "version-line"
        case .reservedName: return "reserved-name"
        case .duplicateName: return "duplicate-name"
        case .undeclaredInSource: return "undeclared-in-source"
        case .undeclaredInProject: return "undeclared-in-project"
        }
    }
}

/// The checks made on a ``ShaderProject`` before it is compiled.
public enum ShaderValidator {
    /// The names declared by the prelude (`ss/prelude.glsl`), which a project may not use.
    public static let reservedNames: Set<String> = ["u_time", "u_resolution"]

    /// The kind of a source uniform declaration.
    private enum DeclarationKind { case float, sampler }

    private static let declarationPattern = try! NSRegularExpression(
        pattern: #"\buniform\s+(?:(?:lowp|mediump|highp)\s+)?(float|sampler2D)\s+([A-Za-z_][A-Za-z0-9_]*)\s*;"#)
    private static let mainPattern = try! NSRegularExpression(pattern: #"\bvoid\s+main\s*\("#)
    private static let versionPattern = try! NSRegularExpression(pattern: #"^\s*#\s*version\b"#)

    /// Every issue of `project`, in the order described above; an empty list means the project may compile.
    public static func validate(_ project: ShaderProject) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let limits = project.limits
        let source = project.source
        let bytes = source.utf8.count
        if bytes > limits.maxSourceBytes { issues.append(.sourceTooLarge(bytes)) }
        let blanked = blankingComments(in: source)
        let lines = Self.lines(of: blanked)
        if lines.count > limits.maxLines { issues.append(.tooManyLines(lines.count)) }
        if project.uniforms.count > limits.maxUniforms { issues.append(.tooManyUniforms(project.uniforms.count)) }
        if project.textureInputs.count > limits.maxTextureInputs {
            issues.append(.tooManyTextureInputs(project.textureInputs.count))
        }

        let declared: [(String, DeclarationKind)] = project.uniforms.map { ($0.name, .float) }
            + project.textureInputs.map { ($0, .sampler) }
        var seen = Set<String>()
        for (name, _) in declared {
            if reservedNames.contains(name) { issues.append(.reservedName(name)) }
            if !seen.insert(name).inserted { issues.append(.duplicateName(name)) }
        }

        let floats = Set(project.uniforms.map(\.name))
        let samplers = Set(project.textureInputs)
        var foundFloats = Set<String>()
        var foundSamplers = Set<String>()
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if versionPattern.firstMatch(in: line, range: range) != nil { issues.append(.versionLine(index + 1)) }
            for match in declarationPattern.matches(in: line, range: range) {
                guard let typeRange = Range(match.range(at: 1), in: line),
                      let nameRange = Range(match.range(at: 2), in: line) else { continue }
                let name = String(line[nameRange])
                let kind: DeclarationKind = line[typeRange] == "float" ? .float : .sampler
                if reservedNames.contains(name) {
                    issues.append(.reservedName(name))
                } else if kind == .float, floats.contains(name) {
                    foundFloats.insert(name)
                } else if kind == .sampler, samplers.contains(name) {
                    foundSamplers.insert(name)
                } else {
                    issues.append(.undeclaredInProject(name))
                }
            }
        }
        if mainPattern.firstMatch(in: blanked, range: NSRange(blanked.startIndex..., in: blanked)) == nil {
            issues.append(.noMain)
        }

        var reported = Set<String>()
        for (name, kind) in declared where !reservedNames.contains(name) {
            let found = kind == .float ? foundFloats.contains(name) : foundSamplers.contains(name)
            if !found, reported.insert(name).inserted { issues.append(.undeclaredInSource(name)) }
        }
        return issues
    }

    /// The lines of `text`, split on `\n`, `\r\n` and `\r`; a final line break does not start a new line, and an
    /// empty text has no lines.
    static func lines(of text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var parts = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if parts.last == "" { parts.removeLast() }
        return parts
    }

    /// `text` with every comment character replaced by a space, line breaks kept, so that line numbers hold.
    static func blankingComments(in text: String) -> String {
        enum State { case code, line, block }
        var state = State.code
        var output = ""
        output.reserveCapacity(text.utf8.count)
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            let next: Unicode.Scalar? = index + 1 < scalars.count ? scalars[index + 1] : nil
            let isBreak = scalar == "\n" || scalar == "\r"
            switch state {
            case .code:
                if scalar == "/", next == "/" {
                    state = .line
                    output.append("  ")
                    index += 2
                    continue
                }
                if scalar == "/", next == "*" {
                    state = .block
                    output.append("  ")
                    index += 2
                    continue
                }
                output.unicodeScalars.append(scalar)
            case .line:
                if isBreak {
                    state = .code
                    output.unicodeScalars.append(scalar)
                } else {
                    output.append(" ")
                }
            case .block:
                if scalar == "*", next == "/" {
                    state = .code
                    output.append("  ")
                    index += 2
                    continue
                }
                if isBreak { output.unicodeScalars.append(scalar) } else { output.append(" ") }
            }
            index += 1
        }
        return output
    }
}
