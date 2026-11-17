// AssemblyTests — feature 159 (A22-P01) T-A22-107 (FR-A22-104; SC-A22-102; clarification Q1). The assembly's three
// texts are exact, the person's source is kept byte for byte, the entry includes the prelude and then the source, and
// the expansion of the entry with the `vc/` includes maps each of the person's lines back to `ss/shader.frag` and its
// authored line. `DiagnosticMapper` keeps the person's lines, keeps other files with their lines (outside the
// source), and gives `unknown`, `<generated>` and line 0 no line.
import ShaderStudioCore
import Testing
import VisualCoreRendering
import VisualCoreShaderSource

@Suite struct AssemblyTests {
    static let prelude = "precision highp float;\nin vec2 v_uv;\nuniform float u_time;\nuniform vec2 u_resolution;\n"
        + "out vec4 fragColor;\n#include \"vc/noise.glsl\"\n#include \"vc/color.glsl\"\n"
    static let entry = "#include \"ss/prelude.glsl\"\n#include \"ss/shader.frag\"\n"

    @Test func fileNamesAndTextsAreExact() {
        #expect(ShaderAssembly.preludeFile == "ss/prelude.glsl")
        #expect(ShaderAssembly.personFile == "ss/shader.frag")
        #expect(ShaderAssembly.entryFile == "ss/main.frag")
        #expect(ShaderAssembly.preludeText == Self.prelude)
        #expect(ShaderAssembly.entryFileText == Self.entry)

        let source = "void main() {\r\n    fragColor = vec4(v_uv, 0.0, 1.0);\r\n}"
        let assembly = ShaderAssembly(source: source)
        #expect(Set(assembly.files.keys) == ["ss/prelude.glsl", "ss/shader.frag", "ss/main.frag"])
        #expect(assembly.files["ss/prelude.glsl"] == Self.prelude)
        #expect(assembly.files["ss/shader.frag"] == source, "the source is kept byte for byte")
        #expect(assembly.files["ss/main.frag"] == Self.entry)
        #expect(assembly.entryText == Self.entry)
        #expect(assembly.personSource == source)
    }

    @Test func entryIncludesThePreludeThenTheSource() {
        let lines = ShaderAssembly(source: "").entryText.split(separator: "\n").map(String.init)
        #expect(lines == ["#include \"ss/prelude.glsl\"", "#include \"ss/shader.frag\""])
        #expect(!ShaderAssembly.preludeText.contains("#version"), "the library inserts the version line")
        #expect(!ShaderAssembly.entryText(of: "").contains("#version"))
    }

    @Test func projectAssemblyEqualsSourceAssembly() throws {
        let template = try #require(ShaderTemplates.all.first)
        #expect(ShaderAssembly(project: template.project) == ShaderAssembly(source: template.project.source))
        #expect(ShaderAssembly(source: "a") != ShaderAssembly(source: "b"))
    }

    @Test func expansionMapsThePersonsLinesBack() throws {
        #expect(!ShaderBundle.visualCoreLibrary.isEmpty, "the vc/ includes are bundled")
        let source = "// line 1\nvoid main() {\n    fragColor = vec4(v_uv, 0.0, 1.0);\n}\n"
        let assembly = ShaderAssembly(source: source)
        var library = ShaderLibrary()
        for (name, text) in ShaderBundle.visualCoreLibrary { library.add(name, text) }
        for (name, text) in assembly.files { library.add(name, text) }
        let expanded = try library.expand(ShaderAssembly.entryFile)
        let lines = expanded.text.components(separatedBy: "\n")
        #expect(lines.first == ShaderLibrary.versionLine)
        #expect(expanded.origins.first == SourceOrigin.generated)
        #expect(expanded.origins.contains(SourceOrigin(file: "vc/noise.glsl", line: 1)))
        #expect(expanded.origins.contains(SourceOrigin(file: "vc/color.glsl", line: 1)))
        let personLines = expanded.origins.enumerated().filter { $0.element.file == ShaderAssembly.personFile }
        #expect(personLines.map(\.element.line) == [1, 2, 3, 4])
        for (index, origin) in personLines {
            #expect(lines[index] == source.components(separatedBy: "\n")[origin.line - 1])
        }
        let preludeLines = expanded.origins.filter { $0.file == ShaderAssembly.preludeFile }.map(\.line)
        #expect(preludeLines == [1, 2, 3, 4, 5], "the include lines are replaced by the included text")
        let firstPerson = try #require(personLines.first?.offset)
        let lastPrelude = try #require(expanded.origins.lastIndex(where: { $0.file == ShaderAssembly.preludeFile }))
        #expect(lastPrelude < firstPerson, "the prelude comes before the person's source")
    }

    @Test func mapperKeepsThePersonsLinesAndSendsTheRestOutside() {
        let input = [
            ShaderDiagnostic(file: "ss/shader.frag", line: 7, stage: .fragment, severity: .error, message: "a"),
            ShaderDiagnostic(file: "ss/prelude.glsl", line: 3, stage: .fragment, severity: .warning, message: "b"),
            ShaderDiagnostic(file: "vc/noise.glsl", line: 12, stage: .fragment, severity: .error, message: "c"),
            ShaderDiagnostic(file: "unknown", line: 4, stage: .fragment, severity: .error, message: "d"),
            ShaderDiagnostic(file: "<generated>", line: 0, stage: .fragment, severity: .error, message: "e"),
            ShaderDiagnostic(file: "ss/shader.frag", line: 0, stage: .link, severity: .error, message: "f"),
        ]
        let mapped = DiagnosticMapper.map(input)
        #expect(mapped == [
            MappedDiagnostic(file: "ss/shader.frag", line: 7, severity: .error, stage: .fragment, message: "a"),
            MappedDiagnostic(file: "ss/prelude.glsl", line: 3, severity: .warning, stage: .fragment, message: "b"),
            MappedDiagnostic(file: "vc/noise.glsl", line: 12, severity: .error, stage: .fragment, message: "c"),
            MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .fragment, message: "d"),
            MappedDiagnostic(file: "<generated>", line: nil, severity: .error, stage: .fragment, message: "e"),
            MappedDiagnostic(file: "ss/shader.frag", line: nil, severity: .error, stage: .link, message: "f"),
        ])
        #expect(mapped.map(DiagnosticMapper.isInPersonSource) == [true, false, false, false, false, false])
        #expect(DiagnosticMapper.map([]).isEmpty)
    }
}

private extension ShaderAssembly {
    static func entryText(of source: String) -> String { ShaderAssembly(source: source).entryText }
}
