// ColorfallCanyonsShaderSourceTests — feature 343 (R02-G05-03) T-R02G0503-003 (FR-R02G0503-002; clarifications Q1, Q2,
// Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared uniform
// listed (equal to the uniform name constants), used and declared once per program, no texture sampler, no loops (so
// none unbounded) and no `discard`, vertex outputs matching fragment inputs, balanced braces, the `ShaderMeshRenderer`
// attribute names and locations, the GLSL palette constants equal to `ColorfallCanyonsPalette`, the glow cap at or below
// the shared Reduce Flashing limit Hue Compass uses, the flow phase driven by `u_time` alone, and the CPU references
// (fluid colour mix equal to the palette's, flow codes, flow bands, glow gain, terrain shade). The real compile happens
// on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limits 2.0 and 0.5 are Hue Compass's `HueCompassShaders.maxGain` and `reducedFlashingGainLimit` (none of these is a
// dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import ColorfallCanyonsCore

@Suite struct ColorfallCanyonsShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "terrain", vertex: ColorfallCanyonsShaders.terrainVertex,
                 fragment: ColorfallCanyonsShaders.terrainFragment, uniforms: ColorfallCanyonsShaders.terrainUniforms),
         Program(name: "fluid", vertex: ColorfallCanyonsShaders.fluidVertex,
                 fragment: ColorfallCanyonsShaders.fluidFragment, uniforms: ColorfallCanyonsShaders.fluidUniforms)]
    }

    static func sources() -> [String] {
        [ColorfallCanyonsShaders.terrainVertex, ColorfallCanyonsShaders.terrainFragment,
         ColorfallCanyonsShaders.fluidVertex, ColorfallCanyonsShaders.fluidFragment]
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

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(ColorfallCanyonsShaders.versionLine == "#version 300 es")
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
            #expect(ColorfallCanyonsShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(ColorfallCanyonsShaders.uniformNames.count == 2)
        let constants: [String] = [
            ColorfallCanyonsShaders.mvpUniform, ColorfallCanyonsShaders.modelUniform, ColorfallCanyonsShaders.eyeUniform,
            ColorfallCanyonsShaders.unitUniform, ColorfallCanyonsShaders.lightDirectionUniform,
            ColorfallCanyonsShaders.cellUniform, ColorfallCanyonsShaders.timeUniform,
            ColorfallCanyonsShaders.flowBandsUniform, ColorfallCanyonsShaders.glowGainUniform,
            ColorfallCanyonsShaders.glowLimitUniform, ColorfallCanyonsShaders.shellUniform,
        ]
        let listed: Set<String> = Set(ColorfallCanyonsShaders.terrainUniforms + ColorfallCanyonsShaders.fluidUniforms)
        #expect(Set(constants) == listed)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let terrain: String = ColorfallCanyonsShaders.terrainVertex + ColorfallCanyonsShaders.terrainFragment
        let terrainDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform mat4 u_model;", "uniform vec3 u_eye;", "uniform float u_unit;",
            "uniform vec3 u_lightDir;",
        ]
        for declaration in terrainDeclarations { #expect(terrain.contains(declaration), "\(declaration)") }
        let fluid: String = ColorfallCanyonsShaders.fluidVertex + ColorfallCanyonsShaders.fluidFragment
        let fluidDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform float u_cell;", "uniform float u_time;", "uniform float u_flowBands;",
            "uniform float u_glowGain;", "uniform float u_glowLimit;", "uniform float u_shell;",
        ]
        for declaration in fluidDeclarations { #expect(fluid.contains(declaration), "\(declaration)") }
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
        #expect(Self.interface("out", in: ColorfallCanyonsShaders.terrainVertex)
                == ["v_normal": "vec3", "v_toEye": "vec3", "v_base": "vec3", "v_steps": "float"])
        #expect(Self.interface("out", in: ColorfallCanyonsShaders.fluidVertex)
                == ["v_weights": "vec3", "v_brightness": "float", "v_dir": "vec2", "v_fall": "float",
                    "v_cell": "vec2"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in ColorfallCanyonsShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(ColorfallCanyonsShaders.terrainVertex) == expected)
        #expect(Self.layouts(ColorfallCanyonsShaders.fluidVertex) == expected)
        #expect(Self.layouts(ColorfallCanyonsShaders.terrainFragment).isEmpty)
        #expect(Self.layouts(ColorfallCanyonsShaders.fluidFragment).isEmpty)
        for source in [ColorfallCanyonsShaders.terrainVertex, ColorfallCanyonsShaders.fluidVertex] {
            for attribute in ColorfallCanyonsShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
    }

    @Test func shaderPaletteConstantsEqualTheCPUPalette() throws {
        let terrainV: String = ColorfallCanyonsShaders.terrainVertex
        let fluidF: String = ColorfallCanyonsShaders.fluidFragment
        #expect(try #require(Self.vec3Constant("CC_SANDSTONE", in: terrainV)) == ColorfallCanyonsPalette.sandstone)
        #expect(try #require(Self.vec3Constant("CC_ROCK", in: terrainV)) == ColorfallCanyonsPalette.rock)
        #expect(try #require(Self.vec3Constant("CC_PEARL", in: terrainV)) == ColorfallCanyonsPalette.pearl)
        #expect(try #require(Self.vec3Constant("CC_NIGHT", in: terrainV)) == ColorfallCanyonsPalette.night)
        #expect(try #require(Self.vec3Constant("CC_PEARL", in: ColorfallCanyonsShaders.terrainFragment))
                == ColorfallCanyonsPalette.pearl)
        #expect(try #require(Self.vec3Constant("CC_CYAN", in: fluidF)) == ColorfallCanyonsPalette.cyan)
        #expect(try #require(Self.vec3Constant("CC_CORAL", in: fluidF)) == ColorfallCanyonsPalette.coral)
        #expect(try #require(Self.vec3Constant("CC_YELLOW", in: fluidF)) == ColorfallCanyonsPalette.yellow)
        #expect(ColorfallCanyonsShaders.night == ColorfallCanyonsPalette.night)
        #expect(ColorfallCanyonsShaders.sandstone == ColorfallCanyonsPalette.sandstone)
        #expect(ColorfallCanyonsShaders.rock == ColorfallCanyonsPalette.rock)
        #expect(ColorfallCanyonsShaders.pearl == ColorfallCanyonsPalette.pearl)
        #expect(ColorfallCanyonsShaders.cyan == ColorfallCanyonsPalette.cyan)
        #expect(ColorfallCanyonsShaders.coral == ColorfallCanyonsPalette.coral)
        #expect(ColorfallCanyonsShaders.yellow == ColorfallCanyonsPalette.yellow)
        #expect(Self.floatConstant("CC_PIT_ROCK", in: terrainV) == ColorfallCanyonsShaders.pitRockShare)
        #expect(Self.floatConstant("CC_MAX_BANDS", in: fluidF) == ColorfallCanyonsShaders.maxFlowBands)
        #expect(Self.floatConstant("CC_FLOW_HERTZ", in: fluidF) == ColorfallCanyonsShaders.flowHertz)
        #expect(Self.floatConstant("CC_BAND_DEPTH", in: fluidF) == ColorfallCanyonsShaders.bandDepth)
        #expect(Self.floatConstant("CC_MAX_GAIN", in: fluidF) == ColorfallCanyonsShaders.maxGlowGain)
        let terrainF: String = ColorfallCanyonsShaders.terrainFragment
        #expect(Self.floatConstant("CC_AMBIENT", in: terrainF) == ColorfallCanyonsShaders.ambient)
        #expect(Self.floatConstant("CC_DIFFUSE", in: terrainF) == ColorfallCanyonsShaders.diffuse)
        #expect(Self.floatConstant("CC_STRATA", in: terrainF) == ColorfallCanyonsShaders.strataPerStep)
        #expect(Self.floatConstant("CC_STRATA_DEPTH", in: terrainF) == ColorfallCanyonsShaders.strataDepth)
        #expect(ColorfallCanyonsShaders.ambient + ColorfallCanyonsShaders.diffuse == 1.0)
        #expect(Double(ColorfallCanyonsTier.all[0].flowBands) == ColorfallCanyonsShaders.maxFlowBands)
    }

    @Test func fluidColourMixEqualsThePaletteMix() {
        let samples: [[Int]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [3, 2, 1], [7, 0, 5], [0, 4, 4], [24, 24, 24], [1, 9, 2]]
        for masses in samples {
            let w: SIMD3<Double> = ColorfallCanyonsShaders.weights(masses: masses)
            let gpu: SIMD3<Double> = ColorfallCanyonsShaders.fluidColour(weights: w)
            let cpu: SIMD3<Double> = ColorfallCanyonsPalette.fluid(masses)
            let error: Double = max(abs(gpu.x - cpu.x), max(abs(gpu.y - cpu.y), abs(gpu.z - cpu.z)))
            #expect(error <= 1e-12, "\(masses): \(gpu) vs \(cpu)")
        }
        #expect(ColorfallCanyonsShaders.weights(masses: [0, 0, 0]) == SIMD3<Double>(0, 0, 0))
        #expect(ColorfallCanyonsShaders.weights(masses: [1, 2]) == SIMD3<Double>(0, 0, 0))
        let fragment: String = ColorfallCanyonsShaders.fluidFragment
        #expect(fragment.contains("vec3 w = v_weights / max(v_weights.x + v_weights.y + v_weights.z, 0.0001);"))
        #expect(fragment.contains("vec3 base = clamp(w.x * CC_CYAN + w.y * CC_CORAL + w.z * CC_YELLOW, 0.0, 1.0);"))
        #expect(ColorfallCanyonsShaders.fluidVertex.contains("v_weights = max(a_normal, vec3(0.0));"))
    }

    @Test func everyColourCarriesItsPattern() {
        let fragment: String = ColorfallCanyonsShaders.fluidFragment
        #expect(fragment.contains("float mark = clamp(w.x * stripe + w.y * spot + w.z * chevron, 0.0, 1.0);"))
        #expect(fragment.contains("vec3 body = base * level * band * (1.0 - CC_PATTERN_DEPTH * mark);"))
        #expect(Self.wordCount("stripe", in: fragment) >= 2)
        #expect(Self.wordCount("spot", in: fragment) >= 2)
        #expect(Self.wordCount("chevron", in: fragment) >= 2)
        #expect(ColorfallCanyonsPattern.of(.cyan) == .stripes)
        #expect(ColorfallCanyonsPattern.of(.coral) == .dots)
        #expect(ColorfallCanyonsPattern.of(.yellow) == .chevrons)
        #expect(ColorfallCanyonsShaders.patternDepth > 0.2 && ColorfallCanyonsShaders.patternDepth < 1)
    }

    @Test func glowCapStaysAtOrBelowTheSharedLimit() {
        // Hue Compass: maxGain 2.0, reducedFlashingGainLimit 0.5 (HueCompassShaders).
        let hueCompassMaxGain: Double = 2.0
        let hueCompassReducedFlashingLimit: Double = 0.5
        #expect(ColorfallCanyonsShaders.glowGainCap <= hueCompassReducedFlashingLimit)
        #expect(ColorfallCanyonsShaders.maxGlowGain <= hueCompassMaxGain)
        #expect(ColorfallCanyonsShaders.glowGainCap < ColorfallCanyonsShaders.standardGlowGain)
        #expect(ColorfallCanyonsShaders.standardGlowGain <= ColorfallCanyonsShaders.standardGlowLimit)
        #expect(ColorfallCanyonsShaders.standardGlowLimit <= ColorfallCanyonsShaders.maxGlowGain)
        #expect(ColorfallCanyonsShaders.glowLimit(reduceFlashing: true) == ColorfallCanyonsShaders.glowGainCap)
        #expect(ColorfallCanyonsShaders.glowLimit(reduceFlashing: false) == ColorfallCanyonsShaders.standardGlowLimit)
        #expect(ColorfallCanyonsShaders.fluidFragment.contains(
            "float gain = min(clamp(u_glowGain, 0.0, CC_MAX_GAIN), clamp(u_glowLimit, 0.0, CC_MAX_GAIN));"))
        #expect(ColorfallCanyonsShaders.glowGain(for: ColorfallCanyonsTier.of(0)) == 1)
        #expect(ColorfallCanyonsShaders.glowGain(for: ColorfallCanyonsTier.of(1)) == 1)
        #expect(ColorfallCanyonsShaders.glowGain(for: ColorfallCanyonsTier.of(2)) == 0)
        #expect(ColorfallCanyonsShaders.glowGain(gain: 9, limit: 9) == 2)
        #expect(ColorfallCanyonsShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(ColorfallCanyonsShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let capped: Double = ColorfallCanyonsShaders.glowGain(
                gain: x, limit: ColorfallCanyonsShaders.glowLimit(reduceFlashing: true))
            #expect(capped >= 0 && capped <= ColorfallCanyonsShaders.glowGainCap)
            step += 1
        }
    }

    @Test func flowPhaseUsesOnlyUTime() {
        for source in Self.sources() {
            for identifier in Self.identifiers(source) where identifier.lowercased().contains("time")
                || identifier.lowercased().contains("frame") || identifier.lowercased().contains("clock") {
                #expect(identifier == "u_time", "other time source \(identifier)")
            }
        }
        #expect(Self.wordCount("u_time", in: ColorfallCanyonsShaders.terrainVertex
                               + ColorfallCanyonsShaders.terrainFragment) == 0)
        #expect(Self.wordCount("u_time", in: ColorfallCanyonsShaders.fluidVertex) == 0)
        let fragment: String = ColorfallCanyonsShaders.fluidFragment
        #expect(fragment.contains(
            "float wave = 0.5 + 0.5 * cos(6.283185307179586 * (bands * along - speed * u_time));"))
        #expect(fragment.contains("float bands = clamp(floor(u_flowBands + 0.5), 1.0, CC_MAX_BANDS);"))
        // Reduce Motion holds u_time at 0: the band factor then depends on the position only.
        let a: Double = ColorfallCanyonsShaders.flowBand(along: 0.25, time: 0, bands: 1, waterfall: false, flowing: true)
        #expect(abs(a - (1 - ColorfallCanyonsShaders.bandDepth * 0.5)) < 1e-12)
    }

    @Test func flowCodesRoundTripThroughTheVertexDecoding() {
        let steps: [(dx: Int, dz: Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for step in steps {
            for fall in [false, true] {
                let code: Double = ColorfallCanyonsShaders.flowCode(dx: step.dx, dz: step.dz, waterfall: fall)
                let decoded = ColorfallCanyonsShaders.flowDirection(code: code)
                #expect(decoded.direction == SIMD2<Double>(Double(step.dx), Double(step.dz)))
                #expect(decoded.waterfall == fall)
                let jittered = ColorfallCanyonsShaders.flowDirection(code: code + 0.3)
                #expect(jittered.direction == decoded.direction)
            }
        }
        #expect(ColorfallCanyonsShaders.flowCode(dx: 0, dz: 0, waterfall: false) == 0)
        #expect(ColorfallCanyonsShaders.flowCode(dx: 1, dz: 1, waterfall: true) == 0)
        #expect(ColorfallCanyonsShaders.flowDirection(code: 0).direction == SIMD2<Double>(0, 0))
        #expect(ColorfallCanyonsShaders.flowDirection(code: 99).direction == SIMD2<Double>(0, -1))
        let vertex: String = ColorfallCanyonsShaders.fluidVertex
        #expect(vertex.contains("float code = clamp(floor(a_uv.y + 0.5), 0.0, 8.0);"))
        #expect(vertex.contains("v_dir = vec2(px - nx, pz - nz);"))
    }

    @Test func flowBandsMoveDownhillAndStayBounded() {
        let depth: Double = ColorfallCanyonsShaders.bandDepth
        #expect(ColorfallCanyonsShaders.flowBand(along: 0, time: 0, bands: 2, waterfall: false, flowing: true) == 1)
        #expect(ColorfallCanyonsShaders.flowBand(along: 0.4, time: 7, bands: 2, waterfall: false, flowing: false) == 1)
        #expect(ColorfallCanyonsShaders.flowBand(along: 0, time: .nan, bands: 2, waterfall: false, flowing: true) == 1)
        var step: Int = 0
        while step < 60 {
            let along: Double = Double(step) / 60
            let time: Double = Double(step) * 0.37
            for bands in [1.0, 2.0, 3.0, 9.0] {
                for fall in [false, true] {
                    let f: Double = ColorfallCanyonsShaders.flowBand(along: along, time: time, bands: bands,
                                                                     waterfall: fall, flowing: true)
                    #expect(f >= 1 - depth - 1e-12 && f <= 1 + 1e-12)
                    // The crest moves downhill: a later time at a point further along gives the same factor.
                    let b: Double = min(bands, ColorfallCanyonsShaders.maxFlowBands)
                    let speed: Double = ColorfallCanyonsShaders.flowHertz * (fall ? 2 : 1)
                    let moved: Double = ColorfallCanyonsShaders.flowBand(along: along + speed * 0.5 / b,
                                                                         time: time + 0.5, bands: bands,
                                                                         waterfall: fall, flowing: true)
                    #expect(abs(moved - f) < 1e-9)
                }
            }
            step += 1
        }
    }

    @Test func terrainLightingCarriesLambertAmbientAndRim() {
        let fragment: String = ColorfallCanyonsShaders.terrainFragment
        #expect(fragment.contains("float lambert = max(dot(n, l), 0.0);"))
        #expect(fragment.contains("float fresnel = pow(1.0 - facing, 3.0);"))
        #expect(fragment.contains("vec3 lit = base * (CC_AMBIENT + CC_DIFFUSE * lambert);"))
        #expect(fragment.contains("vec3 rim = mix(base, CC_PEARL, 0.5) * (CC_RIM * fresnel);"))
        #expect(ColorfallCanyonsShaders.terrainVertex.contains("v_normal = mat3(u_model) * a_normal;"))
        let sand: SIMD3<Double> = ColorfallCanyonsPalette.sandstone
        let facingLight: SIMD3<Double> = ColorfallCanyonsShaders.terrainShade(base: sand, normalDotLight: 1, facing: 1,
                                                                             steps: 0)
        let shadowed: SIMD3<Double> = ColorfallCanyonsShaders.terrainShade(base: sand, normalDotLight: -1, facing: 1,
                                                                          steps: 0)
        #expect(abs(facingLight.x - sand.x) < 1e-12)
        #expect(abs(shadowed.x - sand.x * ColorfallCanyonsShaders.ambient) < 1e-12)
        let grazing: SIMD3<Double> = ColorfallCanyonsShaders.terrainShade(base: sand, normalDotLight: -1, facing: 0,
                                                                         steps: 0)
        #expect(grazing.x > shadowed.x)
        // Every material stays apart from night (open cells differ from the background).
        for material in ColorfallCanyonsShaders.TerrainMaterial.allCases {
            let c: SIMD3<Double> = material.colour
            let night: SIMD3<Double> = ColorfallCanyonsPalette.night
            #expect(c != night)
            #expect(Double(material.rawValue) == material.code)
        }
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }
}
