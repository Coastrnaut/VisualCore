// EditorDocument — feature 159 (A22-P01) T-A22-108 (FR-A22-105; clarification Q4; User Story 4). The editor's model
// of the person's source: numbered lines (from 1, over `\n`, `\r\n` and `\r`, by the line rule of `GLSLTokenizer`),
// each with its syntax tokens and the diagnostics that name it. A diagnostic of `ss/shader.frag` with a line inside
// the source attaches to that line; every other one (another file such as the prelude or a `vc/` include, no line, or
// a line past the end) is "outside the source", listed above it by the view. Input order is kept in both places.
// Pure Swift; no UI framework, GL call, clock or network.

/// One numbered line of the editor: its text, tokens and the diagnostics reported on it.
public struct EditorLine: Sendable, Equatable {
    /// The 1-based line number, as the compiler counts lines of `ss/shader.frag`.
    public let number: Int
    /// The line's text without its terminator.
    public let text: String
    /// The line's tokens; their texts concatenated equal `text`.
    public let tokens: [Token]
    /// The diagnostics on this line, in the order they were given.
    public let diagnostics: [MappedDiagnostic]

    /// Creates a line.
    public init(number: Int, text: String, tokens: [Token], diagnostics: [MappedDiagnostic]) {
        self.number = number
        self.text = text
        self.tokens = tokens
        self.diagnostics = diagnostics
    }
}

/// The editor model of a source: its lines with tokens and attached diagnostics, and the diagnostics outside it.
public struct EditorDocument: Sendable, Equatable {
    /// The file name under which the person's source is compiled; only its diagnostics attach to lines.
    public static let personFile = "ss/shader.frag"

    /// The source's lines, numbered 1…`lines.count` (always at least one line; the empty source is one empty line).
    public let lines: [EditorLine]
    /// Diagnostics not on a line of the source (another file, no line, or a line out of range), in input order.
    public let outside: [MappedDiagnostic]

    /// Builds the model: splits and tokenizes `source`, then attaches each diagnostic of `personFile` whose line is
    /// in 1…`lines.count` to that line and lists the rest in `outside`, keeping the given order in both.
    public init(source: String, diagnostics: [MappedDiagnostic] = []) {
        let split = GLSLTokenizer.split(source)
        var perLine = [[MappedDiagnostic]](repeating: [], count: split.count)
        var outside: [MappedDiagnostic] = []
        for diagnostic in diagnostics {
            if diagnostic.file == Self.personFile, let line = diagnostic.line, (1...split.count).contains(line) {
                perLine[line - 1].append(diagnostic)
            } else {
                outside.append(diagnostic)
            }
        }
        lines = split.indices.map { index in
            EditorLine(number: index + 1, text: split[index].text, tokens: split[index].tokens,
                       diagnostics: perLine[index])
        }
        self.outside = outside
    }

    /// The lines that carry at least one diagnostic (the view's error markers), in line order.
    public var markedLines: [Int] { lines.filter { !$0.diagnostics.isEmpty }.map(\.number) }
}
