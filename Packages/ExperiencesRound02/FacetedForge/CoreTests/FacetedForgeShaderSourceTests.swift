// FacetedForgeShaderSourceTests — feature 373 (R02-G08-03) T-R02G0803-003 (FR-R02G0803-002, FR-R02G0803-004,
// FR-R02G0803-007). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants) and every listed uniform declared and used, at most 16
// vec4 uniform slots per program, no texture sampler, no `discard`, every loop bounded by a constant (the crystal
// fragment's one dispersion loop by `FF_MAX_LAYERS` = 3, no `while`), vertex outputs matching fragment inputs, balanced
// braces, the `ShaderMeshRenderer` attribute names and locations, the material codes, the GLSL palette constants
// parsing back to `FacetedForgePalette` within 1/255, the dispersion driven by `u_time` alone and following the tier,
// the cut-face lattice and the dashed preview rim (non-colour cues), the glow gain per tier and the Reduce Flashing
// limit. The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limit 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this
// target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import FacetedForgeCore

@Suite struct FacetedForgeShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "crystal", vertex: FacetedForgeShaders.crystalVertex,
                 fragment: FacetedForgeShaders.crystalFragment, uniforms: FacetedForgeShaders.crystalUniforms),
         Program(name: "glow", vertex: FacetedForgeShaders.glowVertex,
                 fragment: FacetedForgeShaders.glowFragment, uniforms: FacetedForgeShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [FacetedForgeShaders.crystalVertex, FacetedForgeShaders.crystalFragment,
         FacetedForgeShaders.glowVertex, FacetedForgeShaders.glowFragment]
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
        #expect(FacetedForgeShaders.versionLine == "#version 300 es")
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
            #expect(FacetedForgeShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(FacetedForgeShaders.uniformNames.count == 2)
        let constants: [String] = [
            FacetedForgeShaders.mvpUniform, FacetedForgeShaders.lightDirectionUniform,
            FacetedForgeShaders.eyeUniform, FacetedForgeShaders.timeUniform, FacetedForgeShaders.layersUniform,
            FacetedForgeShaders.glowUniform, FacetedForgeShaders.glowLimitUniform,
        ]
        let listed: Set<String> = Set(FacetedForgeShaders.crystalUniforms + FacetedForgeShaders.glowUniforms)
        #expect(Set(constants) == listed)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let crystal: String = FacetedForgeShaders.crystalVertex + FacetedForgeShaders.crystalFragment
        let crystalDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_lightDir;", "uniform vec3 u_eye;", "uniform float u_time;",
            "uniform float u_layers;",
        ]
        for declaration in crystalDeclarations { #expect(crystal.contains(declaration), "\(declaration)") }
        let glow: String = FacetedForgeShaders.glowVertex + FacetedForgeShaders.glowFragment
        let glowDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_glow;", "uniform float u_glowLimit;"]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(FacetedForgeShaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: program.vertex + "\n" + program.fragment)
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= FacetedForgeShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["crystal": 8, "glow": 6])
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
        #expect(Self.wordCount("for", in: FacetedForgeShaders.crystalVertex) == 0)
        #expect(Self.wordCount("for", in: FacetedForgeShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: FacetedForgeShaders.glowFragment) == 0)
        let fragment: String = FacetedForgeShaders.crystalFragment
        #expect(Self.wordCount("for", in: fragment) == 1)
        #expect(fragment.contains("for (int i = 0; i < FF_MAX_LAYERS; i++) {"))
        #expect(Self.scalarConstant("int", "FF_MAX_LAYERS", in: fragment) == 3)
        #expect(FacetedForgeShaders.maxDispersionLayers == 3)
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
        let crystalOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_position": "vec3", "v_material": "float", "v_shade": "float",
            "v_alpha": "float",
        ]
        #expect(Self.interface("out", in: FacetedForgeShaders.crystalVertex) == crystalOuts)
        #expect(Self.interface("out", in: FacetedForgeShaders.glowVertex) == ["v_colour": "vec3", "v_glow": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in FacetedForgeShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(FacetedForgeShaders.crystalVertex) == expected)
        #expect(Self.layouts(FacetedForgeShaders.glowVertex) == expected)
        #expect(Self.layouts(FacetedForgeShaders.crystalFragment).isEmpty)
        #expect(Self.layouts(FacetedForgeShaders.glowFragment).isEmpty)
        for source in [FacetedForgeShaders.crystalVertex, FacetedForgeShaders.glowVertex] {
            for attribute in FacetedForgeShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // Mesh streams: crystal uv = (material code, shade); glow colour in the normal slot, uv = (glow, 0).
        let vertex: String = FacetedForgeShaders.crystalVertex
        #expect(vertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 8.0);"))
        #expect(vertex.contains("float shade = clamp(a_uv.y, 0.0, 1.0);"))
        #expect(vertex.contains("v_base = base * mix(shade, 1.0, isPreview);"))
        #expect(FacetedForgeShaders.glowVertex.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(FacetedForgeShaders.glowVertex.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsParseBackToTheCPUPalette() throws {
        let tolerance: Double = 1.0 / 255.0
        let crystalV: String = FacetedForgeShaders.crystalVertex
        let crystalF: String = FacetedForgeShaders.crystalFragment
        let glowF: String = FacetedForgeShaders.glowFragment
        let pairs: [(name: String, colour: SIMD3<Double>, source: String)] = [
            (name: "FF_GROUND", colour: FacetedForgePalette.ground, source: crystalV),
            (name: "FF_ICE", colour: FacetedForgePalette.ice, source: crystalV),
            (name: "FF_AMBER", colour: FacetedForgePalette.amber, source: crystalV),
            (name: "FF_HIGHLIGHT", colour: FacetedForgePalette.highlight, source: crystalV),
            (name: "FF_RUBY", colour: FacetedForgePalette.ruby, source: crystalV),
            (name: "FF_SLIVER", colour: FacetedForgePalette.sliver, source: crystalV),
            (name: "FF_SPENT", colour: FacetedForgePalette.spent, source: crystalV),
            (name: "FF_UNSPENT", colour: FacetedForgePalette.unspent, source: crystalV),
            (name: "FF_LATTICE", colour: FacetedForgePalette.lattice, source: crystalV),
            (name: "FF_HIGHLIGHT", colour: FacetedForgePalette.highlight, source: crystalF),
            (name: "FF_RUBY", colour: FacetedForgePalette.ruby, source: crystalF),
            (name: "FF_AMBER", colour: FacetedForgePalette.amber, source: crystalF),
            (name: "FF_LATTICE", colour: FacetedForgePalette.lattice, source: crystalF),
            (name: "FF_LATTICE", colour: FacetedForgePalette.lattice, source: glowF),
        ]
        for pair in pairs {
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(pair.name, in: pair.source), "\(pair.name)")
            #expect(Self.distance(parsed, pair.colour) <= tolerance, "\(pair.name)")
        }
        // The hex values of the design: #07090F ground, #BFE6F5 ice; six fixed decimals.
        #expect(Self.distance(FacetedForgePalette.ground, SIMD3<Double>(7, 9, 15) / 255) < 1e-12)
        #expect(Self.distance(FacetedForgePalette.ice, SIMD3<Double>(191, 230, 245) / 255) < 1e-12)
        #expect(crystalV.contains("const vec3 FF_GROUND = vec3(0.027451, 0.035294, 0.058824);"))
        let swiftConstants: [(SIMD3<Double>, SIMD3<Double>)] = [
            (FacetedForgeShaders.ground, FacetedForgePalette.ground),
            (FacetedForgeShaders.ice, FacetedForgePalette.ice),
            (FacetedForgeShaders.highlight, FacetedForgePalette.highlight),
            (FacetedForgeShaders.ruby, FacetedForgePalette.ruby),
            (FacetedForgeShaders.amber, FacetedForgePalette.amber),
            (FacetedForgeShaders.lattice, FacetedForgePalette.lattice),
            (FacetedForgeShaders.sliver, FacetedForgePalette.sliver),
            (FacetedForgeShaders.spent, FacetedForgePalette.spent),
            (FacetedForgeShaders.unspent, FacetedForgePalette.unspent),
        ]
        for pair in swiftConstants { #expect(pair.0 == pair.1) }
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "FF_GLASS_ALPHA", value: FacetedForgeShaders.glassAlpha, source: crystalV),
            (name: "FF_PREVIEW_ALPHA", value: FacetedForgeShaders.previewAlpha, source: crystalV),
            (name: "FF_AMBIENT", value: FacetedForgeShaders.ambient, source: crystalF),
            (name: "FF_DIFFUSE", value: FacetedForgeShaders.diffuse, source: crystalF),
            (name: "FF_FRESNEL_POWER", value: FacetedForgeShaders.fresnelPower, source: crystalF),
            (name: "FF_FRESNEL_WEIGHT", value: FacetedForgeShaders.fresnelWeight, source: crystalF),
            (name: "FF_FRESNEL_ALPHA", value: FacetedForgeShaders.fresnelAlpha, source: crystalF),
            (name: "FF_DISPERSION_WEIGHT", value: FacetedForgeShaders.dispersionWeight, source: crystalF),
            (name: "FF_DISPERSION_FREQUENCY", value: FacetedForgeShaders.dispersionFrequency, source: crystalF),
            (name: "FF_DISPERSION_SPEED", value: FacetedForgeShaders.dispersionSpeed, source: crystalF),
            (name: "FF_CUT_EMISSION", value: FacetedForgeShaders.cutEmission, source: crystalF),
            (name: "FF_LATTICE_FREQUENCY", value: FacetedForgeShaders.latticeFrequency, source: crystalF),
            (name: "FF_LATTICE_WIDTH", value: FacetedForgeShaders.latticeWidth, source: crystalF),
            (name: "FF_LATTICE_STRENGTH", value: FacetedForgeShaders.latticeStrength, source: crystalF),
            (name: "FF_RIM_WIDTH", value: FacetedForgeShaders.previewRimWidth, source: crystalF),
            (name: "FF_DASH_FREQUENCY", value: FacetedForgeShaders.dashFrequency, source: crystalF),
            (name: "FF_GLOW", value: FacetedForgeShaders.glowWeight, source: glowF),
            (name: "FF_CORE", value: FacetedForgeShaders.coreLift, source: glowF),
            (name: "FF_MAX_GAIN", value: FacetedForgeShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(FacetedForgeShaders.ambient + FacetedForgeShaders.diffuse == 1.0)
    }

    @Test func materialCodesSelectThePaletteAndOnlyGlassAndPreviewAreTranslucent() {
        var codes: [Double] = []
        for material in FacetedForgeShaders.CrystalMaterial.allCases {
            codes.append(material.code)
            #expect(Double(material.rawValue) == material.code)
            if material != .ground { #expect(material.colour != FacetedForgePalette.ground) }
            var alpha: Double = 1
            if material == .glass { alpha = 0.45 }
            if material == .preview { alpha = 0.6 }
            #expect(material.alpha == alpha, "\(material)")
        }
        #expect(codes == [0, 1, 2, 3, 4, 5, 6, 7, 8])
        let named: [Double] = [
            FacetedForgeShaders.groundMaterial, FacetedForgeShaders.glassMaterial,
            FacetedForgeShaders.cutFaceMaterial, FacetedForgeShaders.bevelMaterial,
            FacetedForgeShaders.previewMaterial, FacetedForgeShaders.sliverCrossMaterial,
            FacetedForgeShaders.spentBarMaterial, FacetedForgeShaders.unspentBarMaterial,
            FacetedForgeShaders.latticeMaterial,
        ]
        #expect(named == codes)
        #expect(FacetedForgeShaders.CrystalMaterial.glass.colour == FacetedForgePalette.ice)
        #expect(FacetedForgeShaders.CrystalMaterial.cutFace.colour == FacetedForgePalette.amber)
        #expect(FacetedForgeShaders.CrystalMaterial.preview.colour == FacetedForgePalette.ruby)
        #expect(FacetedForgeShaders.CrystalMaterial.sliverCross.colour == FacetedForgePalette.sliver)
        #expect(FacetedForgeShaders.CrystalMaterial.spentBar.colour == FacetedForgePalette.spent)
        #expect(FacetedForgeShaders.CrystalMaterial.unspentBar.colour == FacetedForgePalette.unspent)
        #expect(FacetedForgeShaders.CrystalMaterial.lattice.colour == FacetedForgePalette.lattice)
        let vertex: String = FacetedForgeShaders.crystalVertex
        #expect(vertex.contains("v_alpha = mix(mix(1.0, FF_GLASS_ALPHA, isGlass), FF_PREVIEW_ALPHA, isPreview);"))
        #expect(vertex.contains("base = mix(base, FF_LATTICE, isCode(m, 8.0));"))
        let lit: SIMD3<Double> = FacetedForgeShaders.crystalShade(base: FacetedForgePalette.unspent, normalDotLight: 1)
        #expect(Self.distance(lit, FacetedForgePalette.unspent) < 1e-12)
        let dark: SIMD3<Double> = FacetedForgeShaders.crystalShade(base: FacetedForgePalette.ice, normalDotLight: -1)
        #expect(Self.distance(dark, FacetedForgePalette.ice * FacetedForgeShaders.ambient) < 1e-12)
        // The cut faces stay warm (red minus blue at least 0.15, the frame check) across the amber-to-ruby range.
        #expect(FacetedForgePalette.amber.x - FacetedForgePalette.amber.z >= 0.15)
        #expect(FacetedForgePalette.ruby.x - FacetedForgePalette.ruby.z >= 0.15)
        #expect(FacetedForgePalette.lattice.x - FacetedForgePalette.lattice.z >= 0.15)
    }

    @Test func glassFresnelAndDispersionMoveWithUTimeAloneAndFollowTheTier() {
        let fragment: String = FacetedForgeShaders.crystalFragment
        #expect(fragment.contains("float layers = clamp(u_layers, 0.0, float(FF_MAX_LAYERS));"))
        #expect(fragment.contains("float on = 1.0 - step(layers, float(i));"))
        #expect(fragment.contains("float fresnel = pow(1.0 - facing, FF_FRESNEL_POWER);"))
        #expect(fragment.contains("vec3 glass = lit + FF_HIGHLIGHT * (FF_FRESNEL_WEIGHT * fresnel) + shimmer;"))
        for source in Self.sources() {
            for identifier in Self.identifiers(source) where identifier.lowercased().contains("time")
                || identifier.lowercased().contains("frame") || identifier.lowercased().contains("clock") {
                #expect(identifier == "u_time", "other time source \(identifier)")
            }
        }
        #expect(Self.wordCount("u_time", in: FacetedForgeShaders.crystalVertex + FacetedForgeShaders.glowVertex
                               + FacetedForgeShaders.glowFragment) == 0)
        var expectedLayers: [Double] = []
        for tier in FacetedForgeTier.all { expectedLayers.append(FacetedForgeShaders.dispersionLayers(for: tier)) }
        #expect(expectedLayers == [3, 2, 1])
        // Fresnel: 0 facing the eye, 1 at grazing, rising in between.
        #expect(FacetedForgeShaders.fresnel(normalDotView: 1) == 0)
        #expect(FacetedForgeShaders.fresnel(normalDotView: -1) == 0)
        #expect(FacetedForgeShaders.fresnel(normalDotView: 0) == 1)
        #expect(FacetedForgeShaders.fresnel(normalDotView: 0.3) > FacetedForgeShaders.fresnel(normalDotView: 0.7))
        // Bands stay in 0 ... 1, stand still at time 0 (Reduce Motion) and move with time.
        let p: SIMD3<Double> = SIMD3<Double>(0.2, -0.1, 0.35)
        var layer: Int = 0
        while layer < FacetedForgeShaders.maxDispersionLayers {
            let still: Double = FacetedForgeShaders.dispersionBand(layer: layer, time: 0, position: p)
            let again: Double = FacetedForgeShaders.dispersionBand(layer: layer, time: 0, position: p)
            let later: Double = FacetedForgeShaders.dispersionBand(layer: layer, time: 1.5, position: p)
            #expect(still == again)
            #expect(abs(still - later) > 1e-3)
            #expect(later >= 0 && later <= 1 && still >= 0 && still <= 1)
            layer += 1
        }
    }

    @Test func cutFacesCarryALatticeAndThePreviewRimIsDashed() {
        let fragment: String = FacetedForgeShaders.crystalFragment
        #expect(fragment.contains("vec3 cut = mix(interior, FF_LATTICE, FF_LATTICE_STRENGTH * grid);"))
        let interior: String = "vec3 interior = mix(FF_AMBER, FF_RUBY, heat) * glowLight * clamp(v_shade, 0.0, 1.0);"
        #expect(fragment.contains(interior))
        #expect(fragment.contains("float rim = 1.0 - step(FF_RIM_WIDTH, v_shade);"))
        #expect(fragment.contains("vec3 preview = mix(lit, FF_HIGHLIGHT, rimOn);"))
        // Grid lines: 1 on an integer, 0 halfway between.
        #expect(FacetedForgeShaders.gridLine(0) == 1)
        #expect(FacetedForgeShaders.gridLine(3) == 1)
        #expect(FacetedForgeShaders.gridLine(0.5) == 0)
        #expect(FacetedForgeShaders.gridLine(-2.5) == 0)
        // Across a cut face (normal +z) the lattice is both present and absent: a pattern, not a flat colour.
        let normal: SIMD3<Double> = SIMD3<Double>(0, 0, 1)
        var on: Int = 0
        var off: Int = 0
        var step: Int = 0
        while step < 200 {
            let x: Double = -0.5 + Double(step) / 200
            let value: Double = FacetedForgeShaders.lattice(position: SIMD3<Double>(x, 0.0625, 0.3), normal: normal)
            #expect(value >= 0 && value <= 1)
            if value > 0.9 { on += 1 }
            if value < 0.1 { off += 1 }
            step += 1
        }
        #expect(on > 0)
        #expect(off > 0)
        // Along any rim edge the 3D checker alternates dash and gap.
        let directions: [SIMD3<Double>] = [
            SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0), SIMD3<Double>(0, 0, 1), SIMD3<Double>(0.6, 0.8, 0),
            SIMD3<Double>(0.577, -0.577, 0.577),
        ]
        for direction in directions {
            var dashes: Int = 0
            var gaps: Int = 0
            var i: Int = 0
            while i < 100 {
                let point: SIMD3<Double> = SIMD3<Double>(0.013, 0.021, 0.034) + direction * (Double(i) / 100)
                let dash: Double = FacetedForgeShaders.previewDash(position: point)
                #expect(dash == 0 || dash == 1)
                if dash == 1 { dashes += 1 } else { gaps += 1 }
                i += 1
            }
            #expect(dashes > 10 && gaps > 10, "\(direction)")
        }
    }

    @Test func glowGainPerTierAndReduceFlashingLimit() {
        let reducedFlashingLimit: Double = 0.5   // Hue Compass's reducedFlashingGainLimit.
        #expect(FacetedForgeShaders.maxGlowGain == 1.5)
        #expect(FacetedForgeShaders.glowGainCap <= reducedFlashingLimit)
        #expect(FacetedForgeShaders.glowLimit(reduceFlashing: true)
                < FacetedForgeShaders.glowLimit(reduceFlashing: false))
        #expect(FacetedForgeShaders.glowLimit(reduceFlashing: true) == FacetedForgeShaders.glowGainCap)
        #expect(FacetedForgeShaders.glowLimit(reduceFlashing: false) == FacetedForgeShaders.standardGlowLimit)
        #expect(FacetedForgeShaders.standardGlowLimit <= FacetedForgeShaders.maxGlowGain)
        #expect(FacetedForgeShaders.glowFragment.contains(
            "float gain = min(clamp(u_glow, 0.0, FF_MAX_GAIN), clamp(u_glowLimit, 0.0, FF_MAX_GAIN));"))
        #expect(FacetedForgeShaders.glowGain(for: FacetedForgeTier.of(0)) == 1)
        #expect(FacetedForgeShaders.glowGain(for: FacetedForgeTier.of(1)) == 1)
        #expect(FacetedForgeShaders.glowGain(for: FacetedForgeTier.of(2)) == 0)
        #expect(FacetedForgeShaders.glowGain(gain: 9, limit: 9) == 1.5)
        #expect(FacetedForgeShaders.glowGain(gain: -1, limit: 1) == 0)
        #expect(FacetedForgeShaders.glowGain(gain: Double.nan, limit: 1) == 0)
        var step: Int = 0
        while step <= 40 {
            let x: Double = Double(step) / 10 - 1
            let capped: Double = FacetedForgeShaders.glowGain(
                gain: x, limit: FacetedForgeShaders.glowLimit(reduceFlashing: true))
            #expect(capped >= 0 && capped <= FacetedForgeShaders.glowGainCap)
            let glow: SIMD4<Double> = FacetedForgeShaders.glowColour(colour: FacetedForgePalette.amber, glow: 1,
                                                                     gain: capped)
            #expect(glow.x >= 0 && glow.x <= 1 && glow.y >= 0 && glow.y <= 1 && glow.z >= 0 && glow.z <= 1)
            #expect(glow.w <= FacetedForgeShaders.glowWeight * FacetedForgeShaders.glowGainCap + 1e-12)
            step += 1
        }
        let plain: SIMD4<Double> = FacetedForgeShaders.glowColour(colour: FacetedForgePalette.amber, glow: 0,
                                                                  gain: 1.5)
        #expect(Self.distance(SIMD3<Double>(plain.x, plain.y, plain.z), FacetedForgePalette.amber) < 1e-12)
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
