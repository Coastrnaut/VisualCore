// MushroomWeatherShaderSourceTests — feature 493 (R02-G20-03) T-R02G2003-003 (FR-R02G2003-001, 002, 004, 007;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and used in its stage, the time input
// only in the forest vertex stage and multiplied by the motion (Reduce Motion), at most 16 vec4 uniform slots per
// program, no texture sampler, no `discard`, no loop (so no unbounded one), no reserved word used as a name, vertex
// outputs matching fragment inputs, balanced braces, ASCII-only sources, the attribute names and locations (the
// `ShaderMeshRenderer` streams), the material code table (distinct, ordered 0 … 30, each selected by the vertex shader
// with its palette colour and handled exactly once by the fragment shader), the value and broken mark carried in uv,
// the GLSL palette constants generated from `MushroomWeatherPalette` and parsing back within 1e-6, the layered solids
// (flat on level-2), the translucent caps with moisture beads whose density follows h/M, the signed-distance quad
// shapes inside the quad extent, the still backdrop gradient, the droplets and motes moved by time and stopped under
// Reduce Motion, the won level lighting every cap, the glow per kind, the glow gain per tier (0 at level-2) and the
// Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of each source (skipped
// otherwise). Test data uses explicit types and plain loops (CI type-check rule).
//
// Feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-002, 005, 006): the table now runs 0 … 30 — the ghost pod (29, a
// disc at the ghost opacity in the pod colour) and the scrubber (30, a strip in the moon colour) appended after the
// mold patch, every earlier code, the value scale and the broken offset unchanged.
import Foundation
import Testing
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherShaderSourceTests {
    typealias Shaders = MushroomWeatherShaders
    typealias Palette = MushroomWeatherPalette
    typealias Material = MushroomWeatherMaterial

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "forest", vertex: Shaders.forestVertex, fragment: Shaders.forestFragment,
                 uniforms: Shaders.forestUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.forestVertex, Shaders.forestFragment, Shaders.glowVertex, Shaders.glowFragment]
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
        let constants: [String] = [Shaders.mvpUniform, Shaders.timeUniform, Shaders.motionUniform, Shaders.wonUniform,
                                   Shaders.glowGainUniform, Shaders.glowLimitUniform]
        #expect(constants == ["u_mvp", "u_time", "u_motion", "u_won", "u_glowGain", "u_glowLimit"])
        #expect(Set(constants) == Set(Shaders.forestUniforms + Shaders.glowUniforms))
        #expect(Shaders.forestUniforms == ["u_mvp", "u_time", "u_motion", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.forestVertex) == ["u_mvp", "u_time", "u_motion", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.forestFragment).isEmpty)
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won"])
        // Time moves only the forest vertex stage, always times the motion (Reduce Motion stops it).
        #expect(Self.wordCount("u_time", in: Shaders.forestVertex) == 2)
        #expect(Shaders.forestVertex.contains("float clock = max(u_time, 0.0) * clamp(u_motion, 0.0, 1.0);"))
        let timeless: [String] = [Shaders.forestFragment, Shaders.glowVertex, Shaders.glowFragment]
        for source in timeless {
            #expect(Self.wordCount("u_time", in: source) == 0)
            #expect(Self.wordCount("u_motion", in: source) == 0)
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
        #expect(slotsByProgram == ["forest": 7, "glow": 7])
    }

    @Test func noTextureSamplerNoDiscardNoLoopsAndNoReservedNames() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture"))
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("discard", in: source) == 0)
            #expect(Self.wordCount("break", in: source) == 0)
            // GLSL ES 3.00 reserved words and built-in function names never used as names.
            let reserved: [String] = [
                "flat", "smooth", "centroid", "sample", "input", "output", "filter", "distance", "fixed", "half",
                "patch", "active", "common", "partition", "long", "short", "double", "unsigned", "superp", "inline",
                "static", "public", "external", "interface", "class", "union", "enum", "typedef", "template", "this",
                "goto", "resource", "cast", "namespace", "using", "sizeof", "noperspective", "volatile", "precise",
            ]
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
            // Every statement line inside a function ends with a semicolon or a brace.
            for line in Self.lines(source) where !line.hasPrefix("#") {
                let last: Character? = line.last
                #expect(last == ";" || last == "{" || last == "}", "\(line)")
            }
        }
        for program in Self.programs() {
            let outs: [String: String] = Self.interface("out", in: program.vertex)
            let ins: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outs == ins, "\(program.name)")
            #expect(Self.interface("out", in: program.fragment) == ["color": "vec4"], "\(program.name)")
            #expect(program.fragment.contains("color = vec4(rgb * alpha, alpha);"), "\(program.name) premultiplied")
        }
        let forestOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_material": "float", "v_local": "float", "v_value": "float",
        ]
        #expect(Self.interface("out", in: Shaders.forestVertex) == forestOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.forestVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.forestFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.forestVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        let forest: String = Shaders.forestVertex
        let forestLines: [String] = [
            "float coded = clamp(floor(a_uv.x + 0.5), 0.0, MW_BROKEN_OFFSET + MW_MAX_MATERIAL);",
            "float marked = step(MW_BROKEN_OFFSET - 0.5, coded);",
            "float m = clamp(coded - MW_BROKEN_OFFSET * marked, 0.0, MW_MAX_MATERIAL);",
            "float value = clamp((a_uv.x - coded) / MW_VALUE_SCALE, 0.0, 1.0);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "v_aux = a_normal;",
            "float won = clamp(u_won, 0.0, 1.0);",
            "base = mix(base, MW_BROKEN, marked);",
            "gl_Position = u_mvp * vec4(p, 1.0);",
        ]
        for line in forestLines { #expect(forest.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("float x = clamp(a_uv.x, 0.0, 3.0);"))
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 1.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "MW_MIDNIGHT", colour: Palette.midnight), (name: "MW_MIDNIGHT_TOP", colour: Palette.midnightTop),
            (name: "MW_MOON", colour: Palette.moon), (name: "MW_MOSS", colour: Palette.moss),
            (name: "MW_LOG", colour: Palette.log), (name: "MW_FROND", colour: Palette.frond),
            (name: "MW_MIST_LOW", colour: Palette.mistLow), (name: "MW_MIST_HIGH", colour: Palette.mistHigh),
            (name: "MW_SITE", colour: Palette.site), (name: "MW_STALK", colour: Palette.stalk),
            (name: "MW_CAP", colour: Palette.cap), (name: "MW_CAP_OUT", colour: Palette.capOut),
            (name: "MW_POD", colour: Palette.pod), (name: "MW_DROPLET", colour: Palette.droplet),
            (name: "MW_VENT", colour: Palette.vent), (name: "MW_BAND", colour: Palette.band),
            (name: "MW_MARKER", colour: Palette.marker), (name: "MW_ACTIONS_LIT", colour: Palette.actionsLit),
            (name: "MW_ACTIONS_UNLIT", colour: Palette.actionsUnlit), (name: "MW_BROKEN", colour: Palette.broken),
            (name: "MW_GLOW", colour: Palette.glow),
        ]
        #expect(palette.count == 21)
        #expect(Palette.all.count == 21)
        #expect(Shaders.paletteConstants.count == palette.count)
        var tableNames: Set<String> = []
        for (index, entry) in Shaders.paletteConstants.enumerated() {
            tableNames.insert(entry.name)
            #expect(entry.name == palette[index].name)
            #expect(entry.colour == palette[index].colour, "\(entry.name)")
            #expect(entry.name == Shaders.constantName(Palette.all[index].name))
            var found: Int = 0
            for source in Self.sources() {
                guard let parsed = Self.vec3Constant(entry.name, in: source) else { continue }
                found += 1
                #expect(Self.gap(parsed, entry.colour) <= tolerance, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
            // The forest vertex shader carries the whole generated palette.
            #expect(Self.vec3Constant(entry.name, in: Shaders.forestVertex) != nil, "\(entry.name)")
        }
        #expect(tableNames.count == palette.count)
        // Every vec3 constant in every source is a palette colour with the table's value, or the view direction.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "MW_VIEW_DIR" {
                    #expect(Self.gap(parsed, Shaders.viewDirection) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.gap(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals; every hex parses to its colour.
        for entry in Palette.all {
            let hex: String = String(entry.hex.dropFirst())
            let value: Int = try #require(Int(hex, radix: 16), "\(entry.hex)")
            let colour: SIMD3<Double> = SIMD3<Double>(Double((value >> 16) & 0xFF) / 255,
                                                      Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
            #expect(Self.gap(colour, entry.colour) < 1e-12, "\(entry.name)")
        }
        let vertex: String = Shaders.forestVertex
        #expect(vertex.contains("const vec3 MW_MIDNIGHT = vec3(0.019608, 0.039216, 0.101961);"))
        #expect(vertex.contains("const vec3 MW_CAP = vec3(0.372549, 0.827451, 0.627451);"))
        let fragment: String = Shaders.forestFragment
        #expect(fragment.contains("const vec3 MW_MIDNIGHT_TOP = vec3(0.054902, 0.101961, 0.200000);"))
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "MW_MAX_MATERIAL", value: 30, source: vertex),
            (name: "MW_BROKEN_OFFSET", value: Shaders.brokenOffset, source: vertex),
            (name: "MW_VALUE_SCALE", value: Shaders.valueScale, source: vertex),
            (name: "MW_DROPLET_RATE", value: Shaders.dropletRate, source: vertex),
            (name: "MW_MOTE_RATE", value: Shaders.moteRate, source: vertex),
            (name: "MW_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "MW_MARK_FEATHER", value: Shaders.markFeather, source: fragment),
            (name: "MW_RING_HALF", value: Shaders.ringHalf, source: fragment),
            (name: "MW_DASH_COUNT", value: Shaders.dashCount, source: fragment),
            (name: "MW_DASH_DUTY", value: Shaders.dashDuty, source: fragment),
            (name: "MW_DASH_FEATHER", value: Shaders.dashFeather, source: fragment),
            (name: "MW_BRACKET_BAR", value: Shaders.bracketBar, source: fragment),
            (name: "MW_BRACKET_END", value: Shaders.bracketEnd, source: fragment),
            (name: "MW_MOLD_LOBES", value: Shaders.moldLobes, source: fragment),
            (name: "MW_MOLD_WOBBLE", value: Shaders.moldWobble, source: fragment),
            (name: "MW_LIMB_SHADE", value: Shaders.limbShade, source: fragment),
            (name: "MW_LIMB_EDGE", value: Shaders.limbEdge, source: fragment),
            (name: "MW_CORE_START", value: Shaders.coreStart, source: fragment),
            (name: "MW_CORE_LIFT", value: Shaders.coreLift, source: fragment),
            (name: "MW_RIM_POWER", value: Shaders.rimPower, source: fragment),
            (name: "MW_RIM_LIFT", value: Shaders.rimLift, source: fragment),
            (name: "MW_CAP_ALPHA", value: Shaders.capAlpha, source: fragment),
            (name: "MW_BEAD_COLUMNS", value: Shaders.beadColumns, source: fragment),
            (name: "MW_BEAD_ROWS", value: Shaders.beadRows, source: fragment),
            (name: "MW_BEAD_MIN", value: Shaders.beadMin, source: fragment),
            (name: "MW_BEAD_MAX", value: Shaders.beadMax, source: fragment),
            (name: "MW_BEAD_RADIUS", value: Shaders.beadRadius, source: fragment),
            (name: "MW_BEAD_FEATHER", value: Shaders.beadFeather, source: fragment),
            (name: "MW_BEAD_LIFT", value: Shaders.beadLift, source: fragment),
            (name: "MW_MIST_ALPHA", value: Shaders.mistAlpha, source: fragment),
            (name: "MW_DROPLET_FADE_IN", value: Shaders.dropletFadeIn, source: fragment),
            (name: "MW_GHOST_ALPHA", value: Shaders.ghostAlpha, source: fragment),
            (name: "MW_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "MW_GLOW_CORE", value: Shaders.glowCore, source: glowF),
            (name: "MW_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let value: Double? = Self.scalarConstant("float", entry.name, in: entry.source)
            let parsed: Double = try #require(value, "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
        // The view direction points from the target toward the authored eye.
        let eye: SIMD3<Double> = SIMD3<Double>(0, -1.4, 3.0)
        let unitEye: SIMD3<Double> = eye / (eye * eye).sum().squareRoot()
        #expect(Self.gap(Shaders.viewDirection, unitEye) < 1e-12)
    }

    @Test func materialCodeTableIsConsistent() {
        let names: [String] = [
            "backdrop", "moon", "phaseTickLit", "phaseTickUnlit", "floor", "log", "stone", "frond", "mist",
            "siteRing", "stalk", "cap", "capOut", "bandRingSolid", "bandRingDashed", "pod", "podRing", "droplet",
            "mote", "ventFrame", "ventSlat", "gaugeTrack", "bandBracket", "marker", "runLit", "runUnlit", "barLit",
            "barUnlit", "moldPatch", "ghostPod", "scrubber",
        ]
        #expect(Material.allCases.count == names.count)
        #expect(Shaders.materials.count == names.count)
        #expect(Shaders.maxMaterial == names.count - 1)
        #expect(Shaders.brokenOffset > Double(Shaders.maxMaterial) + 1)
        var codes: Set<Float> = []
        for (index, material) in Material.allCases.enumerated() {
            codes.insert(material.code)
            #expect(material.rawValue == index)
            #expect(material.code == Float(index))
            #expect("\(material)" == names[index])
            #expect(Shaders.materials[index].name == names[index])
            #expect(Shaders.materials[index].code == material.code)
            #expect(Shaders.materials[index].constant == material.paletteConstant)
            var known: Bool = false
            for constant in Shaders.paletteConstants where constant.name == material.paletteConstant {
                known = true
                #expect(material.baseColour == constant.colour, "\(material)")
            }
            #expect(known, "\(material) selects \(material.paletteConstant)")
        }
        #expect(codes.count == names.count)
        // The vertex shader selects every material's colour with its code, in code order.
        let vertex: String = Shaders.forestVertex
        #expect(vertex.contains("vec3 base = MW_MIDNIGHT;"))
        #expect(Material.backdrop.paletteConstant == "MW_MIDNIGHT")
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
        let fragment: String = Shaders.forestFragment
        for material in Material.allCases {
            let token: String = "isCode(m, \(material.rawValue).0)"
            #expect(Self.occurrences(token, in: fragment) == 1, "\(material) handled \(token)")
        }
        #expect(Self.occurrences("isCode(m, 31.0)", in: fragment) == 0)
        // The design's colours per element (clarification Q1).
        let expected: [(material: Material, colour: SIMD3<Double>)] = [
            (material: .moon, colour: Palette.moon), (material: .floor, colour: Palette.moss),
            (material: .log, colour: Palette.log), (material: .stone, colour: Palette.log),
            (material: .frond, colour: Palette.frond), (material: .mist, colour: Palette.mistLow),
            (material: .siteRing, colour: Palette.site), (material: .stalk, colour: Palette.stalk),
            (material: .cap, colour: Palette.cap), (material: .capOut, colour: Palette.capOut),
            (material: .bandRingSolid, colour: Palette.band), (material: .bandRingDashed, colour: Palette.band),
            (material: .pod, colour: Palette.pod), (material: .podRing, colour: Palette.pod),
            (material: .droplet, colour: Palette.droplet), (material: .ventSlat, colour: Palette.vent),
            (material: .ventFrame, colour: Palette.vent), (material: .bandBracket, colour: Palette.band),
            (material: .marker, colour: Palette.marker), (material: .barLit, colour: Palette.actionsLit),
            (material: .barUnlit, colour: Palette.actionsUnlit), (material: .moldPatch, colour: Palette.broken),
            (material: .ghostPod, colour: Palette.pod), (material: .scrubber, colour: Palette.moon),
        ]
        for entry in expected { #expect(entry.material.baseColour == entry.colour, "\(entry.material)") }
        // Frame checks (clarification Q3): the lit bar reads amber (red above blue by 0.08); the gauge track differs
        // from the backdrop by 0.1; a cap (in band or lit) is brighter than the moss by 0.2.
        #expect(Palette.actionsLit.x - Palette.actionsLit.z >= 0.08)
        #expect(Self.luminance(Material.gaugeTrack.baseColour) - Self.luminance(Palette.midnightTop) >= 0.1)
        #expect(Self.luminance(Palette.cap) - Self.luminance(Palette.moss) >= 0.2)
        #expect(Self.luminance(Palette.capOut) - Self.luminance(Palette.moss) >= 0.2)
    }

    @Test func theValueAndTheBrokenMarkTravelInUV() {
        let steps: Int = 10
        for material in Material.allCases {
            let flags: [Bool] = [false, true]
            for broken in flags {
                for step in 0...steps {
                    let value: Double = Double(step) / Double(steps)
                    let x: Double = Shaders.encode(material, value: value, broken: broken)
                    let decoded: (material: Material, value: Double, broken: Bool) = Shaders.decode(x)
                    #expect(decoded.material == material, "\(material) \(broken) \(value)")
                    #expect(decoded.broken == broken, "\(material) \(broken) \(value)")
                    let carried: Double = material.isValued ? value : 0
                    #expect(abs(decoded.value - carried) < 1e-12, "\(material) \(value)")
                    // Through the Float of the uv stream the value is kept within 1e-4.
                    let stream: Float = Float(x)
                    let floatDecoded: (material: Material, value: Double, broken: Bool) =
                        Shaders.decode(Double(stream))
                    #expect(floatDecoded.material == material)
                    #expect(floatDecoded.broken == broken)
                    #expect(abs(floatDecoded.value - carried) < 1e-4)
                }
            }
        }
        var valued: [Material] = []
        for material in Material.allCases where material.isValued { valued.append(material) }
        #expect(valued == [.moon, .mist, .cap, .capOut, .droplet, .mote])
        #expect(Shaders.valueScale < 0.5)
        #expect(Shaders.encode(.cap, value: Double.nan) == 11)
        #expect(Shaders.encode(.cap, value: 7) == 11 + Shaders.valueScale)
        #expect(Shaders.encode(.floor, value: 0.5) == 4)
        #expect(Shaders.encode(.stalk, broken: true) == 42)
        #expect(Shaders.decode(Double.nan).material == .backdrop)
        #expect(Shaders.decode(-4).material == .backdrop)
        #expect(Shaders.decode(28).material == .moldPatch)
        #expect(Shaders.decode(30).material == .scrubber)
        #expect(Shaders.decode(30).broken == false)
        #expect(Shaders.decode(31).material == .scrubber)
        #expect(Shaders.decode(31).broken == false)
        #expect(Shaders.decode(999).material == .scrubber)
        #expect(Shaders.decode(999).broken == true)
        // Moon brightness (4 + L) / 7, moisture h/M.
        #expect(Shaders.moonBrightness(moonlight: 0) == 4.0 / 7.0)
        #expect(Shaders.moonBrightness(moonlight: 3) == 1)
        #expect(Shaders.moonBrightness(moonlight: -2) == 4.0 / 7.0)
        #expect(Shaders.moonBrightness(moonlight: 9) == 1)
        #expect(Shaders.moisture(humidity: 5, moldBound: 10) == 0.5)
        #expect(Shaders.moisture(humidity: 20, moldBound: 10) == 1)
        #expect(Shaders.moisture(humidity: 3, moldBound: 0) == 0)
        // Base colours: broken wins; mist shade by h/M; the moon by its brightness; capOut lit by a won level.
        #expect(Shaders.baseColour(of: .cap, value: 0.3, broken: true, won: 0) == Palette.broken)
        #expect(Shaders.baseColour(of: .mist, value: 0, broken: false, won: 0) == Palette.mistLow)
        #expect(Self.gap(Shaders.baseColour(of: .mist, value: 1, broken: false, won: 0), Palette.mistHigh) < 1e-12)
        let dim: SIMD3<Double> = Shaders.baseColour(of: .moon, value: Shaders.moonBrightness(moonlight: 0),
                                                    broken: false, won: 0)
        #expect(Self.luminance(dim) < Self.luminance(Palette.moon))
        // The moon at its dimmest still differs from the backdrop by more than the frame check's 0.1.
        #expect(Self.luminance(dim) - Self.luminance(Palette.midnightTop) >= 0.1)
        let vertex: String = Shaders.forestVertex
        #expect(vertex.contains("base = mix(base, MW_MIST_HIGH, isCode(m, 8.0) * value);"))
        #expect(vertex.contains("base = base * mix(1.0, value, isCode(m, 1.0));"))
    }

    @Test func aWonLevelLightsEveryCap() {
        #expect(Shaders.baseColour(of: .capOut, value: 0.5, broken: false, won: 0) == Palette.capOut)
        #expect(Self.gap(Shaders.baseColour(of: .capOut, value: 0.5, broken: false, won: 1), Palette.cap) < 1e-12)
        #expect(Shaders.baseColour(of: .cap, value: 0.5, broken: false, won: 1) == Palette.cap)
        #expect(Shaders.baseColour(of: .stalk, value: 0, broken: false, won: 1) == Palette.stalk)
        #expect(Shaders.baseColour(of: .capOut, value: 0, broken: false, won: Double.nan) == Palette.capOut)
        let vertex: String = Shaders.forestVertex
        let capOut: String = "base = mix(base, MW_CAP_OUT, isCode(m, 12.0));"
        let lit: String = "base = mix(base, MW_CAP, isCode(m, 12.0) * won);"
        #expect(vertex.contains(lit))
        if let a = vertex.range(of: capOut), let b = vertex.range(of: lit) {
            #expect(a.upperBound <= b.lowerBound)
        }
        // The glow raises every cap shell to full on a won level; pods keep their factor.
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let out: Double = Shaders.glowFactor(inBand: false)
        #expect(out == Shaders.capOutGlowFactor)
        #expect(Shaders.glowFactor(inBand: true) == 1)
        let rest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cap, factor: out, radius: 0, gain: 1, won: 0)
        let won: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cap, factor: out, radius: 0, gain: 1, won: 1)
        #expect(abs(rest.w - Shaders.glowWeight * out) < 1e-12)
        #expect(abs(won.w - Shaders.glowWeight) < 1e-12)
        let pod: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .pod, factor: 0.5, radius: 0, gain: 1, won: 1)
        #expect(abs(pod.w - Shaders.glowWeight * 0.5) < 1e-12)
        #expect(Shaders.glowFragment.contains("float factor = mix(clamp(v_factor, 0.0, 1.0), 1.0, won * isCap);"))
    }

    @Test func solidsAreShadedInLayersFromTheNormalAndFlatOnLevelTwo() {
        let solids: [Material] = [.log, .stone, .stalk, .cap, .capOut, .pod]
        for material in solids {
            let base: SIMD3<Double> = material.baseColour
            let core: SIMD3<Double> = Shaders.solidShade(material, mu: 1)
            let mid: SIMD3<Double> = Shaders.solidShade(material, mu: 0.6)
            let limb: SIMD3<Double> = Shaders.solidShade(material, mu: 0.25)
            let expectedCore: SIMD3<Double> = base + (SIMD3<Double>(1, 1, 1) - base) * Shaders.coreLift
            #expect(Self.gap(core, expectedCore) < 1e-12, "\(material)")
            #expect(Self.luminance(core) >= Self.luminance(mid), "\(material)")
            // Limb darkening shows on the bright solids (on the dark log and stone the rim light dominates).
            if material == .stalk || material == .cap || material == .pod {
                #expect(Self.luminance(mid) > Self.luminance(limb), "\(material)")
            }
            #expect(Self.gap(Shaders.solidShade(material, normal: Shaders.viewDirection), core) < 1e-9)
            #expect(Shaders.solidShade(material, mu: Double.nan) == core)
            // A flat level-2 solid writes a zero normal: shaded flat in its base colour.
            #expect(Shaders.solidShade(material, normal: SIMD3<Double>(0, 0, 0)) == base)
            #expect(Shaders.solidShade(material, normal: SIMD3<Double>(Double.nan, 0, 1)) == base)
            let shade: SIMD3<Double> = base * Shaders.limbShade
            let rim: SIMD3<Double> = shade + (Palette.glow - shade) * Shaders.rimLift
            #expect(Self.gap(Shaders.solidShade(material, mu: 0), rim) < 1e-12, "\(material)")
        }
        // A cap's top (normal +z) under the authored camera stays far brighter than the moss, shaded or flat.
        let moss: Double = Self.luminance(Palette.moss)
        let top: SIMD3<Double> = Shaders.solidShade(.cap, normal: SIMD3<Double>(0, 0, 1))
        #expect(Self.luminance(top) - moss >= 0.2)
        #expect(Self.luminance(Shaders.solidShade(.cap, normal: SIMD3<Double>(0, 0, 0))) - moss >= 0.2)
        // Over the moss at its core opacity the cap still clears the frame check's 0.2.
        let alpha: Double = Shaders.capOpacity(mu: (SIMD3<Double>(0, 0, 1) * Shaders.viewDirection).sum())
        let blended: SIMD3<Double> = top * alpha + Palette.moss * (1 - alpha)
        #expect(Self.luminance(blended) - moss >= 0.2)
        let fragment: String = Shaders.forestFragment
        let lines: [String] = [
            "float shaded = step(0.0001, nl);",
            "vec3 body = mix(v_base * MW_LIMB_SHADE, v_base, smoothstep(0.0, MW_LIMB_EDGE, mu));",
            "body = mix(body, vec3(1.0), MW_CORE_LIFT * smoothstep(MW_CORE_START, 1.0, mu));",
            "body = mix(body, MW_GLOW, MW_RIM_LIFT * rim);",
            "vec3 solidRgb = mix(v_base, body, shaded);",
            "rgb = mix(rgb, solidRgb, solid);",
            "coverage = coverage + edge * (solid + strip) + edge * capAlpha * isCap;",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func capsAreTranslucentWithMoistureBeadsFollowingHumidity() {
        // Opacity: capAlpha at the core, 1 at the rim; flat caps opaque.
        #expect(abs(Shaders.capOpacity(mu: 1) - Shaders.capAlpha) < 1e-12)
        #expect(Shaders.capOpacity(mu: 0) == 1)
        #expect(Shaders.capAlpha < 1)
        #expect(Shaders.capOpacity(mu: Double.nan) == Shaders.capAlpha)
        // Density follows h/M.
        #expect(Shaders.beadDensity(moisture: 0) == Shaders.beadMin)
        #expect(Shaders.beadDensity(moisture: 1) == Shaders.beadMax)
        #expect(Shaders.beadDensity(moisture: Double.nan) == Shaders.beadMin)
        #expect(Shaders.beadMin < Shaders.beadMax)
        // Over a fixed sample of the upper hemisphere, the share of points on a bead grows with the moisture.
        var previous: Int = -1
        let moistures: [Double] = [0, 0.5, 1]
        for moisture in moistures {
            var hits: Int = 0
            for i in 0..<60 {
                for j in 1..<30 {
                    let azimuth: Double = 2 * Double.pi * Double(i) / 60
                    let polar: Double = 1.4 * Double(j) / 30
                    let n: SIMD3<Double> = SIMD3<Double>(sin(polar) * cos(azimuth), sin(polar) * sin(azimuth),
                                                         cos(polar))
                    if Shaders.beadCoverage(normal: n, moisture: moisture) > 0.5 { hits += 1 }
                }
            }
            #expect(hits > previous, "\(moisture): \(hits)")
            previous = hits
        }
        #expect(previous > 0)
        // No beads on a flat cap.
        #expect(Shaders.beadCoverage(normal: SIMD3<Double>(0, 0, 0), moisture: 1) == 0)
        #expect(Shaders.beadCoverage(normal: SIMD3<Double>(Double.nan, 0, 1), moisture: 1) == 0)
        // The hash is in 0 ..< 1.
        for x in -5...5 {
            for y in -5...5 {
                let h: Double = Shaders.beadHash(x: Double(x), y: Double(y))
                #expect(h >= 0 && h < 1)
            }
        }
        let fragment: String = Shaders.forestFragment
        let lines: [String] = [
            "return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);",
            "float density = mix(MW_BEAD_MIN, MW_BEAD_MAX, value);",
            "float present = step(beadHash(floor(q)), density);",
            "vec3 capRgb = mix(solidRgb, vec3(1.0), MW_BEAD_LIFT * bead * shaded);",
            "float capAlpha = mix(1.0, mix(MW_CAP_ALPHA, 1.0, rim), shaded);",
            "rgb = mix(rgb, capRgb, isCap);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func signedDistanceQuadShapesStayInsideTheQuad() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        #expect(Shaders.quadCoverage(.floor, u: 0.9, v: -0.9) == 1)
        #expect(Shaders.quadCoverage(.floor, u: 1.2, v: 0) == 0)
        #expect(abs(Shaders.quadCoverage(.mist, u: 0, v: 0) - Shaders.mistAlpha) < 1e-12)
        #expect(Shaders.quadCoverage(.marker, u: 0, v: 0) == 1)
        #expect(Shaders.quadCoverage(.marker, u: 0.8, v: 0.8) == 0)
        #expect(Shaders.quadCoverage(.siteRing, u: 0, v: 0) == 0)
        #expect(Shaders.quadCoverage(.siteRing, u: 1 - Shaders.ringHalf, v: 0) == 1)
        #expect(Shaders.quadCoverage(.phaseTickUnlit, u: 0, v: 0) == 0)
        #expect(Shaders.quadCoverage(.phaseTickLit, u: 0, v: 0) == 1)
        #expect(Shaders.quadCoverage(.moldPatch, u: 0, v: 0) == 1)
        #expect(Shaders.quadCoverage(.stalk, u: 0, v: 0) == 0)
        #expect(Shaders.quadCoverage(.floor, u: Double.nan, v: 0) == 0)
        // Bracket: the bar along the top and the end ticks, empty in the middle below the bar.
        #expect(Shaders.quadCoverage(.bandBracket, u: 0, v: 0.8) == 1)
        #expect(Shaders.quadCoverage(.bandBracket, u: 0.88, v: -0.8) == 1)
        #expect(Shaders.quadCoverage(.bandBracket, u: 0, v: -0.5) == 0)
        // Dashed ring: a dash and a gap at mid-radius, about dashDuty of the circle drawn.
        let mid: Double = 1 - Shaders.ringHalf
        var drawn: Int = 0
        let samples: Int = 720
        for i in 0..<samples {
            let a: Double = 2 * Double.pi * (Double(i) + 0.5) / Double(samples)
            if Shaders.quadCoverage(.bandRingDashed, u: mid * cos(a), v: mid * sin(a)) > 0.5 { drawn += 1 }
        }
        let share: Double = Double(drawn) / Double(samples)
        #expect(abs(share - Shaders.dashDuty) < 0.05, "\(share)")
        #expect(Shaders.quadCoverage(.bandRingSolid, u: mid, v: 0) == 1)
        // Every quad shape fits inside the quad the geometry spans, with room for the feather.
        let quads: [Material] = [
            .moon, .phaseTickLit, .phaseTickUnlit, .floor, .mist, .siteRing, .bandRingSolid, .bandRingDashed, .podRing,
            .droplet, .mote, .ventSlat, .bandBracket, .marker, .runLit, .runUnlit, .barLit, .barUnlit, .moldPatch,
            .ghostPod,
        ]
        #expect(quads.count == 20)
        for material in Material.allCases where !quads.contains(material) {
            #expect(Shaders.quadCoverage(material, u: 0, v: 0) == 0, "\(material)")
            #expect(Shaders.quadCoverage(material, u: mid, v: 0) == 0, "\(material)")
        }
        let e: Double = Shaders.quadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges {
                for shape in quads {
                    #expect(Shaders.quadCoverage(shape, u: p.x, v: p.y) == 0, "\(shape) \(p)")
                }
            }
        }
        let fragment: String = Shaders.forestFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - MW_EDGE_FEATHER, 1.0, d);",
            "float squareCover = cover(1.0 - max(abs(p.x), abs(p.y)));",
            "float discCover = cover(1.0 - r);",
            "float ringCover = cover(MW_RING_HALF - abs(r - (1.0 - MW_RING_HALF)));",
            "float dash = smoothstep(-MW_DASH_FEATHER, MW_DASH_FEATHER, MW_DASH_DUTY * 0.5 - abs(t - 0.5));",
            "float arm = max(cover(p.y - MW_BRACKET_BAR), cover(abs(p.x) - MW_BRACKET_END));",
            "float moldCover = cover(1.0 - r - MW_MOLD_WOBBLE * sin(MW_MOLD_LOBES * ang));",
            "coverage = coverage + squareCover * square + squareCover * MW_MIST_ALPHA * isMist;",
            "coverage = coverage + ringCover * ring + ringCover * dash * dashed;",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func theBackdropIsAStillGradient() {
        #expect(Self.gap(Shaders.backdropColour(height: 0), Palette.midnight) < 1e-12)
        #expect(Self.gap(Shaders.backdropColour(height: 1), Palette.midnightTop) < 1e-12)
        let middle: SIMD3<Double> = (Palette.midnight + Palette.midnightTop) * 0.5
        #expect(Self.gap(Shaders.backdropColour(height: 0.5), middle) < 1e-12)
        #expect(Shaders.backdropColour(height: Double.nan) == Palette.midnight)
        #expect(Shaders.backdropColour(height: 4) == Palette.midnightTop)
        let fragment: String = Shaders.forestFragment
        #expect(fragment.contains("vec3 backdrop = mix(MW_MIDNIGHT, MW_MIDNIGHT_TOP, h);"))
        #expect(fragment.contains("float sky = isCode(m, 0.0);"))
        #expect(fragment.contains("vec3 rgb = mix(v_base, backdrop, sky);"))
    }

    @Test func dropletsAndMotesMoveByTimeAndStopUnderReduceMotion() {
        #expect(Shaders.motion(reduceMotion: true) == 0)
        #expect(Shaders.motion(reduceMotion: false) == 1)
        let phases: [Double] = [0, 0.25, 0.7]
        let times: [Double] = [0, 0.4, 3.3, 59]
        for phase in phases {
            for time in times {
                // Stopped: at its phase whatever the time.
                #expect(abs(Shaders.dropletLife(phase: phase, time: time, motion: 0) - phase) < 1e-12)
                let still: SIMD2<Double> = Shaders.moteOffset(phase: phase, radius: 0.08, time: time, motion: 0)
                let start: SIMD2<Double> = Shaders.moteOffset(phase: phase, radius: 0.08, time: 0, motion: 1)
                #expect(abs(still.x - start.x) < 1e-12 && abs(still.y - start.y) < 1e-12)
                let life: Double = Shaders.dropletLife(phase: phase, time: time, motion: 1)
                #expect(life >= 0 && life < 1)
                let offset: SIMD2<Double> = Shaders.moteOffset(phase: phase, radius: 0.08, time: time, motion: 1)
                #expect((offset * offset).sum().squareRoot() <= 2 * 0.08 + 1e-12)
            }
        }
        // Moving: a droplet advances with time.
        let a: Double = Shaders.dropletLife(phase: 0.1, time: 0.2, motion: 1)
        #expect(abs(a - (0.1 + 0.2 * Shaders.dropletRate)) < 1e-12)
        let zero: SIMD2<Double> = Shaders.moteOffset(phase: 0, radius: 0.08, time: 0, motion: 1)
        #expect(abs(zero.x) < 1e-12 && abs(zero.y) < 1e-12)
        // The wrap period holds whole cycles of both, so wrapping never makes anything jump.
        let dropletCycles: Double = Shaders.timeWrap * Shaders.dropletRate
        let moteCycles: Double = Shaders.timeWrap * Shaders.moteRate
        #expect(abs(dropletCycles - dropletCycles.rounded()) < 1e-9)
        #expect(abs(moteCycles - moteCycles.rounded()) < 1e-9)
        #expect(Shaders.shaderTime(Shaders.timeWrap + 2.5) == 2.5)
        #expect(Shaders.shaderTime(-3) == 0)
        #expect(Shaders.shaderTime(Double.nan) == 0)
        #expect(Shaders.shaderTime(Double.infinity) == 0)
        // Fades: invisible at the start and the end of the life, visible between.
        #expect(Shaders.dropletFade(life: 0) == 0)
        #expect(Shaders.dropletFade(life: 1) == 0)
        #expect(Shaders.dropletFade(life: 0.4) > 0.5)
        // A droplet stays inside the camera box: the pod at 0.1 s plus its rise at the largest scale.
        let largest: Double = 1.8 / 6
        #expect(0.1 * largest + Shaders.dropletRise(scale: largest) <= 0.3)
        #expect(Shaders.dropletRise(scale: Double.nan) == 0)
        let vertex: String = Shaders.forestVertex
        let lines: [String] = [
            "float life = fract(value + clock * MW_DROPLET_RATE);",
            "float angle = MW_TAU * (value + clock * MW_MOTE_RATE);",
            "p.z = p.z + isDroplet * life * a_normal.z;",
            "p.xy = p.xy + isMote * a_normal.z * vec2(cos(angle) - 1.0, sin(angle));",
            "v_value = mix(value, life, isDroplet);",
        ]
        for line in lines { #expect(vertex.contains(line), "\(line)") }
        let fade: String = "float fade = smoothstep(0.0, MW_DROPLET_FADE_IN, value) * (1.0 - value);"
        #expect(Shaders.forestFragment.contains(fade))
    }

    @Test func glowShadesTheCapsAndThePods() {
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let cap: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cap, factor: 1, radius: 1, gain: 1, won: 0)
        #expect(SIMD3<Double>(cap.x, cap.y, cap.z) == Palette.cap)
        #expect(cap.w == 0)
        let pod: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .pod, factor: 1, radius: 1, gain: 1, won: 0)
        #expect(SIMD3<Double>(pod.x, pod.y, pod.z) == Palette.pod)
        let inner: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cap, factor: 1, radius: 0, gain: 1, won: 0)
        let lifted: SIMD3<Double> = Palette.cap + (Palette.glow - Palette.cap) * Shaders.glowCore
        #expect(Self.gap(SIMD3<Double>(inner.x, inner.y, inner.z), lifted) < 1e-12)
        #expect(abs(inner.w - Shaders.glowWeight) < 1e-12)
        let coloured: SIMD4<Double> = Shaders.glowColour(colour: Palette.site, kind: .cap, factor: 1, radius: 1,
                                                         gain: 1, won: 0)
        #expect(SIMD3<Double>(coloured.x, coloured.y, coloured.z) == Palette.site)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.allCases.count == 2)
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .cap)
        #expect(Shaders.GlowKind.decode(99).kind == .pod)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("vec3 fallback = mix(MW_CAP, MW_POD, isPod);"))
        #expect(glow.contains("rgb = mix(rgb, MW_GLOW, MW_GLOW_CORE * fade);"))
        #expect(glow.contains("float alpha = clamp(MW_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in MushroomWeatherTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowGain(for: MushroomWeatherTier.of(2)) == 0)
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
            "float gain = min(clamp(u_glowGain, 0.0, MW_MAX_GAIN), clamp(u_glowLimit, 0.0, MW_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("MushroomWeatherShaders.swift")
        let text: String = try String(contentsOf: core, encoding: .utf8)
        let metal: String = "import " + "Metal" + "Kit"
        #expect(!text.contains(metal))
        let denied: [String] = ["Project" + "M", "Preset" + "Library", "Milk" + "Drop"]
        for word in denied { #expect(!text.contains(word), "\(word)") }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            #expect(line.count <= 120, "\(line)")
        }
        #expect(text.contains("T-R02G2003-003"))
    }

    /// A real front-end compile with `glslangValidator` when it is installed (macOS only; skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { tool = path }
        guard let validator = tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mw-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "forest.vert", source: Shaders.forestVertex), (name: "forest.frag", source: Shaders.forestFragment),
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

    /// Feature 494 (R02-G20-04) T-R02G2004-002: the ghost pod and the scrubber materials appended after code 28.
    @Test func ghostPodAndScrubberMaterialsFollowTheEncodingContract() {
        #expect(Material.ghostPod.rawValue == 29)
        #expect(Material.scrubber.rawValue == 30)
        #expect(Shaders.maxMaterial == 30)
        #expect(Shaders.brokenOffset == 32)
        #expect(Double(Shaders.maxMaterial) + Shaders.valueScale < Shaders.brokenOffset - 0.5)
        #expect(!Material.ghostPod.isValued && !Material.scrubber.isValued)
        #expect(Shaders.encode(.ghostPod) == 29 && Shaders.encode(.scrubber, broken: true) == 62)
        // The ghost pod: a disc at the ghost opacity, empty outside the unit circle and inside the quad.
        #expect(abs(Shaders.quadCoverage(.ghostPod, u: 0, v: 0) - Shaders.ghostAlpha) < 1e-12)
        #expect(Shaders.quadCoverage(.ghostPod, u: 0.8, v: 0.8) == 0)
        #expect(Shaders.ghostAlpha > 0 && Shaders.ghostAlpha < 1)
        #expect(Shaders.quadCoverage(.scrubber, u: 0, v: 0) == 0)
        let fragment: String = Shaders.forestFragment
        #expect(fragment.contains("float isGhost = isCode(m, 29.0);"))
        #expect(fragment.contains("coverage = coverage + discCover * MW_GHOST_ALPHA * isGhost;"))
        let strip: String = "float strip = isCode(m, 7.0) + isCode(m, 19.0) + isCode(m, 21.0) + isCode(m, 30.0);"
        #expect(fragment.contains(strip))
        let vertex: String = Shaders.forestVertex
        #expect(vertex.contains("base = mix(base, MW_POD, isCode(m, 29.0));"))
        #expect(vertex.contains("base = mix(base, MW_MOON, isCode(m, 30.0));"))
        // The fallback colours the geometry writes for the two materials.
        #expect(MushroomWeatherSceneGeometry.colour(of: Shaders.encode(.ghostPod)) == Palette.pod)
        #expect(MushroomWeatherSceneGeometry.colour(of: Shaders.encode(.scrubber)) == Palette.moon)
    }
}
