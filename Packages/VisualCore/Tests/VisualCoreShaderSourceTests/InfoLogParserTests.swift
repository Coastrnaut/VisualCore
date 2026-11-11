// InfoLogParserTests — feature 004 T-F306 (FR-F304). The ANGLE format is pinned against a real
// simulator capture in VisualCoreRendering ShaderProgramTests (T-F310).
import Testing
@testable import VisualCoreShaderSource

@Test func parsesErrorsAndWarningsAndMapsThroughTheExpansion() throws {
    var lib = ShaderLibrary()
    lib.add("noise.glsl", "float noise(vec2 p) {\n  return undefinedThing(p);\n}")
    lib.add("main.frag", "precision mediump float;\n#include \"noise.glsl\"\nout vec4 c;\nvoid main() { c = vec4(noise(vec2(0))); }")
    let e = try lib.expand("main.frag")
    let bad = try #require(e.text.components(separatedBy: "\n").firstIndex { $0.contains("undefinedThing") }) + 1
    let log = "ERROR: 0:\(bad): 'undefinedThing' : no matching overloaded function found\nWARNING: 0:1: 'extension' : not supported\n"
    let d = InfoLogParser.parse(log, stage: .fragment, map: e)
    #expect(d.count == 2)
    #expect(d[0] == ShaderDiagnostic(file: "noise.glsl", line: 2, stage: .fragment, severity: .error,
                                     message: "'undefinedThing' : no matching overloaded function found"))
    #expect(d[1].severity == .warning)
    #expect(d[1].file == "<generated>")
}

@Test func unparseableLinesKeepTheRawMessage() {
    let d = InfoLogParser.parse("Link failed: varying mismatch\n\n", stage: .link, map: nil)
    #expect(d == [ShaderDiagnostic(file: "unknown", line: 0, stage: .link, severity: .error, message: "Link failed: varying mismatch")])
}

@Test func withoutAMapTheExpandedLineIsReported() {
    let d = InfoLogParser.parse("ERROR: 0:7: 'x' : undeclared identifier", stage: .vertex, map: nil)
    #expect(d == [ShaderDiagnostic(file: "unknown", line: 7, stage: .vertex, severity: .error, message: "'x' : undeclared identifier")])
}

@Test func trailingSummaryLinesAreIgnoredWhenTheyCarryNoNewInformation() {
    let d = InfoLogParser.parse("ERROR: 0:3: 'y' : syntax error\nERROR: 1 compilation errors.  No code generated.\n", stage: .fragment, map: nil)
    #expect(d.count == 1)
    #expect(d.first?.line == 3)
}
