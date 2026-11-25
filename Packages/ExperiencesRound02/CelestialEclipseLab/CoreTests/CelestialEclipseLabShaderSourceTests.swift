// CelestialEclipseLabShaderSourceTests — feature 463 (R02-G17-03) T-R02G1703-003 (FR-R02G1703-001, 002, 004;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and used in its stage, at most 16 vec4
// uniform slots per program, no texture sampler, no `discard`, no loop, vertex outputs matching fragment inputs,
// balanced braces, ASCII-only sources, the attribute names and locations (the `ShaderMeshRenderer` streams), the
// material codes distinct, ordered 0 … 16 and each selected by the vertex shader with its palette colour, the GLSL
// palette constants parsing back to `CelestialEclipseLabPalette` within 1e-6, the layered body shading, the shadow lens
// (dark inside, an ember rim, alpha bounds), the signed-distance references (edge, chosen-ring dashes, diamonds,
// crosses), the backdrop gradient and its sparse specks (under 5 % of sampled pixels), the halo pulse rule (1 with
// Reduce Motion, 0.85 … 1 otherwise, finite, 1 for a non-finite time), the won flare of matched halos, the glow gain
// per tier (0 at level-2) and the Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end
// compile of each source (skipped otherwise). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabShaderSourceTests {
    typealias Shaders = CelestialEclipseLabShaders
    typealias Palette = CelestialEclipseLabPalette

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "sky", vertex: Shaders.skyVertex, fragment: Shaders.skyFragment, uniforms: Shaders.skyUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.skyVertex, Shaders.skyFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// (type, name, array length) of the declarations in `source` starting with `keyword` and a space.
    static func declarations(_ keyword: String, in source: String) -> [(type: String, name: String, count: Int)] {
        var result: [(type: String, name: String, count: Int)] = []
        for line in lines(source) where line.hasPrefix("\(keyword) ") {
            let parts: [String] = tokens(line)
            guard parts.count >= 3 else { continue }
            var name: String = parts[parts.count - 1]
            var count: Int = 1
            if let open = name.firstIndex(of: "["), name.hasSuffix("]") {
                let inner: String = String(name[name.index(after: open)..<name.index(before: name.endIndex)])
                count = Int(inner) ?? 0
                name = String(name[name.startIndex..<open])
            }
            result.append((type: parts[parts.count - 2], name: name, count: count))
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

    /// (name, type) of the stage interface declarations starting with `keyword` (`in` or `out`).
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

    /// The vec4 slots one uniform of GLSL `type` occupies (mat4: 4, mat3: 3, mat2: 2, anything scalar or vector: 1).
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

    /// Relative luminance (Rec. 709 weights).
    static func luminance(_ c: SIMD3<Double>) -> Double {
        (c * SIMD3<Double>(0.2126, 0.7152, 0.0722)).sum()
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(Shaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func everyUniformTheSceneSetsIsDeclaredAndUsed() {
        for program in Self.programs() {
            let vertexDeclared: [String] = Self.declared("uniform", in: program.vertex)
            let fragmentDeclared: [String] = Self.declared("uniform", in: program.fragment)
            #expect(Set(vertexDeclared).count == vertexDeclared.count, "\(program.name) vertex repeats a uniform")
            #expect(Set(fragmentDeclared).count == fragmentDeclared.count, "\(program.name) fragment repeats")
            #expect(Set(vertexDeclared).isDisjoint(with: Set(fragmentDeclared)), "\(program.name) declares twice")
            #expect(Self.unique(vertexDeclared + fragmentDeclared) == program.uniforms,
                    "\(program.name) declares in a different order or set")
            #expect(Shaders.uniformNames[program.name] == program.uniforms)
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(Shaders.uniformNames.count == 2)
        let constants: [String] = [Shaders.mvpUniform, Shaders.wonUniform, Shaders.pulseUniform,
                                   Shaders.glowGainUniform, Shaders.glowLimitUniform]
        #expect(constants == ["u_mvp", "u_won", "u_pulse", "u_glowGain", "u_glowLimit"])
        #expect(Set(constants) == Set(Shaders.skyUniforms + Shaders.glowUniforms))
        #expect(Shaders.skyUniforms == ["u_mvp", "u_won", "u_pulse"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won", "u_pulse"])
        #expect(Self.declared("uniform", in: Shaders.skyVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.skyFragment) == ["u_pulse"])
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won", "u_pulse"])
        // No time input: the only motion is the halo pulse the presenter passes (1 with Reduce Motion).
        for source in Self.sources() { #expect(Self.wordCount("u_time", in: source) == 0) }
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(Shaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: "\(program.vertex)\n\(program.fragment)")
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                #expect(declaration.count >= 1, "\(declaration.name) has no length")
                slots += Self.vec4Slots(declaration.type) * declaration.count
            }
            #expect(slots <= Shaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["sky": 6, "glow": 8])
    }

    @Test func noTextureSamplerNoDiscardAndNoLoops() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture"))
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("discard", in: source) == 0)
            #expect(Self.wordCount("break", in: source) == 0)
            // GLSL ES 3.00 reserved words never used as names.
            let reserved: [String] = ["flat", "smooth", "centroid", "sample", "input", "output", "filter"]
            for word in reserved { #expect(Self.wordCount(word, in: source) == 0, "\(word)") }
        }
    }

    @Test func bracesBalancedAndInterfacesMatch() {
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
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
        for program in Self.programs() {
            let outs: [String: String] = Self.interface("out", in: program.vertex)
            let ins: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outs == ins, "\(program.name)")
            #expect(Self.interface("out", in: program.fragment) == ["color": "vec4"], "\(program.name)")
            #expect(program.fragment.contains("color = vec4(rgb * alpha, alpha);"), "\(program.name) premultiplied")
        }
        let skyOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_material": "float", "v_local": "float", "v_won": "float",
        ]
        #expect(Self.interface("out", in: Shaders.skyVertex) == skyOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        var skyListed: [String] = []
        for attribute in Shaders.skyAttributes { skyListed.append("\(attribute.location) \(attribute.name)") }
        #expect(skyListed == listed)
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.skyVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.skyFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.skyVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        // No crescent-mask attributes: the shadow lens is geometry.
        for source in Self.sources() { #expect(!source.contains("a_mask"), "mask attribute left") }
        let sky: String = Shaders.skyVertex
        let skyLines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, CE_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "v_aux = a_normal;",
            "v_won = clamp(u_won, 0.0, 1.0);",
        ]
        for line in skyLines { #expect(sky.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 3.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "CE_INK", colour: Palette.ink), (name: "CE_INK_TOP", colour: Palette.inkTop),
            (name: "CE_SPECK", colour: Palette.speck), (name: "CE_DISC", colour: Palette.disc),
            (name: "CE_DISC_SHADE", colour: Palette.discShade), (name: "CE_ORBIT", colour: Palette.orbit),
            (name: "CE_FIXED_FRAME", colour: Palette.fixedFrame), (name: "CE_CHOSEN", colour: Palette.chosen),
            (name: "CE_CORONA", colour: Palette.corona), (name: "CE_CORONA_GLOW", colour: Palette.coronaGlow),
            (name: "CE_SHADOW", colour: Palette.crescentShadow), (name: "CE_EMBER", colour: Palette.ember),
            (name: "CE_WINDOW", colour: Palette.window), (name: "CE_MATCHED", colour: Palette.matched),
            (name: "CE_UNWANTED", colour: Palette.unwanted), (name: "CE_FAINT_EVENT", colour: Palette.faintEvent),
            (name: "CE_PLAYHEAD", colour: Palette.playhead), (name: "CE_ACTIONS_LIT", colour: Palette.actionsLit),
            (name: "CE_ACTIONS_UNLIT", colour: Palette.actionsUnlit), (name: "CE_BROKEN", colour: Palette.broken),
            (name: "CE_GLOW", colour: Palette.glow),
        ]
        #expect(Shaders.paletteConstants.count == palette.count)
        var tableNames: Set<String> = []
        for (index, entry) in Shaders.paletteConstants.enumerated() {
            tableNames.insert(entry.name)
            #expect(entry.name == palette[index].name)
            #expect(entry.colour == palette[index].colour, "\(entry.name)")
            var found: Int = 0
            for source in Self.sources() {
                guard let parsed = Self.vec3Constant(entry.name, in: source) else { continue }
                found += 1
                #expect(Self.distance(parsed, entry.colour) <= tolerance, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
        }
        #expect(tableNames.count == palette.count)
        // Every vec3 constant in every source is a palette colour with the table's value, or the view direction.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "CE_VIEW_DIR" {
                    #expect(Self.distance(parsed, Shaders.viewDirection) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals.
        let vertex: String = Shaders.skyVertex
        #expect(vertex.contains("const vec3 CE_INK = vec3(0.043137, 0.082353, 0.188235);"))
        #expect(vertex.contains("const vec3 CE_CORONA = vec3(0.949020, 0.756863, 0.305882);"))
        let fragment: String = Shaders.skyFragment
        #expect(fragment.contains("const vec3 CE_INK_TOP = vec3(0.086275, 0.133333, 0.290196);"))
        #expect(fragment.contains("const vec3 CE_SHADOW = vec3(0.019608, 0.039216, 0.094118);"))
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "CE_MAX_MATERIAL", value: 16, source: vertex),
            (name: "CE_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "CE_CELLS_ACROSS", value: Shaders.cellsAcross, source: fragment),
            (name: "CE_CELLS_UP", value: Shaders.cellsUp, source: fragment),
            (name: "CE_SPECK_DENSITY", value: Shaders.speckDensity, source: fragment),
            (name: "CE_SPECK_RADIUS", value: Shaders.speckRadius, source: fragment),
            (name: "CE_LIMB_EDGE", value: Shaders.limbEdge, source: fragment),
            (name: "CE_CORE_LIFT", value: Shaders.coreLift, source: fragment),
            (name: "CE_RIM_LIFT", value: Shaders.rimLift, source: fragment),
            (name: "CE_SHADOW_ALPHA", value: Shaders.shadowAlpha, source: fragment),
            (name: "CE_SHADOW_RIM_START", value: Shaders.shadowRimStart, source: fragment),
            (name: "CE_EMBER_RIM", value: Shaders.emberRim, source: fragment),
            (name: "CE_SHADOW_EDGE", value: Shaders.shadowEdge, source: fragment),
            (name: "CE_CHOSEN_DASHES", value: Shaders.chosenDashes, source: fragment),
            (name: "CE_HALO_CORE", value: Shaders.haloCore, source: fragment),
            (name: "CE_FLARE_LIFT", value: Shaders.flareLift, source: fragment),
            (name: "CE_CROSS_ARM", value: Shaders.crossArm, source: fragment),
            (name: "CE_INV_SQRT2", value: 1 / 2.0.squareRoot(), source: fragment),
            (name: "CE_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "CE_HALO_REST", value: Shaders.haloRest, source: glowF),
            (name: "CE_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let value: Double? = Self.scalarConstant("float", entry.name, in: entry.source)
            let parsed: Double = try #require(value, "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
    }

    @Test func materialCodesAreDistinctOrderedAndSelected() {
        let named: [(name: String, code: Float)] = [
            (name: "materialBackdrop", code: Shaders.materialBackdrop),
            (name: "materialRing", code: Shaders.materialRing),
            (name: "materialNotch", code: Shaders.materialNotch), (name: "materialFrame", code: Shaders.materialFrame),
            (name: "materialBody", code: Shaders.materialBody), (name: "materialHalo", code: Shaders.materialHalo),
            (name: "materialChosen", code: Shaders.materialChosen),
            (name: "materialStrip", code: Shaders.materialStrip),
            (name: "materialBracket", code: Shaders.materialBracket),
            (name: "materialDiamond", code: Shaders.materialDiamond),
            (name: "materialCross", code: Shaders.materialCross), (name: "materialFaint", code: Shaders.materialFaint),
            (name: "materialPlayhead", code: Shaders.materialPlayhead),
            (name: "materialBar", code: Shaders.materialBar),
            (name: "materialBarUnlit", code: Shaders.materialBarUnlit),
            (name: "materialBroken", code: Shaders.materialBroken),
            (name: "materialShadow", code: Shaders.materialShadow),
        ]
        #expect(Shaders.materials.count == named.count)
        var codes: Set<Float> = []
        for (index, entry) in named.enumerated() {
            codes.insert(entry.code)
            #expect(entry.code == Float(index), "\(entry.name)")
            #expect(Shaders.materials[index].name == entry.name)
            #expect(Shaders.materials[index].code == entry.code)
        }
        #expect(codes.count == named.count)
        let vertex: String = Shaders.skyVertex
        #expect(vertex.contains("vec3 base = CE_INK;"))
        #expect(Shaders.materials[0].constant == "CE_INK")
        for entry in Shaders.materials where entry.code != Shaders.materialBackdrop {
            let line: String = "base = mix(base, \(entry.constant), isCode(m, \(Int(entry.code)).0));"
            #expect(vertex.contains(line), "\(entry.name): \(line)")
            var known: Bool = false
            for constant in Shaders.paletteConstants where constant.name == entry.constant { known = true }
            #expect(known, "\(entry.name) selects \(entry.constant)")
        }
        let fragment: String = Shaders.skyFragment
        let lines: [String] = [
            "float sky = isCode(m, 0.0);",
            "coverage = mix(coverage, 1.0, sky);",
            "rgb = mix(rgb, disc, isCode(m, 4.0));",
            "rgb = mix(rgb, halo, isCode(m, 5.0));",
            "float isDiamond = isCode(m, 9.0) + isCode(m, 11.0);",
            "coverage = mix(coverage, diamond, isDiamond);",
            "coverage = mix(coverage, crossMark, isCode(m, 10.0));",
            "coverage = coverage * mix(1.0, chosenDash, isCode(m, 6.0));",
            "float isShadow = isCode(m, 16.0);",
            "rgb = mix(rgb, lens, isShadow);",
            "coverage = mix(coverage, lensCover, isShadow);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
        // The lit bar reads corona gold: red above blue by far more than the frame check's 0.08.
        #expect(Palette.actionsLit.x - Palette.actionsLit.z >= 0.08)
    }

    @Test func bodiesAreShadedInLayersFromTheNormal() {
        let ink: Double = Self.luminance(Palette.ink)
        let core: SIMD3<Double> = Shaders.bodyShade(mu: 1)
        let mid: SIMD3<Double> = Shaders.bodyShade(mu: 0.6)
        let limb: SIMD3<Double> = Shaders.bodyShade(mu: 0.25)
        let rim: SIMD3<Double> = Shaders.bodyShade(mu: 0)
        let expectedCore: SIMD3<Double> = Palette.disc + (SIMD3<Double>(1, 1, 1) - Palette.disc) * Shaders.coreLift
        #expect(Self.distance(core, expectedCore) < 1e-12)
        #expect(Self.luminance(core) > Self.luminance(mid))
        #expect(Self.luminance(mid) > Self.luminance(limb))
        // The rim light lifts the very limb toward the corona glow.
        let shadeRim: SIMD3<Double> = Palette.discShade + (Palette.coronaGlow - Palette.discShade) * Shaders.rimLift
        #expect(Self.distance(rim, shadeRim) < 1e-12)
        // Every layer is far brighter than the backdrop (the frame check's body margin is 0.25).
        for step in 0...20 {
            let mu: Double = Double(step) / 20
            #expect(Self.luminance(Shaders.bodyShade(mu: mu)) - ink >= 0.25, "mu \(mu)")
        }
        #expect(Self.distance(Shaders.bodyShade(normal: Shaders.viewDirection), core) < 1e-9)
        #expect(Shaders.bodyShade(normal: SIMD3<Double>(0, 0, 0)) == core)
        #expect(Shaders.bodyShade(normal: SIMD3<Double>(Double.nan, 0, 1)) == core)
        #expect(Shaders.bodyShade(normal: -Shaders.viewDirection) == rim)
        #expect(Shaders.bodyShade(mu: Double.nan) == core)
        #expect(abs((Shaders.viewDirection * Shaders.viewDirection).sum() - 1) < 1e-12)
        let fragment: String = Shaders.skyFragment
        let lines: [String] = [
            "vec3 disc = mix(CE_DISC_SHADE, CE_DISC, smoothstep(0.0, CE_LIMB_EDGE, mu));",
            "disc = mix(disc, vec3(1.0), CE_CORE_LIFT * smoothstep(CE_CORE_START, 1.0, mu));",
            "disc = mix(disc, CE_CORONA_GLOW, CE_RIM_LIFT * pow(1.0 - mu, CE_RIM_POWER));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func shadowLensIsDarkWithAnEmberRim() {
        let centre: SIMD4<Double> = Shaders.shadowColour(radial: 0)
        let centreRGB: SIMD3<Double> = SIMD3<Double>(centre.x, centre.y, centre.z)
        // Inside: exactly the crescent shadow at the lens alpha.
        #expect(Self.distance(centreRGB, Palette.crescentShadow) < 1e-12)
        #expect(centre.w == Shaders.shadowAlpha)
        #expect(Shaders.shadowAlpha >= 0.85 && Shaders.shadowAlpha <= 1)
        let inner: SIMD4<Double> = Shaders.shadowColour(radial: Shaders.shadowRimStart - 0.01)
        #expect(inner == centre)
        // Far darker than a lit body: the crescent reads at once.
        #expect(Self.luminance(Shaders.bodyShade(mu: 0)) - Self.luminance(centreRGB) >= 0.4)
        // Toward the outline the rim leans toward ember (red above blue), full at the outline.
        let rim: SIMD4<Double> = Shaders.shadowColour(radial: 0.99)
        let outline: SIMD4<Double> = Shaders.shadowColour(radial: 1)
        let outlineRGB: SIMD3<Double> = SIMD3<Double>(outline.x, outline.y, outline.z)
        let shadow: SIMD3<Double> = Palette.crescentShadow
        let expected: SIMD3<Double> = shadow + (Palette.ember - shadow) * Shaders.emberRim
        #expect(Self.distance(outlineRGB, expected) < 1e-12)
        #expect(rim.x - rim.z > centre.x - centre.z)
        #expect(outline.x - outline.z > 0)
        // Alpha stays within 0 … shadowAlpha, falling to 0 at the outline; the sign of the radial does not matter.
        for step in 0...40 {
            let radial: Double = Double(step) / 40
            let c: SIMD4<Double> = Shaders.shadowColour(radial: radial)
            #expect(c.w >= 0 && c.w <= Shaders.shadowAlpha, "\(radial)")
            #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1, "\(radial)")
            #expect(Shaders.shadowColour(radial: -radial) == c, "\(radial)")
        }
        #expect(outline.w == 0)
        #expect(Shaders.shadowColour(radial: Double.nan) == outline)
        #expect(Shaders.shadowColour(radial: 5) == outline)
        let fragment: String = Shaders.skyFragment
        let lines: [String] = [
            "float rim = smoothstep(CE_SHADOW_RIM_START, 1.0, d);",
            "vec3 lens = mix(CE_SHADOW, CE_EMBER, CE_EMBER_RIM * rim);",
            "float lensCover = CE_SHADOW_ALPHA * (1.0 - smoothstep(CE_SHADOW_EDGE, 1.0, d));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
        #expect(Shaders.skyVertex.contains("base = mix(base, CE_SHADOW, isCode(m, 16.0));"))
    }

    @Test func signedDistanceShadingReferences() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        // The chosen ring shows its dashes with their duty.
        var lit: Int = 0
        var runs: Int = 0
        var previous: Double = 0
        for step in 0..<720 {
            let value: Double = Shaders.chosenDashCoverage(angle: (Double(step) + 0.5) / 720)
            lit += Int(value)
            if value == 1 && previous == 0 { runs += 1 }
            previous = value
        }
        #expect(runs == Int(Shaders.chosenDashes))
        #expect(abs(Double(lit) / 720 - Shaders.chosenDuty) < 0.02)
        // Diamonds: the centre and near the corners inside; beyond the sides outside.
        let diamondInside: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(0.45, 0.45), SIMD2(0.9, 0), SIMD2(0, -0.9)]
        for p in diamondInside { #expect(Shaders.diamondDistance(u: p.x, v: p.y) > 0, "\(p)") }
        let diamondOutside: [SIMD2<Double>] = [SIMD2(0.6, 0.6), SIMD2(1.1, 0), SIMD2(-0.8, 0.5)]
        for p in diamondOutside { #expect(Shaders.diamondDistance(u: p.x, v: p.y) < 0, "\(p)") }
        #expect(Shaders.diamondCoverage(u: 0, v: 0) == 1)
        // Crosses: the centre and along the diagonals inside; off the arms and beyond the square outside.
        let crossInside: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(-0.5, 0.5), SIMD2(0.9, -0.9)]
        for p in crossInside { #expect(Shaders.crossDistance(u: p.x, v: p.y) > 0, "\(p)") }
        let crossOutside: [SIMD2<Double>] = [SIMD2(0.5, 0), SIMD2(0, 0.8), SIMD2(1.1, 1.1)]
        for p in crossOutside { #expect(Shaders.crossDistance(u: p.x, v: p.y) < 0, "\(p)") }
        #expect(Shaders.crossCoverage(u: 0, v: 0) == 1)
        #expect(Shaders.diamondDistance(u: Double.nan, v: 0) == -1)
        #expect(Shaders.crossDistance(u: 0, v: Double.infinity) == -1)
        // Both marks fit inside the quad the geometry spans, with room for the feather.
        let e: Double = Shaders.markQuadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges {
                #expect(Shaders.diamondCoverage(u: p.x, v: p.y) == 0, "\(p)")
                #expect(Shaders.crossCoverage(u: p.x, v: p.y) == 0, "\(p)")
            }
        }
        let fragment: String = Shaders.skyFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - CE_EDGE_FEATHER, 1.0, d);",
            "float chosenDash = 1.0 - step(CE_CHOSEN_DUTY, fract(t * CE_CHOSEN_DASHES));",
            "float diamond = smoothstep(-CE_MARK_FEATHER, CE_MARK_FEATHER, diamondDistance(v_aux.xy));",
            "float crossMark = smoothstep(-CE_MARK_FEATHER, CE_MARK_FEATHER, crossDistance(v_aux.xy));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func backdropGradientAndSparseSpecks() {
        let bottom: SIMD3<Double> = Shaders.backdropColour(height: 0, horizontal: 0.123)
        let top: SIMD3<Double> = Shaders.backdropColour(height: 1, horizontal: 0.123)
        if Shaders.speckCoverage(height: 0, horizontal: 0.123) == 0 {
            #expect(Self.distance(bottom, Palette.ink) < 1e-12)
        }
        if Shaders.speckCoverage(height: 1, horizontal: 0.123) == 0 {
            #expect(Self.distance(top, Palette.inkTop) < 1e-12)
        }
        // Under 5 % of the backdrop's pixels carry a speck; some do; elsewhere it is exactly the gradient.
        let columns: Int = 400
        let rows: Int = 240
        var specked: Int = 0
        var gradientDeviation: Double = 0
        for row in 0..<rows {
            let h: Double = (Double(row) + 0.5) / Double(rows)
            for column in 0..<columns {
                let s: Double = -1 + 2 * (Double(column) + 0.5) / Double(columns)
                if Shaders.speckCoverage(height: h, horizontal: s) > 0 {
                    specked += 1
                } else {
                    let c: SIMD3<Double> = Shaders.backdropColour(height: h, horizontal: s)
                    let g: SIMD3<Double> = Palette.ink + (Palette.inkTop - Palette.ink) * h
                    gradientDeviation = max(gradientDeviation, Self.distance(c, g))
                }
            }
        }
        let share: Double = Double(specked) / Double(rows * columns)
        #expect(share < 0.05, "\(share)")
        #expect(share > 0.001, "\(share)")
        #expect(gradientDeviation < 1e-12)
        #expect(Shaders.speckCoverage(height: Double.nan, horizontal: Double.nan) >= 0)
        let fragment: String = Shaders.skyFragment
        let lines: [String] = [
            "float speck = step(1.0 - CE_SPECK_DENSITY, pick);",
            "vec3 gradient = mix(CE_INK, CE_INK_TOP, h);",
            "vec2 cellPos = vec2((s + 1.0) * 0.5 * CE_CELLS_ACROSS, h * CE_CELLS_UP);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func haloPulseRule() {
        let times: [Double] = [0, 0.3, 0.6, 1.2, 1.8, 2.4, 10, 100, 3_600, 86_400, -5]
        for time in times {
            #expect(Shaders.haloPulse(time: time, reduceMotion: true) == 1, "\(time)")
            let value: Double = Shaders.haloPulse(time: time, reduceMotion: false)
            #expect(value >= Shaders.pulseLow && value <= 1, "\(time): \(value)")
        }
        #expect(Shaders.pulseLow == 0.85)
        #expect(Shaders.haloPulse(time: 0, reduceMotion: false) == 1)
        #expect(abs(Shaders.haloPulse(time: Shaders.pulsePeriod / 2, reduceMotion: false) - Shaders.pulseLow) < 1e-12)
        let a: Double = Shaders.haloPulse(time: 0.7, reduceMotion: false)
        let b: Double = Shaders.haloPulse(time: 0.7 + Shaders.pulsePeriod, reduceMotion: false)
        #expect(abs(a - b) < 1e-9)
        // It moves without Reduce Motion: the samples over one period span most of the range.
        var low: Double = 1
        for step in 0..<48 {
            low = min(low, Shaders.haloPulse(time: Shaders.pulsePeriod * Double(step) / 48, reduceMotion: false))
        }
        #expect(low < 0.86)
        let odd: [Double] = [Double.nan, Double.infinity, -Double.infinity]
        for time in odd {
            #expect(Shaders.haloPulse(time: time, reduceMotion: false) == 1, "\(time)")
            #expect(Shaders.haloPulse(time: time, reduceMotion: true) == 1, "\(time)")
        }
        let huge: [Double] = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, 1e300]
        for time in huge {
            let value: Double = Shaders.haloPulse(time: time, reduceMotion: false)
            #expect(value.isFinite && value >= Shaders.pulseLow && value <= 1, "\(time)")
        }
        // The halo's alpha follows the pulse; a matched halo on a won level flares toward full.
        #expect(abs(Shaders.haloAlpha(across: 0, pulse: 0.85, won: 0, matched: false) - 0.85) < 1e-12)
        #expect(Shaders.haloAlpha(across: 0, pulse: 1, won: 0, matched: false) == 1)
        #expect(Shaders.haloAlpha(across: 0, pulse: 0.85, won: 1, matched: false) == 0.85)
        #expect(Shaders.haloAlpha(across: 0, pulse: 0.85, won: 1, matched: true) > 0.85)
        #expect(Shaders.haloAlpha(across: 1, pulse: 1, won: 1, matched: true) == 0)
        let fragment: String = Shaders.skyFragment
        #expect(fragment.contains("float pulse = clamp(u_pulse, 0.0, 1.0);"))
        #expect(fragment.contains("coverage = coverage * mix(1.0, mix(pulse, 1.0, flare), isCode(m, 5.0));"))
    }

    @Test func aWonLevelFlaresTheMatchedHalos() {
        let rest: SIMD3<Double> = Shaders.haloColour(across: 1, won: 0, matched: true)
        #expect(Self.distance(rest, Palette.corona) < 1e-12)
        let centre: SIMD3<Double> = Shaders.haloColour(across: 0, won: 0, matched: false)
        let expectedCentre: SIMD3<Double> = Palette.corona + (Palette.coronaGlow - Palette.corona) * Shaders.haloCore
        #expect(Self.distance(centre, expectedCentre) < 1e-12)
        let flared: SIMD3<Double> = Shaders.haloColour(across: 1, won: 1, matched: true)
        let expectedFlare: SIMD3<Double> = Palette.corona + (Palette.coronaGlow - Palette.corona) * Shaders.flareLift
        #expect(Self.distance(flared, expectedFlare) < 1e-12)
        #expect(Shaders.haloColour(across: 1, won: 1, matched: false) == rest)
        #expect(Shaders.haloColour(across: 1, won: Double.nan, matched: true) == rest)
        // The glow: a matched halo's shell rises from its rest to full with the won light; an unmatched one stays.
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let matchedRest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .matchedHalo, factor: 1, radius: 0,
                                                            gain: 1, won: 0, pulse: 1)
        let matchedWon: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .matchedHalo, factor: 1, radius: 0,
                                                           gain: 1, won: 1, pulse: 1)
        let plainWon: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .halo, factor: 1, radius: 0, gain: 1,
                                                         won: 1, pulse: 1)
        #expect(abs(matchedRest.w - Shaders.glowWeight * Shaders.haloRest) < 1e-12)
        #expect(abs(matchedWon.w - Shaders.glowWeight) < 1e-12)
        #expect(abs(plainWon.w - Shaders.glowWeight * Shaders.haloRest) < 1e-12)
        #expect(SIMD3<Double>(matchedWon.x, matchedWon.y, matchedWon.z) == Palette.coronaGlow)
        // The pulse scales a halo shell but not the chosen ring's or a mark's.
        let pulsed: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .halo, factor: 1, radius: 0, gain: 1,
                                                       won: 0, pulse: 0.85)
        #expect(abs(pulsed.w - Shaders.glowWeight * Shaders.haloRest * 0.85) < 1e-12)
        let chosen: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .chosen, factor: 1, radius: 0, gain: 1,
                                                       won: 0, pulse: 0.85)
        #expect(abs(chosen.w - Shaders.glowWeight) < 1e-12)
        #expect(SIMD3<Double>(chosen.x, chosen.y, chosen.z) == Palette.chosen)
        let mark: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .mark, factor: 1, radius: 0, gain: 1,
                                                     won: 0, pulse: 0.85)
        #expect(SIMD3<Double>(mark.x, mark.y, mark.z) == Palette.glow)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .mark, factor: 1, radius: 1, gain: 1,
                                                      won: 0, pulse: 1)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .halo)
        #expect(Shaders.GlowKind.decode(99).kind == .mark)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("float rest = pulse * mix(CE_HALO_REST, 1.0, won * isMatched);"))
        #expect(glow.contains("float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, rest, isHalo);"))
        let fragment: String = Shaders.skyFragment
        #expect(fragment.contains("float flare = CE_FLARE_LIFT * won * matchedHalo;"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in CelestialEclipseLabTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowGain(for: CelestialEclipseLabTier.of(2)) == 0)
        #expect(Shaders.glowLimit(reduceFlashing: false) == Shaders.standardGlowLimit)
        #expect(Shaders.glowLimit(reduceFlashing: true) == Shaders.glowGainCap)
        #expect(Shaders.glowGainCap == 0.5)
        #expect(Shaders.glowLimit(reduceFlashing: true) < Shaders.glowLimit(reduceFlashing: false))
        for gain in gains {
            #expect(gain <= Shaders.glowLimit(reduceFlashing: false))
            #expect(gain <= Shaders.maxGlowGain)
            let capped: Double = Shaders.glowGain(gain: gain, limit: Shaders.glowLimit(reduceFlashing: true))
            #expect(capped <= Shaders.glowGainCap)
            for kind in Shaders.GlowKind.allCases {
                let glow: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: kind, factor: 1,
                                                             radius: 0, gain: capped, won: 1, pulse: 1)
                #expect(glow.w <= Shaders.glowWeight * Shaders.glowGainCap + 1e-12, "\(kind)")
            }
        }
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        let line: String =
            "float gain = min(clamp(u_glowGain, 0.0, CE_MAX_GAIN), clamp(u_glowLimit, 0.0, CE_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("CelestialEclipseLabShaders.swift")
        let text: String = try String(contentsOf: core, encoding: .utf8)
        let metal: String = "import " + "Metal" + "Kit"
        #expect(!text.contains(metal))
        let denied: [String] = ["Project" + "M", "Preset" + "Library", "Milk" + "Drop"]
        for word in denied { #expect(!text.contains(word), "\(word)") }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            #expect(line.count <= 120, "\(line)")
        }
    }

    /// A real front-end compile with `glslangValidator` when it is installed (macOS only; skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { tool = path }
        guard let validator = tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ce-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "sky.vert", source: Shaders.skyVertex), (name: "sky.frag", source: Shaders.skyFragment),
            (name: "glow.vert", source: Shaders.glowVertex), (name: "glow.frag", source: Shaders.glowFragment),
        ]
        for file in files {
            let url: URL = directory.appendingPathComponent(file.name)
            try file.source.write(to: url, atomically: true, encoding: .utf8)
            let process: Process = Process()
            process.executableURL = URL(fileURLWithPath: validator)
            process.arguments = [url.path]
            let pipe: Pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let output: String = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            #expect(process.terminationStatus == 0, "\(file.name): \(output)")
        }
        #endif
    }
}
