// HueCompassShaderSourceTests — feature 333 (R02-G04-03) T-R02G0403-003 (FR-R02G0403-001, FR-R02G0403-002;
// clarifications Q1, Q3, Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement,
// every declared uniform listed, used and declared once per program, no texture sampler and no loops, vertex outputs
// matching fragment inputs, balanced braces, the `ShaderMeshRenderer` attribute names and locations, the fresnel rim,
// capped glow and fog drift terms, ASCII only, the band constants of the GLSL rule equal to the Swift ones, a CPU
// re-evaluation of the GLSL band rule (from the constants parsed out of the source) equal to `HueCompassPalette.band`
// for all 24 bands within 1e-9, and the CPU references (fresnel, glow gain, gain limit, fog drift, fog alpha, band
// code). The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams (neither is a
// dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import HueCompassCore

@Suite struct HueCompassShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "glass", vertex: HueCompassShaders.glassVertex,
                 fragment: HueCompassShaders.glassFragment, uniforms: HueCompassShaders.glassUniforms),
         Program(name: "solid", vertex: HueCompassShaders.solidVertex,
                 fragment: HueCompassShaders.solidFragment, uniforms: HueCompassShaders.solidUniforms)]
    }

    static func sources() -> [String] {
        [HueCompassShaders.glassVertex, HueCompassShaders.glassFragment,
         HueCompassShaders.solidVertex, HueCompassShaders.solidFragment]
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

    /// The value of the GLSL constant `const float <name> = <value>;` in `source`, nil when absent or not a number.
    static func constant(_ name: String, in source: String) -> Double? {
        let prefix: String = "const float \(name) = "
        for line in lines(source) where line.hasPrefix(prefix) && line.hasSuffix(";") {
            let value: String = String(line.dropFirst(prefix.count).dropLast())
            return Double(value)
        }
        return nil
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

    /// The GLSL `hcBand` rule re-evaluated on the CPU from the constants parsed out of the source: hue band / bands,
    /// sector floor(h), fraction h - sector, and the six HSV cases in the source's order.
    static func glslBand(_ band: Int, bands: Double, saturation: Double, value: Double) -> SIMD3<Double> {
        let count: Int = Int(bands)
        let n: Int = max(band, 0)
        let b: Int = n - (n / count) * count
        let h: Double = Double(b) / bands * 6.0
        let sector: Double = h.rounded(.down)
        let f: Double = h - sector
        let v: Double = value
        let p: Double = v * (1.0 - saturation)
        let q: Double = v * (1.0 - saturation * f)
        let t: Double = v * (1.0 - saturation * (1.0 - f))
        let s: Int = Int(sector)
        if s == 0 { return SIMD3<Double>(v, t, p) }
        if s == 1 { return SIMD3<Double>(q, v, p) }
        if s == 2 { return SIMD3<Double>(p, v, t) }
        if s == 3 { return SIMD3<Double>(p, q, v) }
        if s == 4 { return SIMD3<Double>(t, p, v) }
        return SIMD3<Double>(v, p, q)
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(HueCompassShaders.versionLine == "#version 300 es")
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
            #expect(HueCompassShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(HueCompassShaders.uniformNames.count == 2)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let glass: String = HueCompassShaders.glassVertex + HueCompassShaders.glassFragment
        let glassDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform mat4 u_model;", "uniform vec3 u_eye;", "uniform vec3 u_color;",
            "uniform float u_opacity;", "uniform float u_gain;", "uniform float u_gainLimit;", "uniform float u_shell;",
        ]
        for declaration in glassDeclarations { #expect(glass.contains(declaration), "\(declaration)") }
        let solid: String = HueCompassShaders.solidVertex + HueCompassShaders.solidFragment
        let solidDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform float u_time;", "uniform float u_fog;", "uniform float u_opacity;",
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
        #expect(Self.interface("out", in: HueCompassShaders.glassVertex) == ["v_normal": "vec3", "v_toEye": "vec3"])
        #expect(Self.interface("out", in: HueCompassShaders.solidVertex) == ["v_color": "vec3", "v_alpha": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in HueCompassShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        #expect(Self.layouts(HueCompassShaders.glassVertex) == ["0 a_position vec3", "1 a_normal vec3"])
        #expect(Self.layouts(HueCompassShaders.solidVertex)
                == ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"])
        #expect(Self.layouts(HueCompassShaders.glassFragment).isEmpty)
        #expect(Self.layouts(HueCompassShaders.solidFragment).isEmpty)
        for source in Self.sources() {
            for attribute in HueCompassShaders.attributes where source.contains("layout(location = \(attribute.location))") {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
    }

    @Test func glassCarriesTheFresnelRimAndCappedGlow() {
        let fragment: String = HueCompassShaders.glassFragment
        #expect(fragment.contains("float facing = clamp(abs(dot(n, v)), 0.0, 1.0);"))
        #expect(fragment.contains("float fresnel = pow(1.0 - facing, 3.0);"))
        #expect(fragment.contains("vec3 rim = mix(base, vec3(1.0), 0.5) * (0.6 * fresnel);"))
        #expect(fragment.contains("float gain = min(clamp(u_gain, 0.0, 2.0), clamp(u_gainLimit, 0.0, 2.0));"))
        #expect(fragment.contains("vec3 glow = base * (0.25 * gain);"))
        #expect(fragment.contains("float isShell = step(0.5, u_shell);"))
        #expect(HueCompassShaders.glassVertex.contains("v_normal = mat3(u_model) * a_normal;"))
        #expect(HueCompassShaders.glassVertex.contains("v_toEye = u_eye - world.xyz;"))
    }

    @Test func solidCarriesTheBandColourFogBrightnessAndDrift() {
        let vertex: String = HueCompassShaders.solidVertex
        #expect(vertex.contains(HueCompassShaders.bandFunction))
        #expect(vertex.contains("v_color = mix(clamp(a_normal, 0.0, 1.0), hcBand(band), isBand);"))
        #expect(vertex.contains("v_alpha = mix(1.0, clamp(code, 0.0, 1.0), isFog);"))
        #expect(vertex.contains("float drift = 0.01 * sin(6.283185307179586 * (0.1 * u_time + a_uv.y));"))
        #expect(vertex.contains("vec3 p = a_position + vec3(0.0, 0.0, isFog * drift);"))
        #expect(Self.wordCount("hcBand", in: vertex) >= 2)
        #expect(HueCompassShaders.solidFragment.contains("clamp(u_opacity, 0.0, 1.0) * clamp(v_alpha, 0.0, 1.0)"))
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }

    @Test func glslBandConstantsEqualTheSwiftOnes() {
        let source: String = HueCompassShaders.solidVertex
        let bands: Double? = Self.constant("HC_BANDS", in: source)
        let saturation: Double? = Self.constant("HC_SATURATION", in: source)
        let value: Double? = Self.constant("HC_VALUE", in: source)
        #expect(bands == Double(HueCompassWheel.bands))
        #expect(bands == Double(HueCompassShaders.bandCount))
        #expect(saturation == HueCompassPalette.bandSaturation)
        #expect(saturation == HueCompassShaders.bandSaturation)
        #expect(value == HueCompassPalette.bandValue)
        #expect(value == HueCompassShaders.bandValue)
        #expect(HueCompassShaders.bandSaturation == 0.85)
        #expect(HueCompassShaders.bandValue == 1.0)
        let cases: [String] = [
            "if (s == 0) { return vec3(v, t, p); }", "if (s == 1) { return vec3(q, v, p); }",
            "if (s == 2) { return vec3(p, v, t); }", "if (s == 3) { return vec3(p, q, v); }",
            "if (s == 4) { return vec3(t, p, v); }", "return vec3(v, p, q);",
            "float h = float(b) / HC_BANDS * 6.0;", "float p = v * (1.0 - HC_SATURATION);",
            "float q = v * (1.0 - HC_SATURATION * f);", "float t = v * (1.0 - HC_SATURATION * (1.0 - f));",
        ]
        for line in cases { #expect(source.contains(line), "\(line)") }
    }

    @Test func glslBandRuleEqualsThePaletteForAllBands() throws {
        let source: String = HueCompassShaders.solidVertex
        let bands: Double = try #require(Self.constant("HC_BANDS", in: source))
        let saturation: Double = try #require(Self.constant("HC_SATURATION", in: source))
        let value: Double = try #require(Self.constant("HC_VALUE", in: source))
        var band: Int = 0
        while band < HueCompassWheel.bands {
            let gpu: SIMD3<Double> = Self.glslBand(band, bands: bands, saturation: saturation, value: value)
            let cpu: SIMD3<Double> = HueCompassPalette.band(band)
            #expect(abs(gpu.x - cpu.x) <= 1e-9 && abs(gpu.y - cpu.y) <= 1e-9 && abs(gpu.z - cpu.z) <= 1e-9,
                    "band \(band): \(gpu) vs \(cpu)")
            let wrapped: SIMD3<Double> = Self.glslBand(band + 24, bands: bands, saturation: saturation, value: value)
            #expect(wrapped == gpu)
            band += 1
        }
    }

    @Test func bandCodeSelectsTheBandInTheSolidVertex() {
        let source: String = HueCompassShaders.solidVertex
        #expect(source.contains("float isBand = (1.0 - isFog) * step(0.5, code);"))
        #expect(source.contains("int band = int(floor(code + 0.5)) - 1;"))
        var band: Int = 0
        while band < HueCompassWheel.bands {
            let code: Double = HueCompassShaders.bandCode(band)
            #expect(code >= 0.5)
            #expect(Int((code + 0.5).rounded(.down)) - 1 == band)
            band += 1
        }
        #expect(HueCompassShaders.bandCode(-1) == 24)
        #expect(HueCompassShaders.bandCode(24) == 1)
    }

    @Test func gainBoundsMatchTheShaderConstants() {
        #expect(HueCompassShaders.maxGain == 2.0)
        #expect(HueCompassShaders.fresnelPower == 3.0)
        #expect(HueCompassShaders.reducedFlashingGainLimit < HueCompassShaders.standardGain)
        #expect(HueCompassShaders.standardGain <= HueCompassShaders.standardGainLimit)
        #expect(HueCompassShaders.standardGainLimit <= HueCompassShaders.maxGain)
        #expect(HueCompassShaders.gainLimit(reduceFlashing: false) == 2.0)
        #expect(HueCompassShaders.gainLimit(reduceFlashing: true) == 0.5)
        let standard: Double = HueCompassShaders.glowGain(gain: HueCompassShaders.standardGain,
                                                          limit: HueCompassShaders.gainLimit(reduceFlashing: false))
        let reduced: Double = HueCompassShaders.glowGain(gain: HueCompassShaders.standardGain,
                                                         limit: HueCompassShaders.gainLimit(reduceFlashing: true))
        #expect(standard == 1.0)
        #expect(reduced == 0.5)
        #expect(HueCompassShaders.glowGain(gain: 9, limit: 9) == 2)
        #expect(HueCompassShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(HueCompassShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let g: Double = HueCompassShaders.glowGain(gain: x, limit: 3 - x)
            #expect(g >= 0 && g <= HueCompassShaders.maxGain)
            #expect(HueCompassShaders.glowGain(gain: x, limit: 0.5) <= 0.5)
            step += 1
        }
    }

    @Test func fresnelReferenceStaysBounded() {
        #expect(HueCompassShaders.fresnel(facing: 1) == 0)
        #expect(HueCompassShaders.fresnel(facing: 0) == 1)
        #expect(HueCompassShaders.fresnel(facing: 0.5) == 0.125)
        #expect(HueCompassShaders.fresnel(facing: -0.5) == 0.125)
        #expect(HueCompassShaders.fresnel(facing: Double.nan) == 0)
        var step: Int = 0
        while step <= 40 {
            let f: Double = HueCompassShaders.fresnel(facing: Double(step) / 20 - 0.5)
            #expect(f >= 0 && f <= 1)
            step += 1
        }
    }

    @Test func fogDriftIsSlowSmallAndStillAtTimeZero() {
        #expect(HueCompassShaders.fogDrift(time: 0, phase: 0) == 0)
        #expect(abs(HueCompassShaders.fogDrift(time: 0, phase: 0.25) - HueCompassShaders.fogDriftAmplitude) < 1e-12)
        #expect(abs(HueCompassShaders.fogDrift(time: 2.5, phase: 0) - HueCompassShaders.fogDriftAmplitude) < 1e-12)
        #expect(HueCompassShaders.fogDrift(time: Double.infinity, phase: 0) == 0)
        #expect(HueCompassShaders.fogDriftHertz <= 0.25)
        #expect(HueCompassShaders.fogDriftAmplitude <= 0.02)
        var step: Int = 0
        while step < 96 {
            let phase: Double = Double(step) / 96
            let drift: Double = HueCompassShaders.fogDrift(time: Double(step) * 0.7, phase: phase)
            #expect(abs(drift) <= HueCompassShaders.fogDriftAmplitude + 1e-15)
            let period: Double = HueCompassShaders.fogDrift(time: Double(step) * 0.7 + 1 / HueCompassShaders.fogDriftHertz,
                                                            phase: phase)
            #expect(abs(period - drift) < 1e-12)
            step += 1
        }
    }

    @Test func fogAlphaFollowsBrightnessOnly() {
        var density: Int = 0
        var previous: Double = -1
        while density <= 9 {
            let alpha: Double = HueCompassShaders.fogAlpha(brightness: Double(density) / 9, opacity: 1)
            #expect(alpha > previous)
            #expect(alpha >= 0 && alpha <= 1)
            previous = alpha
            density += 1
        }
        #expect(HueCompassShaders.fogAlpha(brightness: 0, opacity: 1) == 0)
        #expect(HueCompassShaders.fogAlpha(brightness: 2, opacity: 0.5) == 0.5)
        #expect(HueCompassShaders.fogAlpha(brightness: Double.nan, opacity: 1) == 0)
    }
}
