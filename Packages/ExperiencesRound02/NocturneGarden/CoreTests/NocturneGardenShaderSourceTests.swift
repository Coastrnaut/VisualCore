// NocturneGardenShaderSourceTests — feature 383 (R02-G09-03) T-R02G0903-003 (FR-R02G0903-002, FR-R02G0903-004,
// FR-R02G0903-006). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants) and every listed uniform declared and used, at most 16
// vec4 uniform slots per program, no texture sampler, no `discard`, every loop bounded by a constant (the garden
// fragment's one mist loop by `NG_MAX_LAYERS` = 3, no `while`), vertex outputs matching fragment inputs, balanced
// braces, the `ShaderMeshRenderer` attribute names and locations, the material codes, the GLSL palette constants
// parsing back to `NocturneGardenPalette` within 1/255, the mist drift and the sway driven by `u_time` alone and
// following the tier, the feathered shadow cover, the forbidden hatch (a non-colour cue), the glow gain per tier and
// the Reduce Flashing limit. The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limit 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this
// target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import NocturneGardenCore

@Suite struct NocturneGardenShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "garden", vertex: NocturneGardenShaders.gardenVertex,
                 fragment: NocturneGardenShaders.gardenFragment, uniforms: NocturneGardenShaders.gardenUniforms),
         Program(name: "glow", vertex: NocturneGardenShaders.glowVertex,
                 fragment: NocturneGardenShaders.glowFragment, uniforms: NocturneGardenShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [NocturneGardenShaders.gardenVertex, NocturneGardenShaders.gardenFragment,
         NocturneGardenShaders.glowVertex, NocturneGardenShaders.glowFragment]
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

    /// `names` with repeats removed, first occurrence kept.
    static func unique(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for name in names where !seen.contains(name) {
            seen.insert(name)
            result.append(name)
        }
        return result
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

    /// Rec. 709 luminance of `c`.
    static func luminance(_ c: SIMD3<Double>) -> Double {
        0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(NocturneGardenShaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func everyUniformConstantIsDeclaredAndUsed() {
        for program in Self.programs() {
            let vertexDeclared: [String] = Self.declared("uniform", in: program.vertex)
            let fragmentDeclared: [String] = Self.declared("uniform", in: program.fragment)
            #expect(Set(vertexDeclared).count == vertexDeclared.count, "\(program.name) vertex repeats a uniform")
            #expect(Set(fragmentDeclared).count == fragmentDeclared.count, "\(program.name) fragment repeats")
            #expect(Self.unique(vertexDeclared + fragmentDeclared) == program.uniforms,
                    "\(program.name) declares in a different order or set")
            #expect(Set(program.uniforms).count == program.uniforms.count, "\(program.name) list has duplicates")
            #expect(NocturneGardenShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
            // A uniform declared in a stage is used in that stage.
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(NocturneGardenShaders.uniformNames.count == 2)
        let constants: [String] = [
            NocturneGardenShaders.mvpUniform, NocturneGardenShaders.timeUniform,
            NocturneGardenShaders.lightDirectionUniform, NocturneGardenShaders.eyeUniform,
            NocturneGardenShaders.mistLayersUniform, NocturneGardenShaders.glowUniform,
            NocturneGardenShaders.glowLimitUniform,
        ]
        let listed: Set<String> = Set(NocturneGardenShaders.gardenUniforms + NocturneGardenShaders.glowUniforms)
        #expect(Set(constants) == listed)
        #expect(Set(constants).count == constants.count)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let vertex: String = NocturneGardenShaders.gardenVertex
        #expect(vertex.contains("uniform mat4 u_mvp;"))
        #expect(vertex.contains("uniform float u_time;"))
        let fragment: String = NocturneGardenShaders.gardenFragment
        let fragmentDeclarations: [String] = [
            "uniform vec3 u_lightDir;", "uniform vec3 u_eye;", "uniform float u_time;", "uniform float u_mistLayers;",
        ]
        for declaration in fragmentDeclarations { #expect(fragment.contains(declaration), "\(declaration)") }
        let glow: String = NocturneGardenShaders.glowVertex + NocturneGardenShaders.glowFragment
        let glowDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_glow;", "uniform float u_glowLimit;"]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(NocturneGardenShaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: program.vertex + "\n" + program.fragment)
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= NocturneGardenShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["garden": 8, "glow": 6])
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
        #expect(Self.wordCount("for", in: NocturneGardenShaders.gardenVertex) == 0)
        #expect(Self.wordCount("for", in: NocturneGardenShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: NocturneGardenShaders.glowFragment) == 0)
        let fragment: String = NocturneGardenShaders.gardenFragment
        #expect(Self.wordCount("for", in: fragment) == 1)
        #expect(fragment.contains("for (int i = 0; i < NG_MAX_LAYERS; i++) {"))
        #expect(Self.scalarConstant("int", "NG_MAX_LAYERS", in: fragment) == 3)
        #expect(NocturneGardenShaders.maxMistLayers == 3)
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
        let gardenOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_position": "vec3", "v_material": "float", "v_shade": "float",
        ]
        #expect(Self.interface("out", in: NocturneGardenShaders.gardenVertex) == gardenOuts)
        #expect(Self.interface("out", in: NocturneGardenShaders.glowVertex) == ["v_colour": "vec3", "v_glow": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in NocturneGardenShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(NocturneGardenShaders.gardenVertex) == expected)
        #expect(Self.layouts(NocturneGardenShaders.glowVertex) == expected)
        #expect(Self.layouts(NocturneGardenShaders.gardenFragment).isEmpty)
        #expect(Self.layouts(NocturneGardenShaders.glowFragment).isEmpty)
        for source in [NocturneGardenShaders.gardenVertex, NocturneGardenShaders.glowVertex] {
            for attribute in NocturneGardenShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // Mesh streams: garden uv = (material code, shade); glow colour in the normal slot, uv = (glow, 0).
        let vertex: String = NocturneGardenShaders.gardenVertex
        #expect(vertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 12.0);"))
        #expect(vertex.contains("float shade = clamp(a_uv.y, 0.0, 1.0);"))
        #expect(vertex.contains("v_base = base * mix(shade, 1.0, isShadow);"))
        #expect(NocturneGardenShaders.glowVertex.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(NocturneGardenShaders.glowVertex.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsParseBackToTheCPUPalette() throws {
        let tolerance: Double = 1.0 / 255.0
        let gardenV: String = NocturneGardenShaders.gardenVertex
        let gardenF: String = NocturneGardenShaders.gardenFragment
        let glowF: String = NocturneGardenShaders.glowFragment
        let pairs: [(name: String, colour: SIMD3<Double>, source: String)] = [
            (name: "NG_GROUND", colour: NocturneGardenPalette.ground, source: gardenV),
            (name: "NG_MIST", colour: NocturneGardenPalette.mist, source: gardenV),
            (name: "NG_SHADOW", colour: NocturneGardenPalette.shadow, source: gardenV),
            (name: "NG_GOLD", colour: NocturneGardenPalette.gold, source: gardenV),
            (name: "NG_CORAL", colour: NocturneGardenPalette.coral, source: gardenV),
            (name: "NG_LEAK", colour: NocturneGardenPalette.leak, source: gardenV),
            (name: "NG_BODY", colour: NocturneGardenPalette.body, source: gardenV),
            (name: "NG_LANTERN", colour: NocturneGardenPalette.lantern, source: gardenV),
            (name: "NG_SPENT", colour: NocturneGardenPalette.spent, source: gardenV),
            (name: "NG_UNSPENT", colour: NocturneGardenPalette.unspent, source: gardenV),
            (name: "NG_GLOW", colour: NocturneGardenPalette.glow, source: gardenV),
            (name: "NG_MIST", colour: NocturneGardenPalette.mist, source: gardenF),
            (name: "NG_MIST_HIGHLIGHT", colour: NocturneGardenPalette.mistHighlight, source: gardenF),
            (name: "NG_GOLD", colour: NocturneGardenPalette.gold, source: gardenF),
            (name: "NG_CORAL", colour: NocturneGardenPalette.coral, source: gardenF),
            (name: "NG_GLOW", colour: NocturneGardenPalette.glow, source: gardenF),
            (name: "NG_LANTERN", colour: NocturneGardenPalette.lantern, source: glowF),
        ]
        for pair in pairs {
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(pair.name, in: pair.source), "\(pair.name)")
            #expect(Self.distance(parsed, pair.colour) <= tolerance, "\(pair.name)")
        }
        // Every vec3 constant in every source is one of the palette colours (no stray colour).
        let palette: [SIMD3<Double>] = [
            NocturneGardenPalette.ground, NocturneGardenPalette.mist, NocturneGardenPalette.mistHighlight,
            NocturneGardenPalette.shadow, NocturneGardenPalette.gold, NocturneGardenPalette.coral,
            NocturneGardenPalette.leak, NocturneGardenPalette.body, NocturneGardenPalette.glow,
            NocturneGardenPalette.lantern, NocturneGardenPalette.spent, NocturneGardenPalette.unspent,
        ]
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                var nearest: Double = 1
                for colour in palette { nearest = min(nearest, Self.distance(parsed, colour)) }
                #expect(nearest <= tolerance, "\(name) is not a palette colour")
            }
        }
        // The hex values of the design: #0A1230 ground, #B8C4E0 mist; six fixed decimals.
        #expect(Self.distance(NocturneGardenPalette.ground, SIMD3<Double>(10, 18, 48) / 255) < 1e-12)
        #expect(Self.distance(NocturneGardenPalette.mist, SIMD3<Double>(184, 196, 224) / 255) < 1e-12)
        #expect(gardenV.contains("const vec3 NG_GROUND = vec3(0.039216, 0.070588, 0.188235);"))
        let swiftConstants: [(SIMD3<Double>, SIMD3<Double>)] = [
            (NocturneGardenShaders.ground, NocturneGardenPalette.ground),
            (NocturneGardenShaders.mist, NocturneGardenPalette.mist),
            (NocturneGardenShaders.mistHighlight, NocturneGardenPalette.mistHighlight),
            (NocturneGardenShaders.shadow, NocturneGardenPalette.shadow),
            (NocturneGardenShaders.gold, NocturneGardenPalette.gold),
            (NocturneGardenShaders.coral, NocturneGardenPalette.coral),
            (NocturneGardenShaders.leak, NocturneGardenPalette.leak),
            (NocturneGardenShaders.body, NocturneGardenPalette.body),
            (NocturneGardenShaders.glow, NocturneGardenPalette.glow),
            (NocturneGardenShaders.lantern, NocturneGardenPalette.lantern),
            (NocturneGardenShaders.spent, NocturneGardenPalette.spent),
            (NocturneGardenShaders.unspent, NocturneGardenPalette.unspent),
        ]
        for pair in swiftConstants { #expect(pair.0 == pair.1) }
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "NG_SWAY_AMPLITUDE", value: NocturneGardenShaders.swayAmplitude, source: gardenV),
            (name: "NG_SWAY_SPEED", value: NocturneGardenShaders.swaySpeed, source: gardenV),
            (name: "NG_SWAY_PHASE", value: NocturneGardenShaders.swayPhase, source: gardenV),
            (name: "NG_SWAY_HEIGHT", value: NocturneGardenShaders.swayHeight, source: gardenV),
            (name: "NG_AMBIENT", value: NocturneGardenShaders.ambient, source: gardenF),
            (name: "NG_DIFFUSE", value: NocturneGardenShaders.diffuse, source: gardenF),
            (name: "NG_EMISSION", value: NocturneGardenShaders.emission, source: gardenF),
            (name: "NG_FRESNEL_POWER", value: NocturneGardenShaders.fresnelPower, source: gardenF),
            (name: "NG_PEARL_WEIGHT", value: NocturneGardenShaders.pearlWeight, source: gardenF),
            (name: "NG_BODY_RIM", value: NocturneGardenShaders.bodyRimWeight, source: gardenF),
            (name: "NG_STEM_RIM", value: NocturneGardenShaders.stemRimWeight, source: gardenF),
            (name: "NG_MIST_WEIGHT", value: NocturneGardenShaders.mistLayerWeight, source: gardenF),
            (name: "NG_MIST_FREQUENCY", value: NocturneGardenShaders.mistFrequency, source: gardenF),
            (name: "NG_MIST_SPEED", value: NocturneGardenShaders.mistSpeed, source: gardenF),
            (name: "NG_MIST_TINT_STEP", value: NocturneGardenShaders.mistTintStep, source: gardenF),
            (name: "NG_HATCH_FREQUENCY", value: NocturneGardenShaders.hatchFrequency, source: gardenF),
            (name: "NG_HATCH_WIDTH", value: NocturneGardenShaders.hatchWidth, source: gardenF),
            (name: "NG_HATCH_GAP_TINT", value: NocturneGardenShaders.hatchGapTint, source: gardenF),
            (name: "NG_GLOW_WEIGHT", value: NocturneGardenShaders.glowWeight, source: glowF),
            (name: "NG_CORE", value: NocturneGardenShaders.coreLift, source: glowF),
            (name: "NG_MAX_GAIN", value: NocturneGardenShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(NocturneGardenShaders.ambient + NocturneGardenShaders.diffuse == 1.0)
    }

    @Test func materialCodesAreDistinctAndSelectThePalette() {
        var codes: [Double] = []
        for material in NocturneGardenShaders.GardenMaterial.allCases {
            codes.append(material.code)
            #expect(Double(material.rawValue) == material.code)
            if material != .ground { #expect(material.colour != NocturneGardenPalette.ground) }
        }
        #expect(codes == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        #expect(Set(codes).count == codes.count)
        let named: [Double] = [
            NocturneGardenShaders.groundMaterial, NocturneGardenShaders.mistMaterial,
            NocturneGardenShaders.shadowMaterial, NocturneGardenShaders.targetRimMaterial,
            NocturneGardenShaders.forbiddenHatchMaterial, NocturneGardenShaders.leakCrossMaterial,
            NocturneGardenShaders.bloomBodyMaterial, NocturneGardenShaders.leafStemMaterial,
            NocturneGardenShaders.lanternMaterial, NocturneGardenShaders.spentBarMaterial,
            NocturneGardenShaders.unspentBarMaterial, NocturneGardenShaders.headRimMaterial,
            NocturneGardenShaders.previewMaterial,
        ]
        #expect(named == codes)
        #expect(Set(named).count == named.count)
        typealias Material = NocturneGardenShaders.GardenMaterial
        #expect(Material.mist.colour == NocturneGardenPalette.mist)
        #expect(Material.shadow.colour == NocturneGardenPalette.shadow)
        #expect(Material.targetRim.colour == NocturneGardenPalette.gold)
        #expect(Material.forbiddenHatch.colour == NocturneGardenPalette.coral)
        #expect(Material.leakCross.colour == NocturneGardenPalette.leak)
        #expect(Material.bloomBody.colour == NocturneGardenPalette.body)
        #expect(Material.leafStem.colour == NocturneGardenPalette.body)
        #expect(Material.lantern.colour == NocturneGardenPalette.lantern)
        #expect(Material.spentBar.colour == NocturneGardenPalette.spent)
        #expect(Material.unspentBar.colour == NocturneGardenPalette.unspent)
        #expect(Material.headRim.colour == NocturneGardenPalette.glow)
        #expect(Material.preview.colour == NocturneGardenPalette.mistHighlight)
        #expect(NocturneGardenShaders.previewMaterial == 12)
        // The vertex shader's selection chain covers every code with its palette constant, in code order.
        let vertex: String = NocturneGardenShaders.gardenVertex
        let selections: [String] = [
            "vec3 base = mix(NG_GROUND, NG_MIST, isCode(m, 1.0));", "base = mix(base, NG_SHADOW, isShadow);",
            "base = mix(base, NG_GOLD, isCode(m, 3.0));", "base = mix(base, NG_CORAL, isCode(m, 4.0));",
            "base = mix(base, NG_LEAK, isCode(m, 5.0));", "base = mix(base, NG_BODY, isCode(m, 6.0));",
            "base = mix(base, NG_BODY, isCode(m, 7.0));", "base = mix(base, NG_LANTERN, isCode(m, 8.0));",
            "base = mix(base, NG_SPENT, isCode(m, 9.0));", "base = mix(base, NG_UNSPENT, isCode(m, 10.0));",
            "base = mix(base, NG_GLOW, isCode(m, 11.0));",
            // Feature 384 (R02-G09-04): the drag preview outline.
            "base = mix(base, NG_MIST_HIGHLIGHT, isCode(m, 12.0));",
        ]
        for selection in selections { #expect(vertex.contains(selection), "\(selection)") }
        #expect(vertex.contains("float isShadow = isCode(m, 2.0);"))
        // Emissive and swaying sets agree with the sources.
        var emissive: [Int] = []
        var sways: [Int] = []
        for material in Material.allCases {
            if material.isEmissive { emissive.append(material.rawValue) }
            if material.sways { sways.append(material.rawValue) }
        }
        #expect(emissive == [3, 4, 5, 8, 9, 11, 12])
        #expect(sways == [6, 7, 11])
        let emissiveLine: String = "float emissive = isCode(m, 3.0) + isHatch + isCode(m, 5.0) + isCode(m, 8.0)"
            + " + isCode(m, 9.0) + isCode(m, 11.0)\n        + isPreview;"
        #expect(NocturneGardenShaders.gardenFragment.contains(emissiveLine))
        #expect(vertex.contains("float sways = isCode(m, 6.0) + isCode(m, 7.0) + isCode(m, 11.0);"))
        let lit: SIMD3<Double> = NocturneGardenShaders.gardenShade(base: NocturneGardenPalette.unspent,
                                                                    normalDotLight: 1)
        #expect(Self.distance(lit, NocturneGardenPalette.unspent) < 1e-12)
        let dark: SIMD3<Double> = NocturneGardenShaders.gardenShade(base: NocturneGardenPalette.mist,
                                                                     normalDotLight: -1)
        #expect(Self.distance(dark, NocturneGardenPalette.mist * NocturneGardenShaders.ambient) < 1e-12)
        let glowing: SIMD3<Double> = NocturneGardenShaders.emissiveShade(base: NocturneGardenPalette.gold,
                                                                          normalDotLight: -1)
        #expect(Self.distance(glowing, NocturneGardenPalette.gold * NocturneGardenShaders.emission) < 1e-12)
    }

    @Test func shadowIsDeepBlackWithAFeatheredCover() {
        let fragment: String = NocturneGardenShaders.gardenFragment
        #expect(fragment.contains("float cover = smoothstep(0.0, 1.0, clamp(v_shade, 0.0, 1.0));"))
        #expect(fragment.contains("vec3 shadowColour = mix(mistLit, lit, cover);"))
        #expect(NocturneGardenShaders.shadowCover(shade: 0) == 0)
        #expect(NocturneGardenShaders.shadowCover(shade: 1) == 1)
        #expect(NocturneGardenShaders.shadowCover(shade: 0.5) == 0.5)
        #expect(NocturneGardenShaders.shadowCover(shade: Double.nan) == 0)
        var previous: Double = -1
        var step: Int = 0
        while step <= 20 {
            let cover: Double = NocturneGardenShaders.shadowCover(shade: Double(step) / 20)
            #expect(cover >= previous)
            previous = cover
            step += 1
        }
        // The frame check: shadow darker than the mist by at least 0.15 in luminance, under any light.
        let shadowDark: SIMD3<Double> = NocturneGardenShaders.gardenShade(base: NocturneGardenPalette.shadow,
                                                                           normalDotLight: 1)
        let mistDim: SIMD3<Double> = NocturneGardenShaders.gardenShade(base: NocturneGardenPalette.mist,
                                                                        normalDotLight: 0)
        #expect(Self.luminance(mistDim) - Self.luminance(shadowDark) >= 0.15)
    }

    @Test func mistDriftAndSwayMoveWithUTimeAloneAndFollowTheTier() {
        let fragment: String = NocturneGardenShaders.gardenFragment
        #expect(fragment.contains("float layers = clamp(u_mistLayers, 0.0, float(NG_MAX_LAYERS));"))
        #expect(fragment.contains("float on = 1.0 - step(layers, float(i));"))
        #expect(fragment.contains("float band = 0.5 + 0.5 * sin(phase + NG_MIST_SPEED * (k + 1.0) * u_time);"))
        #expect(NocturneGardenShaders.gardenVertex.contains(
            "float swing = NG_SWAY_AMPLITUDE * rise * sin(NG_SWAY_SPEED * u_time + NG_SWAY_PHASE * a_position.x);"))
        for source in Self.sources() {
            for identifier in Self.identifiers(source) where identifier.lowercased().contains("time")
                || identifier.lowercased().contains("frame") || identifier.lowercased().contains("clock") {
                #expect(identifier == "u_time", "other time source \(identifier)")
            }
        }
        #expect(Self.wordCount("u_time", in: NocturneGardenShaders.glowVertex + NocturneGardenShaders.glowFragment)
                == 0)
        var expectedLayers: [Double] = []
        for tier in NocturneGardenTier.all { expectedLayers.append(NocturneGardenShaders.mistLayers(for: tier)) }
        #expect(expectedLayers == [3, 2, 1])
        // Fresnel: 0 facing the eye, 1 at grazing, rising in between.
        #expect(NocturneGardenShaders.fresnel(normalDotView: 1) == 0)
        #expect(NocturneGardenShaders.fresnel(normalDotView: -1) == 0)
        #expect(NocturneGardenShaders.fresnel(normalDotView: 0) == 1)
        #expect(NocturneGardenShaders.fresnel(normalDotView: 0.3) > NocturneGardenShaders.fresnel(normalDotView: 0.7))
        // Bands stay in 0 ... 1, stand still at time 0 (Reduce Motion) and move with time.
        let p: SIMD3<Double> = SIMD3<Double>(0.2, 0.45, 0)
        var layer: Int = 0
        while layer < NocturneGardenShaders.maxMistLayers {
            let still: Double = NocturneGardenShaders.mistBand(layer: layer, time: 0, position: p)
            let again: Double = NocturneGardenShaders.mistBand(layer: layer, time: 0, position: p)
            let later: Double = NocturneGardenShaders.mistBand(layer: layer, time: 1.5, position: p)
            #expect(still == again)
            #expect(abs(still - later) > 1e-3)
            #expect(later >= 0 && later <= 1 && still >= 0 && still <= 1)
            layer += 1
        }
        // Sway: bounded by the amplitude, still at time 0, moving with time, feet (y <= 0) planted.
        let head: SIMD3<Double> = SIMD3<Double>(-0.3, 0.9, 0.35)
        #expect(NocturneGardenShaders.sway(position: head, time: 0)
                == NocturneGardenShaders.sway(position: head, time: 0))
        #expect(abs(NocturneGardenShaders.sway(position: head, time: 0)
                    - NocturneGardenShaders.sway(position: head, time: 1.2)) > 1e-4)
        #expect(NocturneGardenShaders.sway(position: SIMD3<Double>(0.4, 0, 0.35), time: 2) == 0)
        var tick: Int = 0
        while tick < 100 {
            let t: Double = Double(tick) * 0.13
            let offset: Double = NocturneGardenShaders.sway(position: head, time: t)
            #expect(abs(offset) <= NocturneGardenShaders.swayAmplitude)
            tick += 1
        }
    }

    @Test func forbiddenCellsCarryADiagonalHatchAndStayWarm() {
        let fragment: String = NocturneGardenShaders.gardenFragment
        #expect(fragment.contains("float stripe = fract((v_position.x + v_position.y) * NG_HATCH_FREQUENCY);"))
        #expect(fragment.contains("vec3 hatchColour = mix(gap, lit, line);"))
        // Across a forbidden cell the hatch is both line and gap: a pattern, not a flat colour.
        var lines: Int = 0
        var gaps: Int = 0
        var step: Int = 0
        while step < 200 {
            let x: Double = -0.5 + Double(step) / 200
            let value: Double = NocturneGardenShaders.hatch(position: SIMD3<Double>(x, 0.3, 0))
            #expect(value == 0 || value == 1)
            if value == 1 { lines += 1 } else { gaps += 1 }
            step += 1
        }
        #expect(lines > 20)
        #expect(gaps > 20)
        // Diagonal: constant along x + y = const, so moving along (1, -1) keeps the hatch value.
        let a: Double = NocturneGardenShaders.hatch(position: SIMD3<Double>(0.1, 0.2, 0))
        let b: Double = NocturneGardenShaders.hatch(position: SIMD3<Double>(0.25, 0.05, 0))
        #expect(a == b)
        // The frame check: a forbidden cell is warmer than the mist (red minus blue at least 0.15), lines and gaps,
        // at the weakest emissive light.
        let gap: SIMD3<Double> = NocturneGardenShaders.emissiveShade(base: NocturneGardenShaders.hatchGap,
                                                                      normalDotLight: 0)
        let line: SIMD3<Double> = NocturneGardenShaders.emissiveShade(base: NocturneGardenPalette.coral,
                                                                       normalDotLight: 0)
        #expect(gap.x - gap.z >= 0.15)
        #expect(line.x - line.z >= 0.15)
        #expect(NocturneGardenPalette.mist.x - NocturneGardenPalette.mist.z < 0)
    }

    @Test func bodiesAreDarkWithAGlowRim() {
        let fragment: String = NocturneGardenShaders.gardenFragment
        #expect(fragment.contains(
            "vec3 bodyColour = lit + NG_GLOW * (NG_BODY_RIM * fresnel * isBody + NG_STEM_RIM * fresnel * isStem);"))
        #expect(NocturneGardenShaders.bodyRimWeight > NocturneGardenShaders.stemRimWeight)
        #expect(NocturneGardenShaders.stemRimWeight > 0)
        #expect(Self.luminance(NocturneGardenPalette.body) < 0.1)
        #expect(Self.luminance(NocturneGardenPalette.glow) > 0.5)
    }

    @Test func glowGainPerTierAndReduceFlashingLimit() {
        let reducedFlashingLimit: Double = 0.5   // Hue Compass's reducedFlashingGainLimit.
        #expect(NocturneGardenShaders.maxGlowGain == 1.5)
        #expect(NocturneGardenShaders.glowGainCap <= reducedFlashingLimit)
        #expect(NocturneGardenShaders.glowLimit(reduceFlashing: true)
                < NocturneGardenShaders.glowLimit(reduceFlashing: false))
        #expect(NocturneGardenShaders.glowLimit(reduceFlashing: true) == NocturneGardenShaders.glowGainCap)
        #expect(NocturneGardenShaders.glowLimit(reduceFlashing: false) == NocturneGardenShaders.standardGlowLimit)
        #expect(NocturneGardenShaders.standardGlowLimit <= NocturneGardenShaders.maxGlowGain)
        #expect(NocturneGardenShaders.glowFragment.contains(
            "float gain = min(clamp(u_glow, 0.0, NG_MAX_GAIN), clamp(u_glowLimit, 0.0, NG_MAX_GAIN));"))
        let gain0: Double = NocturneGardenShaders.glowGain(for: NocturneGardenTier.of(0))
        let gain1: Double = NocturneGardenShaders.glowGain(for: NocturneGardenTier.of(1))
        let gain2: Double = NocturneGardenShaders.glowGain(for: NocturneGardenTier.of(2))
        #expect(gain0 > gain1)
        #expect(gain1 > 0)
        #expect(gain2 == 0)
        #expect(gain0 <= NocturneGardenShaders.maxGlowGain)
        #expect(NocturneGardenShaders.glowGain(gain: 9, limit: 9) == 1.5)
        #expect(NocturneGardenShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(NocturneGardenShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let capped: Double = NocturneGardenShaders.glowGain(
                gain: x, limit: NocturneGardenShaders.glowLimit(reduceFlashing: true))
            #expect(capped >= 0 && capped <= NocturneGardenShaders.glowGainCap)
            let glow: SIMD4<Double> = NocturneGardenShaders.glowColour(colour: NocturneGardenPalette.glow, glow: 1,
                                                                       gain: capped)
            #expect(glow.x >= 0 && glow.x <= 1 && glow.y >= 0 && glow.y <= 1 && glow.z >= 0 && glow.z <= 1)
            #expect(glow.w <= NocturneGardenShaders.glowWeight * NocturneGardenShaders.glowGainCap + 1e-12)
            step += 1
        }
        let plain: SIMD4<Double> = NocturneGardenShaders.glowColour(colour: NocturneGardenPalette.glow, glow: 0,
                                                                    gain: 1.5)
        #expect(Self.distance(SIMD3<Double>(plain.x, plain.y, plain.z), NocturneGardenPalette.glow) < 1e-12)
        #expect(plain.w == 0)
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }
}
