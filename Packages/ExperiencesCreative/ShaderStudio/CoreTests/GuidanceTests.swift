// GuidanceTests — feature 162 (A22-P04) T-A22-403 (FR-A22-401, FR-A22-402; SC-A22-401; clarification Q1). Every
// refusal code has its own sentence; the line, the limit and the name are named; the `#version` and undeclared-uniform
// sentences are exact; the three compiler patterns match literal sample messages, case-insensitively, and any other
// message gets the general sentence. Synthetic data only.
import Testing
@testable import ShaderStudioCore

@Suite struct GuidanceTests {
    /// One issue of every code.
    static let everyIssue: [ValidationIssue] = [
        .sourceTooLarge(20_000), .tooManyLines(401), .tooManyUniforms(17), .tooManyTextureInputs(3), .noMain,
        .versionLine(2), .reservedName("u_time"), .duplicateName("u_gain"), .undeclaredInSource("u_speed"),
        .undeclaredInProject("u_extra"),
    ]

    @Test func everyCodeHasADistinctSentence() {
        #expect(Set(Self.everyIssue.map(\.code)).count == 10)
        let sentences = Self.everyIssue.map { Guidance.forIssue($0) }
        #expect(Set(sentences).count == sentences.count)
        for sentence in sentences {
            #expect(sentence.hasSuffix("."))
            #expect(sentence != Guidance.general)
        }
    }

    @Test func versionLineNamesTheLine() {
        #expect(Guidance.forIssue(.versionLine(3))
            == "Remove the #version line on line 3: Shader Studio supplies GLSL ES 3.00 itself.")
    }

    @Test func undeclaredInSourceShowsTheDeclaration() {
        #expect(Guidance.forIssue(.undeclaredInSource("u_speed")) == "Declare u_speed as `uniform float u_speed;` above main.")
    }

    @Test func undeclaredInProjectNamesBothFixes() {
        let sentence = Guidance.forIssue(.undeclaredInProject("u_extra"))
        #expect(sentence.contains("u_extra"))
        #expect(sentence.contains("inspector"))
        #expect(sentence.contains("source"))
    }

    @Test func limitsAndNamesAreNamed() {
        #expect(Guidance.forIssue(.sourceTooLarge(20_000)).contains("16384"))
        #expect(Guidance.forIssue(.tooManyLines(401)).contains("400"))
        #expect(Guidance.forIssue(.tooManyUniforms(17)).contains("16"))
        #expect(Guidance.forIssue(.tooManyTextureInputs(3)).contains("2"))
        #expect(Guidance.forIssue(.reservedName("u_time")).contains("u_time"))
        #expect(Guidance.forIssue(.duplicateName("u_gain")).contains("u_gain"))
        let custom = ShaderLimits(maxSourceBytes: 100, maxLines: 5, maxUniforms: 4, maxTextureInputs: 1)
        #expect(Guidance.forIssue(.tooManyLines(6), limits: custom).contains("limit is 5"))
    }

    @Test func undeclaredIdentifierTakesTheQuotedName() {
        let message = "'ss_undefinedGain' : undeclared identifier"
        #expect(Guidance.forDiagnostic(message: message)
            == "Declare ss_undefinedGain before it is used, for example `uniform float ss_undefinedGain;`.")
        #expect(Guidance.forDiagnostic(message: "UNDECLARED IDENTIFIER").contains("Declare it"))
    }

    @Test func syntaxAndTypePatternsMatchSampleMessages() {
        #expect(Guidance.forDiagnostic(message: "'float' : Syntax Error") == Guidance.syntax)
        let typeMessages = ["'=' : cannot convert from 'highp 3-component vector of float' to 'highp float'",
                            "'*' : wrong operand types - no operation '*' exists",
                            "'vc_fbm' : No matching overloaded function found", "'=' : dimension mismatch"]
        for message in typeMessages { #expect(Guidance.forDiagnostic(message: message) == Guidance.typeMismatch) }
    }

    @Test func unrecognisedMessageGetsTheGeneralSentence() {
        #expect(Guidance.forDiagnostic(message: "'x' : redefinition") == "Check this line for a typing mistake.")
        #expect(Guidance.forDiagnostic(message: "") == Guidance.general)
    }
}
