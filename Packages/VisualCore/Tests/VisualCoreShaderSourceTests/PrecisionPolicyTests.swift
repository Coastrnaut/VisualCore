// PrecisionPolicyTests — feature 206 T-R02F06-003 (FR-R02F06-004, research R5).
import Testing
@testable import VisualCoreShaderSource

private func lib(_ pairs: [(String, String)]) -> ShaderLibrary {
    var l = ShaderLibrary()
    for (n, t) in pairs { l.add(n, t) }
    return l
}

private let withoutStatement = "out vec4 color;\nvoid main() { color = vec4(1.0); }"
private let withStatement = "precision mediump float;\nout vec4 color;\nvoid main() { color = vec4(1.0); }"

@Test func policyFollowsTheDeviceReport() {
    #expect(PrecisionPolicy(fragmentHighpSupported: true) == .high)
    #expect(PrecisionPolicy(fragmentHighpSupported: false) == .medium)
}

@Test func highPolicyInsertsHighpAfterTheDefines() throws {
    let defines = try DefineSet(["HQ": "1"])
    let e = try lib([("m.frag", withoutStatement)]).expand("m.frag", defines: defines, precision: .high, stage: .fragment)
    let lines = e.text.components(separatedBy: "\n")
    #expect(Array(lines.prefix(3)) == ["#version 300 es", "#define HQ 1", "precision highp float;"])
    #expect(e.origin(ofExpandedLine: 3) == .generated)
    #expect(e.origin(ofExpandedLine: 4) == SourceOrigin(file: "m.frag", line: 1))
    #expect(e.precisionFindings.isEmpty)
}

@Test func mediumPolicyInsertsMediump() throws {
    let e = try lib([("m.frag", withoutStatement)]).expand("m.frag", defines: .empty, precision: .medium, stage: .fragment)
    #expect(e.text.components(separatedBy: "\n")[1] == "precision mediump float;")
    #expect(e.origin(ofExpandedLine: 2) == .generated)
}

@Test func anExistingStatementIsKeptForBothPolicies() throws {
    let l = lib([("m.frag", withStatement)])
    for policy in PrecisionPolicy.allCases {
        let e = try l.expand("m.frag", defines: .empty, precision: policy, stage: .fragment)
        #expect(e.text == "#version 300 es\n" + withStatement)
        #expect(e == (try l.expand("m.frag")))
    }
}

@Test func aStatementInAnIncludeCounts() throws {
    let l = lib([("m.frag", "#include \"p.glsl\"\nvoid main() {}"), ("p.glsl", "precision lowp float;  // low")])
    let e = try l.expand("m.frag", defines: .empty, precision: .high, stage: .fragment)
    #expect(!e.text.contains("highp"))
}

@Test func vertexShadersAndNilPolicyAreUntouched() throws {
    let l = lib([("m.vert", withoutStatement), ("m.frag", withoutStatement)])
    let plain = try l.expand("m.vert")
    #expect(try l.expand("m.vert", defines: .empty, precision: .high, stage: .vertex) == plain)
    #expect(try l.expand("m.vert", defines: .empty, precision: .medium, stage: .vertex) == plain)
    let fragmentPlain = try l.expand("m.frag")
    #expect(try l.expand("m.frag", defines: .empty, precision: nil, stage: .fragment) == fragmentPlain)
    let highpVertex = lib([("h.vert", "highp float x;")])
    #expect(try highpVertex.expand("h.vert", defines: .empty, precision: .medium, stage: .vertex).precisionFindings.isEmpty)
}

@Test func highpUnderMediumPolicyIsAFindingWithFileAndLine() throws {
    let l = lib([
        ("m.frag", "precision highp float;\n#include \"u.glsl\"\nvoid main() {}"),
        ("u.glsl", "// highp in a comment is ignored\nuniform highp vec2 u_res;"),
    ])
    let medium = try l.expand("m.frag", defines: .empty, precision: .medium, stage: .fragment)
    #expect(medium.precisionFindings.map(\.file) == ["m.frag", "u.glsl"])
    #expect(medium.precisionFindings.map(\.line) == [1, 2])
    #expect(medium.precisionFindings[0].message.contains("precision statement"))
    #expect(medium.precisionFindings[1].message.contains("qualifier"))
    #expect(try l.expand("m.frag", defines: .empty, precision: .high, stage: .fragment).precisionFindings.isEmpty)
}

@Test func inlineOverloadMatchesNamedOverload() throws {
    let l = lib([("m.frag", withoutStatement)])
    let named = try l.expand("m.frag", defines: .empty, precision: .high, stage: .fragment)
    let inline = try l.expand(source: withoutStatement, named: "m.frag", defines: .empty, precision: .high, stage: .fragment)
    #expect(named == inline)
    #expect(throws: ShaderSourceError.unknownSource("x.frag")) {
        try l.expand("x.frag", defines: .empty, precision: .high, stage: .fragment)
    }
}
