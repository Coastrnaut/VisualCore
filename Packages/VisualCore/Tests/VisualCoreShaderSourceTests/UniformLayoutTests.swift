// UniformLayoutTests — feature 206 T-R02F06-005 (FR-R02F06-006, research R7).
import Testing
@testable import VisualCoreShaderSource

private func layout() throws -> UniformLayout {
    try UniformLayout([
        UniformDeclaration(name: "u_time", type: .float),
        UniformDeclaration(name: "u_res", type: .vec2),
        UniformDeclaration(name: "u_tex", type: .sampler2D),
        UniformDeclaration(name: "u_unused", type: .mat4),
    ])
}

@Test func matchingUniformsAreValidAndRemovedOnesUnused() throws {
    let report = try layout().check(active: ["u_time": .float, "u_res": .vec2, "u_tex": .sampler2D])
    #expect(report.isValid)
    #expect(report.reasonCode == nil)
    #expect(report.undeclared.isEmpty && report.mistyped.isEmpty)
    #expect(report.unused == ["u_unused"])
}

@Test func undeclaredAndMistypedAreErrorsInSortedOrder() throws {
    let report = try layout().check(active: [
        "u_zeta": .float, "u_alpha": .int, "u_time": .vec3, "u_res": .ivec2, "u_tex": .sampler2D,
    ])
    #expect(!report.isValid)
    #expect(report.undeclared == ["u_alpha", "u_zeta"])
    #expect(report.mistyped == [
        UniformMismatch(name: "u_res", declared: .vec2, actual: .ivec2),
        UniformMismatch(name: "u_time", declared: .float, actual: .vec3),
    ])
    #expect(report.unused == ["u_unused"])
    #expect(report.reasonCode == .uniformUndeclared)
    let typeOnly = try layout().check(active: ["u_time": .int])
    #expect(typeOnly.reasonCode == .uniformType)
    #expect(typeOnly.unused == ["u_res", "u_tex", "u_unused"])
}

@Test func checkIsDeterministic() throws {
    let active: [String: UniformType] = ["b": .float, "a": .float, "c": .bool, "u_time": .other(0x8B5E)]
    let first = try layout().check(active: active)
    for _ in 0..<10 { #expect(try layout().check(active: active) == first) }
    #expect(first.undeclared == ["a", "b", "c"])
    #expect(first.mistyped == [UniformMismatch(name: "u_time", declared: .float, actual: .other(0x8B5E))])
}

@Test func layoutRefusesDuplicateNamesAndOtherTypes() {
    #expect(throws: UniformLayoutError.duplicateName("u_a")) {
        try UniformLayout([UniformDeclaration(name: "u_a", type: .float), UniformDeclaration(name: "u_a", type: .vec2)])
    }
    #expect(throws: UniformLayoutError.undeclarableType("u_x")) {
        try UniformLayout([UniformDeclaration(name: "u_x", type: .other(1))])
    }
}

@Test func declarationsAreSortedAndLookedUp() throws {
    let l = try layout()
    #expect(l.declarations.map(\.name) == ["u_res", "u_tex", "u_time", "u_unused"])
    #expect(l.type(of: "u_tex") == .sampler2D)
    #expect(l.type(of: "nope") == nil)
}

@Test func glslNamesCoverEveryType() {
    let types: [(UniformType, String)] = [
        (.float, "float"), (.vec2, "vec2"), (.vec3, "vec3"), (.vec4, "vec4"), (.int, "int"), (.ivec2, "ivec2"),
        (.ivec3, "ivec3"), (.ivec4, "ivec4"), (.bool, "bool"), (.mat3, "mat3"), (.mat4, "mat4"),
        (.sampler2D, "sampler2D"), (.sampler3D, "sampler3D"), (.samplerCube, "samplerCube"), (.other(0x8B5E), "other(0x8B5E)"),
    ]
    for (type, name) in types { #expect(type.glslName == name) }
}
