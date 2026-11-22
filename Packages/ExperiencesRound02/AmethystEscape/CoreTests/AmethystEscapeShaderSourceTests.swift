// AmethystEscapeShaderSourceTests — feature 363 (R02-G07-03) T-R02G0703-003 (FR-R02G0703-002, FR-R02G0703-003).
// Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared uniform listed
// (equal to the uniform name constants) and every listed uniform declared and used, at most 16 vec4 uniform slots per
// program, no texture sampler, no `discard`, every loop bounded by a constant (the crystal fragment's one highlight loop
// by `AE_MAX_LAYERS` = 3, no `while`), vertex outputs matching fragment inputs, balanced braces, the `ShaderMeshRenderer`
// attribute names and locations, the GLSL palette constants parsing back to `AmethystEscapePalette` within 1/255, the
// facet alpha 0.55, the highlights driven by `u_time` alone, the glow gain per tier and the Reduce Flashing limit. The
// real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limit 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this
// target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "crystal", vertex: AmethystEscapeShaders.crystalVertex,
                 fragment: AmethystEscapeShaders.crystalFragment, uniforms: AmethystEscapeShaders.crystalUniforms),
         Program(name: "glow", vertex: AmethystEscapeShaders.glowVertex,
                 fragment: AmethystEscapeShaders.glowFragment, uniforms: AmethystEscapeShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [AmethystEscapeShaders.crystalVertex, AmethystEscapeShaders.crystalFragment,
         AmethystEscapeShaders.glowVertex, AmethystEscapeShaders.glowFragment]
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

    /// (type, name) of the declarations in `source` starting with `keyword` and a space, in order.
    static func declarations(_ keyword: String, in source: String) -> [(type: String, name: String)] {
        var result: [(type: String, name: String)] = []
        for line in lines(source) where line.hasPrefix(keyword + " ") {
            let parts: [String] = tokens(line)
            if parts.count >= 3 { result.append((type: parts[parts.count - 2], name: parts[parts.count - 1])) }
        }
        return result
    }

    /// Names of the declarations in `source` starting with `keyword` and a space.
    static func declared(_ keyword: String, in source: String) -> [String] {
        var names: [String] = []
        for declaration in declarations(keyword, in: source) { names.append(declaration.name) }
        return names
    }

    /// (name, type) of the stage interface declarations starting with `keyword` (`in` or `out`); layout lines excluded.
    static func interface(_ keyword: String, in source: String) -> [String: String] {
        var result: [String: String] = [:]
        for declaration in declarations(keyword, in: source) { result[declaration.name] = declaration.type }
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

    /// The value of `const <type> <name> = <value>;` in `source`, nil when absent or not a number.
    static func scalarConstant(_ type: String, _ name: String, in source: String) -> Double? {
        let prefix: String = "const \(type) \(name) = "
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

    /// The vec4 slots a uniform of GLSL `type` occupies (mat4: 4, mat3: 3, anything scalar or vector: 1).
    static func vec4Slots(_ type: String) -> Int {
        switch type {
        case "mat4": 4
        case "mat3": 3
        case "mat2": 2
        default: 1
        }
    }

    /// The largest component difference of `a` and `b`.
    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z)))
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(AmethystEscapeShaders.versionLine == "#version 300 es")
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
            #expect(AmethystEscapeShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(AmethystEscapeShaders.uniformNames.count == 2)
        let constants: [String] = [
            AmethystEscapeShaders.mvpUniform, AmethystEscapeShaders.lightDirectionUniform,
            AmethystEscapeShaders.timeUniform, AmethystEscapeShaders.highlightLayersUniform,
            AmethystEscapeShaders.failureUniform, AmethystEscapeShaders.glowGainUniform,
            AmethystEscapeShaders.glowLimitUniform, AmethystEscapeShaders.shellUniform,
        ]
        let listed: Set<String> = Set(AmethystEscapeShaders.crystalUniforms + AmethystEscapeShaders.glowUniforms)
        #expect(Set(constants) == listed)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let crystal: String = AmethystEscapeShaders.crystalVertex + AmethystEscapeShaders.crystalFragment
        let crystalDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_lightDir;", "uniform float u_time;",
            "uniform float u_highlightLayers;", "uniform float u_failure;",
        ]
        for declaration in crystalDeclarations { #expect(crystal.contains(declaration), "\(declaration)") }
        let glow: String = AmethystEscapeShaders.glowVertex + AmethystEscapeShaders.glowFragment
        let glowDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform float u_glowGain;", "uniform float u_glowLimit;", "uniform float u_shell;",
        ]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(AmethystEscapeShaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: program.vertex + "\n" + program.fragment)
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= AmethystEscapeShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["crystal": 8, "glow": 7])
    }

    @Test func noTextureSamplerNoDiscardAndLoopsBoundedByConstants() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture"))
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
            #expect(Self.wordCount("discard", in: source) == 0)
            #expect(Self.wordCount("break", in: source) == 0)
            for line in Self.lines(source) where Self.identifiers(line).first == "for" {
                // for (int i = 0; i < CONST; i++) with CONST declared `const int`.
                let parts: [String] = line.components(separatedBy: ";")
                #expect(parts.count == 3, "\(line)")
                let bound: [String] = Self.identifiers(parts.count > 1 ? parts[1] : "")
                #expect(bound.count == 2, "\(line)")
                if let name = bound.last {
                    #expect(Self.scalarConstant("int", name, in: source) != nil, "\(name) is not a constant")
                }
            }
        }
        #expect(Self.wordCount("for", in: AmethystEscapeShaders.crystalVertex) == 0)
        #expect(Self.wordCount("for", in: AmethystEscapeShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: AmethystEscapeShaders.glowFragment) == 0)
        let fragment: String = AmethystEscapeShaders.crystalFragment
        #expect(Self.wordCount("for", in: fragment) == 1)
        #expect(fragment.contains("for (int i = 0; i < AE_MAX_LAYERS; i++) {"))
        #expect(Self.scalarConstant("int", "AE_MAX_LAYERS", in: fragment) == 3)
        #expect(AmethystEscapeShaders.maxHighlightLayers == 3)
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
        #expect(Self.interface("out", in: AmethystEscapeShaders.crystalVertex)
                == ["v_normal": "vec3", "v_base": "vec3", "v_position": "vec3", "v_isFacet": "float",
                    "v_alpha": "float"])
        #expect(Self.interface("out", in: AmethystEscapeShaders.glowVertex) == ["v_colour": "vec3", "v_glow": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in AmethystEscapeShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(AmethystEscapeShaders.crystalVertex) == expected)
        #expect(Self.layouts(AmethystEscapeShaders.glowVertex) == expected)
        #expect(Self.layouts(AmethystEscapeShaders.crystalFragment).isEmpty)
        #expect(Self.layouts(AmethystEscapeShaders.glowFragment).isEmpty)
        for source in [AmethystEscapeShaders.crystalVertex, AmethystEscapeShaders.glowVertex] {
            for attribute in AmethystEscapeShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // Mesh streams: crystal uv = (material code, shade); glow colour in the normal slot, uv = (glow, 0).
        #expect(AmethystEscapeShaders.crystalVertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 4.0);"))
        #expect(AmethystEscapeShaders.crystalVertex.contains("v_base = base * clamp(a_uv.y, 0.0, 1.0);"))
        #expect(AmethystEscapeShaders.glowVertex.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(AmethystEscapeShaders.glowVertex.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsParseBackToTheCPUPalette() throws {
        let tolerance: Double = 1.0 / 255.0
        let crystalV: String = AmethystEscapeShaders.crystalVertex
        let crystalF: String = AmethystEscapeShaders.crystalFragment
        let glowF: String = AmethystEscapeShaders.glowFragment
        let pairs: [(name: String, colour: SIMD3<Double>, source: String)] = [
            (name: "AE_BACKDROP", colour: AmethystEscapePalette.backdrop, source: crystalV),
            (name: "AE_AMETHYST", colour: AmethystEscapePalette.amethyst, source: crystalV),
            (name: "AE_PLATINUM", colour: AmethystEscapePalette.platinum, source: crystalV),
            (name: "AE_BLOCKED", colour: AmethystEscapePalette.blocked, source: crystalV),
            (name: "AE_AMBER", colour: AmethystEscapePalette.amber, source: crystalV),
            (name: "AE_HIGHLIGHT", colour: AmethystEscapePalette.highlight, source: crystalF),
            (name: "AE_AMBER", colour: AmethystEscapePalette.amber, source: crystalF),
            (name: "AE_PEARL", colour: AmethystEscapePalette.pearl, source: glowF),
        ]
        for pair in pairs {
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(pair.name, in: pair.source), "\(pair.name)")
            #expect(Self.distance(parsed, pair.colour) <= tolerance, "\(pair.name)")
        }
        // The hex values of the design: #0A0614 backdrop, #8E4FD8 amethyst; six fixed decimals.
        #expect(Self.distance(AmethystEscapePalette.backdrop, SIMD3<Double>(10, 6, 20) / 255) < 1e-12)
        #expect(Self.distance(AmethystEscapePalette.amethyst, SIMD3<Double>(142, 79, 216) / 255) < 1e-12)
        #expect(crystalV.contains("const vec3 AE_BACKDROP = vec3(0.039216, 0.023529, 0.078431);"))
        #expect(AmethystEscapeShaders.backdrop == AmethystEscapePalette.backdrop)
        #expect(AmethystEscapeShaders.amethyst == AmethystEscapePalette.amethyst)
        #expect(AmethystEscapeShaders.highlight == AmethystEscapePalette.highlight)
        #expect(AmethystEscapeShaders.platinum == AmethystEscapePalette.platinum)
        #expect(AmethystEscapeShaders.blocked == AmethystEscapePalette.blocked)
        #expect(AmethystEscapeShaders.pearl == AmethystEscapePalette.pearl)
        #expect(AmethystEscapeShaders.amber == AmethystEscapePalette.amber)
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "AE_FACET_ALPHA", value: AmethystEscapeShaders.facetAlpha, source: crystalV),
            (name: "AE_AMBIENT", value: AmethystEscapeShaders.ambient, source: crystalF),
            (name: "AE_DIFFUSE", value: AmethystEscapeShaders.diffuse, source: crystalF),
            (name: "AE_SHININESS", value: AmethystEscapeShaders.shininess, source: crystalF),
            (name: "AE_HIGHLIGHT_WEIGHT", value: AmethystEscapeShaders.highlightWeight, source: crystalF),
            (name: "AE_HIGHLIGHT_SPEED", value: AmethystEscapeShaders.highlightSpeed, source: crystalF),
            (name: "AE_HIGHLIGHT_ELEVATION", value: AmethystEscapeShaders.highlightElevation, source: crystalF),
            (name: "AE_HIGHLIGHT_SPATIAL", value: AmethystEscapeShaders.highlightSpatial, source: crystalF),
            (name: "AE_FAILURE_TINT", value: AmethystEscapeShaders.failureTint, source: crystalF),
            (name: "AE_GLOW", value: AmethystEscapeShaders.glowWeight, source: glowF),
            (name: "AE_CORE", value: AmethystEscapeShaders.coreLift, source: glowF),
            (name: "AE_SHELL", value: AmethystEscapeShaders.shellWeight, source: glowF),
            (name: "AE_MAX_GAIN", value: AmethystEscapeShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(AmethystEscapeShaders.ambient + AmethystEscapeShaders.diffuse == 1.0)
    }

    @Test func crystalMaterialsSelectThePaletteAndOnlyFacetsAreTranslucent() {
        var codes: [Double] = []
        for material in AmethystEscapeShaders.CrystalMaterial.allCases {
            codes.append(material.code)
            #expect(Double(material.rawValue) == material.code)
            if material != .backdrop { #expect(material.colour != AmethystEscapePalette.backdrop) }
            #expect(material.alpha == (material == .facet ? 0.55 : 1.0))
        }
        #expect(codes == [0, 1, 2, 3, 4])
        #expect(AmethystEscapeShaders.facetAlpha == 0.55)
        #expect(AmethystEscapeShaders.CrystalMaterial.facet.colour == AmethystEscapePalette.amethyst)
        #expect(AmethystEscapeShaders.CrystalMaterial.platinum.colour == AmethystEscapePalette.platinum)
        #expect(AmethystEscapeShaders.CrystalMaterial.blocked.colour == AmethystEscapePalette.blocked)
        #expect(AmethystEscapeShaders.CrystalMaterial.amber.colour == AmethystEscapePalette.amber)
        let vertex: String = AmethystEscapeShaders.crystalVertex
        #expect(vertex.contains("v_alpha = mix(1.0, AE_FACET_ALPHA, isFacet);"))
        #expect(vertex.contains("base = mix(base, AE_AMBER, isAmber);"))
        let lit: SIMD3<Double> = AmethystEscapeShaders.crystalShade(base: AmethystEscapePalette.platinum,
                                                                    normalDotLight: 1)
        #expect(Self.distance(lit, AmethystEscapePalette.platinum) < 1e-12)
        let calm: SIMD3<Double> = AmethystEscapeShaders.failureMix(colour: AmethystEscapePalette.amethyst, failure: 0)
        #expect(calm == AmethystEscapePalette.amethyst)
        let failed: SIMD3<Double> = AmethystEscapeShaders.failureMix(colour: AmethystEscapePalette.amethyst,
                                                                     failure: 1)
        #expect(Self.distance(failed, AmethystEscapePalette.amber) < Self.distance(AmethystEscapePalette.amethyst,
                                                                                   AmethystEscapePalette.amber))
        #expect(AmethystEscapeShaders.failureMix(colour: AmethystEscapePalette.pearl, failure: .nan)
                == AmethystEscapePalette.pearl)
    }

    @Test func highlightsShiftWithUTimeAloneAndFollowTheTier() {
        let fragment: String = AmethystEscapeShaders.crystalFragment
        #expect(fragment.contains("float layers = clamp(u_highlightLayers, 0.0, float(AE_MAX_LAYERS));"))
        #expect(fragment.contains("float on = 1.0 - step(layers, float(i));"))
        #expect(fragment.contains("rgb = rgb + AE_HIGHLIGHT * sparkle * step(0.5, v_isFacet);"))
        for source in Self.sources() {
            for identifier in Self.identifiers(source) where identifier.lowercased().contains("time")
                || identifier.lowercased().contains("frame") || identifier.lowercased().contains("clock") {
                #expect(identifier == "u_time", "other time source \(identifier)")
            }
        }
        #expect(Self.wordCount("u_time", in: AmethystEscapeShaders.crystalVertex + AmethystEscapeShaders.glowVertex
                               + AmethystEscapeShaders.glowFragment) == 0)
        var expectedLayers: [Double] = []
        for tier in AmethystEscapeTier.all { expectedLayers.append(AmethystEscapeShaders.highlightLayers(for: tier)) }
        #expect(expectedLayers == [3, 2, 1])
        // Highlight directions are unit length, move with time and stand still at time 0 (Reduce Motion).
        var layer: Int = 0
        while layer < AmethystEscapeShaders.maxHighlightLayers {
            let still: SIMD3<Double> = AmethystEscapeShaders.highlightDirection(layer: layer, time: 0, phase: 0.3)
            let again: SIMD3<Double> = AmethystEscapeShaders.highlightDirection(layer: layer, time: 0, phase: 0.3)
            let later: SIMD3<Double> = AmethystEscapeShaders.highlightDirection(layer: layer, time: 1.5, phase: 0.3)
            #expect(still == again)
            #expect(Self.distance(still, later) > 1e-3)
            #expect(abs((later * later).sum() - 1) < 1e-12)
            #expect(later.y > 0)
            layer += 1
        }
    }

    @Test func glowGainPerTierAndReduceFlashingLimit() {
        let reducedFlashingLimit: Double = 0.5   // Hue Compass's reducedFlashingGainLimit.
        #expect(AmethystEscapeShaders.maxGlowGain == 1.5)
        #expect(AmethystEscapeShaders.glowGainCap <= reducedFlashingLimit)
        #expect(AmethystEscapeShaders.glowLimit(reduceFlashing: true)
                < AmethystEscapeShaders.glowLimit(reduceFlashing: false))
        #expect(AmethystEscapeShaders.glowLimit(reduceFlashing: true) == AmethystEscapeShaders.glowGainCap)
        #expect(AmethystEscapeShaders.glowLimit(reduceFlashing: false) == AmethystEscapeShaders.standardGlowLimit)
        #expect(AmethystEscapeShaders.standardGlowLimit <= AmethystEscapeShaders.maxGlowGain)
        #expect(AmethystEscapeShaders.glowFragment.contains(
            "float gain = min(clamp(u_glowGain, 0.0, AE_MAX_GAIN), clamp(u_glowLimit, 0.0, AE_MAX_GAIN));"))
        #expect(AmethystEscapeShaders.glowGain(for: AmethystEscapeTier.of(0)) == 1)
        #expect(AmethystEscapeShaders.glowGain(for: AmethystEscapeTier.of(1)) == 1)
        #expect(AmethystEscapeShaders.glowGain(for: AmethystEscapeTier.of(2)) == 0)
        #expect(AmethystEscapeShaders.glowGain(gain: 9, limit: 9) == 1.5)
        #expect(AmethystEscapeShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(AmethystEscapeShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let capped: Double = AmethystEscapeShaders.glowGain(
                gain: x, limit: AmethystEscapeShaders.glowLimit(reduceFlashing: true))
            #expect(capped >= 0 && capped <= AmethystEscapeShaders.glowGainCap)
            let colour: SIMD3<Double> = AmethystEscapeShaders.glowColour(colour: AmethystEscapePalette.exit, glow: 1,
                                                                         gain: capped)
            #expect(colour.x >= 0 && colour.x <= 1 && colour.y >= 0 && colour.y <= 1 && colour.z >= 0 && colour.z <= 1)
            step += 1
        }
        let plain: SIMD3<Double> = AmethystEscapeShaders.glowColour(colour: AmethystEscapePalette.exit, glow: 0,
                                                                    gain: 1.5)
        #expect(Self.distance(plain, AmethystEscapePalette.exit) < 1e-12)
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }
}
