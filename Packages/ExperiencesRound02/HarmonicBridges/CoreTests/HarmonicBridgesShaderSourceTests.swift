// HarmonicBridgesShaderSourceTests — feature 413 (R02-G12-03) T-R02G1203-003 (FR-R02G1203-001, 002, 004, 007;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and every listed uniform declared and
// used, at most 16 vec4 uniform slots per program (arrays counted by their length), no texture sampler, no `discard`,
// every loop bounded by a constant of at most 3 (the bridge vertex's one mode loop by `HB_MAX_MODES` = 3, no `while`),
// vertex outputs matching fragment inputs, balanced braces, the `ShaderMeshRenderer` attribute names and locations and
// the geometry's vertex streams, distinct and documented material codes each selected by the vertex shader, the GLSL
// palette constants parsing back to `HarmonicBridgesPalette` within 1e-6, the mode packing (m0 + 24 m1 + 576 m2,
// mi = 4 ni + wi), the wave (0.01 · w per mode), shell, membrane and won references, the glow gain per tier and the
// Reduce Flashing limit, and, when `glslangValidator` is installed, a real front-end compile of each source (skipped
// otherwise; the real compile happens on the simulator).
// Feature 416 (R02-G12-06) T-R02G1206-005: both fragment stages declare `u_wonLight`, which scales the won lift (7 vec4
// slots per program).
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams (none of
// these is a dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "bridge", vertex: HarmonicBridgesShaders.bridgeVertex,
                 fragment: HarmonicBridgesShaders.bridgeFragment, uniforms: HarmonicBridgesShaders.bridgeUniforms),
         Program(name: "glow", vertex: HarmonicBridgesShaders.glowVertex,
                 fragment: HarmonicBridgesShaders.glowFragment, uniforms: HarmonicBridgesShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [HarmonicBridgesShaders.bridgeVertex, HarmonicBridgesShaders.bridgeFragment,
         HarmonicBridgesShaders.glowVertex, HarmonicBridgesShaders.glowFragment]
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

    /// (type, name, array length) of the declarations in `source` starting with `keyword` and a space, in order; the
    /// length is 1 for a non-array.
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
        #expect(HarmonicBridgesShaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
            let forbidden: String = "import " + "Metal" + "Kit"
            #expect(!source.contains(forbidden))
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
            #expect(HarmonicBridgesShaders.uniformNames[program.name] == program.uniforms)
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(HarmonicBridgesShaders.uniformNames.count == 2)
        let constants: [String] = [
            HarmonicBridgesShaders.mvpUniform, HarmonicBridgesShaders.timeUniform, HarmonicBridgesShaders.motionUniform,
            HarmonicBridgesShaders.glowGainUniform, HarmonicBridgesShaders.glowLimitUniform,
            HarmonicBridgesShaders.wonLightUniform,
        ]
        let names: [String] = ["u_mvp", "u_time", "u_motion", "u_glowGain", "u_glowLimit", "u_wonLight"]
        #expect(constants == names)
        let listed: Set<String> = Set(HarmonicBridgesShaders.bridgeUniforms + HarmonicBridgesShaders.glowUniforms)
        #expect(Set(constants) == listed)
        #expect(HarmonicBridgesShaders.bridgeUniforms == ["u_mvp", "u_time", "u_motion", "u_wonLight"])
        #expect(HarmonicBridgesShaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_wonLight"])
        // Feature 416: the bridge fragment declares only the won light.
        #expect(Self.declared("uniform", in: HarmonicBridgesShaders.bridgeFragment) == ["u_wonLight"])
        #expect(HarmonicBridgesShaders.bridgeFragment.contains("uniform float u_wonLight;"))
        let bridge: String = HarmonicBridgesShaders.bridgeVertex
        let bridgeDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_time;", "uniform float u_motion;"]
        for declaration in bridgeDeclarations { #expect(bridge.contains(declaration), "\(declaration)") }
        let glow: String = HarmonicBridgesShaders.glowVertex + HarmonicBridgesShaders.glowFragment
        let glowDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_glowGain;",
                                          "uniform float u_glowLimit;", "uniform float u_wonLight;"]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
        // The glow never pulses: no time input. The won flag comes from the streams, not a uniform; the uniform
        // `u_wonLight` only scales its lift (feature 416).
        #expect(Self.wordCount("u_time", in: glow) == 0)
        #expect(Self.wordCount("u_motion", in: glow) == 0)
        for source in Self.sources() { #expect(Self.wordCount("u_won", in: source) == 0) }
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(HarmonicBridgesShaders.maxUniformVec4s == 16)
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
            #expect(slots <= HarmonicBridgesShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["bridge": 7, "glow": 7])
        #expect(HarmonicBridgesShaders.maxModes == HarmonicBridgesLevel.toneCounts.upperBound)
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
                    #expect((value ?? 99) <= 3, "\(name) bounds a loop above 3")
                }
            }
        }
        #expect(Self.wordCount("for", in: HarmonicBridgesShaders.bridgeFragment) == 0)
        #expect(Self.wordCount("for", in: HarmonicBridgesShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: HarmonicBridgesShaders.glowFragment) == 0)
        let vertex: String = HarmonicBridgesShaders.bridgeVertex
        #expect(Self.wordCount("for", in: vertex) == 1)
        #expect(vertex.contains("for (int k = 0; k < HB_MAX_MODES; k++) {"))
        #expect(Self.scalarConstant("int", "HB_MAX_MODES", in: vertex) == 3)
        #expect(HarmonicBridgesShaders.maxModes == 3)
        // Integer-safe decoding: the packed value is rounded and clamped to 0 … 13823, every division is offset by a
        // half before floor, so exact multiples never round down.
        #expect(Self.scalarConstant("float", "HB_MAX_PACKED", in: vertex) == 13823)
        #expect(Self.scalarConstant("float", "HB_PACK_BASE", in: vertex) == 24)
        let decode: [String] = [
            "float packed = clamp(floor(a_normal.y + 0.5), 0.0, HB_MAX_PACKED) * carrier;",
            "float rest = floor((packed + 0.5) / HB_PACK_BASE);",
            "float mode = packed - rest * HB_PACK_BASE;",
            "float n = floor((mode + 0.5) / 4.0);",
            "float w = mode - n * 4.0;",
        ]
        for line in decode { #expect(vertex.contains(line), "\(line)") }
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
        let bridgeOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_material": "float", "v_local": "float", "v_fade": "float",
            "v_won": "float",
        ]
        #expect(Self.interface("out", in: HarmonicBridgesShaders.bridgeVertex) == bridgeOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_glow": "float", "v_won": "float"]
        #expect(Self.interface("out", in: HarmonicBridgesShaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in HarmonicBridgesShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(HarmonicBridgesShaders.bridgeVertex) == expected)
        #expect(Self.layouts(HarmonicBridgesShaders.glowVertex) == expected)
        #expect(Self.layouts(HarmonicBridgesShaders.bridgeFragment).isEmpty)
        #expect(Self.layouts(HarmonicBridgesShaders.glowFragment).isEmpty)
        let vertices: [String] = [HarmonicBridgesShaders.bridgeVertex, HarmonicBridgesShaders.glowVertex]
        for source in vertices {
            for attribute in HarmonicBridgesShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // The geometry's streams: uv = (material code, d); wave carriers' normal (u, packed, theta); wave shells'
        // normal (centre.x, phase, centre.z); membranes' and glow rings' normal (0, 1, won); glow colour in the normal
        // slot, uv = (glow factor, won).
        let vertex: String = HarmonicBridgesShaders.bridgeVertex
        let lines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, 15.0);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "float u = clamp(a_normal.x, 0.0, 1.0);",
            "vec3 side = vec3(cos(a_normal.z), 0.0, sin(a_normal.z));",
            "vec2 centre = vec2(a_normal.x, a_normal.z);",
            "float progress = fract(t / HB_SHELL_SECONDS + clamp(a_normal.y, 0.0, 1.0));",
            "v_won = clamp(a_normal.z, 0.0, 1.0) * clamp(isCode(m, 6.0) + isCode(m, 9.0), 0.0, 1.0);",
        ]
        for line in lines { #expect(vertex.contains(line), "\(line)") }
        let glow: String = HarmonicBridgesShaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
        #expect(glow.contains("v_won = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        // The table covers the whole palette, each entry once, and every entry is written into some source.
        #expect(HarmonicBridgesShaders.paletteConstants.count == 16)
        var tableNames: Set<String> = []
        for entry in HarmonicBridgesShaders.paletteConstants {
            tableNames.insert(entry.name)
            var found: Int = 0
            for source in Self.sources() {
                guard let parsed = Self.vec3Constant(entry.name, in: source) else { continue }
                found += 1
                #expect(Self.distance(parsed, entry.colour) <= tolerance, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
        }
        #expect(tableNames.count == 16)
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "HB_GROUND", colour: HarmonicBridgesPalette.ground),
            (name: "HB_ISLAND_FACE", colour: HarmonicBridgesPalette.islandFace),
            (name: "HB_ISLAND_EDGE", colour: HarmonicBridgesPalette.islandEdge),
            (name: "HB_STRING", colour: HarmonicBridgesPalette.string),
            (name: "HB_MEMBRANE", colour: HarmonicBridgesPalette.membrane),
            (name: "HB_MARK_FILLED", colour: HarmonicBridgesPalette.markFilled),
            (name: "HB_MARK_HOLLOW", colour: HarmonicBridgesPalette.markHollow),
            (name: "HB_START", colour: HarmonicBridgesPalette.start),
            (name: "HB_GOAL", colour: HarmonicBridgesPalette.goal),
            (name: "HB_GLOW", colour: HarmonicBridgesPalette.glow),
            (name: "HB_SHELL", colour: HarmonicBridgesPalette.shell),
            (name: "HB_PIP", colour: HarmonicBridgesPalette.pip),
            (name: "HB_PIP_UNLIT", colour: HarmonicBridgesPalette.pipUnlit),
            (name: "HB_BROKEN", colour: HarmonicBridgesPalette.brokenOutline),
            (name: "HB_GAUGE_LIT", colour: HarmonicBridgesPalette.gaugeLit),
            (name: "HB_GAUGE_UNLIT", colour: HarmonicBridgesPalette.gaugeUnlit),
        ]
        for entry in palette {
            var matched: Bool = false
            for constant in HarmonicBridgesShaders.paletteConstants where constant.name == entry.name {
                matched = constant.colour == entry.colour
            }
            #expect(matched, "\(entry.name)")
        }
        // Every vec3 constant in every source is a named palette colour with the table's value, or the light direction.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "HB_LIGHT" {
                    #expect(Self.distance(parsed, HarmonicBridgesShaders.lightDirection) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in HarmonicBridgesShaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3 and the spec correction for the broken outline), six decimals.
        #expect(Self.distance(HarmonicBridgesPalette.ground, SIMD3<Double>(7, 6, 12) / 255) < 1e-12)
        #expect(Self.distance(HarmonicBridgesPalette.membrane, SIMD3<Double>(79, 216, 232) / 255) < 1e-12)
        #expect(Self.distance(HarmonicBridgesPalette.brokenOutline, SIMD3<Double>(255, 107, 74) / 255) < 1e-12)
        let bridgeV: String = HarmonicBridgesShaders.bridgeVertex
        #expect(bridgeV.contains("const vec3 HB_GROUND = vec3(0.027451, 0.023529, 0.047059);"))
        #expect(bridgeV.contains("const vec3 HB_MEMBRANE = vec3(0.309804, 0.847059, 0.909804);"))
        #expect(bridgeV.contains("const vec3 HB_BROKEN = vec3(1.000000, 0.419608, 0.290196);"))
        let light: SIMD3<Double> = HarmonicBridgesShaders.lightDirection
        #expect(abs((light.x * light.x + light.y * light.y + light.z * light.z) - 1) < 1e-12)
        let bridgeF: String = HarmonicBridgesShaders.bridgeFragment
        let glowF: String = HarmonicBridgesShaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "HB_MAX_MODE", value: Double(HarmonicBridgesSwing.maxMode), source: bridgeV),
            (name: "HB_PI", value: Double.pi, source: bridgeV),
            (name: "HB_WAVE_AMPLITUDE", value: HarmonicBridgesShaders.waveAmplitude, source: bridgeV),
            (name: "HB_WAVE_PERIOD", value: HarmonicBridgesShaders.wavePeriod, source: bridgeV),
            (name: "HB_SHELL_SECONDS", value: HarmonicBridgesShaders.shellSeconds, source: bridgeV),
            (name: "HB_SHELL_RADIUS", value: HarmonicBridgesShaders.maxShellRadius, source: bridgeV),
            (name: "HB_SHELL_HALF_WIDTH", value: HarmonicBridgesShaders.shellHalfWidth, source: bridgeV),
            (name: "HB_AMBIENT", value: HarmonicBridgesShaders.ambient, source: bridgeF),
            (name: "HB_DIFFUSE", value: HarmonicBridgesShaders.diffuse, source: bridgeF),
            (name: "HB_EDGE_FEATHER", value: HarmonicBridgesShaders.edgeFeather, source: bridgeF),
            (name: "HB_MEMBRANE_ALPHA", value: HarmonicBridgesShaders.membraneCoreAlpha, source: bridgeF),
            (name: "HB_MEMBRANE_RIM", value: HarmonicBridgesShaders.membraneRim, source: bridgeF),
            (name: "HB_WON_LIFT", value: HarmonicBridgesShaders.wonLift, source: bridgeF),
            (name: "HB_GLOW_WEIGHT", value: HarmonicBridgesShaders.glowWeight, source: glowF),
            (name: "HB_CORE", value: HarmonicBridgesShaders.coreLift, source: glowF),
            (name: "HB_WON_LIFT", value: HarmonicBridgesShaders.wonLift, source: glowF),
            (name: "HB_MAX_GAIN", value: HarmonicBridgesShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(HarmonicBridgesShaders.ambient + HarmonicBridgesShaders.diffuse == 1.0)
        // Clarification Q1 and Q2 values with the spec's amplitude correction (0.01 · w).
        #expect(HarmonicBridgesShaders.waveAmplitude == 0.01)
        #expect(HarmonicBridgesShaders.wavePeriod == 1.6)
        #expect(HarmonicBridgesShaders.shellSeconds == 1.6)
        #expect(HarmonicBridgesShaders.maxShellRadius == 0.15)
        #expect(HarmonicBridgesShaders.shellHalfWidth * 2 == 0.01)
    }

    @Test func everyMaterialCodeIsDistinctDocumentedAndSelected() {
        var codes: [Int] = []
        for material in HarmonicBridgesMaterial.allCases {
            codes.append(material.rawValue)
            #expect(Double(material.rawValue) == material.code)
            if material != .ground { #expect(material.colour != HarmonicBridgesPalette.ground) }
        }
        var expectedCodes: [Int] = []
        for code in 0...15 { expectedCodes.append(code) }
        #expect(codes == expectedCodes)
        // The vertex shader selects each material's colour by its code, in code order; every code 1 … 15 appears.
        let selections: [(code: Int, constant: String)] = [
            (code: 1, constant: "HB_ISLAND_FACE"), (code: 2, constant: "HB_ISLAND_EDGE"),
            (code: 3, constant: "HB_START"), (code: 4, constant: "HB_GOAL"), (code: 5, constant: "HB_STRING"),
            (code: 6, constant: "HB_MEMBRANE"), (code: 7, constant: "HB_MARK_FILLED"),
            (code: 8, constant: "HB_MARK_HOLLOW"), (code: 9, constant: "HB_GLOW"), (code: 10, constant: "HB_SHELL"),
            (code: 11, constant: "HB_PIP"), (code: 12, constant: "HB_PIP_UNLIT"), (code: 13, constant: "HB_BROKEN"),
            (code: 14, constant: "HB_GAUGE_LIT"), (code: 15, constant: "HB_GAUGE_UNLIT"),
        ]
        #expect(selections.count == HarmonicBridgesMaterial.allCases.count - 1)
        let vertex: String = HarmonicBridgesShaders.bridgeVertex
        #expect(vertex.contains("vec3 base = mix(HB_GROUND, HB_ISLAND_FACE, isCode(m, 1.0));"))
        for selection in selections where selection.code > 1 {
            let line: String = "base = mix(base, \(selection.constant), isCode(m, \(selection.code).0));"
            #expect(vertex.contains(line), "\(line)")
        }
        for selection in selections {
            let material: HarmonicBridgesMaterial? = HarmonicBridgesMaterial(rawValue: selection.code)
            var expected: SIMD3<Double>? = nil
            for constant in HarmonicBridgesShaders.paletteConstants where constant.name == selection.constant {
                expected = constant.colour
            }
            #expect(material?.colour == expected, "\(selection.constant)")
        }
        // Lit materials, wave and won carriers and local-coordinate layouts as documented, matching the shader's tests.
        var lit: [Int] = []
        var carriers: [Int] = []
        var won: [Int] = []
        var fans: [Int] = []
        var strips: [Int] = []
        var solids: [Int] = []
        for material in HarmonicBridgesMaterial.allCases {
            if material.isLit { lit.append(material.rawValue) }
            if material.carriesWave { carriers.append(material.rawValue) }
            if material.carriesWon { won.append(material.rawValue) }
            switch material.localCoordinate {
            case .fan: fans.append(material.rawValue)
            case .strip: strips.append(material.rawValue)
            case .none: solids.append(material.rawValue)
            }
        }
        #expect(lit == [1])
        #expect(carriers == [5, 7, 8, 13])
        #expect(won == [6, 9])
        #expect(fans == [4, 7, 11, 14, 15])
        #expect(strips == [2, 3, 5, 6, 8, 9, 10, 12, 13])
        #expect(solids == [0, 1])
        #expect(vertex.contains(
            "float carrier = clamp(isCode(m, 5.0) + isCode(m, 7.0) + isCode(m, 8.0) + isCode(m, 13.0), 0.0, 1.0);"))
        #expect(vertex.contains("float isShell = isCode(m, 10.0);"))
        let fragment: String = HarmonicBridgesShaders.bridgeFragment
        #expect(fragment.contains("float isLit = isCode(m, 1.0);"))
        #expect(fragment.contains("float isMembrane = isCode(m, 6.0);"))
        // Shapes and colours tell the states apart.
        #expect(HarmonicBridgesMaterial.brokenOutline.colour != HarmonicBridgesMaterial.string.colour)
        #expect(HarmonicBridgesMaterial.pip.colour != HarmonicBridgesMaterial.pipUnlit.colour)
        #expect(HarmonicBridgesMaterial.markFilled.colour != HarmonicBridgesMaterial.markHollow.colour)
    }

    /// The file header documents every material code and the vertex stream convention the geometry follows.
    @Test func materialCodesAndMeshConventionAreDocumented() throws {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            .appendingPathComponent("HarmonicBridgesShaders.swift")
        let text: String = try String(contentsOf: file, encoding: .utf8)
        var header: String = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("//") else { break }
            header.append(String(line.dropFirst(2)))
            header.append(" ")
        }
        var flat: String = ""
        for word in header.split(whereSeparator: { $0 == " " }) { flat.append("\(word) ") }
        let phrases: [String] = [
            "feature 413 (R02-G12-03) T-R02G1203-003", "FR-R02G1203-001, 002, 004, 007",
            "0 ground, 1 island face, 2 island edge, 3 start ring, 4 goal star, 5 string,",
            "6 membrane, 7 filled mark, 8 hollow mark, 9 glow ring, 10 wave shell, 11 pip,",
            "12 unlit pip, 13 broken outline, 14 gauge lit, 15 gauge unlit)", "`a_uv.y` the local edge coordinate",
            "(u, packed, θ)", "packed = m0 + 24 m1 + 576 m2", "mi = 4 ni + wi", "(centre.x, phase, centre.z)",
            "(0, 1, won)", "`a_uv.x` is the glow factor", "`a_uv.y` the won flag",
        ]
        for phrase in phrases { #expect(flat.contains(phrase), "\(phrase)") }
    }

    @Test func softEdgesAndTranslucentMembranesFollowTheLocalCoordinate() {
        #expect(HarmonicBridgesShaders.edgeCoverage(local: 0) == 1)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: 0.8) == 1)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: 1) == 0)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: -1) == 0)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: 3) == 0)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: .nan) == 0)
        let mid: Double = HarmonicBridgesShaders.edgeCoverage(local: 0.925)
        #expect(abs(mid - 0.5) < 1e-9)
        #expect(HarmonicBridgesShaders.edgeCoverage(local: -0.925) == mid)
        // Membranes: translucent in the middle, opaque at the rim, lifted on a won level; monotone across.
        #expect(HarmonicBridgesShaders.membraneAlpha(local: 0, won: false) == HarmonicBridgesShaders.membraneCoreAlpha)
        #expect(HarmonicBridgesShaders.membraneAlpha(local: 0.85, won: false) == 1)
        let wonMiddle: Double = HarmonicBridgesShaders.membraneAlpha(local: 0, won: true)
        #expect(wonMiddle > HarmonicBridgesShaders.membraneCoreAlpha && wonMiddle < 1)
        var previous: Double = 0
        for i in 0...100 {
            let value: Double = HarmonicBridgesShaders.membraneAlpha(local: Double(i) / 100, won: false)
            #expect(value >= previous - 1e-12 && value <= 1)
            previous = value
        }
        // Clarification Q3: a membrane's middle over the ground keeps blue above red by at least 0.05 and differs from
        // the ground by at least 0.08 in luminance.
        let a: Double = HarmonicBridgesShaders.membraneCoreAlpha
        let ground: SIMD3<Double> = HarmonicBridgesPalette.ground
        let mixed: SIMD3<Double> = HarmonicBridgesPalette.membrane * a + ground * (1 - a)
        #expect(mixed.z - mixed.x >= 0.05)
        let luminance: Double = 0.2126 * (mixed.x - ground.x) + 0.7152 * (mixed.y - ground.y)
            + 0.0722 * (mixed.z - ground.z)
        #expect(luminance >= 0.08)
        let fragment: String = HarmonicBridgesShaders.bridgeFragment
        #expect(fragment.contains("float rim = smoothstep(HB_MEMBRANE_RIM, 1.0 - HB_EDGE_FEATHER, d);"))
        #expect(fragment.contains(
            "float alpha = clamp(soft * mix(1.0, membrane, isMembrane) * clamp(v_fade, 0.0, 1.0), 0.0, 1.0);"))
    }

    @Test func modesPackAndUnpackAsTheGeometryWritesThem() {
        // Every combination of up to three (mode, strength) pairs round-trips; the value is m0 + 24 m1 + 576 m2.
        for n0 in 0...5 {
            for w0 in 0...3 {
                for n1 in 0...5 {
                    let pairs: [(mode: Int, strength: Int)] = [(mode: n0, strength: w0), (mode: n1, strength: 3),
                                                               (mode: 5, strength: 1)]
                    let packed: Double = HarmonicBridgesShaders.packModes(pairs)
                    let expected: Int = (4 * n0 + w0) + 24 * (4 * n1 + 3) + 576 * (4 * 5 + 1)
                    #expect(packed == Double(expected))
                    #expect(Double(Float(packed)) == packed)
                    let decoded: [(mode: Int, strength: Int)] = HarmonicBridgesShaders.unpackModes(packed)
                    #expect(decoded.count == 3)
                    #expect(decoded[0].mode == n0 && decoded[0].strength == w0)
                    #expect(decoded[1].mode == n1 && decoded[1].strength == 3)
                    #expect(decoded[2].mode == 5 && decoded[2].strength == 1)
                }
            }
        }
        #expect(HarmonicBridgesShaders.packModes([]) == 0)
        #expect(HarmonicBridgesShaders.maxPacked == 13823)
        let none: [(mode: Int, strength: Int)] = HarmonicBridgesShaders.unpackModes(0)
        for pair in none { #expect(pair.mode == 0 && pair.strength == 0) }
        let junk: [(mode: Int, strength: Int)] = HarmonicBridgesShaders.unpackModes(.nan)
        for pair in junk { #expect(pair.mode == 0 && pair.strength == 0) }
        // The hand level: step 0 strings 0 and 1 in mode 1 and string 2 in mode 2 (strength 2); step 1 string 2 in
        // modes 1 and 3 (strength 1 each). Packed as the geometry's packModes does (4 n + w per mode, base 24).
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let play: HarmonicBridgesPlay = HarmonicBridgesPlay(level: level)
        let snapshot: HarmonicBridgesSceneSnapshot = HarmonicBridgesSceneSnapshot(play: play, levelNumber: 1, time: 0)
        var stepZero: [Double] = []
        for string in 0..<snapshot.strings.count {
            var pairs: [(mode: Int, strength: Int)] = []
            for k in 0..<snapshot.modes[0][string].count {
                pairs.append((mode: snapshot.modes[0][string][k], strength: snapshot.strengths[0][string][k]))
            }
            stepZero.append(HarmonicBridgesShaders.packModes(pairs))
        }
        #expect(stepZero == [6, 6, 10, 0])
        var stringTwo: [(mode: Int, strength: Int)] = []
        for k in 0..<snapshot.modes[1][2].count {
            stringTwo.append((mode: snapshot.modes[1][2][k], strength: snapshot.strengths[1][2][k]))
        }
        #expect(HarmonicBridgesShaders.packModes(stringTwo) == Double(5 + 24 * 13))
    }

    @Test func thePresentationWaveFollowsTheSpecAndStopsWithoutMotion() {
        // One mode n = 2, w = 3 at u = 1/4, t = 0: 0.01 · 3 · sin(π/2) · 1 = 0.03.
        let one: Double = HarmonicBridgesShaders.packModes([(mode: 2, strength: 3)])
        let peak: Double = HarmonicBridgesShaders.waveDisplacement(u: 0.25, time: 0, packed: one, motion: 1)
        #expect(abs(peak - 0.03) < 1e-12)
        // A quarter of mode 2's period (1.6 / 2 / 4 = 0.2 s) later the cosine is zero.
        let zero: Double = HarmonicBridgesShaders.waveDisplacement(u: 0.25, time: 0.2, packed: one, motion: 1)
        #expect(abs(zero) < 1e-12)
        // The ends never move; motion 0 (level-2, Reduce Motion) draws the string at rest.
        #expect(abs(HarmonicBridgesShaders.waveDisplacement(u: 0, time: 0.3, packed: one, motion: 1)) < 1e-12)
        #expect(abs(HarmonicBridgesShaders.waveDisplacement(u: 1, time: 0.3, packed: one, motion: 1)) < 1e-12)
        #expect(HarmonicBridgesShaders.waveDisplacement(u: 0.25, time: 0, packed: one, motion: 0) == 0)
        #expect(HarmonicBridgesShaders.waveDisplacement(u: 0.25, time: 0, packed: 0, motion: 1) == 0)
        // Bounded by 0.09 for three tones of strength 3 at every u and t.
        let three: Double = HarmonicBridgesShaders.packModes([(mode: 1, strength: 3), (mode: 3, strength: 3),
                                                              (mode: 5, strength: 3)])
        for i in 0...20 {
            for j in 0...16 {
                let value: Double = HarmonicBridgesShaders.waveDisplacement(u: Double(i) / 20, time: Double(j) / 10,
                                                                            packed: three, motion: 1)
                #expect(value.isFinite && abs(value) <= 0.09 + 1e-12)
            }
        }
        // Motion per tier: level-0 and level-1 swing, level-2 and Reduce Motion do not.
        #expect(HarmonicBridgesShaders.motion(for: HarmonicBridgesTier.of(0), reduceMotion: false) == 1)
        #expect(HarmonicBridgesShaders.motion(for: HarmonicBridgesTier.of(1), reduceMotion: false) == 1)
        #expect(HarmonicBridgesShaders.motion(for: HarmonicBridgesTier.of(2), reduceMotion: false) == 0)
        #expect(HarmonicBridgesShaders.motion(for: HarmonicBridgesTier.of(0), reduceMotion: true) == 0)
        // Wrapped time keeps the image: the wave at t and at t mod 1.6 agree.
        let late: Double = 1234.567
        let wrapped: Double = HarmonicBridgesShaders.wrappedTime(late)
        #expect(wrapped >= 0 && wrapped < 1.6)
        let direct: Double = HarmonicBridgesShaders.waveDisplacement(u: 0.3, time: late, packed: three, motion: 1)
        let viaWrap: Double = HarmonicBridgesShaders.waveDisplacement(u: 0.3, time: wrapped, packed: three, motion: 1)
        #expect(abs(direct - viaWrap) < 1e-9)
        #expect(HarmonicBridgesShaders.wrappedTime(.nan) == 0)
        #expect(HarmonicBridgesShaders.wrappedTime(-3) == 0)
        let vertex: String = HarmonicBridgesShaders.bridgeVertex
        let term: String =
            "wave += HB_WAVE_AMPLITUDE * w * sin(n * HB_PI * u) * cos(2.0 * HB_PI * n * t / HB_WAVE_PERIOD);"
        #expect(vertex.contains(term))
        #expect(vertex.contains("vec3 position = a_position + side * wave * carrier * motion;"))
        #expect(vertex.contains("float motion = clamp(u_motion, 0.0, 1.0);"))
    }

    @Test func waveShellsGrowFromZeroToFifteenHundredthsOverOnePointSixSeconds() {
        #expect(HarmonicBridgesShaders.shellRadius(time: 0, phase: 0) == 0)
        #expect(abs(HarmonicBridgesShaders.shellRadius(time: 0.8, phase: 0) - 0.075) < 1e-12)
        #expect(abs(HarmonicBridgesShaders.shellRadius(time: 1.599, phase: 0) - 0.15) < 0.001)
        #expect(HarmonicBridgesShaders.shellRadius(time: 1.6, phase: 0) < 1e-9)
        #expect(abs(HarmonicBridgesShaders.shellRadius(time: 0, phase: 0.5) - 0.075) < 1e-12)
        #expect(HarmonicBridgesShaders.shellFade(time: 0, phase: 0) == 1)
        #expect(abs(HarmonicBridgesShaders.shellFade(time: 0.8, phase: 0) - 0.5) < 1e-12)
        for i in 0...32 {
            let r: Double = HarmonicBridgesShaders.shellRadius(time: Double(i) * 0.1, phase: 0.5)
            #expect(r >= 0 && r < 0.15 + 1e-12)
        }
        // The geometry places a shell vertex at radius 0.15 ± 0.005 around the centre; the shader moves it along its
        // own direction to r(t) + d · 0.005, keeping its height.
        let centre: SIMD2<Double> = SIMD2<Double>(0.2, -0.1)
        let vertex: SIMD3<Double> = SIMD3<Double>(0.2 + 0.155 * 0.6, 0.1, -0.1 + 0.155 * 0.8)
        let moved: SIMD3<Double> = HarmonicBridgesShaders.shellPosition(vertex: vertex, centre: centre, local: 1,
                                                                        time: 0.8, phase: 0)
        #expect(abs(moved.x - (0.2 + 0.08 * 0.6)) < 1e-12)
        #expect(abs(moved.z - (-0.1 + 0.08 * 0.8)) < 1e-12)
        #expect(moved.y == 0.1)
        let start: SIMD3<Double> = HarmonicBridgesShaders.shellPosition(vertex: vertex, centre: centre, local: -1,
                                                                        time: 0, phase: 0)
        #expect(abs(start.x - centre.x) < 1e-12 && abs(start.z - centre.y) < 1e-12)
        let source: String = HarmonicBridgesShaders.bridgeVertex
        let lines: [String] = [
            "float radius = max(HB_SHELL_RADIUS * progress + clamp(a_uv.y, -1.0, 1.0) * HB_SHELL_HALF_WIDTH, 0.0);",
            "vec3 shell = vec3(centre.x + direction.x * radius, a_position.y, centre.y + direction.y * radius);",
            "position = mix(position, shell, isShell);",
            "v_fade = mix(1.0, (1.0 - progress) * motion, isShell);",
        ]
        for line in lines { #expect(source.contains(line), "\(line)") }
    }

    /// Feature 416 (R02-G12-06): the won flag's lift is scaled by the eased won light `u_wonLight` in both programs.
    @Test func aWonLevelLiftsMembranesGlowRingsAndTheGlow() {
        let vertex: String = HarmonicBridgesShaders.bridgeVertex
        #expect(vertex.contains(
            "v_won = clamp(a_normal.z, 0.0, 1.0) * clamp(isCode(m, 6.0) + isCode(m, 9.0), 0.0, 1.0);"))
        let fragment: String = HarmonicBridgesShaders.bridgeFragment
        #expect(fragment.contains("float won = clamp(v_won, 0.0, 1.0) * clamp(u_wonLight, 0.0, 1.0);"))
        #expect(fragment.contains("rgb = mix(rgb, HB_MARK_FILLED, HB_WON_LIFT * won);"))
        #expect(fragment.contains("float membrane = mix(mix(HB_MEMBRANE_ALPHA, 1.0, rim), 1.0, HB_WON_LIFT * won);"))
        #expect(HarmonicBridgesShaders.wonLift > 0 && HarmonicBridgesShaders.wonLift <= 1)
        let glow: String = HarmonicBridgesShaders.glowFragment
        #expect(glow.contains("float won = clamp(v_won, 0.0, 1.0) * clamp(u_wonLight, 0.0, 1.0);"))
        #expect(glow.contains(
            "vec3 rgb = mix(colour, HB_MARK_FILLED, clamp((HB_CORE * gain + HB_WON_LIFT * won) * v_glow, 0.0, 1.0));"))
        let plain: SIMD4<Double> = HarmonicBridgesShaders.glowColour(colour: HarmonicBridgesPalette.glow, glow: 1,
                                                                     gain: 1, won: false)
        let won: SIMD4<Double> = HarmonicBridgesShaders.glowColour(colour: HarmonicBridgesPalette.glow, glow: 1,
                                                                   gain: 1, won: true)
        #expect(won.x + won.y + won.z > plain.x + plain.y + plain.z)
        // The won lift never raises the glow's alpha past the gain (Reduce Flashing still caps it).
        #expect(won.w == plain.w)
    }
    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        let gains: [Double] = [
            HarmonicBridgesShaders.glowGain(for: HarmonicBridgesTier.of(0)),
            HarmonicBridgesShaders.glowGain(for: HarmonicBridgesTier.of(1)),
            HarmonicBridgesShaders.glowGain(for: HarmonicBridgesTier.of(2)),
        ]
        #expect(gains == [1.5, 1.0, 0])
        #expect(HarmonicBridgesShaders.glowLimit(reduceFlashing: false) == HarmonicBridgesShaders.standardGlowLimit)
        #expect(HarmonicBridgesShaders.glowLimit(reduceFlashing: true) == HarmonicBridgesShaders.glowGainCap)
        #expect(HarmonicBridgesShaders.glowGainCap == 0.5)
        #expect(HarmonicBridgesShaders.standardGlowLimit == 1.5)
        #expect(HarmonicBridgesShaders.maxGlowGain == 1.5)
        for gain in gains {
            let limit: Double = HarmonicBridgesShaders.glowLimit(reduceFlashing: true)
            let capped: Double = HarmonicBridgesShaders.glowGain(gain: gain, limit: limit)
            #expect(capped <= HarmonicBridgesShaders.glowGainCap)
        }
        #expect(HarmonicBridgesShaders.glowGain(gain: 9, limit: 9) == HarmonicBridgesShaders.maxGlowGain)
        #expect(HarmonicBridgesShaders.glowGain(gain: .nan, limit: 1) == 0)
        #expect(HarmonicBridgesShaders.glowGain(gain: -1, limit: 1) == 0)
        let zero: SIMD4<Double> = HarmonicBridgesShaders.glowColour(colour: HarmonicBridgesPalette.glow, glow: 1,
                                                                    gain: 0, won: true)
        #expect(zero.w == 0)
        let full: SIMD4<Double> = HarmonicBridgesShaders.glowColour(colour: SIMD3<Double>(0, 0, 0), glow: 1, gain: 1.5,
                                                                    won: false)
        #expect(abs(full.w - 0.75) < 1e-12)
        let reduced: SIMD4<Double> = HarmonicBridgesShaders.glowColour(colour: HarmonicBridgesPalette.glow, glow: 1,
                                                                       gain: 0.5, won: false)
        #expect(reduced.w < full.w)
        let glow: String = HarmonicBridgesShaders.glowFragment
        let gainLine: String =
            "float gain = min(clamp(u_glowGain, 0.0, HB_MAX_GAIN), clamp(u_glowLimit, 0.0, HB_MAX_GAIN));"
        #expect(glow.contains(gainLine))
        #expect(glow.contains("float alpha = clamp(HB_GLOW_WEIGHT * gain * v_glow, 0.0, 1.0);"))
    }

    /// A real front-end compile with `glslangValidator` when it is installed (skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator",
                                    "/usr/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            tool = path
            break
        }
        guard let tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hb-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "bridge.vert", source: HarmonicBridgesShaders.bridgeVertex),
            (name: "bridge.frag", source: HarmonicBridgesShaders.bridgeFragment),
            (name: "glow.vert", source: HarmonicBridgesShaders.glowVertex),
            (name: "glow.frag", source: HarmonicBridgesShaders.glowFragment),
        ]
        for file in files {
            let url: URL = directory.appendingPathComponent(file.name)
            try file.source.write(to: url, atomically: true, encoding: .utf8)
            let process: Process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = [url.path]
            let pipe: Pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let output: String = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            #expect(process.terminationStatus == 0, "\(file.name): \(output)")
        }
        #endif
    }
}
