// WaveKnotKeeperShaderSourceTests — feature 323 (R02-G03-03) T-R02G0303-003 (FR-R02G0303-001, FR-R02G0303-002;
// research R3). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared
// uniform listed, used and declared once per program, no texture sampler and no loops, vertex outputs matching fragment
// inputs, balanced braces, the `ShaderMeshRenderer` attribute names and locations, the fresnel, caustic pulse and gate
// edge terms, ASCII only, and the CPU references (fresnel, caustic, gain, solid colour). The real compile happens on the
// simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams (neither is a
// dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "rope", vertex: WaveKnotKeeperShaders.ropeVertex,
                 fragment: WaveKnotKeeperShaders.ropeFragment, uniforms: WaveKnotKeeperShaders.ropeUniforms),
         Program(name: "solid", vertex: WaveKnotKeeperShaders.solidVertex,
                 fragment: WaveKnotKeeperShaders.solidFragment, uniforms: WaveKnotKeeperShaders.solidUniforms)]
    }

    static func sources() -> [String] {
        [WaveKnotKeeperShaders.ropeVertex, WaveKnotKeeperShaders.ropeFragment,
         WaveKnotKeeperShaders.solidVertex, WaveKnotKeeperShaders.solidFragment]
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

    /// "location name type" of the `layout(location = n) in type name;` lines of `source`, in order.
    static func layouts(_ source: String) -> [String] {
        var result: [String] = []
        for line in lines(source) where line.hasPrefix("layout(location = ") {
            let parts: [String] = tokens(line)
            result.append("\(String(parts[2].dropLast())) \(parts[parts.count - 1]) \(parts[parts.count - 2])")
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
        #expect(WaveKnotKeeperShaders.versionLine == "#version 300 es")
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
            #expect(declared == program.uniforms, "\(program.name) declares in a different order or set")
            #expect(Set(program.uniforms).count == program.uniforms.count, "\(program.name) list has duplicates")
            #expect(WaveKnotKeeperShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(WaveKnotKeeperShaders.uniformNames.count == 2)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let rope: String = WaveKnotKeeperShaders.ropeVertex + WaveKnotKeeperShaders.ropeFragment
        let ropeDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_eye;", "uniform float u_pulse;", "uniform float u_gain;",
            "uniform float u_shell;", "uniform float u_opacity;", "uniform vec3 u_pearl;", "uniform vec3 u_sapphire;",
            "uniform vec3 u_ember;",
        ]
        for declaration in ropeDeclarations { #expect(rope.contains(declaration), "\(declaration)") }
        let solid: String = WaveKnotKeeperShaders.solidVertex + WaveKnotKeeperShaders.solidFragment
        let solidDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_color;", "uniform float u_opacity;", "uniform float u_rim;",
            "uniform vec3 u_viewDir;", "uniform float u_edge;", "uniform vec3 u_boxCenter;", "uniform vec3 u_boxHalf;",
        ]
        for declaration in solidDeclarations { #expect(solid.contains(declaration), "\(declaration)") }
    }

    @Test func noTextureSamplerAndNoLoops() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture("))
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
        }
    }

    @Test func bracesAndParenthesesAreBalanced() {
        for source in Self.sources() {
            var braces: Int = 0
            var parens: Int = 0
            var negative: Bool = false
            for c in source {
                if c == "{" { braces += 1 }
                if c == "}" { braces -= 1 }
                if c == "(" { parens += 1 }
                if c == ")" { parens -= 1 }
                if braces < 0 || parens < 0 { negative = true }
            }
            #expect(braces == 0)
            #expect(parens == 0)
            #expect(!negative)
            #expect(source.contains("void main() {"))
        }
    }

    @Test func vertexOutputsMatchFragmentInputs() {
        for program in Self.programs() {
            let outs: [String: String] = Self.interface("out", in: program.vertex)
            let ins: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outs == ins, "\(program.name)")
            let fragmentOuts: [String: String] = Self.interface("out", in: program.fragment)
            #expect(fragmentOuts == ["color": "vec4"], "\(program.name)")
            #expect(program.fragment.contains("color = vec4(rgb * alpha, alpha);"), "\(program.name) premultiplied")
        }
        #expect(Self.interface("out", in: WaveKnotKeeperShaders.ropeVertex)
                == ["v_normal": "vec3", "v_toEye": "vec3", "v_weight": "float"])
        #expect(Self.interface("out", in: WaveKnotKeeperShaders.solidVertex) == ["v_normal": "vec3", "v_local": "vec3"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in WaveKnotKeeperShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        #expect(Self.layouts(WaveKnotKeeperShaders.ropeVertex)
                == ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"])
        #expect(Self.layouts(WaveKnotKeeperShaders.solidVertex) == ["0 a_position vec3", "1 a_normal vec3"])
        #expect(Self.layouts(WaveKnotKeeperShaders.ropeFragment).isEmpty)
        #expect(Self.layouts(WaveKnotKeeperShaders.solidFragment).isEmpty)
        #expect(WaveKnotKeeperShaders.ropeVertex.contains("v_weight = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func ropeCarriesTheFresnelCausticPulseAndGlowShellTerms() {
        let fragment: String = WaveKnotKeeperShaders.ropeFragment
        #expect(fragment.contains("float facing = clamp(abs(dot(n, v)), 0.0, 1.0);"))
        #expect(fragment.contains("float fresnel = pow(1.0 - facing, 3.0);"))
        #expect(fragment.contains("mix(u_sapphire, u_pearl, 0.35 + 0.65 * fresnel)"))
        #expect(fragment.contains("u_pearl * (0.45 * fresnel)"))
        #expect(fragment.contains("float caustic = clamp(u_pulse, 0.0, 1.0) * clamp(v_weight, 0.0, 1.0) * gain;"))
        #expect(fragment.contains("u_ember * caustic"))
        #expect(fragment.contains("float isShell = step(0.5, u_shell);"))
        #expect(WaveKnotKeeperShaders.ropeVertex.contains("v_toEye = u_eye - a_position;"))
    }

    @Test func solidCarriesTheRimAndGateEdgeTerms() {
        let fragment: String = WaveKnotKeeperShaders.solidFragment
        #expect(fragment.contains("float rim = (1.0 - facing) * (1.0 - facing);"))
        #expect(fragment.contains("float median = max(min(q.x, q.y), min(max(q.x, q.y), q.z));"))
        #expect(fragment.contains("smoothstep(0.86, 0.98, median)"))
        #expect(fragment.contains("clamp(u_edge, 0.0, 1.0)"))
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }

    @Test func boundsMatchTheShaderConstants() {
        #expect(WaveKnotKeeperShaders.maxGain == 2.0)
        #expect(WaveKnotKeeperShaders.ropeFragment.contains("clamp(u_gain, 0.0, 2.0)"))
        #expect(WaveKnotKeeperShaders.fresnelPower == 3.0)
        #expect(WaveKnotKeeperShaders.edgeStart == 0.86)
        #expect(WaveKnotKeeperShaders.reducedFlashingGain < WaveKnotKeeperShaders.standardGain)
        #expect(WaveKnotKeeperShaders.standardGain <= WaveKnotKeeperShaders.maxGain)
        #expect(WaveKnotKeeperShaders.gain(reduceFlashing: false) == 1.0)
        #expect(WaveKnotKeeperShaders.gain(reduceFlashing: true) == 0.5)
    }

    @Test func fresnelAndCausticReferencesStayBounded() {
        #expect(WaveKnotKeeperShaders.fresnel(facing: 1) == 0)
        #expect(WaveKnotKeeperShaders.fresnel(facing: 0) == 1)
        #expect(WaveKnotKeeperShaders.fresnel(facing: 0.5) == 0.125)
        #expect(WaveKnotKeeperShaders.fresnel(facing: -0.5) == 0.125)
        #expect(WaveKnotKeeperShaders.fresnel(facing: Double.nan) == 0)
        #expect(WaveKnotKeeperShaders.caustic(pulse: 1, weight: 1, gain: 1) == 1)
        #expect(WaveKnotKeeperShaders.caustic(pulse: 0.5, weight: 0.5, gain: 1) == 0.25)
        #expect(WaveKnotKeeperShaders.caustic(pulse: 1, weight: 0, gain: 2) == 0)
        #expect(WaveKnotKeeperShaders.caustic(pulse: 3, weight: 3, gain: 9) == 2)
        #expect(WaveKnotKeeperShaders.caustic(pulse: Double.infinity, weight: 1, gain: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 20 - 0.5
            let f: Double = WaveKnotKeeperShaders.fresnel(facing: x)
            let c: Double = WaveKnotKeeperShaders.caustic(pulse: x, weight: 1 - x, gain: x * 3)
            #expect(f >= 0 && f <= 1)
            #expect(c >= 0 && c <= WaveKnotKeeperShaders.maxGain)
            step += 1
        }
    }

    @Test func causticFollowsTheSnapshotPulse() {
        let reduced: Double = WaveKnotKeeperShaders.gain(reduceFlashing: true)
        var step: Int = 0
        while step < 16 {
            let time: Double = Double(step) * 0.25
            let pulse: Double = 0.5 + 0.5 * sin(2 * Double.pi * WaveKnotKeeperSceneSnapshot.pulseHertz * time)
            let full: Double = WaveKnotKeeperShaders.caustic(pulse: pulse, weight: 1, gain: 1)
            let capped: Double = WaveKnotKeeperShaders.caustic(pulse: pulse, weight: 1, gain: reduced)
            #expect(abs(full - pulse) < 1e-12)
            #expect(capped <= full)
            step += 1
        }
    }

    @Test func solidColourIsTheFacingColour() {
        let pearl: SIMD3<Double> = WaveKnotKeeperPalette.pearl
        #expect(WaveKnotKeeperShaders.solidColour(pearl) == pearl)
        let ember: SIMD3<Double> = WaveKnotKeeperPalette.ember
        #expect(WaveKnotKeeperShaders.solidColour(ember) == ember)
        let over: SIMD3<Double> = SIMD3<Double>(1.5, -0.2, 0.5)
        #expect(WaveKnotKeeperShaders.solidColour(over) == SIMD3<Double>(1, 0, 0.5))
    }
}
