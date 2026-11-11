// ShaderLibraryTests — feature 004 T-F304 (FR-F301–FR-F303, FR-F317, SC-F302).
import Testing
@testable import VisualCoreShaderSource

private func lib(_ pairs: [(String, String)]) -> ShaderLibrary {
    var l = ShaderLibrary()
    for (n, t) in pairs { l.add(n, t) }
    return l
}

@Test func addsVersionWhenMissingAndMapsLines() throws {
    let e = try lib([("main.frag", "void main() {}\n")]).expand("main.frag")
    #expect(e.text.hasPrefix("#version 300 es\n"))
    #expect(e.origin(ofExpandedLine: 1) == SourceOrigin(file: "<generated>", line: 0))
    #expect(e.origin(ofExpandedLine: 2) == SourceOrigin(file: "main.frag", line: 1))
}

@Test func keepsAnExistingVersionLine() throws {
    let e = try lib([("a.vert", "#version 300 es\nvoid main() {}")]).expand("a.vert")
    #expect(e.text.components(separatedBy: "\n").filter { $0.hasPrefix("#version") }.count == 1)
    #expect(e.origin(ofExpandedLine: 1) == SourceOrigin(file: "a.vert", line: 1))
    #expect(e.origin(ofExpandedLine: 2) == SourceOrigin(file: "a.vert", line: 2))
}

@Test func definesFollowTheVersionSortedAndAreGenerated() throws {
    let e = try lib([("m.frag", "void main() {}")]).expand("m.frag", defines: ["QUALITY": "2", "BLOOM": "1"])
    let lines = e.text.components(separatedBy: "\n")
    #expect(lines[1] == "#define BLOOM 1")
    #expect(lines[2] == "#define QUALITY 2")
    #expect(e.origin(ofExpandedLine: 2).file == "<generated>")
    #expect(e.origin(ofExpandedLine: 4) == SourceOrigin(file: "m.frag", line: 1))
}

@Test func nestedIncludesMapEveryLineToItsFile() throws {
    let l = lib([
        ("main.frag", "precision mediump float;\n#include \"noise.glsl\"\nvoid main() {}"),
        ("noise.glsl", "#include \"hash.glsl\"\nfloat noise(vec2 p) { return hash(p); }"),
        ("hash.glsl", "float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9, 78.2))) * 43758.5); }"),
    ])
    let e = try l.expand("main.frag")
    let lines = e.text.components(separatedBy: "\n")
    let hashLine = try #require(lines.firstIndex { $0.hasPrefix("float hash") }) + 1
    let noiseLine = try #require(lines.firstIndex { $0.hasPrefix("float noise") }) + 1
    let mainLine = try #require(lines.firstIndex { $0.hasPrefix("void main") }) + 1
    #expect(e.origin(ofExpandedLine: hashLine) == SourceOrigin(file: "hash.glsl", line: 1))
    #expect(e.origin(ofExpandedLine: noiseLine) == SourceOrigin(file: "noise.glsl", line: 2))
    #expect(e.origin(ofExpandedLine: mainLine) == SourceOrigin(file: "main.frag", line: 3))
    #expect(!e.text.contains("#include"))
}

@Test func rejectsMoreThan64KiBAfterExpansion() {
    let big = String(repeating: "// padding padding padding padding padding padding padding\n", count: 1200)
    #expect(throws: ShaderSourceError.self) { try lib([("big.frag", big)]).expand("big.frag") }
    do { _ = try lib([("big.frag", big)]).expand("big.frag") } catch {
        guard case .tooLarge(let n) = error as? ShaderSourceError else { Issue.record("wrong error \(error)"); return }
        #expect(n > ShaderLibrary.maxExpandedBytes)
    }
}

@Test func rejectsIncludesDeeperThanEight() {
    var pairs: [(String, String)] = [("main.frag", "#include \"l1.glsl\"\nvoid main() {}")]
    for i in 1...9 { pairs.append(("l\(i).glsl", i < 9 ? "#include \"l\(i + 1).glsl\"" : "float x;")) }
    #expect(throws: ShaderSourceError.tooDeep(9)) { try lib(pairs).expand("main.frag") }
    var ok: [(String, String)] = [("main.frag", "#include \"l1.glsl\"\nvoid main() {}")]
    for i in 1...8 { ok.append(("l\(i).glsl", i < 8 ? "#include \"l\(i + 1).glsl\"" : "float x;")) }
    #expect((try? lib(ok).expand("main.frag")) != nil)
}

@Test func rejectsCycles() {
    let l = lib([("main.frag", "#include \"a.glsl\""), ("a.glsl", "#include \"b.glsl\""), ("b.glsl", "#include \"a.glsl\"")])
    #expect(throws: ShaderSourceError.cycle(["main.frag", "a.glsl", "b.glsl", "a.glsl"])) { try l.expand("main.frag") }
}

@Test func unknownIncludeNamesTheIncludingFileAndLine() {
    let l = lib([("main.frag", "float a;\n#include \"missing.glsl\"")])
    #expect(throws: ShaderSourceError.unknownInclude("missing.glsl", file: "main.frag", line: 2)) { try l.expand("main.frag") }
    #expect(throws: ShaderSourceError.unknownSource("nope.frag")) { try l.expand("nope.frag") }
}

@Test func onlyGLSLES300IsAccepted() {
    #expect(throws: ShaderSourceError.unsupportedVersion(file: "old.frag", line: 1)) {
        try lib([("old.frag", "#version 100\nvoid main() {}")]).expand("old.frag")
    }
    #expect(throws: ShaderSourceError.unsupportedVersion(file: "inc.glsl", line: 1)) {
        try lib([("m.frag", "#include \"inc.glsl\""), ("inc.glsl", "#version 300 es")]).expand("m.frag")
    }
}

@Test func variantsDifferOnlyByDefines() throws {
    let l = lib([("m.frag", "void main() {}")])
    let a = try l.expand("m.frag", defines: ["HQ": "1"])
    let b = try l.expand("m.frag", defines: ["HQ": "0"])
    let c = try l.expand("m.frag", defines: ["HQ": "1"])
    #expect(a.text != b.text)
    #expect(a == c)
}

@Test func inlineSourcesExpandWithTheLibrary() throws {
    let l = lib([("common.glsl", "float k;")])
    let e = try l.expand(source: "#include \"common.glsl\"\nvoid main() {}", named: "inline.frag")
    #expect(e.origin(ofExpandedLine: 3) == SourceOrigin(file: "inline.frag", line: 2))
}
