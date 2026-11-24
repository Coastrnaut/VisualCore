// MoonlitMechanismShaderSourceTests — feature 433 (R02-G14-03) T-R02G1403-003 (FR-R02G1403-001, 002; clarifications
// Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared uniform
// listed (equal to the uniform name constants the scene sets) and used in its stage, at most 16 vec4 uniform slots per
// program, no texture sampler, no `discard`, no unbounded loop (any `for` bounded by an int constant), vertex outputs
// matching fragment inputs, balanced braces, ASCII-only sources, the `ShaderMeshRenderer` attribute names and
// locations, the material codes distinct, ordered 0 … 21 and each selected by the vertex shader, the GLSL palette
// constants parsing back to `MoonlitMechanismPalette` within 1e-6, the soft edge, feather, dots, hatching and fresnel
// references, the won wall glow, the glow gain per tier (0 at level-2) and the Reduce Flashing cap, and, when
// `glslangValidator` is installed, a real front-end compile of each source (skipped otherwise).
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams. Test data
// uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismShaderSourceTests {
    typealias Shaders = MoonlitMechanismShaders
    typealias Palette = MoonlitMechanismPalette
    typealias Material = MoonlitMechanismShaders.Material

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "clockwork", vertex: Shaders.clockworkVertex, fragment: Shaders.clockworkFragment,
                 uniforms: Shaders.clockworkUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.clockworkVertex, Shaders.clockworkFragment, Shaders.glowVertex, Shaders.glowFragment]
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
        #expect(Set(constants) == Set(Shaders.clockworkUniforms + Shaders.glowUniforms))
        #expect(Shaders.clockworkUniforms == ["u_mvp", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.clockworkVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.clockworkFragment).isEmpty)
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won"])
        // No time input: nothing pulses or flashes in the shaders.
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
        #expect(slotsByProgram == ["clockwork": 5, "glow": 7])
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
                let parts: [String] = line.components(separatedBy: ";")
                #expect(parts.count == 3, "\(line)")
                let bound: [String] = Self.identifiers(parts.count > 1 ? parts[1] : "")
                #expect(bound.count == 2, "\(line)")
                if let name = bound.last {
                    let value: Double? = Self.scalarConstant("int", name, in: source)
                    #expect(value != nil, "\(name) is not a constant")
                    #expect((value ?? 99) <= 16, "\(name) bounds a loop above 16")
                }
            }
            // No loop at all in this feature's sources.
            #expect(Self.wordCount("for", in: source) == 0)
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
        let clockworkOuts: [String: String] = [
            "v_base": "vec3", "v_alpha": "float", "v_material": "float", "v_local": "float", "v_wall": "vec2",
        ]
        #expect(Self.interface("out", in: Shaders.clockworkVertex) == clockworkOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.clockworkVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.clockworkFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        for attribute in Shaders.attributes {
            #expect(Self.wordCount(attribute.name, in: Shaders.glowVertex) >= 2, "\(attribute.name) unread in glow")
        }
        // The clockwork program reads the position and uv; the normal is declared for the layout only (emissive).
        #expect(Self.wordCount("a_position", in: Shaders.clockworkVertex) >= 2)
        #expect(Self.wordCount("a_uv", in: Shaders.clockworkVertex) >= 2)
        let vertex: String = Shaders.clockworkVertex
        let lines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, MM_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - plain);",
            "v_wall = a_position.xy;",
        ]
        for line in lines { #expect(vertex.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 2.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "MM_NIGHT", colour: Palette.night), (name: "MM_PAPER", colour: Palette.paper),
            (name: "MM_INK", colour: Palette.ink), (name: "MM_GEAR", colour: Palette.gear),
            (name: "MM_RIM", colour: Palette.rim), (name: "MM_BLADE", colour: Palette.blade),
            (name: "MM_LAMP", colour: Palette.lamp), (name: "MM_LAMP_GLOW", colour: Palette.lampGlow),
            (name: "MM_TARGET", colour: Palette.target), (name: "MM_FORBIDDEN", colour: Palette.forbidden),
            (name: "MM_STRAY", colour: Palette.stray), (name: "MM_BROKEN", colour: Palette.broken),
            (name: "MM_CARD_LIT", colour: Palette.cardLit), (name: "MM_CARD_UNLIT", colour: Palette.cardUnlit),
            (name: "MM_ALIGN_LIT", colour: Palette.alignLit), (name: "MM_ALIGN_UNLIT", colour: Palette.alignUnlit),
            (name: "MM_MOVES_LIT", colour: Palette.movesLit), (name: "MM_MOVES_UNLIT", colour: Palette.movesUnlit),
            (name: "MM_GLOW", colour: Palette.glow),
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
        // Every vec3 constant in every source is a palette colour with the table's value.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals.
        let vertex: String = Shaders.clockworkVertex
        #expect(vertex.contains("const vec3 MM_NIGHT = vec3(0.027451, 0.039216, 0.078431);"))
        #expect(vertex.contains("const vec3 MM_PAPER = vec3(0.909804, 0.874510, 0.784314);"))
        #expect(vertex.contains("const vec3 MM_GEAR = vec3(0.788235, 0.635294, 0.290196);"))
        let fragment: String = Shaders.clockworkFragment
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "MM_GEAR_ALPHA", value: Palette.gearAlpha, source: vertex),
            (name: "MM_BLADE_ALPHA", value: Palette.bladeAlpha, source: vertex),
            (name: "MM_WON_LIFT", value: Shaders.wonLift, source: vertex),
            (name: "MM_MAX_MATERIAL", value: 21, source: vertex),
            (name: "MM_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "MM_DOT_PERIOD", value: Shaders.dotPeriod, source: fragment),
            (name: "MM_DOT_DUTY", value: Shaders.dotDuty, source: fragment),
            (name: "MM_HATCH_PERIOD", value: Shaders.hatchPeriod, source: fragment),
            (name: "MM_HATCH_DUTY", value: Shaders.hatchDuty, source: fragment),
            (name: "MM_RIM_LIFT", value: Shaders.rimLift, source: fragment),
            (name: "MM_RIM_ALPHA", value: Shaders.rimAlpha, source: fragment),
            (name: "MM_RIM_BEVEL", value: Shaders.rimBevel, source: fragment),
            (name: "MM_BLADE_SHEEN", value: Shaders.bladeSheen, source: fragment),
            (name: "MM_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "MM_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source), "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
    }

    @Test func materialCodesAreDistinctOrderedAndSelected() {
        var names: [String] = []
        var codes: [Float] = []
        for material in Material.allCases {
            names.append(String(describing: material))
            codes.append(material.code)
        }
        let expectedNames: [String] = [
            "backdrop", "paper", "ink", "inkFeather", "targetOutline", "missingDotted", "strayHatch", "forbiddenMark",
            "gearBody", "gearRim", "gearNotch", "blade", "lamp", "ladder", "cardLit", "cardUnlit", "cardBorder",
            "alignLit", "alignUnlit", "movesLit", "movesUnlit", "broken",
        ]
        #expect(names == expectedNames)
        #expect(Set(codes).count == codes.count)
        for (index, code) in codes.enumerated() { #expect(code == Float(index), "\(names[index])") }
        // Every code above the default (the backdrop) is selected in the vertex shader with its palette colour.
        let vertex: String = Shaders.clockworkVertex
        for material in Material.allCases where material != .backdrop {
            let selector: String = "isCode(m, \(Int(material.code)).0)"
            #expect(vertex.contains(selector), "\(material) not selected")
        }
        #expect(vertex.contains("vec3 base = mix(MM_NIGHT, mix(MM_PAPER, MM_GLOW, MM_WON_LIFT * won), isCode(m, 1.0));"))
        let selections: [(material: Material, constant: String)] = [
            (material: .ink, constant: "MM_INK"), (material: .inkFeather, constant: "MM_INK"),
            (material: .targetOutline, constant: "MM_TARGET"), (material: .missingDotted, constant: "MM_TARGET"),
            (material: .strayHatch, constant: "MM_STRAY"), (material: .forbiddenMark, constant: "MM_FORBIDDEN"),
            (material: .gearBody, constant: "MM_GEAR"), (material: .gearRim, constant: "MM_RIM"),
            (material: .gearNotch, constant: "MM_INK"), (material: .blade, constant: "MM_BLADE"),
            (material: .lamp, constant: "MM_LAMP"), (material: .ladder, constant: "MM_LAMP"),
            (material: .cardLit, constant: "MM_CARD_LIT"), (material: .cardUnlit, constant: "MM_CARD_UNLIT"),
            (material: .cardBorder, constant: "MM_RIM"), (material: .alignLit, constant: "MM_ALIGN_LIT"),
            (material: .alignUnlit, constant: "MM_ALIGN_UNLIT"), (material: .movesLit, constant: "MM_MOVES_LIT"),
            (material: .movesUnlit, constant: "MM_MOVES_UNLIT"), (material: .broken, constant: "MM_BROKEN"),
        ]
        #expect(selections.count == Material.allCases.count - 2)
        for entry in selections {
            let line: String = "base = mix(base, \(entry.constant), isCode(m, \(Int(entry.material.code)).0));"
            #expect(vertex.contains(line), "\(line)")
            var hit: Bool = false
            for constant in Shaders.paletteConstants where constant.name == entry.constant {
                hit = constant.colour == entry.material.colour
            }
            #expect(hit, "\(entry.material) colour")
        }
        #expect(Material.gearBody.alpha == Palette.gearAlpha)
        #expect(Material.blade.alpha == Palette.bladeAlpha)
        #expect(Material.ink.alpha == 1)
        #expect(Material.inkFeather.localCoordinate == .feather)
        #expect(Material.paper.localCoordinate == .none)
        #expect(Material.gearRim.localCoordinate == .strip)
        #expect(Material.gearBody.localCoordinate == .fan)
    }

    @Test func signedDistanceShadingReferences() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        #expect(Shaders.featherCoverage(local: 0) == 1)
        #expect(Shaders.featherCoverage(local: 1) == 0)
        #expect(abs(Shaders.featherCoverage(local: 0.5) - 0.5) < 1e-12)
        #expect(Shaders.dotCoverage(x: 0.0, y: 0.006) == 0)
        #expect(Shaders.dotCoverage(x: 0.0, y: 0.021) == 1)
        #expect(Shaders.hatchCoverage(x: 0.005, y: 0.0) == 1)
        #expect(Shaders.hatchCoverage(x: 0.02, y: 0.0) == 0)
        let centre: (colour: SIMD3<Double>, alpha: Double) = Shaders.gearBodyShade(local: 0)
        #expect(centre.colour == Palette.gear)
        #expect(centre.alpha == Palette.gearAlpha)
        let rim: (colour: SIMD3<Double>, alpha: Double) = Shaders.gearBodyShade(local: 1)
        #expect(rim.alpha > centre.alpha)
        #expect(rim.alpha <= 1)
        #expect(rim.colour.x > rim.colour.z + 0.08)
        let fragment: String = Shaders.clockworkFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - MM_EDGE_FEATHER, 1.0, d);",
            "float feather = 1.0 - smoothstep(0.0, 1.0, d);",
            "float dots = step(MM_DOT_DUTY, fract((v_wall.x + v_wall.y) / MM_DOT_PERIOD));",
            "float hatch = 1.0 - step(MM_HATCH_DUTY, fract((v_wall.x - v_wall.y) / MM_HATCH_PERIOD));",
            "float fresnel = d2 * d2 * isBody;",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func aWonLevelLiftsTheWallAndItsGlow() {
        #expect(Shaders.paperColour(won: 0) == Palette.paper)
        let lifted: SIMD3<Double> = Shaders.paperColour(won: 1)
        let expected: SIMD3<Double> = Palette.paper + (Palette.glow - Palette.paper) * Shaders.wonLift
        #expect(Self.distance(lifted, expected) < 1e-12)
        #expect(Shaders.paperColour(won: Double.nan) == Palette.paper)
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let notWon: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .wall, factor: 1, radius: 0, gain: 1.5,
                                                       won: 0)
        #expect(notWon.w == 0)
        let won: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .wall, factor: 1, radius: 0, gain: 1.5, won: 1)
        #expect(won.w > 0)
        let lamp: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .lamp, factor: 1, radius: 0, gain: 1, won: 0)
        #expect(lamp.w > 0)
        #expect(SIMD3<Double>(lamp.x, lamp.y, lamp.z) == Palette.lampGlow)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .card, factor: 1, radius: 1, gain: 1, won: 0)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.glowFragment.contains("float fade = r * r * mix(1.0, won, isWall);"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        let gains: [Double] = [Shaders.glowGain(for: MoonlitMechanismTier.of(0)),
                               Shaders.glowGain(for: MoonlitMechanismTier.of(1)),
                               Shaders.glowGain(for: MoonlitMechanismTier.of(2))]
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowLimit(reduceFlashing: false) == Shaders.standardGlowLimit)
        #expect(Shaders.glowLimit(reduceFlashing: true) == Shaders.glowGainCap)
        #expect(Shaders.glowGainCap == 0.5)
        for gain in gains {
            let capped: Double = Shaders.glowGain(gain: gain, limit: Shaders.glowLimit(reduceFlashing: true))
            #expect(capped <= Shaders.glowGainCap)
            let glow: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .wall, factor: 1,
                                                         radius: 0, gain: capped, won: 1)
            #expect(glow.w <= Shaders.glowWeight * Shaders.glowGainCap + 1e-12)
        }
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        let line: String = "float gain = min(clamp(u_glowGain, 0.0, MM_MAX_GAIN), clamp(u_glowLimit, 0.0, MM_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// A real front-end compile with `glslangValidator` when it is installed (macOS only; skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { tool = path }
        guard let validator = tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mm-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "clockwork.vert", source: Shaders.clockworkVertex),
            (name: "clockwork.frag", source: Shaders.clockworkFragment),
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
