// MicroscopicAuroraShaderSourceTests — feature 483 (R02-G19-03) T-R02G1903-003 (FR-R02G1903-001, 002, 004;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and used in its stage, no time input,
// at most 16 vec4 uniform slots per program, no texture sampler, no `discard`, no loop (so no unbounded one), vertex
// outputs matching fragment inputs, balanced braces, ASCII-only sources, the attribute names and locations (the
// `ShaderMeshRenderer` streams), the material code table (distinct, ordered 0 … 21, each selected by the vertex shader
// with its palette colour and handled exactly once by the fragment shader, decoded back), the ribbon's along
// coordinate carried in uv, the GLSL palette constants parsing back to `MicroscopicAuroraPalette` within 1/255 (and
// 1e-6), the layered capsule shading (flat on level-2), the signed-distance references (edge, ribbon, cell square,
// filled and hollow marks), the ribbons' emissive core fading to the tail and the won brightening, the stencil lit on
// a won level, the still backdrop gradient, the glow per kind, the glow gain per tier (0 at level-2) and the Reduce
// Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of each source (skipped
// otherwise). Test data uses explicit types and plain loops (CI type-check rule).
//
// Feature 484 (R02-G19-04) T-R02G1904-002 (FR-R02G1904-002 … 004): the table grows to 0 … 21 with 20 `ghostWell` (well
// colour, strip coverage at `ghostAlpha`) and 21 `scrubber` (rim colour, strip coverage), 0 … 19 unchanged; decoding
// clamps to 21; each new code is selected by the vertex shader and handled once by the fragment shader.
import Foundation
import Testing
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraShaderSourceTests {
    typealias Shaders = MicroscopicAuroraShaders
    typealias Palette = MicroscopicAuroraPalette
    typealias Material = MicroscopicAuroraMaterial

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "dish", vertex: Shaders.dishVertex, fragment: Shaders.dishFragment,
                 uniforms: Shaders.dishUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.dishVertex, Shaders.dishFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// Occurrences of `needle` in `text`.
    static func occurrences(_ needle: String, in text: String) -> Int {
        var count: Int = 0
        var start: String.Index = text.startIndex
        while let range = text.range(of: needle, range: start..<text.endIndex) {
            count += 1
            start = range.upperBound
        }
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
    static func gap(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
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
        let constants: [String] = [Shaders.mvpUniform, Shaders.wonUniform, Shaders.glowGainUniform,
                                   Shaders.glowLimitUniform]
        #expect(constants == ["u_mvp", "u_won", "u_glowGain", "u_glowLimit"])
        #expect(Set(constants) == Set(Shaders.dishUniforms + Shaders.glowUniforms))
        #expect(Shaders.dishUniforms == ["u_mvp", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.dishVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.dishFragment).isEmpty)
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won"])
        // Nothing moves by time: no time input and no pulse.
        for source in Self.sources() {
            #expect(Self.wordCount("u_time", in: source) == 0)
            #expect(Self.wordCount("u_pulse", in: source) == 0)
        }
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
        #expect(slotsByProgram == ["dish": 5, "glow": 7])
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
            // GLSL ES 3.00 reserved words and built-in function names never used as names.
            let reserved: [String] = ["flat", "smooth", "centroid", "sample", "input", "output", "filter", "distance"]
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
        let dishOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_material": "float", "v_local": "float", "v_along": "float",
            "v_won": "float",
        ]
        #expect(Self.interface("out", in: Shaders.dishVertex) == dishOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.dishVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.dishFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.dishVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        let dish: String = Shaders.dishVertex
        let dishLines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, MA_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "v_along = clamp((a_uv.x - m) / MA_ALONG_SCALE, 0.0, 1.0);",
            "v_aux = a_normal;",
            "float won = clamp(u_won, 0.0, 1.0);",
            "v_won = won;",
        ]
        for line in dishLines { #expect(dish.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("float x = clamp(a_uv.x, 0.0, 3.0);"))
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 1.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let byteTolerance: Double = 1.0 / 255.0
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "MA_ABYSS", colour: Palette.abyss), (name: "MA_ABYSS_TOP", colour: Palette.abyssTop),
            (name: "MA_FIELD", colour: Palette.field), (name: "MA_FROND", colour: Palette.frond),
            (name: "MA_RIM", colour: Palette.rim), (name: "MA_STENCIL", colour: Palette.stencil),
            (name: "MA_LIT", colour: Palette.lit), (name: "MA_STRAY", colour: Palette.stray),
            (name: "MA_SITE", colour: Palette.site), (name: "MA_WELL", colour: Palette.well),
            (name: "MA_RIBBON", colour: Palette.ribbon), (name: "MA_SWIMMER", colour: Palette.swimmer),
            (name: "MA_MET", colour: Palette.met), (name: "MA_UNMET", colour: Palette.unmet),
            (name: "MA_ACTIONS_LIT", colour: Palette.actionsLit),
            (name: "MA_ACTIONS_UNLIT", colour: Palette.actionsUnlit),
            (name: "MA_BROKEN", colour: Palette.broken), (name: "MA_GLOW", colour: Palette.glow),
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
                #expect(Self.gap(parsed, entry.colour) <= tolerance, "\(entry.name)")
                #expect(Self.gap(parsed, entry.colour) <= byteTolerance, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
        }
        #expect(tableNames.count == palette.count)
        // Every vec3 constant in every source is a palette colour with the table's value, or the view direction.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "MA_VIEW_DIR" {
                    #expect(Self.gap(parsed, Shaders.viewDirection) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.gap(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals.
        let vertex: String = Shaders.dishVertex
        #expect(vertex.contains("const vec3 MA_ABYSS = vec3(0.015686, 0.066667, 0.058824);"))
        #expect(vertex.contains("const vec3 MA_RIBBON = vec3(0.560784, 0.941176, 0.839216);"))
        let fragment: String = Shaders.dishFragment
        #expect(fragment.contains("const vec3 MA_ABYSS_TOP = vec3(0.043137, 0.164706, 0.149020);"))
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "MA_MAX_MATERIAL", value: 21, source: vertex),
            (name: "MA_ALONG_SCALE", value: Shaders.alongScale, source: vertex),
            (name: "MA_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "MA_RIBBON_FEATHER", value: Shaders.ribbonFeather, source: fragment),
            (name: "MA_LIMB_SHADE", value: Shaders.limbShade, source: fragment),
            (name: "MA_LIMB_EDGE", value: Shaders.limbEdge, source: fragment),
            (name: "MA_CORE_START", value: Shaders.coreStart, source: fragment),
            (name: "MA_CORE_LIFT", value: Shaders.coreLift, source: fragment),
            (name: "MA_RIM_POWER", value: Shaders.rimPower, source: fragment),
            (name: "MA_RIM_LIFT", value: Shaders.rimLift, source: fragment),
            (name: "MA_RIBBON_ALPHA", value: Shaders.ribbonAlpha, source: fragment),
            (name: "MA_RIBBON_CORE", value: Shaders.ribbonCore, source: fragment),
            (name: "MA_WON_LIFT", value: Shaders.wonLift, source: fragment),
            (name: "MA_MARK_FEATHER", value: Shaders.markFeather, source: fragment),
            (name: "MA_RING_HALF", value: Shaders.markRingHalf, source: fragment),
            (name: "MA_GHOST_ALPHA", value: Shaders.ghostAlpha, source: fragment),
            (name: "MA_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "MA_RIBBON_REST", value: Shaders.ribbonRest, source: glowF),
            (name: "MA_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let value: Double? = Self.scalarConstant("float", entry.name, in: entry.source)
            let parsed: Double = try #require(value, "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
    }

    @Test func materialCodeTableIsConsistent() {
        let names: [String] = [
            "backdrop", "field", "frond", "rim", "stencil", "litCell", "strayCell", "siteRing", "wellSpiral",
            "wellArrow", "ribbon", "swimmer", "swimmerTail", "gaugeTrack", "requirementTick", "markMet", "markUnmet",
            "barLit", "barUnlit", "broken", "ghostWell", "scrubber",
        ]
        #expect(Material.allCases.count == names.count)
        #expect(Shaders.materials.count == names.count)
        var codes: Set<Float> = []
        for (index, material) in Material.allCases.enumerated() {
            codes.insert(material.code)
            #expect(material.rawValue == index)
            #expect(material.code == Float(index))
            #expect("\(material)" == names[index])
            #expect(Shaders.materials[index].name == names[index])
            #expect(Shaders.materials[index].code == material.code)
            #expect(Shaders.materials[index].constant == material.paletteConstant)
            // The decoder rounds to the nearest code.
            #expect(Material.decode(Double(index)) == material)
            #expect(Material.decode(Double(index) + 0.3) == material)
            #expect(Material.decode(Double(index) - 0.3) == material)
            var known: Bool = false
            for constant in Shaders.paletteConstants where constant.name == material.paletteConstant {
                known = true
                #expect(material.baseColour == constant.colour, "\(material)")
            }
            #expect(known, "\(material) selects \(material.paletteConstant)")
        }
        #expect(codes.count == names.count)
        #expect(Material.decode(-4) == .backdrop)
        #expect(Material.decode(99) == .scrubber)
        #expect(Material.decode(Double.nan) == .backdrop)
        // The vertex shader selects every material's colour with its code, in code order.
        let vertex: String = Shaders.dishVertex
        #expect(vertex.contains("vec3 base = MA_ABYSS;"))
        #expect(Material.backdrop.paletteConstant == "MA_ABYSS")
        var previous: String.Index = vertex.startIndex
        for material in Material.allCases where material != .backdrop {
            let line: String = "base = mix(base, \(material.paletteConstant), isCode(m, \(material.rawValue).0));"
            #expect(vertex.contains(line), "\(material): \(line)")
            if let range = vertex.range(of: line) {
                #expect(range.lowerBound >= previous, "\(material) out of order")
                previous = range.upperBound
            }
        }
        // The fragment shader handles every code exactly once, so each pixel has one coverage rule.
        let fragment: String = Shaders.dishFragment
        for material in Material.allCases {
            let token: String = "isCode(m, \(material.rawValue).0)"
            #expect(Self.occurrences(token, in: fragment) == 1, "\(material) handled \(token)")
        }
        // The design's colours per element (clarification Q1).
        #expect(Material.field.baseColour == Palette.field)
        #expect(Material.frond.baseColour == Palette.frond)
        #expect(Material.rim.baseColour == Palette.rim)
        #expect(Material.stencil.baseColour == Palette.stencil)
        #expect(Material.litCell.baseColour == Palette.lit)
        #expect(Material.strayCell.baseColour == Palette.stray)
        #expect(Material.siteRing.baseColour == Palette.site)
        #expect(Material.wellSpiral.baseColour == Palette.well)
        #expect(Material.wellArrow.baseColour == Palette.well)
        #expect(Material.ribbon.baseColour == Palette.ribbon)
        #expect(Material.swimmer.baseColour == Palette.swimmer)
        #expect(Material.swimmerTail.baseColour == Palette.site)
        #expect(Material.markMet.baseColour == Palette.met)
        #expect(Material.markUnmet.baseColour == Palette.unmet)
        #expect(Material.barLit.baseColour == Palette.actionsLit)
        #expect(Material.barUnlit.baseColour == Palette.actionsUnlit)
        #expect(Material.broken.baseColour == Palette.broken)
        #expect(Material.ghostWell.baseColour == Palette.well)
        #expect(Material.scrubber.baseColour == Palette.rim)
        // The lit bar reads heliotrope: blue above green by more than the frame check's 0.08.
        #expect(Palette.actionsLit.z - Palette.actionsLit.y >= 0.08)
        // The gauge track and the rim differ from the backdrop by more than the frame check's 0.1.
        #expect(Self.luminance(Material.gaugeTrack.baseColour) - Self.luminance(Palette.abyssTop) >= 0.1)
        #expect(Self.luminance(Material.rim.baseColour) - Self.luminance(Palette.abyssTop) >= 0.1)
    }

    /// Feature 484: the ghost well and the scrubber materials, 0 … 19 unchanged.
    @Test func ghostWellAndScrubberMaterials() {
        #expect(Material.ghostWell.rawValue == 20 && Material.scrubber.rawValue == 21)
        #expect(Material.allCases.count == 22)
        #expect(Material.broken.rawValue == 19 && Material.backdrop.rawValue == 0)
        #expect(Material.ghostWell.paletteConstant == "MA_WELL" && Material.scrubber.paletteConstant == "MA_RIM")
        #expect(Material.decode(20.4) == .ghostWell && Material.decode(21.49) == .scrubber)
        #expect(Material.decode(19.4) == .broken && Material.decode(1_000) == .scrubber)
        // The fallback colours.
        #expect(MicroscopicAuroraSceneGeometry.colour(of: 20) == Palette.well)
        #expect(MicroscopicAuroraSceneGeometry.colour(of: 21) == Palette.rim)
        #expect(MicroscopicAuroraSceneGeometry.colour(of: 22) == Palette.broken)
        // The vertex shader selects them after the broken colour; the fragment shader treats the scrubber as a strip
        // and the ghost as a strip at the ghost alpha.
        let vertex: String = Shaders.dishVertex
        #expect(vertex.contains("base = mix(base, MA_WELL, isCode(m, 20.0));"))
        #expect(vertex.contains("base = mix(base, MA_RIM, isCode(m, 21.0));"))
        #expect(vertex.contains("const float MA_MAX_MATERIAL = 21.000000;"))
        let fragment: String = Shaders.dishFragment
        #expect(fragment.contains("isCode(m, 19.0) + isCode(m, 21.0);"))
        #expect(fragment.contains("float ghost = isCode(m, 20.0);"))
        #expect(fragment.contains("coverage = coverage + edge * ghost * MA_GHOST_ALPHA;"))
        #expect(fragment.contains("const float MA_GHOST_ALPHA = 0.500000;"))
        // The CPU reference of the ghost's coverage.
        #expect(Shaders.ghostAlpha > 0 && Shaders.ghostAlpha < 1)
        #expect(Shaders.ghostCoverage(local: 0) == Shaders.ghostAlpha)
        #expect(Shaders.ghostCoverage(local: 1) == 0)
        #expect(Shaders.ghostCoverage(local: Double.nan) == 0)
        #expect(Shaders.ghostCoverage(local: 0.9) == Shaders.edgeCoverage(local: 0.9) * Shaders.ghostAlpha)
        // The scrubber reads against the backdrop like the rim (the frame check's 0.1).
        #expect(Self.luminance(Material.scrubber.baseColour) - Self.luminance(Palette.abyssTop) >= 0.1)
        // A ribbon code still decodes to the ribbon; codes above the table clamp to the scrubber.
        #expect(Material.decode(Shaders.ribbonCode(along: 1)) == .ribbon)
        #expect(Shaders.ribbonAlong(code: 21) == 0)
    }

    @Test func theRibbonsAlongCoordinateTravelsInUV() {
        let steps: Int = 10
        for step in 0...steps {
            let along: Double = Double(step) / Double(steps)
            let code: Double = Shaders.ribbonCode(along: along)
            #expect(Material.decode(code) == .ribbon, "\(along)")
            #expect(abs(Shaders.ribbonAlong(code: code) - along) < 1e-12, "\(along)")
        }
        #expect(Shaders.alongScale < 0.5)
        #expect(Shaders.ribbonCode(along: Double.nan) == 10)
        #expect(Shaders.ribbonCode(along: 7) == 10 + Shaders.alongScale)
        #expect(Shaders.ribbonAlong(code: Double.infinity) == 0)
        #expect(Shaders.ribbonAlong(code: Double(Material.swimmer.rawValue)) == 0)
    }

    @Test func capsulesAreShadedInLayersFromTheNormalAndFlatOnLevelTwo() {
        let capsules: [Material] = [.swimmer, .swimmerTail]
        for material in capsules {
            let base: SIMD3<Double> = material.baseColour
            let core: SIMD3<Double> = Shaders.capsuleShade(material, mu: 1)
            let mid: SIMD3<Double> = Shaders.capsuleShade(material, mu: 0.6)
            let limb: SIMD3<Double> = Shaders.capsuleShade(material, mu: 0.25)
            let expectedCore: SIMD3<Double> = base + (SIMD3<Double>(1, 1, 1) - base) * Shaders.coreLift
            #expect(Self.gap(core, expectedCore) < 1e-12, "\(material)")
            #expect(Self.luminance(core) >= Self.luminance(mid), "\(material)")
            #expect(Self.luminance(mid) > Self.luminance(limb), "\(material)")
            #expect(Self.gap(Shaders.capsuleShade(material, normal: Shaders.viewDirection), core) < 1e-9)
            #expect(Shaders.capsuleShade(material, mu: Double.nan) == core)
            // A level-2 flat capsule writes a zero normal: shaded flat in its base colour.
            #expect(Shaders.capsuleShade(material, normal: SIMD3<Double>(0, 0, 0)) == base)
            #expect(Shaders.capsuleShade(material, normal: SIMD3<Double>(Double.nan, 0, 1)) == base)
            // The rim light toward the glow colour at grazing angles.
            let shade: SIMD3<Double> = base * Shaders.limbShade
            let rim: SIMD3<Double> = shade + (Palette.glow - shade) * Shaders.rimLift
            #expect(Self.gap(Shaders.capsuleShade(material, mu: 0), rim) < 1e-12, "\(material)")
        }
        // A swimmer's centre is far brighter than the dish field (the frame check's 0.25), shaded or flat.
        let field: Double = Self.luminance(Palette.field)
        #expect(Self.luminance(Shaders.capsuleShade(.swimmer, mu: 1)) - field >= 0.25)
        #expect(Self.luminance(Shaders.capsuleShade(.swimmer, normal: SIMD3<Double>(0, 0, 0))) - field >= 0.25)
        let fragment: String = Shaders.dishFragment
        let lines: [String] = [
            "float shaded = step(0.0001, nl);",
            "vec3 body = mix(v_base * MA_LIMB_SHADE, v_base, smoothstep(0.0, MA_LIMB_EDGE, mu));",
            "body = mix(body, vec3(1.0), MA_CORE_LIFT * smoothstep(MA_CORE_START, 1.0, mu));",
            "body = mix(body, MA_GLOW, MA_RIM_LIFT * pow(1.0 - mu, MA_RIM_POWER));",
            "vec3 capsule = mix(v_base, body, shaded);",
            "rgb = mix(rgb, capsule, isCapsule);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func signedDistanceShadingReferences() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        #expect(Shaders.ribbonCoverage(across: 0) == 1)
        #expect(Shaders.ribbonCoverage(across: 1) == 0)
        #expect(Shaders.ribbonCoverage(across: 0.7) < Shaders.edgeCoverage(local: 0.7))
        #expect(Shaders.squareDistance(u: 0.9, v: 0.9) > 0)
        #expect(Shaders.squareDistance(u: 1.1, v: 0) < 0)
        #expect(Shaders.discDistance(u: 0, v: 0) == 1)
        #expect(Shaders.discDistance(u: 0.8, v: 0.8) < 0)
        #expect(Shaders.ringDistance(u: 0, v: 0) < 0)
        #expect(Shaders.ringDistance(u: 1 - Shaders.markRingHalf, v: 0) > 0)
        #expect(Shaders.markCoverage(.litCell, u: 0.9, v: -0.9) == 1)
        #expect(Shaders.markCoverage(.strayCell, u: 0, v: 0) == 1)
        #expect(Shaders.markCoverage(.markMet, u: 0, v: 0) == 1)
        #expect(Shaders.markCoverage(.markUnmet, u: 0, v: 0) == 0)
        #expect(Shaders.markCoverage(.markUnmet, u: 1 - Shaders.markRingHalf, v: 0) == 1)
        #expect(Shaders.markCoverage(.ribbon, u: 0, v: 0) == 0)
        #expect(Shaders.squareDistance(u: 0, v: Double.infinity) == -1)
        #expect(Shaders.discDistance(u: Double.nan, v: 0) == -1)
        #expect(Shaders.ringDistance(u: Double.nan, v: 0) == -1)
        // Every cell and mark fits inside the quad the geometry spans, with room for the feather.
        let shapes: [Material] = [.litCell, .strayCell, .markMet, .markUnmet]
        let e: Double = Shaders.markQuadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges {
                for shape in shapes {
                    #expect(Shaders.markCoverage(shape, u: p.x, v: p.y) == 0, "\(shape) \(p)")
                }
            }
        }
        let fragment: String = Shaders.dishFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - MA_EDGE_FEATHER, 1.0, d);",
            "float ribbon = 1.0 - smoothstep(1.0 - MA_RIBBON_FEATHER, 1.0, d);",
            "float cell = markCover(1.0 - max(abs(p.x), abs(p.y)));",
            "float filled = markCover(1.0 - r);",
            "float hollow = markCover(MA_RING_HALF - abs(r - (1.0 - MA_RING_HALF)));",
            "coverage = coverage + edge * (strip + fan + isCapsule);",
            "coverage = coverage + filled * isMet + hollow * isUnmet;",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func ribbonsHaveAnEmissiveCoreFadingToTheTailAndAWonLevelBrightensThem() {
        let head: SIMD3<Double> = Shaders.ribbonColour(across: 0, along: 1, won: 0)
        let tail: SIMD3<Double> = Shaders.ribbonColour(across: 0, along: 0, won: 0)
        let side: SIMD3<Double> = Shaders.ribbonColour(across: 1, along: 1, won: 0)
        let white: SIMD3<Double> = SIMD3<Double>(1, 1, 1)
        let expectedHead: SIMD3<Double> = Palette.ribbon + (white - Palette.ribbon) * Shaders.ribbonCore
        #expect(Self.gap(head, expectedHead) < 1e-12)
        #expect(Self.gap(tail, Palette.ribbon) < 1e-12)
        #expect(Self.gap(side, Palette.ribbon) < 1e-12)
        #expect(Self.luminance(head) > Self.luminance(side))
        // The opacity fades to 0 at the tail.
        #expect(abs(Shaders.ribbonOpacity(across: 0, along: 1, won: 0) - Shaders.ribbonAlpha) < 1e-12)
        #expect(Shaders.ribbonOpacity(across: 0, along: 0, won: 0) == 0)
        var previous: Double = -1
        for step in 0...8 {
            let value: Double = Shaders.ribbonOpacity(across: 0, along: Double(step) / 8, won: 0)
            #expect(value > previous)
            previous = value
        }
        // Won: brighter colour and full opacity at the head.
        #expect(Self.luminance(Shaders.ribbonColour(across: 1, along: 1, won: 1)) > Self.luminance(side))
        #expect(Shaders.ribbonOpacity(across: 0, along: 1, won: 1) == 1)
        #expect(Shaders.ribbonColour(across: 1, along: 1, won: Double.nan) == side)
        // Won: every stencil outline is lit in the lit colour.
        #expect(Shaders.baseColour(of: .stencil, won: 0) == Palette.stencil)
        #expect(Self.gap(Shaders.baseColour(of: .stencil, won: 1), Palette.lit) < 1e-12)
        #expect(Shaders.baseColour(of: .gaugeTrack, won: 1) == Palette.stencil)
        #expect(Shaders.baseColour(of: .ribbon, won: 1) == Palette.ribbon)
        let vertex: String = Shaders.dishVertex
        let stencil: String = "base = mix(base, MA_STENCIL, isCode(m, 4.0));"
        let lit: String = "base = mix(base, MA_LIT, isCode(m, 4.0) * won);"
        #expect(vertex.contains(lit))
        if let a = vertex.range(of: stencil), let b = vertex.range(of: lit) {
            #expect(a.upperBound <= b.lowerBound)
        }
        let fragment: String = Shaders.dishFragment
        let lines: [String] = [
            "float lift = clamp(MA_RIBBON_CORE * (1.0 - d) * along + MA_WON_LIFT * won, 0.0, 1.0);",
            "vec3 ribbonRgb = mix(v_base, vec3(1.0), lift);",
            "float ribbonCover = ribbon * along * mix(MA_RIBBON_ALPHA, 1.0, won);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func theBackdropIsAStillGradient() {
        #expect(Self.gap(Shaders.backdropColour(height: 0), Palette.abyss) < 1e-12)
        #expect(Self.gap(Shaders.backdropColour(height: 1), Palette.abyssTop) < 1e-12)
        let middle: SIMD3<Double> = (Palette.abyss + Palette.abyssTop) * 0.5
        #expect(Self.gap(Shaders.backdropColour(height: 0.5), middle) < 1e-12)
        #expect(Shaders.backdropColour(height: Double.nan) == Palette.abyss)
        #expect(Shaders.backdropColour(height: 4) == Palette.abyssTop)
        let fragment: String = Shaders.dishFragment
        #expect(fragment.contains("vec3 backdrop = mix(MA_ABYSS, MA_ABYSS_TOP, h);"))
        #expect(fragment.contains("float sky = isCode(m, 0.0);"))
        #expect(Self.wordCount("hash", in: fragment) == 0)
    }

    @Test func glowShadesTheSwimmersAndTheRibbons() {
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let swimmer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .swimmer, factor: 1, radius: 0, gain: 1,
                                                        won: 0)
        #expect(SIMD3<Double>(swimmer.x, swimmer.y, swimmer.z) == Palette.glow)
        #expect(abs(swimmer.w - Shaders.glowWeight) < 1e-12)
        let rest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .ribbon, factor: 1, radius: 0, gain: 1,
                                                     won: 0)
        let won: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .ribbon, factor: 1, radius: 0, gain: 1,
                                                    won: 1)
        #expect(SIMD3<Double>(rest.x, rest.y, rest.z) == Palette.ribbon)
        #expect(abs(rest.w - Shaders.glowWeight * Shaders.ribbonRest) < 1e-12)
        #expect(abs(won.w - Shaders.glowWeight) < 1e-12)
        let coloured: SIMD4<Double> = Shaders.glowColour(colour: Palette.site, kind: .swimmer, factor: 1,
                                                         radius: 0, gain: 1, won: 0)
        #expect(SIMD3<Double>(coloured.x, coloured.y, coloured.z) == Palette.site)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .swimmer, factor: 1, radius: 1, gain: 1,
                                                      won: 0)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.allCases.count == 2)
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .swimmer)
        #expect(Shaders.GlowKind.decode(99).kind == .ribbon)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("vec3 fallback = mix(MA_GLOW, MA_RIBBON, isRibbon);"))
        #expect(glow.contains("float rest = mix(1.0, mix(MA_RIBBON_REST, 1.0, won), isRibbon);"))
        #expect(glow.contains("float factor = clamp(v_factor, 0.0, 1.0) * rest;"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in MicroscopicAuroraTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowGain(for: MicroscopicAuroraTier.of(2)) == 0)
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
                                                             radius: 0, gain: capped, won: 1)
                #expect(glow.w <= Shaders.glowWeight * Shaders.glowGainCap + 1e-12, "\(kind)")
            }
        }
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        let line: String =
            "float gain = min(clamp(u_glowGain, 0.0, MA_MAX_GAIN), clamp(u_glowLimit, 0.0, MA_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("MicroscopicAuroraShaders.swift")
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
            .appendingPathComponent("ma-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "dish.vert", source: Shaders.dishVertex), (name: "dish.frag", source: Shaders.dishFragment),
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
