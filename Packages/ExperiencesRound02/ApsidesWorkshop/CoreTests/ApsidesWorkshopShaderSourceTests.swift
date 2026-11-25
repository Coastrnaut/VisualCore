// ApsidesWorkshopShaderSourceTests — feature 473 (R02-G18-03) T-R02G1803-003 (FR-R02G1803-001, 002, 004;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and used in its stage, at most 16 vec4
// uniform slots per program, no texture sampler, no `discard`, no loop (so no unbounded one), vertex outputs matching
// fragment inputs, balanced braces, ASCII-only sources, the attribute names and locations (the `ShaderMeshRenderer`
// streams), the material code table (distinct, ordered 0 … 22, each selected by the vertex shader with its palette
// colour, decoded back), the GLSL palette constants parsing back to `ApsidesWorkshopPalette` within 1e-6, the layered
// sphere shading (the orbiter's deep rose rim), the signed-distance references (edge, ribbon, hazard hatching, diamond,
// square, filled and hollow marks), the orbit ribbon's emissive core and the won brightening, every gauge mark lit on a
// won level, the backdrop gradient and its sparse specks (under 5 % of sampled pixels), the star pulse rule (exactly 1
// with Reduce Motion, 0.85 … 1 otherwise, finite, 1 for a non-finite time), the glow per kind, the glow gain per tier
// (0 at level-2) and the Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of
// each source (skipped otherwise). Test data uses explicit types and plain loops (CI type-check rule).
//
// Feature 474 (R02-G18-04) T-R02G1804-002 (FR-R02G1804-004; clarification Q3): the new material 22 `ghostPreview`
// (glacial, selected by the vertex shader in code order, decoded back, the decode clamp now 0 … 22, 23 materials): its
// dashed loop (``ApsidesWorkshopShaders/ghostPreviewDashes`` dashes of duty ``ApsidesWorkshopShaders/ghostPreviewDuty``
// under the ribbon edge) and its outlined diamond and square (a band just inside the shape, empty at its centre and
// outside), each times ``ApsidesWorkshopShaders/ghostPreviewAlpha``, inside the mark quad; the fragment shader's lines
// for it and its constants.
import Foundation
import Testing
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopShaderSourceTests {
    typealias Shaders = ApsidesWorkshopShaders
    typealias Palette = ApsidesWorkshopPalette
    typealias Material = ApsidesWorkshopMaterial

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "compass", vertex: Shaders.compassVertex, fragment: Shaders.compassFragment,
                 uniforms: Shaders.compassUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.compassVertex, Shaders.compassFragment, Shaders.glowVertex, Shaders.glowFragment]
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
        #expect(Set(constants) == Set(Shaders.compassUniforms + Shaders.glowUniforms))
        #expect(Shaders.compassUniforms == ["u_mvp", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won", "u_pulse"])
        #expect(Self.declared("uniform", in: Shaders.compassVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.compassFragment).isEmpty)
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won", "u_pulse"])
        // No time input: the only motion is the star pulse the presenter passes (1 with Reduce Motion).
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
        #expect(slotsByProgram == ["compass": 5, "glow": 8])
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
        let compassOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_material": "float", "v_local": "float", "v_won": "float",
        ]
        #expect(Self.interface("out", in: Shaders.compassVertex) == compassOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.compassVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.compassFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.compassVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        let compass: String = Shaders.compassVertex
        let compassLines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, AW_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "v_aux = a_normal;",
            "float won = clamp(u_won, 0.0, 1.0);",
            "v_won = won;",
        ]
        for line in compassLines { #expect(compass.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("float x = clamp(a_uv.x, 0.0, 5.0);"))
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 2.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "AW_MIDNIGHT", colour: Palette.midnight), (name: "AW_MIDNIGHT_TOP", colour: Palette.midnightTop),
            (name: "AW_SPECK", colour: Palette.speck), (name: "AW_WEDGE", colour: Palette.wedge),
            (name: "AW_TARGET_WEDGE", colour: Palette.targetWedge), (name: "AW_COMPASS", colour: Palette.compass),
            (name: "AW_GHOST", colour: Palette.ghost), (name: "AW_GLACIAL", colour: Palette.glacial),
            (name: "AW_DEEP_ROSE", colour: Palette.deepRose), (name: "AW_PLANET", colour: Palette.planet),
            (name: "AW_HAZARD", colour: Palette.hazard), (name: "AW_STAR", colour: Palette.star),
            (name: "AW_MET", colour: Palette.met), (name: "AW_UNMET", colour: Palette.unmet),
            (name: "AW_ACTIONS_LIT", colour: Palette.actionsLit),
            (name: "AW_ACTIONS_UNLIT", colour: Palette.actionsUnlit),
            (name: "AW_BROKEN", colour: Palette.broken), (name: "AW_GLOW", colour: Palette.glow),
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
                if name == "AW_VIEW_DIR" {
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
        let vertex: String = Shaders.compassVertex
        #expect(vertex.contains("const vec3 AW_MIDNIGHT = vec3(0.039216, 0.043137, 0.121569);"))
        #expect(vertex.contains("const vec3 AW_DEEP_ROSE = vec3(0.760784, 0.270588, 0.431373);"))
        let fragment: String = Shaders.compassFragment
        #expect(fragment.contains("const vec3 AW_MIDNIGHT_TOP = vec3(0.101961, 0.078431, 0.219608);"))
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "AW_MAX_MATERIAL", value: 22, source: vertex),
            (name: "AW_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "AW_RIBBON_FEATHER", value: Shaders.ribbonFeather, source: fragment),
            (name: "AW_CELLS_ACROSS", value: Shaders.cellsAcross, source: fragment),
            (name: "AW_CELLS_UP", value: Shaders.cellsUp, source: fragment),
            (name: "AW_SPECK_DENSITY", value: Shaders.speckDensity, source: fragment),
            (name: "AW_SPECK_RADIUS", value: Shaders.speckRadius, source: fragment),
            (name: "AW_LIMB_SHADE", value: Shaders.limbShade, source: fragment),
            (name: "AW_LIMB_EDGE", value: Shaders.limbEdge, source: fragment),
            (name: "AW_CORE_LIFT", value: Shaders.coreLift, source: fragment),
            (name: "AW_RIM_LIFT", value: Shaders.rimLift, source: fragment),
            (name: "AW_ORBITER_RIM_LIFT", value: Shaders.orbiterRimLift, source: fragment),
            (name: "AW_WEDGE_ALPHA", value: Shaders.wedgeAlpha, source: fragment),
            (name: "AW_GHOST_ALPHA", value: Shaders.ghostAlpha, source: fragment),
            (name: "AW_ORBIT_ALPHA", value: Shaders.orbitAlpha, source: fragment),
            (name: "AW_ORBIT_CORE", value: Shaders.orbitCore, source: fragment),
            (name: "AW_WON_LIFT", value: Shaders.wonLift, source: fragment),
            (name: "AW_HAZARD_HATCHES", value: Shaders.hazardHatches, source: fragment),
            (name: "AW_HAZARD_DUTY", value: Shaders.hazardDuty, source: fragment),
            (name: "AW_HAZARD_FLOOR", value: Shaders.hazardFloor, source: fragment),
            (name: "AW_MARK_FEATHER", value: Shaders.markFeather, source: fragment),
            (name: "AW_RING_HALF", value: Shaders.markRingHalf, source: fragment),
            (name: "AW_INV_SQRT2", value: 1 / 2.0.squareRoot(), source: fragment),
            (name: "AW_GHOST_DASHES", value: Shaders.ghostPreviewDashes, source: fragment),
            (name: "AW_GHOST_DUTY", value: Shaders.ghostPreviewDuty, source: fragment),
            (name: "AW_GHOST_PREVIEW_ALPHA", value: Shaders.ghostPreviewAlpha, source: fragment),
            (name: "AW_GHOST_OUTLINE_HALF", value: Shaders.ghostOutlineHalf, source: fragment),
            (name: "AW_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "AW_ORBIT_REST", value: Shaders.orbitRest, source: glowF),
            (name: "AW_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let value: Double? = Self.scalarConstant("float", entry.name, in: entry.source)
            let parsed: Double = try #require(value, "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
    }

    @Test func materialCodeTableIsConsistent() {
        let names: [String] = [
            "backdrop", "wedge", "targetWedge", "spoke", "rim", "notch", "bracket", "ghost", "orbit", "periapsis",
            "apoapsis", "planet", "hazard", "star", "orbiter", "gaugeTrack", "gaugeBand", "markMet", "markUnmet",
            "barLit", "barUnlit", "broken", "ghostPreview",
        ]
        #expect(names.count == 23)
        #expect(Material.maxCode == 22)
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
        #expect(Material.decode(99) == .ghostPreview)
        #expect(Material.decode(21.4) == .broken)
        #expect(Material.decode(Double.nan) == .backdrop)
        // The vertex shader selects every material's colour with its code, in code order.
        let vertex: String = Shaders.compassVertex
        #expect(vertex.contains("vec3 base = AW_MIDNIGHT;"))
        #expect(Material.backdrop.paletteConstant == "AW_MIDNIGHT")
        var previous: String.Index = vertex.startIndex
        for material in Material.allCases where material != .backdrop {
            let line: String = "base = mix(base, \(material.paletteConstant), isCode(m, \(material.rawValue).0));"
            #expect(vertex.contains(line), "\(material): \(line)")
            if let range = vertex.range(of: line) {
                #expect(range.lowerBound >= previous, "\(material) out of order")
                previous = range.upperBound
            }
        }
        // The design's colours per element (clarification Q1).
        #expect(Material.wedge.baseColour == Palette.wedge)
        #expect(Material.targetWedge.baseColour == Palette.targetWedge)
        #expect(Material.spoke.baseColour == Palette.compass)
        #expect(Material.ghost.baseColour == Palette.ghost)
        #expect(Material.orbit.baseColour == Palette.glacial)
        #expect(Material.periapsis.baseColour == Palette.deepRose)
        #expect(Material.apoapsis.baseColour == Palette.deepRose)
        #expect(Material.planet.baseColour == Palette.planet)
        #expect(Material.hazard.baseColour == Palette.hazard)
        #expect(Material.star.baseColour == Palette.star)
        #expect(Material.orbiter.baseColour == Palette.glacial)
        #expect(Material.markMet.baseColour == Palette.met)
        #expect(Material.markUnmet.baseColour == Palette.unmet)
        #expect(Material.barLit.baseColour == Palette.actionsLit)
        #expect(Material.barUnlit.baseColour == Palette.actionsUnlit)
        #expect(Material.broken.baseColour == Palette.broken)
        #expect(Material.ghostPreview.baseColour == Palette.glacial)
        // The fragment shader branches on the same codes.
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "float sky = isCode(m, 0.0);",
            "float isWedge = isCode(m, 1.0) + isCode(m, 2.0);",
            "rgb = mix(rgb, mix(v_base, AW_GLACIAL, AW_NOTCH_LIFT), isCode(m, 5.0));",
            "coverage = mix(coverage, ribbon * AW_GHOST_ALPHA, isCode(m, 7.0));",
            "coverage = mix(coverage, orbitCover, isCode(m, 8.0));",
            "coverage = mix(coverage, diamond, isCode(m, 9.0));",
            "coverage = mix(coverage, squareMark, isCode(m, 10.0));",
            "float isSphere = isCode(m, 11.0) + isCode(m, 13.0) + isOrbiter;",
            "coverage = coverage * mix(1.0, mix(AW_HAZARD_FLOOR, 1.0, hatch), isCode(m, 12.0));",
            "float isOrbiter = isCode(m, 14.0);",
            "coverage = mix(coverage, filled, isCode(m, 17.0));",
            "coverage = mix(coverage, unmetMark, isCode(m, 18.0));",
            "coverage = mix(coverage, ghostCover * AW_GHOST_PREVIEW_ALPHA, isCode(m, 22.0));",
            "coverage = mix(coverage, 1.0, sky);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
        // The lit bar reads deep rose: red above blue by far more than the frame check's 0.08.
        #expect(Palette.actionsLit.x - Palette.actionsLit.z >= 0.08)
        // The gauge track differs from the backdrop by more than the frame check's 0.1.
        #expect(Self.luminance(Material.gaugeTrack.baseColour) - Self.luminance(Palette.midnightTop) >= 0.1)
    }

    @Test func spheresAreShadedInLayersFromTheNormal() {
        let bodies: [Material] = [.planet, .star, .orbiter]
        let sky: Double = Self.luminance(Palette.midnightTop)
        for material in bodies {
            let base: SIMD3<Double> = material.baseColour
            let core: SIMD3<Double> = Shaders.sphereShade(material, mu: 1)
            let mid: SIMD3<Double> = Shaders.sphereShade(material, mu: 0.6)
            let limb: SIMD3<Double> = Shaders.sphereShade(material, mu: 0.25)
            let expectedCore: SIMD3<Double> = base + (SIMD3<Double>(1, 1, 1) - base) * Shaders.coreLift
            #expect(Self.distance(core, expectedCore) < 1e-12, "\(material)")
            #expect(Self.luminance(core) >= Self.luminance(mid), "\(material)")
            #expect(Self.luminance(mid) > Self.luminance(limb), "\(material)")
            #expect(Self.distance(Shaders.sphereShade(material, normal: Shaders.viewDirection), core) < 1e-9)
            #expect(Shaders.sphereShade(material, normal: SIMD3<Double>(0, 0, 0)) == core)
            #expect(Shaders.sphereShade(material, normal: SIMD3<Double>(Double.nan, 0, 1)) == core)
            #expect(Shaders.sphereShade(material, mu: Double.nan) == core)
        }
        // The star's and the orbiter's centres are far brighter than the backdrop (the frame check's 0.25).
        #expect(Self.luminance(Shaders.sphereShade(.star, mu: 1)) - sky >= 0.25)
        #expect(Self.luminance(Shaders.sphereShade(.orbiter, mu: 1)) - sky >= 0.25)
        // The rim light: toward the glow colour on a planet, toward deep rose on the orbiter.
        let planetShade: SIMD3<Double> = Palette.planet * Shaders.limbShade
        let planetRim: SIMD3<Double> = planetShade + (Palette.glow - planetShade) * Shaders.rimLift
        #expect(Self.distance(Shaders.sphereShade(.planet, mu: 0), planetRim) < 1e-12)
        let orbiterShade: SIMD3<Double> = Palette.glacial * Shaders.limbShade
        let orbiterRim: SIMD3<Double> = orbiterShade + (Palette.deepRose - orbiterShade) * Shaders.orbiterRimLift
        let rim: SIMD3<Double> = Shaders.sphereShade(.orbiter, mu: 0)
        #expect(Self.distance(rim, orbiterRim) < 1e-12)
        #expect(rim.x - rim.z > 0.1)
        #expect(Shaders.sphereShade(.orbiter, normal: -Shaders.viewDirection) == rim)
        #expect(abs((Shaders.viewDirection * Shaders.viewDirection).sum() - 1) < 1e-12)
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "vec3 body = mix(v_base * AW_LIMB_SHADE, v_base, smoothstep(0.0, AW_LIMB_EDGE, mu));",
            "body = mix(body, vec3(1.0), AW_CORE_LIFT * smoothstep(AW_CORE_START, 1.0, mu));",
            "vec3 rimColour = mix(AW_GLOW, AW_DEEP_ROSE, isOrbiter);",
            "body = mix(body, rimColour, rimLift * pow(1.0 - mu, AW_RIM_POWER));",
            "rgb = mix(rgb, body, isSphere);",
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
        // The hazard ring shows its hatches with their duty, over a floor.
        var lit: Int = 0
        var runs: Int = 0
        var previous: Double = 0
        for step in 0..<960 {
            let value: Double = Shaders.hazardHatch(across: 0, along: (Double(step) + 0.5) / 960)
            lit += Int(value)
            if value == 1 && previous == 0 { runs += 1 }
            previous = value
        }
        #expect(runs == Int(Shaders.hazardHatches))
        #expect(abs(Double(lit) / 960 - Shaders.hazardDuty) < 0.02)
        #expect(Shaders.hazardCoverage(across: 0, along: 0.001) == 1)
        let between: Double = (Shaders.hazardDuty + 0.25) / Shaders.hazardHatches
        #expect(abs(Shaders.hazardCoverage(across: 0, along: between) - Shaders.hazardFloor) < 1e-12)
        // Marks: diamond, square, filled disc and hollow ring.
        let diamondInside: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(0.45, 0.45), SIMD2(0.9, 0), SIMD2(0, -0.9)]
        for p in diamondInside { #expect(Shaders.diamondDistance(u: p.x, v: p.y) > 0, "\(p)") }
        let diamondOutside: [SIMD2<Double>] = [SIMD2(0.6, 0.6), SIMD2(1.1, 0), SIMD2(-0.8, 0.5)]
        for p in diamondOutside { #expect(Shaders.diamondDistance(u: p.x, v: p.y) < 0, "\(p)") }
        #expect(Shaders.squareDistance(u: 0.9, v: 0.9) > 0)
        #expect(Shaders.squareDistance(u: 1.1, v: 0) < 0)
        #expect(Shaders.discDistance(u: 0, v: 0) == 1)
        #expect(Shaders.discDistance(u: 0.8, v: 0.8) < 0)
        #expect(Shaders.ringDistance(u: 0, v: 0) < 0)
        #expect(Shaders.ringDistance(u: 1 - Shaders.markRingHalf, v: 0) > 0)
        #expect(Shaders.markCoverage(.periapsis, u: 0, v: 0, won: 0) == 1)
        #expect(Shaders.markCoverage(.apoapsis, u: 0.9, v: -0.9, won: 0) == 1)
        #expect(Shaders.markCoverage(.markMet, u: 0, v: 0, won: 0) == 1)
        #expect(Shaders.markCoverage(.markUnmet, u: 0, v: 0, won: 0) == 0)
        #expect(Shaders.markCoverage(.markUnmet, u: 1 - Shaders.markRingHalf, v: 0, won: 0) == 1)
        #expect(Shaders.markCoverage(.orbit, u: 0, v: 0, won: 0) == 0)
        #expect(Shaders.diamondDistance(u: Double.nan, v: 0) == -1)
        #expect(Shaders.squareDistance(u: 0, v: Double.infinity) == -1)
        #expect(Shaders.ringDistance(u: Double.nan, v: 0) == -1)
        // Every mark fits inside the quad the geometry spans, with room for the feather.
        let marks: [Material] = [.periapsis, .apoapsis, .markMet, .markUnmet]
        let e: Double = Shaders.markQuadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges {
                for mark in marks {
                    #expect(Shaders.markCoverage(mark, u: p.x, v: p.y, won: 1) == 0, "\(mark) \(p)")
                    #expect(Shaders.markCoverage(mark, u: p.x, v: p.y, won: 0) == 0, "\(mark) \(p)")
                }
            }
        }
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - AW_EDGE_FEATHER, 1.0, d);",
            "float ribbon = 1.0 - smoothstep(1.0 - AW_RIBBON_FEATHER, 1.0, d);",
            "float hatch = 1.0 - step(AW_HAZARD_DUTY, fract(t * AW_HAZARD_HATCHES + v_local * AW_HAZARD_SLANT));",
            "float diamond = markCover((1.0 - abs(p.x) - abs(p.y)) * AW_INV_SQRT2);",
            "float squareMark = markCover(1.0 - max(abs(p.x), abs(p.y)));",
            "float filled = markCover(1.0 - r);",
            "float hollow = markCover(AW_RING_HALF - abs(r - (1.0 - AW_RING_HALF)));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    /// Feature 474: material 22, the ghost of a pending orbit — a dashed glacial loop and outlined apsis markers.
    @Test func ghostPreviewIsADashedLoopWithOutlinedMarkers() {
        #expect(Material.ghostPreview.rawValue == 22 && Material.ghostPreview.code == 22)
        #expect(Material.ghostPreview.paletteConstant == "AW_GLACIAL")
        #expect(Shaders.baseColour(of: .ghostPreview, won: 1) == Palette.glacial)
        // The loop: the dashes with their duty, under the ribbon's soft edge, times the alpha.
        var lit: Int = 0
        var runs: Int = 0
        var previous: Double = 0
        let samples: Int = 4800
        for step in 0..<samples {
            let value: Double = Shaders.ghostPreviewDash(along: (Double(step) + 0.5) / Double(samples))
            #expect(value == 0 || value == 1)
            lit += Int(value)
            if value == 1 && previous == 0 { runs += 1 }
            previous = value
        }
        #expect(runs == Int(Shaders.ghostPreviewDashes))
        #expect(abs(Double(lit) / Double(samples) - Shaders.ghostPreviewDuty) < 0.01)
        #expect(Shaders.ghostPreviewDash(along: Double.nan) == 1)
        #expect(Shaders.ghostPreviewCoverage(across: 0, along: 0.001) == Shaders.ghostPreviewAlpha)
        #expect(Shaders.ghostPreviewCoverage(across: 1, along: 0.001) == 0)
        let gap: Double = (Shaders.ghostPreviewDuty + 0.2) / Shaders.ghostPreviewDashes
        #expect(Shaders.ghostPreviewCoverage(across: 0, along: gap) == 0)
        #expect(Shaders.ghostPreviewCoverage(across: Double.nan, along: 0.001) == 0)
        // The markers: a band just inside the diamond or the square; empty at the centre and outside.
        let diamond: Double = Shaders.ghostShapeDiamond
        let square: Double = Shaders.ghostShapeSquare
        let half: Double = Shaders.ghostOutlineHalf
        #expect(Shaders.ghostShapeLine == 0 && diamond == 1 && square == 2)
        #expect(Shaders.ghostOutlineCoverage(shape: diamond, u: 0, v: 0) == 0)
        #expect(Shaders.ghostOutlineCoverage(shape: square, u: 0, v: 0) == 0)
        let onDiamondBand: Double = 1 - half * 2.0.squareRoot()
        #expect(abs(Shaders.ghostOutlineCoverage(shape: diamond, u: onDiamondBand, v: 0)
                    - Shaders.ghostPreviewAlpha) < 1e-12)
        #expect(abs(Shaders.ghostOutlineCoverage(shape: square, u: 1 - half, v: 0.3)
                    - Shaders.ghostPreviewAlpha) < 1e-12)
        #expect(Shaders.ghostOutlineCoverage(shape: square, u: 1.2, v: 0) == 0)
        #expect(Shaders.ghostOutlineCoverage(shape: diamond, u: 0.7, v: 0.7) == 0)
        #expect(Shaders.ghostOutlineCoverage(shape: Shaders.ghostShapeLine, u: 1 - half, v: 0) == 0)
        #expect(Shaders.ghostOutlineCoverage(shape: Double.nan, u: 1 - half, v: 0) == 0)
        #expect(Shaders.ghostOutlineDistance(shape: diamond, u: Double.nan, v: 0) == -1)
        // Both outlines fit inside the quad the geometry spans, with room for the feather.
        let e: Double = Shaders.markQuadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges {
                #expect(Shaders.ghostOutlineCoverage(shape: diamond, u: p.x, v: p.y) == 0, "\(p)")
                #expect(Shaders.ghostOutlineCoverage(shape: square, u: p.x, v: p.y) == 0, "\(p)")
            }
        }
        let vertex: String = Shaders.compassVertex
        #expect(vertex.contains("base = mix(base, AW_GLACIAL, isCode(m, 22.0));"))
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "float ghostShape = floor(v_aux.z + 0.5);",
            "float ghostDash = 1.0 - step(AW_GHOST_DUTY, fract(t * AW_GHOST_DASHES));",
            "float diamondOutline = markCover(AW_GHOST_OUTLINE_HALF - abs(diamondDist - AW_GHOST_OUTLINE_HALF));",
            "float squareOutline = markCover(AW_GHOST_OUTLINE_HALF - abs(squareDist - AW_GHOST_OUTLINE_HALF));",
            "float ghostCover = ribbon * ghostDash;",
            "ghostCover = mix(ghostCover, diamondOutline, isCode(ghostShape, 1.0));",
            "ghostCover = mix(ghostCover, squareOutline, isCode(ghostShape, 2.0));",
            "coverage = mix(coverage, ghostCover * AW_GHOST_PREVIEW_ALPHA, isCode(m, 22.0));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func theOrbitRibbonHasAnEmissiveCoreAndAWonLevelBrightensIt() {
        let centre: SIMD3<Double> = Shaders.orbitColour(across: 0, won: 0)
        let side: SIMD3<Double> = Shaders.orbitColour(across: 1, won: 0)
        #expect(Self.distance(side, Palette.glacial) < 1e-12)
        let white: SIMD3<Double> = SIMD3<Double>(1, 1, 1)
        let expectedCentre: SIMD3<Double> = Palette.glacial + (white - Palette.glacial) * Shaders.orbitCore
        #expect(Self.distance(centre, expectedCentre) < 1e-12)
        #expect(Self.luminance(centre) > Self.luminance(side))
        // Won: brighter colour and full coverage.
        #expect(Self.luminance(Shaders.orbitColour(across: 1, won: 1)) > Self.luminance(side))
        #expect(abs(Shaders.orbitCoverage(across: 0, won: 0) - Shaders.orbitAlpha) < 1e-12)
        #expect(Shaders.orbitCoverage(across: 0, won: 1) == 1)
        #expect(Shaders.orbitColour(across: 1, won: Double.nan) == side)
        // Every gauge mark is lit on a won level: unmet marks fill in the met colour.
        #expect(Shaders.baseColour(of: .markUnmet, won: 0) == Palette.unmet)
        #expect(Self.distance(Shaders.baseColour(of: .markUnmet, won: 1), Palette.met) < 1e-12)
        #expect(Shaders.baseColour(of: .markMet, won: 0) == Palette.met)
        #expect(Shaders.baseColour(of: .orbit, won: 1) == Palette.glacial)
        #expect(Shaders.markCoverage(.markUnmet, u: 0, v: 0, won: 1) == 1)
        #expect(Shaders.markCoverage(.markUnmet, u: 0, v: 0, won: 1)
                == Shaders.markCoverage(.markMet, u: 0, v: 0, won: 0))
        let vertex: String = Shaders.compassVertex
        let unmet: String = "base = mix(base, AW_UNMET, isCode(m, 18.0));"
        let lit: String = "base = mix(base, AW_MET, isCode(m, 18.0) * won);"
        #expect(vertex.contains(lit))
        if let a = vertex.range(of: unmet), let b = vertex.range(of: lit) {
            #expect(a.upperBound <= b.lowerBound)
        }
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "vec3 orbit = mix(AW_GLACIAL, vec3(1.0), clamp(AW_ORBIT_CORE * (1.0 - d) + AW_WON_LIFT * won, 0.0, 1.0));",
            "float orbitCover = ribbon * mix(AW_ORBIT_ALPHA, 1.0, won);",
            "float unmetMark = mix(hollow, filled, won);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func backdropGradientAndSparseSpecks() {
        let bottom: SIMD3<Double> = Shaders.backdropColour(height: 0, horizontal: 0.123)
        let top: SIMD3<Double> = Shaders.backdropColour(height: 1, horizontal: 0.123)
        if Shaders.speckCoverage(height: 0, horizontal: 0.123) == 0 {
            #expect(Self.distance(bottom, Palette.midnight) < 1e-12)
        }
        if Shaders.speckCoverage(height: 1, horizontal: 0.123) == 0 {
            #expect(Self.distance(top, Palette.midnightTop) < 1e-12)
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
                    let g: SIMD3<Double> = Palette.midnight + (Palette.midnightTop - Palette.midnight) * h
                    gradientDeviation = max(gradientDeviation, Self.distance(c, g))
                }
            }
        }
        let share: Double = Double(specked) / Double(rows * columns)
        #expect(share < 0.05, "\(share)")
        #expect(share > 0.001, "\(share)")
        #expect(gradientDeviation < 1e-12)
        #expect(Shaders.speckCoverage(height: Double.nan, horizontal: Double.nan) >= 0)
        let fragment: String = Shaders.compassFragment
        let lines: [String] = [
            "float speck = step(1.0 - AW_SPECK_DENSITY, pick);",
            "vec3 gradient = mix(AW_MIDNIGHT, AW_MIDNIGHT_TOP, h);",
            "vec2 cellPos = vec2((s + 1.0) * 0.5 * AW_CELLS_ACROSS, h * AW_CELLS_UP);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func starPulseRule() {
        let times: [Double] = [0, 0.3, 0.6, 1.2, 1.8, 2.4, 10, 100, 3_600, 86_400, -5]
        for time in times {
            #expect(Shaders.starPulse(time: time, reduceMotion: true) == 1, "\(time)")
            let value: Double = Shaders.starPulse(time: time, reduceMotion: false)
            #expect(value >= Shaders.pulseLow && value <= 1, "\(time): \(value)")
        }
        #expect(Shaders.pulseLow == 0.85)
        #expect(Shaders.starPulse(time: 0, reduceMotion: false) == 1)
        #expect(abs(Shaders.starPulse(time: Shaders.pulsePeriod / 2, reduceMotion: false) - Shaders.pulseLow) < 1e-12)
        let a: Double = Shaders.starPulse(time: 0.7, reduceMotion: false)
        let b: Double = Shaders.starPulse(time: 0.7 + Shaders.pulsePeriod, reduceMotion: false)
        #expect(abs(a - b) < 1e-9)
        // It moves without Reduce Motion: the samples over one period span most of the range.
        var low: Double = 1
        for step in 0..<48 {
            low = min(low, Shaders.starPulse(time: Shaders.pulsePeriod * Double(step) / 48, reduceMotion: false))
        }
        #expect(low < 0.86)
        let odd: [Double] = [Double.nan, Double.infinity, -Double.infinity]
        for time in odd {
            #expect(Shaders.starPulse(time: time, reduceMotion: false) == 1, "\(time)")
            #expect(Shaders.starPulse(time: time, reduceMotion: true) == 1, "\(time)")
        }
        let huge: [Double] = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, 1e300]
        for time in huge {
            let value: Double = Shaders.starPulse(time: time, reduceMotion: false)
            #expect(value.isFinite && value >= Shaders.pulseLow && value <= 1, "\(time)")
        }
        // The pulse scales the star's shell only.
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let pulsed: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .star, factor: 1, radius: 0, gain: 1,
                                                       won: 0, pulse: 0.85)
        #expect(abs(pulsed.w - Shaders.glowWeight * 0.85) < 1e-12)
        let orbiter: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .orbiter, factor: 1, radius: 0, gain: 1,
                                                        won: 0, pulse: 0.85)
        #expect(abs(orbiter.w - Shaders.glowWeight) < 1e-12)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("float pulse = clamp(u_pulse, 0.0, 1.0);"))
        let rest: String = "float rest = mix(1.0, pulse, isStar) * mix(1.0, mix(AW_ORBIT_REST, 1.0, won), isOrbit);"
        #expect(glow.contains(rest))
    }

    @Test func glowShadesTheStarTheOrbitLoopAndTheOrbiter() {
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let star: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .star, factor: 1, radius: 0, gain: 1,
                                                     won: 0, pulse: 1)
        #expect(SIMD3<Double>(star.x, star.y, star.z) == Palette.star)
        let orbitRest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .orbit, factor: 1, radius: 0, gain: 1,
                                                          won: 0, pulse: 1)
        let orbitWon: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .orbit, factor: 1, radius: 0, gain: 1,
                                                         won: 1, pulse: 1)
        #expect(SIMD3<Double>(orbitRest.x, orbitRest.y, orbitRest.z) == Palette.glow)
        #expect(abs(orbitRest.w - Shaders.glowWeight * Shaders.orbitRest) < 1e-12)
        #expect(abs(orbitWon.w - Shaders.glowWeight) < 1e-12)
        let orbiter: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .orbiter, factor: 1, radius: 0, gain: 1,
                                                        won: 0, pulse: 1)
        #expect(SIMD3<Double>(orbiter.x, orbiter.y, orbiter.z) == Palette.glacial)
        let coloured: SIMD4<Double> = Shaders.glowColour(colour: Palette.deepRose, kind: .orbiter, factor: 1,
                                                         radius: 0, gain: 1, won: 0, pulse: 1)
        #expect(SIMD3<Double>(coloured.x, coloured.y, coloured.z) == Palette.deepRose)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .star, factor: 1, radius: 1, gain: 1,
                                                      won: 0, pulse: 1)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.allCases.count == 3)
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .star)
        #expect(Shaders.GlowKind.decode(99).kind == .orbiter)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("vec3 fallback = mix(mix(AW_STAR, AW_GLOW, isOrbit), AW_GLACIAL, isOrbiter);"))
        #expect(glow.contains("float factor = clamp(v_factor, 0.0, 1.0) * rest;"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in ApsidesWorkshopTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowGain(for: ApsidesWorkshopTier.of(2)) == 0)
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
            "float gain = min(clamp(u_glowGain, 0.0, AW_MAX_GAIN), clamp(u_glowLimit, 0.0, AW_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("ApsidesWorkshopShaders.swift")
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
            .appendingPathComponent("aw-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "compass.vert", source: Shaders.compassVertex),
            (name: "compass.frag", source: Shaders.compassFragment),
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
