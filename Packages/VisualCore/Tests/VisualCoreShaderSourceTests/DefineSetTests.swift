// DefineSetTests — feature 206 T-R02F06-002 (FR-R02F06-002, clarification Q4; analyze C1).
import Testing
@testable import VisualCoreShaderSource

@Test func acceptsValidDefinesAndEmitsSortedLines() throws {
    let set = try DefineSet(["QUALITY": "2", "BLOOM": "1", "_x9": ""])
    #expect(set.names == ["BLOOM", "QUALITY", "_x9"])
    #expect(set.lines == ["#define BLOOM 1", "#define QUALITY 2", "#define _x9 "])
    #expect(try DefineSet([:]) == DefineSet.empty)
}

@Test func refusesInvalidNames() {
    #expect(throws: DefineError.invalidName("9LIVES")) { try DefineSet(["9LIVES": "1"]) }
    #expect(throws: DefineError.invalidName("A-B")) { try DefineSet(["A-B": "1"]) }
    #expect(throws: DefineError.invalidName("")) { try DefineSet(["": "1"]) }
    #expect(throws: DefineError.invalidName("É")) { try DefineSet(["É": "1"]) }
}

@Test func refusesReservedNames() {
    #expect(throws: DefineError.reservedName("GL_FOO")) { try DefineSet(["GL_FOO": "1"]) }
    #expect(throws: DefineError.reservedName("__LINE")) { try DefineSet(["__LINE": "1"]) }
    #expect((try? DefineSet(["GLX": "1", "_A": "1"])) != nil)
}

@Test func refusesMultiLineAndLongValues() {
    #expect(throws: DefineError.invalidValue("A")) { try DefineSet(["A": "1\n2"]) }
    #expect(throws: DefineError.invalidValue("A")) { try DefineSet(["A": "1\r2"]) }
    #expect(throws: DefineError.invalidValue("A")) { try DefineSet(["A": String(repeating: "x", count: 257)]) }
    #expect((try? DefineSet(["A": String(repeating: "x", count: 256)])) != nil)
}

@Test func refusesMoreThan32Defines() {
    var many: [String: String] = [:]
    for i in 0..<32 { many["D\(i)"] = "1" }
    #expect((try? DefineSet(many)) != nil)
    many["D32"] = "1"
    #expect(throws: DefineError.tooMany(33)) { try DefineSet(many) }
}

@Test func everyShaderSourceErrorMapsToItsReasonCode() {
    let cases: [(ShaderSourceError, String)] = [
        (.tooLarge(70_000), "shader.too-large"),
        (.tooDeep(9), "shader.include-depth"),
        (.cycle(["a", "b", "a"]), "shader.include-cycle"),
        (.unknownInclude("x", file: "m", line: 1), "shader.unknown-include"),
        (.unknownSource("x"), "shader.unknown-include"),
        (.unsupportedVersion(file: "m", line: 1), "shader.unsupported-version"),
    ]
    for (error, code) in cases { #expect(error.reasonCode.rawValue == code) }
}

@Test func everyDefineErrorMapsToItsReasonCode() {
    let cases: [(DefineError, String)] = [
        (.invalidName("1"), "shader.define-name"),
        (.reservedName("GL_X"), "shader.define-reserved"),
        (.invalidValue("A"), "shader.define-value"),
        (.tooMany(33), "shader.too-many-defines"),
    ]
    for (error, code) in cases { #expect(error.reasonCode.rawValue == code) }
}

@Test func everyVariantErrorMapsToItsReasonCode() {
    let cases: [(VariantError, String)] = [
        (.noValues("A"), "shader.too-many-variants"),
        (.tooManyValues("A"), "shader.too-many-variants"),
        (.duplicateValue("A", "1"), "shader.too-many-variants"),
        (.duplicateSwitch("A"), "shader.too-many-variants"),
        (.tooManySwitches(7), "shader.too-many-variants"),
        (.tooManyCombinations(65), "shader.too-many-variants"),
        (.define(.reservedName("GL_X")), "shader.define-reserved"),
        (.define(.invalidValue("A")), "shader.define-value"),
    ]
    for (error, code) in cases { #expect(error.reasonCode.rawValue == code) }
}

@Test func reasonCodesAreExactlyTheFifteenOfClarificationQ4() {
    let expected: Set<String> = [
        "shader.include-cycle", "shader.include-depth", "shader.too-large", "shader.unknown-include",
        "shader.unsupported-version", "shader.define-name", "shader.define-reserved", "shader.define-value",
        "shader.too-many-defines", "shader.too-many-variants", "shader.compile", "shader.link",
        "shader.uniform-undeclared", "shader.uniform-type", "shader.parameter-not-finite",
    ]
    #expect(ShaderReasonCode.allCases.count == 15)
    #expect(Set(ShaderReasonCode.allCases.map(\.rawValue)) == expected)
}

@Test func failureReportCarriesFeatureAndCallerContext() {
    let diagnostic = ShaderDiagnostic(file: "m.frag", line: 3, stage: .fragment, severity: .error, message: "bad")
    let report = ShaderFailureReport(code: .compile, diagnostics: [diagnostic], experience: "A07", seed: 42, tick: 120, tier: 2)
    #expect(report.feature == "R2-F06")
    #expect(report.code == .compile)
    #expect(report.diagnostics == [diagnostic])
    #expect(report.experience == "A07")
    #expect(report.seed == 42)
    #expect(report.tick == 120)
    #expect(report.tier == 2)
    let bare = ShaderFailureReport(code: ShaderSourceError.tooDeep(9).reasonCode)
    #expect(bare.feature == "R2-F06")
    #expect(bare.code == .includeDepth)
    #expect(bare.diagnostics.isEmpty && bare.experience == nil && bare.seed == nil && bare.tick == nil && bare.tier == nil)
}
