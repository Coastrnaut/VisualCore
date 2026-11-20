// AuroraLoomShaderSourceTests — feature 303 (R02-G01-03) T-R02G0103-004 (FR-R02G0103-002; research R5). Host checks of
// the GLSL ES 3.00 sources: the version line and a precision statement, every declared uniform listed, used and declared
// once per program, no texture sampler, vertex outputs matching fragment inputs, the shared mesh attribute names and
// locations, ASCII only, and the palette fallback. The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine` (not a dependency of
// this target). The attributes `a_position` at 0 and `a_normal` at 1 are VisualCoreRendering's `MeshRenderer` layout fed
// by `Mesh.interleavedPositionNormal()`; `a_uv` at 2 is the ribbon's own stream.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore

@Suite struct AuroraLoomShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "ribbon", vertex: AuroraLoomShaders.ribbonVertex, fragment: AuroraLoomShaders.ribbonFragment,
                 uniforms: AuroraLoomShaders.ribbonUniforms),
         Program(name: "gate", vertex: AuroraLoomShaders.gateVertex, fragment: AuroraLoomShaders.gateFragment,
                 uniforms: AuroraLoomShaders.gateUniforms)]
    }

    static func sources() -> [String] {
        [AuroraLoomShaders.ribbonVertex, AuroraLoomShaders.ribbonFragment,
         AuroraLoomShaders.gateVertex, AuroraLoomShaders.gateFragment]
    }

    /// Trimmed non-empty lines of `source`.
    static func lines(_ source: String) -> [String] {
        var result: [String] = []
        for raw in source.split(separator: "\n", omittingEmptySubsequences: true) {
            let line: String = raw.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { result.append(line) }
        }
        return result
    }

    /// Whitespace-separated tokens of a declaration line without its trailing semicolon.
    static func tokens(_ line: String) -> [String] {
        var body: String = line
        if body.hasSuffix(";") { body.removeLast() }
        var result: [String] = []
        for token in body.split(whereSeparator: { $0 == " " || $0 == "\t" }) { result.append(String(token)) }
        return result
    }

    /// Names (last token) of the declarations in `source` starting with `keyword` and a space.
    static func declared(_ keyword: String, in source: String) -> [String] {
        var names: [String] = []
        for line in lines(source) where line.hasPrefix(keyword + " ") {
            let parts: [String] = tokens(line)
            if let last = parts.last { names.append(last) }
        }
        return names
    }

    /// (name, type) of the stage interface declarations starting with `keyword` (`in` or `out`); layout lines excluded.
    static func interface(_ keyword: String, in source: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in lines(source) where line.hasPrefix(keyword + " ") {
            let parts: [String] = tokens(line)
            if parts.count >= 3 { result[parts[parts.count - 1]] = parts[parts.count - 2] }
        }
        return result
    }

    /// Occurrences of `word` in `text` as a whole identifier.
    static func wordCount(_ word: String, in text: String) -> Int {
        let chars: [Character] = Array(text)
        let target: [Character] = Array(word)
        var count: Int = 0
        var i: Int = 0
        while i + target.count <= chars.count {
            var match: Bool = true
            var k: Int = 0
            while k < target.count {
                if chars[i + k] != target[k] { match = false; break }
                k += 1
            }
            if match {
                let before: Bool = i > 0 && (chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
                let end: Int = i + target.count
                let after: Bool = end < chars.count && (chars[end].isLetter || chars[end].isNumber || chars[end] == "_")
                if !before && !after { count += 1 }
            }
            i += 1
        }
        return count
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(AuroraLoomShaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func everyUniformIsListedDeclaredOnceAndUsed() {
        for program in Self.programs() {
            let declared: [String] = Self.declared("uniform", in: program.vertex)
                + Self.declared("uniform", in: program.fragment)
            #expect(Set(declared) == Set(program.uniforms), "\(program.name)")
            #expect(Set(program.uniforms).count == program.uniforms.count, "\(program.name) list has duplicates")
            for name in program.uniforms {
                var times: Int = 0
                for d in declared where d == name { times += 1 }
                #expect(times == 1, "\(program.name) declares \(name) \(times) times")
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
    }

    @Test func noTextureSamplerAndNoLoops() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture("))
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("while", in: source) == 0)
        }
    }

    @Test func vertexOutputsMatchFragmentInputs() {
        for program in Self.programs() {
            let outs: [String: String] = Self.interface("out", in: program.vertex)
            let ins: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outs == ins, "\(program.name)")
            let fragmentOuts: [String: String] = Self.interface("out", in: program.fragment)
            #expect(fragmentOuts == ["color": "vec4"], "\(program.name)")
        }
        #expect(Self.interface("out", in: AuroraLoomShaders.ribbonVertex)
                == ["v_uv": "vec2", "v_normal": "vec3", "v_layer": "float"])
    }

    @Test func attributesFollowTheSharedMeshUpload() {
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        var listed: [String] = []
        for attribute in AuroraLoomShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        var ribbon: [String] = []
        for line in Self.lines(AuroraLoomShaders.ribbonVertex) where line.hasPrefix("layout(location = ") {
            let parts: [String] = Self.tokens(line)
            let location: String = String(parts[2].dropLast())
            ribbon.append("\(location) \(parts[parts.count - 1]) \(parts[parts.count - 2])")
        }
        #expect(ribbon == expected)
        var gate: [String] = []
        for line in Self.lines(AuroraLoomShaders.gateVertex) where line.hasPrefix("layout(location = ") {
            let parts: [String] = Self.tokens(line)
            gate.append("\(String(parts[2].dropLast())) \(parts[parts.count - 1]) \(parts[parts.count - 2])")
        }
        #expect(gate == ["0 a_position vec3"])
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }

    @Test func fallbackColoursAreThePaletteRibbons() {
        let palette: [SIMD3<Double>] = [AuroraLoomPalette.teal, AuroraLoomPalette.magenta, AuroraLoomPalette.gold]
        for ribbon in -6...8 {
            let index: Int = ((ribbon % 3) + 3) % 3
            #expect(AuroraLoomShaders.fallbackColour(ribbon: ribbon) == palette[index])
        }
        let teal: SIMD3<Double> = AuroraLoomPalette.teal
        #expect(AuroraLoomShaders.gateColour(teal, lit: true) == teal)
        #expect(AuroraLoomShaders.gateColour(teal, lit: false) == teal * 0.45)
        #expect(AuroraLoomShaders.gateDimShare == 0.45)
        #expect(AuroraLoomShaders.gateFragment.contains("mix(0.45, 1.0,"))
        #expect(AuroraLoomShaders.ribbonFragment.contains("clamp(u_glowGain, 0.0, 4.0)"))
        #expect(AuroraLoomShaders.maxGlowGain == 4.0)
    }
}
