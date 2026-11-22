// ChronoConstellatorShaderSourceTests — feature 353 (R02-G06-03) T-R02G0603-003 (FR-R02G0603-002, FR-R02G0603-007).
// Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared uniform listed
// (equal to the uniform name constants) and every listed uniform declared and used, no texture sampler, no loops (so
// none unbounded) and no `discard`, vertex outputs matching fragment inputs, balanced braces, the `ShaderMeshRenderer`
// attribute names and locations, the GLSL palette constants parsing back to `ChronoConstellatorPalette` within 1/255,
// the ribbon alpha 1 - age / R, the shimmer bounded and still under Reduce Motion, driven by `u_time` alone, and the
// glow gain cap clamped in the shader. The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limit 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this
// target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "field", vertex: ChronoConstellatorShaders.fieldVertex,
                 fragment: ChronoConstellatorShaders.fieldFragment, uniforms: ChronoConstellatorShaders.fieldUniforms),
         Program(name: "glow", vertex: ChronoConstellatorShaders.glowVertex,
                 fragment: ChronoConstellatorShaders.glowFragment, uniforms: ChronoConstellatorShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [ChronoConstellatorShaders.fieldVertex, ChronoConstellatorShaders.fieldFragment,
         ChronoConstellatorShaders.glowVertex, ChronoConstellatorShaders.glowFragment]
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

    /// The value of `const float <name> = <value>;` in `source`, nil when absent or not a number.
    static func floatConstant(_ name: String, in source: String) -> Double? {
        let prefix: String = "const float \(name) = "
        for line in lines(source) where line.hasPrefix(prefix) && line.hasSuffix(";") {
            return Double(String(line.dropFirst(prefix.count).dropLast()))
        }
        return nil
    }

    /// The value of `const vec3 <name> = vec3(a, b, c);` in `source`, nil when absent or malformed.
    static func vec3Constant(_ name: String, in source: String) -> SIMD3<Double>? {
        let prefix: String = "const vec3 \(name) = vec3("
        for line in lines(source) where line.hasPrefix(prefix) && line.hasSuffix(");") {
            let body: String = String(line.dropFirst(prefix.count).dropLast(2))
            var values: [Double] = []
            for part in body.split(separator: ",") {
                guard let value = Double(part.trimmingCharacters(in: .whitespaces)) else { return nil }
                values.append(value)
            }
            guard values.count == 3 else { return nil }
            return SIMD3<Double>(values[0], values[1], values[2])
        }
        return nil
    }

    /// The identifiers of `text` (letters, digits and underscores, starting with a letter or underscore).
    static func identifiers(_ text: String) -> [String] {
        var result: [String] = []
        var current: String = ""
        for c in text {
            if c.isLetter || c == "_" || (c.isNumber && !current.isEmpty) {
                current.append(c)
            } else {
                if !current.isEmpty { result.append(current) }
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Occurrences of `word` in `text` as a whole identifier.
    static func wordCount(_ word: String, in text: String) -> Int {
        var count: Int = 0
        for identifier in identifiers(text) where identifier == word { count += 1 }
        return count
    }

    /// The largest component difference of `a` and `b`.
    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z)))
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(ChronoConstellatorShaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func everyUniformConstantIsDeclaredOnceAndUsed() {
        for program in Self.programs() {
            let declared: [String] = Self.declared("uniform", in: program.vertex)
                + Self.declared("uniform", in: program.fragment)
            #expect(declared == program.uniforms, "\(program.name) declares in a different order or set")
            #expect(Set(program.uniforms).count == program.uniforms.count, "\(program.name) list has duplicates")
            #expect(ChronoConstellatorShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(ChronoConstellatorShaders.uniformNames.count == 2)
        let constants: [String] = [
            ChronoConstellatorShaders.mvpUniform, ChronoConstellatorShaders.cellUniform,
            ChronoConstellatorShaders.lightDirectionUniform, ChronoConstellatorShaders.timeUniform,
            ChronoConstellatorShaders.reduceMotionUniform, ChronoConstellatorShaders.ribbonTicksUniform,
            ChronoConstellatorShaders.glowGainUniform, ChronoConstellatorShaders.glowLimitUniform,
            ChronoConstellatorShaders.shellUniform,
        ]
        let listed: Set<String> = Set(ChronoConstellatorShaders.fieldUniforms + ChronoConstellatorShaders.glowUniforms)
        #expect(Set(constants) == listed)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let fieldSource: String = ChronoConstellatorShaders.fieldVertex + ChronoConstellatorShaders.fieldFragment
        let fieldDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_cell;", "uniform vec3 u_lightDir;"]
        for declaration in fieldDeclarations { #expect(fieldSource.contains(declaration), "\(declaration)") }
        let glowSource: String = ChronoConstellatorShaders.glowVertex + ChronoConstellatorShaders.glowFragment
        let glowDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform float u_time;", "uniform float u_reduceMotion;",
            "uniform float u_ribbonTicks;", "uniform float u_glowGain;", "uniform float u_glowLimit;",
            "uniform float u_shell;",
        ]
        for declaration in glowDeclarations { #expect(glowSource.contains(declaration), "\(declaration)") }
    }

    @Test func noTextureSamplerNoLoopsAndNoDiscard() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture"))
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
            #expect(Self.wordCount("discard", in: source) == 0)
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
            #expect(Self.interface("out", in: program.fragment) == ["color": "vec4"], "\(program.name)")
            #expect(program.fragment.contains("color = vec4(rgb * alpha, alpha);"), "\(program.name) premultiplied")
        }
        #expect(Self.interface("out", in: ChronoConstellatorShaders.fieldVertex)
                == ["v_normal": "vec3", "v_base": "vec3", "v_cells": "vec2", "v_isField": "float"])
        #expect(Self.interface("out", in: ChronoConstellatorShaders.glowVertex)
                == ["v_colour": "vec3", "v_age": "float", "v_glow": "float", "v_phase": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in ChronoConstellatorShaders.attributes {
            listed.append("\(attribute.location) \(attribute.name)")
        }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(ChronoConstellatorShaders.fieldVertex) == expected)
        #expect(Self.layouts(ChronoConstellatorShaders.glowVertex) == expected)
        #expect(Self.layouts(ChronoConstellatorShaders.fieldFragment).isEmpty)
        #expect(Self.layouts(ChronoConstellatorShaders.glowFragment).isEmpty)
        for source in [ChronoConstellatorShaders.fieldVertex, ChronoConstellatorShaders.glowVertex] {
            for attribute in ChronoConstellatorShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
    }

    @Test func shaderPaletteConstantsParseBackToTheCPUPalette() throws {
        let tolerance: Double = 1.0 / 255.0
        let fieldV: String = ChronoConstellatorShaders.fieldVertex
        let pairs: [(name: String, colour: SIMD3<Double>)] = [
            (name: "CH_FIELD", colour: ChronoConstellatorPalette.field),
            (name: "CH_GRID", colour: ChronoConstellatorPalette.grid),
            (name: "CH_SILVER", colour: ChronoConstellatorPalette.silver),
            (name: "CH_STAR", colour: ChronoConstellatorPalette.star),
            (name: "CH_ROSE", colour: ChronoConstellatorPalette.rose),
            (name: "CH_AMBER", colour: ChronoConstellatorPalette.amber),
        ]
        for pair in pairs {
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(pair.name, in: fieldV), "\(pair.name)")
            #expect(Self.distance(parsed, pair.colour) <= tolerance, "\(pair.name)")
        }
        let fieldF: String = ChronoConstellatorShaders.fieldFragment
        let grid: SIMD3<Double> = try #require(Self.vec3Constant("CH_GRID", in: fieldF))
        #expect(Self.distance(grid, ChronoConstellatorPalette.grid) <= tolerance)
        let star: SIMD3<Double> = try #require(Self.vec3Constant("CH_STAR", in: ChronoConstellatorShaders.glowFragment))
        #expect(Self.distance(star, ChronoConstellatorPalette.star) <= tolerance)
        // The hex values of the design: #0B0A24 field, #1C1A44 grid.
        #expect(Self.distance(ChronoConstellatorPalette.field, SIMD3<Double>(11, 10, 36) / 255) < 1e-12)
        #expect(Self.distance(ChronoConstellatorPalette.grid, SIMD3<Double>(28, 26, 68) / 255) < 1e-12)
        // Constants are written with six fixed decimals.
        #expect(fieldV.contains("const vec3 CH_FIELD = vec3(0.043137, 0.039216, 0.141176);"))
        #expect(ChronoConstellatorShaders.field == ChronoConstellatorPalette.field)
        #expect(ChronoConstellatorShaders.grid == ChronoConstellatorPalette.grid)
        #expect(ChronoConstellatorShaders.silver == ChronoConstellatorPalette.silver)
        #expect(ChronoConstellatorShaders.star == ChronoConstellatorPalette.star)
        #expect(ChronoConstellatorShaders.rose == ChronoConstellatorPalette.rose)
        #expect(ChronoConstellatorShaders.amber == ChronoConstellatorPalette.amber)
        let glowF: String = ChronoConstellatorShaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "CH_LINE", value: ChronoConstellatorShaders.gridLineWidth,
             source: ChronoConstellatorShaders.fieldFragment),
            (name: "CH_AMBIENT", value: ChronoConstellatorShaders.ambient,
             source: ChronoConstellatorShaders.fieldFragment),
            (name: "CH_DIFFUSE", value: ChronoConstellatorShaders.diffuse,
             source: ChronoConstellatorShaders.fieldFragment),
            (name: "CH_MAX_TICKS", value: ChronoConstellatorShaders.maxRibbonTicks, source: glowF),
            (name: "CH_SHIMMER", value: ChronoConstellatorShaders.shimmerAmplitude, source: glowF),
            (name: "CH_SHIMMER_HERTZ", value: ChronoConstellatorShaders.shimmerHertz, source: glowF),
            (name: "CH_GLOW", value: ChronoConstellatorShaders.glowWeight, source: glowF),
            (name: "CH_CORE", value: ChronoConstellatorShaders.coreLift, source: glowF),
            (name: "CH_SHELL", value: ChronoConstellatorShaders.shellWeight, source: glowF),
            (name: "CH_MAX_GAIN", value: ChronoConstellatorShaders.maxGlowGain, source: glowF),
            (name: "CH_SHIMMER_SPATIAL", value: ChronoConstellatorShaders.shimmerSpatial,
             source: ChronoConstellatorShaders.glowVertex),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.floatConstant(entry.name, in: entry.source), "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(ChronoConstellatorShaders.ambient + ChronoConstellatorShaders.diffuse == 1.0)
        #expect(ChronoConstellatorShaders.maxRibbonTicks == Double(ChronoConstellatorTier.all[0].ribbonTicks))
    }

    @Test func fieldMaterialsSelectThePaletteAndStandApartFromTheField() {
        var codes: [Double] = []
        for material in ChronoConstellatorShaders.FieldMaterial.allCases {
            codes.append(material.code)
            #expect(Double(material.rawValue) == material.code)
            if material != .field { #expect(material.colour != ChronoConstellatorPalette.field) }
        }
        #expect(codes == [0, 1, 2, 3, 4, 5])
        #expect(ChronoConstellatorShaders.FieldMaterial.track.colour == ChronoConstellatorPalette.silver)
        #expect(ChronoConstellatorShaders.FieldMaterial.rose.colour == ChronoConstellatorPalette.rose)
        #expect(ChronoConstellatorShaders.FieldMaterial.amber.colour == ChronoConstellatorPalette.amber)
        let vertex: String = ChronoConstellatorShaders.fieldVertex
        #expect(vertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 5.0);"))
        #expect(vertex.contains("base = mix(base, CH_AMBER, isAmber);"))
        // Grid lines: full on a boundary, none mid-cell.
        #expect(ChronoConstellatorShaders.gridLine(cellsX: 2, cellsZ: 0.5) == 1)
        #expect(ChronoConstellatorShaders.gridLine(cellsX: 0.5, cellsZ: 1.5) == 0)
        #expect(ChronoConstellatorShaders.gridLine(cellsX: .nan, cellsZ: 0) == 0)
        let lit: SIMD3<Double> = ChronoConstellatorShaders.fieldShade(base: ChronoConstellatorPalette.silver,
                                                                       normalDotLight: 1)
        #expect(Self.distance(lit, ChronoConstellatorPalette.silver) < 1e-12)
    }

    @Test func ribbonAlphaIsOneMinusAgeOverTicks() {
        let fragment: String = ChronoConstellatorShaders.glowFragment
        #expect(fragment.contains("float ticks = clamp(u_ribbonTicks, 1.0, CH_MAX_TICKS);"))
        #expect(fragment.contains("float fade = clamp(1.0 - v_age / ticks, 0.0, 1.0);"))
        #expect(fragment.contains("float alpha = fade * mix(1.0, shellAlpha, isShell);"))
        for tier in ChronoConstellatorTier.all {
            var age: Int = 0
            while age <= tier.ribbonTicks + 2 {
                let alpha: Double = ChronoConstellatorShaders.ribbonAlpha(age: age, ticks: tier.ribbonTicks)
                let expected: Double = max(0, 1 - Double(age) / Double(tier.ribbonTicks))
                #expect(abs(alpha - expected) < 1e-12, "\(tier.name) age \(age)")
                #expect(alpha >= 0 && alpha <= 1)
                age += 1
            }
            #expect(ChronoConstellatorShaders.ribbonAlpha(age: 0, ticks: tier.ribbonTicks) == 1)
            #expect(ChronoConstellatorShaders.ribbonAlpha(age: tier.ribbonTicks, ticks: tier.ribbonTicks) == 0)
        }
        #expect(ChronoConstellatorShaders.ribbonAlpha(age: -3, ticks: 6) == 1)
        #expect(ChronoConstellatorShaders.ribbonAlpha(age: 1.0, ticks: 0.0) == 0)
        #expect(ChronoConstellatorShaders.ribbonAlpha(age: 12.0, ticks: 99.0) == 0.5)
        #expect(ChronoConstellatorShaders.ribbonAlpha(age: Double.nan, ticks: 6.0) == 0)
    }

    @Test func shimmerIsBoundedStillUnderReduceMotionAndUsesOnlyUTime() {
        #expect(ChronoConstellatorShaders.shimmerAmplitude > 0 && ChronoConstellatorShaders.shimmerAmplitude <= 0.1)
        let fragment: String = ChronoConstellatorShaders.glowFragment
        #expect(fragment.contains("float motion = 1.0 - step(0.5, u_reduceMotion);"))
        #expect(fragment.contains(
            "float shimmer = 1.0 + CH_SHIMMER * motion * sin(6.283185307179586 * "
                + "(CH_SHIMMER_HERTZ * u_time + v_phase));"))
        for source in Self.sources() {
            for identifier in Self.identifiers(source) where identifier.lowercased().contains("time")
                || identifier.lowercased().contains("frame") || identifier.lowercased().contains("clock") {
                #expect(identifier == "u_time", "other time source \(identifier)")
            }
        }
        #expect(Self.wordCount("u_time", in: ChronoConstellatorShaders.fieldVertex
                               + ChronoConstellatorShaders.fieldFragment + ChronoConstellatorShaders.glowVertex) == 0)
        var step: Int = 0
        while step < 50 {
            let time: Double = Double(step) * 0.37
            let phase: Double = Double(step) * 0.11
            let moving: Double = ChronoConstellatorShaders.shimmer(time: time, phase: phase, reduceMotion: false)
            #expect(abs(moving - 1) <= ChronoConstellatorShaders.shimmerAmplitude + 1e-12)
            #expect(ChronoConstellatorShaders.shimmer(time: time, phase: phase, reduceMotion: true) == 1)
            step += 1
        }
        #expect(ChronoConstellatorShaders.shimmer(time: .infinity, phase: 0, reduceMotion: false) == 1)
    }

    @Test func glowGainIsCappedInTheShader() {
        let reducedFlashingLimit: Double = 0.5   // Hue Compass's reducedFlashingGainLimit.
        #expect(ChronoConstellatorShaders.maxGlowGain == 1.5)
        #expect(ChronoConstellatorShaders.glowGainCap <= reducedFlashingLimit)
        #expect(ChronoConstellatorShaders.glowGainCap < ChronoConstellatorShaders.standardGlowGain)
        #expect(ChronoConstellatorShaders.standardGlowGain <= ChronoConstellatorShaders.standardGlowLimit)
        #expect(ChronoConstellatorShaders.standardGlowLimit <= ChronoConstellatorShaders.maxGlowGain)
        #expect(ChronoConstellatorShaders.glowFragment.contains(
            "float gain = min(clamp(u_glowGain, 0.0, CH_MAX_GAIN), clamp(u_glowLimit, 0.0, CH_MAX_GAIN));"))
        #expect(ChronoConstellatorShaders.glowLimit(reduceFlashing: true) == ChronoConstellatorShaders.glowGainCap)
        #expect(ChronoConstellatorShaders.glowLimit(reduceFlashing: false)
                == ChronoConstellatorShaders.standardGlowLimit)
        #expect(ChronoConstellatorShaders.glowGain(for: ChronoConstellatorTier.of(0)) == 1)
        #expect(ChronoConstellatorShaders.glowGain(for: ChronoConstellatorTier.of(1)) == 1)
        #expect(ChronoConstellatorShaders.glowGain(for: ChronoConstellatorTier.of(2)) == 0)
        #expect(ChronoConstellatorShaders.glowGain(gain: 9, limit: 9) == 1.5)
        #expect(ChronoConstellatorShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(ChronoConstellatorShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let capped: Double = ChronoConstellatorShaders.glowGain(
                gain: x, limit: ChronoConstellatorShaders.glowLimit(reduceFlashing: true))
            #expect(capped >= 0 && capped <= ChronoConstellatorShaders.glowGainCap)
            let colour: SIMD3<Double> = ChronoConstellatorShaders.glowColour(
                colour: ChronoConstellatorPalette.rose, glow: 1, gain: capped, shimmer: 1.1)
            #expect(colour.x >= 0 && colour.x <= 1 && colour.y >= 0 && colour.y <= 1 && colour.z >= 0 && colour.z <= 1)
            step += 1
        }
        let plain: SIMD3<Double> = ChronoConstellatorShaders.glowColour(colour: ChronoConstellatorPalette.silver,
                                                                         glow: 0, gain: 1.5, shimmer: 1)
        #expect(Self.distance(plain, ChronoConstellatorPalette.silver) < 1e-12)
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }
}
