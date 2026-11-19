// IncludeOnceTests — feature 206 T-R02F06-003 (FR-R02F06-001, research R1, R2).
import Testing
@testable import VisualCoreShaderSource

private func lib(_ pairs: [(String, String)]) -> ShaderLibrary {
    var l = ShaderLibrary()
    for (n, t) in pairs { l.add(n, t) }
    return l
}

@Test func diamondIncludePastesTheSharedFileOnce() throws {
    let l = lib([
        ("main.frag", "#include \"a.glsl\"\n#include \"b.glsl\"\nvoid main() {}"),
        ("a.glsl", "#include \"common.glsl\"\nfloat a() { return k; }"),
        ("b.glsl", "#include \"common.glsl\"\nfloat b() { return k; }"),
        ("common.glsl", "const float k = 1.0;"),
    ])
    let e = try l.expand("main.frag")
    let lines = e.text.components(separatedBy: "\n")
    #expect(lines.filter { $0 == "const float k = 1.0;" }.count == 1)
    #expect(lines == ["#version 300 es", "const float k = 1.0;", "float a() { return k; }", "float b() { return k; }", "void main() {}"])
    #expect(e.origin(ofExpandedLine: 4) == SourceOrigin(file: "b.glsl", line: 2))
    #expect(e.origin(ofExpandedLine: 5) == SourceOrigin(file: "main.frag", line: 3))
}

@Test func repeatedIncludeInOneFileIsSkipped() throws {
    let l = lib([("m.frag", "#include \"c.glsl\"\n#include \"c.glsl\""), ("c.glsl", "float c;")])
    #expect(try l.expand("m.frag").text == "#version 300 es\nfloat c;")
}

@Test func cyclesAreStillRefusedWithIncludeOnce() {
    let l = lib([("main.frag", "#include \"a.glsl\""), ("a.glsl", "#include \"b.glsl\""), ("b.glsl", "#include \"a.glsl\"")])
    #expect(throws: ShaderSourceError.cycle(["main.frag", "a.glsl", "b.glsl", "a.glsl"])) { try l.expand("main.frag") }
    let selfInclude = lib([("m.frag", "#include \"m.frag\"")])
    #expect(throws: ShaderSourceError.cycle(["m.frag", "m.frag"])) { try selfInclude.expand("m.frag") }
}

@Test func sizeGuardCountsBytesNotLines() throws {
    // Many short lines: 20,000 lines are 40,015 bytes and pass; 40,000 lines are 80,015 bytes and are refused
    // during expansion, at the first line past 65,536 bytes (the old guard compared the line count).
    let shortLines = String(repeating: "x\n", count: 20_000)
    let ok = try lib([("m.frag", "#include \"pad.glsl\""), ("pad.glsl", shortLines)]).expand("m.frag")
    #expect(ok.text.utf8.count < ShaderLibrary.maxExpandedBytes)
    #expect(ok.origins.count == 20_001)
    let large = String(repeating: "x\n", count: 40_000)
    #expect(throws: ShaderSourceError.self) { try lib([("m.frag", "#include \"pad.glsl\""), ("pad.glsl", large)]).expand("m.frag") }
    do { _ = try lib([("m.frag", "#include \"pad.glsl\""), ("pad.glsl", large)]).expand("m.frag") } catch {
        guard case .tooLarge(let n) = error else { Issue.record("wrong error \(error)"); return }
        #expect(n > ShaderLibrary.maxExpandedBytes)
        #expect(n <= ShaderLibrary.maxExpandedBytes + 2)   // stopped at the first line over the limit
    }
}

@Test func exactly64KiBPassesAndOneMoreByteIsRefused() throws {
    // "#version 300 es" (15 bytes) + "\n" + body; body = 65,536 − 16 bytes.
    let body = String(repeating: "a", count: ShaderLibrary.maxExpandedBytes - 16)
    let e = try lib([("m.frag", body)]).expand("m.frag")
    #expect(e.text.utf8.count == ShaderLibrary.maxExpandedBytes)
    #expect(throws: ShaderSourceError.tooLarge(ShaderLibrary.maxExpandedBytes + 1)) {
        try lib([("m.frag", body + "a")]).expand("m.frag")
    }
}
