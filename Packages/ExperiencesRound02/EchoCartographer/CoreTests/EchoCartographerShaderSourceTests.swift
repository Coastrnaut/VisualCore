// EchoCartographerShaderSourceTests — feature 403 (R02-G11-03) T-R02G1103-003 (FR-R02G1103-001, 002, 004;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and every listed uniform declared and
// used, at most 16 vec4 uniform slots per program, no texture sampler, no `discard`, every loop bounded by a constant
// of at most 4 (the chamber fragment's one echo loop by `EC_MAX_ECHOES` = 4, no `while`), vertex outputs matching
// fragment inputs, balanced braces, the `ShaderMeshRenderer` attribute names and locations, distinct and documented
// material codes, the GLSL palette constants parsing back to `EchoCartographerPalette` within 1e-6, the ring, echo and
// flare references (a cell per 0.1 s, 24 ticks of 0.008333 s per cell, 0.5 s flare), the tier flags, the glow gain per
// tier and the Reduce Flashing limit, and, when `glslangValidator` is installed, a real front-end compile of each
// source (skipped otherwise; the real compile happens on the simulator).
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the limit
// 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this target).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import EchoCartographerCore

@Suite struct EchoCartographerShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "chamber", vertex: EchoCartographerShaders.chamberVertex,
                 fragment: EchoCartographerShaders.chamberFragment, uniforms: EchoCartographerShaders.chamberUniforms),
         Program(name: "glow", vertex: EchoCartographerShaders.glowVertex,
                 fragment: EchoCartographerShaders.glowFragment, uniforms: EchoCartographerShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [EchoCartographerShaders.chamberVertex, EchoCartographerShaders.chamberFragment,
         EchoCartographerShaders.glowVertex, EchoCartographerShaders.glowFragment]
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
        for line in lines(source) where line.hasPrefix("\(keyword) ") {
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

    /// The vec4 slots a uniform of GLSL `type` occupies (mat4: 4, mat3: 3, mat2: 2, anything scalar or vector: 1).
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
        #expect(EchoCartographerShaders.versionLine == "#version 300 es")
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
            #expect(Self.unique(vertexDeclared + fragmentDeclared) == program.uniforms,
                    "\(program.name) declares in a different order or set")
            #expect(EchoCartographerShaders.uniformNames[program.name] == program.uniforms)
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(EchoCartographerShaders.uniformNames.count == 2)
        let constants: [String] = [
            EchoCartographerShaders.mvpUniform, EchoCartographerShaders.lightDirectionUniform,
            EchoCartographerShaders.timeUniform, EchoCartographerShaders.cellSizeUniform,
            EchoCartographerShaders.emitterUniform, EchoCartographerShaders.maxRadiusUniform,
            EchoCartographerShaders.echoDelaysUniform, EchoCartographerShaders.tierUniform,
            EchoCartographerShaders.reduceMotionUniform, EchoCartographerShaders.glowGainUniform,
            EchoCartographerShaders.glowLimitUniform, EchoCartographerShaders.wonLightUniform,
        ]
        let names: [String] = ["u_mvp", "u_lightDir", "u_time", "u_cellSize", "u_emitter", "u_maxRadius",
                               "u_echoDelays", "u_tier", "u_reduceMotion", "u_glowGain", "u_glowLimit", "u_wonLight"]
        #expect(constants == names)
        let listed: Set<String> = Set(EchoCartographerShaders.chamberUniforms + EchoCartographerShaders.glowUniforms)
        #expect(Set(constants) == listed)
        let chamber: String = EchoCartographerShaders.chamberVertex + EchoCartographerShaders.chamberFragment
        let chamberDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_lightDir;", "uniform float u_time;", "uniform float u_cellSize;",
            "uniform vec2 u_emitter;", "uniform float u_maxRadius;", "uniform vec4 u_echoDelays;",
            "uniform vec3 u_tier;", "uniform float u_reduceMotion;", "uniform float u_wonLight;",
        ]
        for declaration in chamberDeclarations { #expect(chamber.contains(declaration), "\(declaration)") }
        let glow: String = EchoCartographerShaders.glowVertex + EchoCartographerShaders.glowFragment
        let glowDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_glowGain;",
                                          "uniform float u_glowLimit;"]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
        #expect(Self.wordCount("u_time", in: glow) == 0)
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(EchoCartographerShaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: "\(program.vertex)\n\(program.fragment)")
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= EchoCartographerShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["chamber": 13, "glow": 6])
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
                    #expect((value ?? 99) <= 4, "\(name) bounds a loop above 4")
                }
            }
        }
        #expect(Self.wordCount("for", in: EchoCartographerShaders.chamberVertex) == 0)
        #expect(Self.wordCount("for", in: EchoCartographerShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: EchoCartographerShaders.glowFragment) == 0)
        let fragment: String = EchoCartographerShaders.chamberFragment
        #expect(Self.wordCount("for", in: fragment) == 1)
        #expect(fragment.contains("for (int i = 0; i < EC_MAX_ECHOES; i++) {"))
        #expect(Self.scalarConstant("int", "EC_MAX_ECHOES", in: fragment) == 4)
        #expect(EchoCartographerShaders.maxEchoes == 4)
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
        let chamberOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_position": "vec3", "v_material": "float", "v_local": "float",
            "v_strike": "float", "v_won": "float",
        ]
        #expect(Self.interface("out", in: EchoCartographerShaders.chamberVertex) == chamberOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_glow": "float"]
        #expect(Self.interface("out", in: EchoCartographerShaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in EchoCartographerShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(EchoCartographerShaders.chamberVertex) == expected)
        #expect(Self.layouts(EchoCartographerShaders.glowVertex) == expected)
        #expect(Self.layouts(EchoCartographerShaders.chamberFragment).isEmpty)
        #expect(Self.layouts(EchoCartographerShaders.glowFragment).isEmpty)
        let vertices: [String] = [EchoCartographerShaders.chamberVertex, EchoCartographerShaders.glowVertex]
        for source in vertices {
            for attribute in EchoCartographerShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // Mesh streams: chamber uv = (material code, local edge coordinate), the struck distance in a_normal.x on wall
        // edges; glow colour in the normal slot, uv = (glow, 0).
        let vertex: String = EchoCartographerShaders.chamberVertex
        #expect(vertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 10.0);"))
        #expect(vertex.contains("v_local = clamp(a_uv.y, -1.0, 1.0);"))
        #expect(vertex.contains("v_strike = max(a_normal.x, 0.0) * isEdge;"))
        #expect(vertex.contains("float isEdge = isCode(m, 7.0);"))
        #expect(EchoCartographerShaders.glowVertex.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(EchoCartographerShaders.glowVertex.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        // The table covers the whole palette, each entry once, and every entry is written into some source.
        #expect(EchoCartographerShaders.paletteConstants.count == 12)
        var tableNames: Set<String> = []
        for entry in EchoCartographerShaders.paletteConstants {
            tableNames.insert(entry.name)
            var found: Int = 0
            for source in Self.sources() {
                guard let parsed = Self.vec3Constant(entry.name, in: source) else { continue }
                found += 1
                #expect(Self.distance(parsed, entry.colour) <= tolerance, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
        }
        #expect(tableNames.count == 12)
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "EC_GROUND", colour: EchoCartographerPalette.ground),
            (name: "EC_FLOOR", colour: EchoCartographerPalette.floor),
            (name: "EC_WALL_FACE", colour: EchoCartographerPalette.wallFace),
            (name: "EC_WALL_EDGE", colour: EchoCartographerPalette.wallEdge),
            (name: "EC_FLARE", colour: EchoCartographerPalette.flare),
            (name: "EC_PULSE", colour: EchoCartographerPalette.pulse),
            (name: "EC_ENTRY", colour: EchoCartographerPalette.entry),
            (name: "EC_MARKER", colour: EchoCartographerPalette.marker),
            (name: "EC_PILLAR", colour: EchoCartographerPalette.pillar),
            (name: "EC_GLOW", colour: EchoCartographerPalette.glow),
            (name: "EC_GAUGE_LIT", colour: EchoCartographerPalette.gaugeLit),
            (name: "EC_GAUGE_UNLIT", colour: EchoCartographerPalette.gaugeUnlit),
        ]
        for entry in palette {
            var matched: Bool = false
            for constant in EchoCartographerShaders.paletteConstants where constant.name == entry.name {
                matched = constant.colour == entry.colour
            }
            #expect(matched, "\(entry.name)")
        }
        // Every vec3 constant in every source is a named palette colour with the table's value (no stray colour).
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in EchoCartographerShaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six fixed decimals.
        #expect(Self.distance(EchoCartographerPalette.ground, SIMD3<Double>(5, 7, 10) / 255) < 1e-12)
        #expect(Self.distance(EchoCartographerPalette.wallEdge, SIMD3<Double>(61, 245, 196) / 255) < 1e-12)
        let chamberV: String = EchoCartographerShaders.chamberVertex
        #expect(chamberV.contains("const vec3 EC_GROUND = vec3(0.019608, 0.027451, 0.039216);"))
        #expect(chamberV.contains("const vec3 EC_WALL_EDGE = vec3(0.239216, 0.960784, 0.768627);"))
        let chamberF: String = EchoCartographerShaders.chamberFragment
        let glowF: String = EchoCartographerShaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "EC_AMBIENT", value: EchoCartographerShaders.ambient, source: chamberF),
            (name: "EC_DIFFUSE", value: EchoCartographerShaders.diffuse, source: chamberF),
            (name: "EC_EDGE_FEATHER", value: EchoCartographerShaders.edgeFeather, source: chamberF),
            (name: "EC_PULSE_SECONDS_PER_CELL", value: EchoCartographerShaders.pulseSecondsPerCell, source: chamberF),
            (name: "EC_ECHO_SECONDS_PER_CELL", value: EchoCartographerShaders.echoSecondsPerCell, source: chamberF),
            (name: "EC_RING_HALF_WIDTH", value: EchoCartographerShaders.ringHalfWidth, source: chamberF),
            (name: "EC_PULSE_FADE_SECONDS", value: EchoCartographerShaders.pulseFadeSeconds, source: chamberF),
            (name: "EC_FACE_OFFSET", value: EchoCartographerShaders.faceOffset, source: chamberF),
            (name: "EC_FLARE_SECONDS", value: EchoCartographerShaders.flareSeconds, source: chamberF),
            (name: "EC_TRAIL_WEIGHT", value: EchoCartographerShaders.trailWeight, source: chamberF),
            (name: "EC_TRAIL_SECONDS", value: EchoCartographerShaders.trailSeconds, source: chamberF),
            (name: "EC_GLOW_WEIGHT", value: EchoCartographerShaders.glowWeight, source: glowF),
            (name: "EC_CORE", value: EchoCartographerShaders.coreLift, source: glowF),
            (name: "EC_MAX_GAIN", value: EchoCartographerShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(EchoCartographerShaders.ambient + EchoCartographerShaders.diffuse == 1.0)
    }

    @Test func materialCodesAreDistinctDocumentedAndSelectThePalette() {
        typealias Material = EchoCartographerShaders.ChamberMaterial
        var codes: [Int] = []
        for material in Material.allCases {
            codes.append(material.rawValue)
            #expect(Double(material.rawValue) == material.code)
            if material != .ground { #expect(material.colour != EchoCartographerPalette.ground) }
        }
        #expect(codes == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let named: [Int] = [
            EchoCartographerShaders.groundMaterial, EchoCartographerShaders.floorMaterial,
            EchoCartographerShaders.entryMaterial, EchoCartographerShaders.markerMaterial,
            EchoCartographerShaders.rayMaterial, EchoCartographerShaders.ringMaterial,
            EchoCartographerShaders.wallFaceMaterial, EchoCartographerShaders.wallEdgeMaterial,
            EchoCartographerShaders.pillarMaterial, EchoCartographerShaders.gaugeLitMaterial,
            EchoCartographerShaders.gaugeUnlitMaterial,
        ]
        #expect(named == codes)
        #expect(Set(named).count == named.count)
        // The vertex shader selects each material's colour by its code, in code order.
        let selections: [(code: Int, constant: String)] = [
            (code: 1, constant: "EC_FLOOR"), (code: 2, constant: "EC_ENTRY"), (code: 3, constant: "EC_MARKER"),
            (code: 4, constant: "EC_PULSE"), (code: 5, constant: "EC_PULSE"), (code: 6, constant: "EC_WALL_FACE"),
            (code: 7, constant: "EC_WALL_EDGE"), (code: 8, constant: "EC_PILLAR"), (code: 9, constant: "EC_GAUGE_LIT"),
            (code: 10, constant: "EC_GAUGE_UNLIT"),
        ]
        let vertex: String = EchoCartographerShaders.chamberVertex
        #expect(vertex.contains("vec3 base = mix(EC_GROUND, EC_FLOOR, isCode(m, 1.0));"))
        for selection in selections where selection.code > 1 {
            let line: String = "base = mix(base, \(selection.constant), isCode(m, \(selection.code).0));"
            #expect(vertex.contains(line), "\(line)")
        }
        for selection in selections {
            let material: Material? = Material(rawValue: selection.code)
            var expected: SIMD3<Double>? = nil
            for constant in EchoCartographerShaders.paletteConstants where constant.name == selection.constant {
                expected = constant.colour
            }
            #expect(material?.colour == expected, "\(selection.constant)")
        }
        // Lit materials and local-coordinate layouts as documented.
        var lit: [Int] = []
        var fans: [Int] = []
        var strips: [Int] = []
        for material in Material.allCases {
            if material.isLit { lit.append(material.rawValue) }
            if material.localCoordinate == .fan { fans.append(material.rawValue) }
            if material.localCoordinate == .strip { strips.append(material.rawValue) }
        }
        #expect(lit == [1, 6])
        #expect(fans == [1, 2, 9, 10])
        #expect(strips == [3, 4, 7])
        #expect(EchoCartographerShaders.chamberFragment.contains("float isLit = isCode(m, 1.0) + isCode(m, 6.0);"))
    }

    /// The file header documents every material code and the vertex attribute convention agent B's geometry follows.
    @Test func materialCodesAndMeshConventionAreDocumented() throws {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            .appendingPathComponent("EchoCartographerShaders.swift")
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
            "feature 403 (R02-G11-03) T-R02G1103-003", "FR-R02G1103-001, 002, 004",
            "0 ground, 1 floor, 2 entry, 3 marker, 4 ray, 5 ring field,",
            "6 wall face, 7 wall edge, 8 pillar, 9 lit gauge bar, 10 unlit gauge bar)",
            "`a_uv.y` the local edge coordinate", "in `a_normal.x`", "`a_uv.x` is the glow factor",
        ]
        for phrase in phrases { #expect(flat.contains(phrase), "\(phrase)") }
    }

    @Test func softEdgesFollowTheLocalCoordinate() {
        #expect(EchoCartographerShaders.edgeCoverage(local: 0) == 1)
        #expect(EchoCartographerShaders.edgeCoverage(local: 0.8) == 1)
        #expect(EchoCartographerShaders.edgeCoverage(local: 1) == 0)
        #expect(EchoCartographerShaders.edgeCoverage(local: -1) == 0)
        #expect(EchoCartographerShaders.edgeCoverage(local: 3) == 0)
        #expect(EchoCartographerShaders.edgeCoverage(local: .nan) == 0)
        let mid: Double = EchoCartographerShaders.edgeCoverage(local: 0.925)
        #expect(abs(mid - 0.5) < 1e-9)
        #expect(EchoCartographerShaders.edgeCoverage(local: -0.925) == mid)
        var previous: Double = 1
        for i in 0...100 {
            let value: Double = EchoCartographerShaders.edgeCoverage(local: Double(i) / 100)
            #expect(value <= previous + 1e-12)
            previous = value
        }
    }

    @Test func thePulseRingGrowsOneCellPerTenthOfASecondUpToTheLongestRay() {
        let s: Double = 0.18
        let maxRadius: Double = 4.5 * s
        #expect(EchoCartographerShaders.pulseRingRadius(time: 0, cellSize: s, maxRadius: maxRadius) == 0)
        let one: Double = EchoCartographerShaders.pulseRingRadius(time: 0.1, cellSize: s, maxRadius: maxRadius)
        #expect(abs(one - s) < 1e-9)
        let three: Double = EchoCartographerShaders.pulseRingRadius(time: 0.3, cellSize: s, maxRadius: maxRadius)
        #expect(abs(three - 3 * s) < 1e-9)
        #expect(EchoCartographerShaders.pulseRingRadius(time: 5, cellSize: s, maxRadius: maxRadius) == maxRadius)
        #expect(EchoCartographerShaders.pulseRingRadius(time: .nan, cellSize: s, maxRadius: maxRadius) == 0)
        // Full until it reaches the longest ray (0.45 s), gone 0.5 s later; nothing without a pulse.
        #expect(EchoCartographerShaders.pulseRingFade(time: 0.2, cellSize: s, maxRadius: maxRadius) == 1)
        let half: Double = EchoCartographerShaders.pulseRingFade(time: 0.7, cellSize: s, maxRadius: maxRadius)
        #expect(abs(half - 0.5) < 1e-9)
        #expect(EchoCartographerShaders.pulseRingFade(time: 0.96, cellSize: s, maxRadius: maxRadius) == 0)
        #expect(EchoCartographerShaders.pulseRingFade(time: 0.2, cellSize: s, maxRadius: 0) == 0)
        let fragment: String = EchoCartographerShaders.chamberFragment
        #expect(fragment.contains("float pulseRadius = min(time / EC_PULSE_SECONDS_PER_CELL * cell, maxRadius);"))
        #expect(fragment.contains("ring *= clamp(u_tier.x, 0.0, 1.0) * motion;"))
        #expect(fragment.contains("float motion = 1.0 - clamp(u_reduceMotion, 0.0, 1.0);"))
    }

    @Test func echoRingsShrinkToTheEmitterAtTheirDelays() throws {
        #expect(EchoCartographerShaders.echoTicksPerCell == 24)
        #expect(abs(EchoCartographerShaders.echoSecondsPerCell - 0.199992) < 1e-12)
        let delay: Double = EchoCartographerShaders.echoDelay(distance: 5)
        #expect(abs(delay - 5 * 24 * 0.008333) < 1e-12)
        let s: Double = 0.2
        // Absent before the pulse ring passes the beacon's distance (about 0.5 s), at that distance then, at the
        // emitter at the delay, absent after it.
        #expect(EchoCartographerShaders.echoRingRadius(delay: delay, time: 0.2, cellSize: s) == nil)
        let first: Double = try #require(EchoCartographerShaders.echoRingRadius(delay: delay, time: 0.5, cellSize: s))
        #expect(abs(first - 5 * s) < 0.001)
        let last: Double = try #require(EchoCartographerShaders.echoRingRadius(delay: delay, time: delay, cellSize: s))
        #expect(abs(last) < 1e-9)
        #expect(EchoCartographerShaders.echoRingRadius(delay: delay, time: delay + 0.01, cellSize: s) == nil)
        #expect(EchoCartographerShaders.echoRingRadius(delay: 0, time: 0, cellSize: s) == nil)
        // The presenter's delays: ascending, at most four, zero in unused slots.
        let cell: EchoCartographerCell = EchoCartographerCell(x: 0, y: 0)
        let report: EchoCartographerEcho = EchoCartographerEcho(emitter: cell, rays: [],
                                                                beaconDistances: [7, 2, 9, 4, 11])
        let delays: SIMD4<Double> = EchoCartographerShaders.echoDelays(report)
        let expected: [Int] = [2, 4, 7, 9]
        for index in 0..<4 {
            #expect(abs(delays[index] - EchoCartographerShaders.echoDelay(distance: expected[index])) < 1e-12)
        }
        let two: EchoCartographerEcho = EchoCartographerEcho(emitter: cell, rays: [], beaconDistances: [3])
        let partial: SIMD4<Double> = EchoCartographerShaders.echoDelays(two)
        #expect(partial[1] == 0 && partial[2] == 0 && partial[3] == 0)
        #expect(EchoCartographerShaders.echoDelays(nil) == SIMD4<Double>(0, 0, 0, 0))
        #expect(EchoCartographerShaders.chamberFragment.contains("float delay = u_echoDelays[i];"))
    }

    @Test func struckWallsFlareWhenTheRingArrivesAndFadeOverHalfASecond() {
        let level0: SIMD3<Double> = EchoCartographerShaders.tierFlags(for: EchoCartographerTier.of(0))
        let level1: SIMD3<Double> = EchoCartographerShaders.tierFlags(for: EchoCartographerTier.of(1))
        let level2: SIMD3<Double> = EchoCartographerShaders.tierFlags(for: EchoCartographerTier.of(2))
        #expect(level0 == SIMD3<Double>(1, 1, 1))
        #expect(level1 == SIMD3<Double>(1, 1, 0))
        #expect(level2 == SIMD3<Double>(0, 0, 0))
        // A wall 4 cells away: its face is reached at 0.35 s (0.98 a hundredth later).
        #expect(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.3, flags: level1) == 0)
        #expect(abs(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.36, flags: level1) - 0.98) < 1e-9)
        #expect(abs(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.6, flags: level1) - 0.5) < 1e-9)
        #expect(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.86, flags: level1) == 0)
        // The level-0 trail lingers dimmer and longer; level-2 and an unstruck wall never flare.
        let trail: Double = EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.95, flags: level0)
        #expect(trail > 0 && trail < EchoCartographerShaders.trailWeight)
        #expect(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 2.0, flags: level0) == 0)
        #expect(EchoCartographerShaders.flareWeight(strikeDistance: 4, time: 0.4, flags: level2) == 0)
        #expect(EchoCartographerShaders.flareWeight(strikeDistance: 0, time: 0.4, flags: level0) == 0)
        for i in 0...40 {
            let value: Double = EchoCartographerShaders.flareWeight(strikeDistance: 6, time: Double(i) * 0.05,
                                                                     flags: level0)
            #expect(value >= 0 && value <= 1)
        }
        let fragment: String = EchoCartographerShaders.chamberFragment
        let flash: String =
            "float flash = isEdge * struck * max(flare, trail) * clamp(u_tier.y, 0.0, 1.0) * motion;"
        #expect(fragment.contains(flash))
        #expect(EchoCartographerShaders.flareSeconds == 0.5)
        #expect(EchoCartographerShaders.pulseSecondsPerCell == 0.1)
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        let gains: [Double] = [
            EchoCartographerShaders.glowGain(for: EchoCartographerTier.of(0)),
            EchoCartographerShaders.glowGain(for: EchoCartographerTier.of(1)),
            EchoCartographerShaders.glowGain(for: EchoCartographerTier.of(2)),
        ]
        #expect(gains == [1.5, 1.0, 0])
        #expect(EchoCartographerShaders.glowLimit(reduceFlashing: false) == EchoCartographerShaders.standardGlowLimit)
        #expect(EchoCartographerShaders.glowLimit(reduceFlashing: true) == EchoCartographerShaders.glowGainCap)
        #expect(EchoCartographerShaders.glowGainCap == 0.5)
        #expect(EchoCartographerShaders.standardGlowLimit == 1.5)
        #expect(EchoCartographerShaders.maxGlowGain == 1.5)
        for gain in gains {
            let cap: Double = EchoCartographerShaders.glowGainCap
            let capped: Double = EchoCartographerShaders.glowGain(gain: gain, limit: cap)
            #expect(capped <= EchoCartographerShaders.glowGainCap)
        }
        #expect(EchoCartographerShaders.glowGain(gain: 9, limit: 9) == EchoCartographerShaders.maxGlowGain)
        #expect(EchoCartographerShaders.glowGain(gain: .nan, limit: 1) == 0)
        #expect(EchoCartographerShaders.glowGain(gain: -1, limit: 1) == 0)
        let zero: SIMD4<Double> = EchoCartographerShaders.glowColour(colour: EchoCartographerPalette.glow, glow: 1,
                                                                     gain: 0)
        #expect(zero.w == 0)
        let full: SIMD4<Double> = EchoCartographerShaders.glowColour(colour: SIMD3<Double>(0, 0, 0), glow: 1, gain: 1.5)
        #expect(abs(full.w - 0.75) < 1e-12)
        let reduced: SIMD4<Double> = EchoCartographerShaders.glowColour(colour: EchoCartographerPalette.glow, glow: 1,
                                                                        gain: 0.5)
        #expect(reduced.w < full.w)
        let glow: String = EchoCartographerShaders.glowFragment
        let gainLine: String =
            "float gain = min(clamp(u_glowGain, 0.0, EC_MAX_GAIN), clamp(u_glowLimit, 0.0, EC_MAX_GAIN));"
        #expect(glow.contains(gainLine))
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
            .appendingPathComponent("ec-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "chamber.vert", source: EchoCartographerShaders.chamberVertex),
            (name: "chamber.frag", source: EchoCartographerShaders.chamberFragment),
            (name: "glow.vert", source: EchoCartographerShaders.glowVertex),
            (name: "glow.frag", source: EchoCartographerShaders.glowFragment),
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

    /// Feature 403 convergence (T-R02G1103-014): the won flag reaches the fragment shader on wall edges only and lifts
    /// them toward the flare colour by ``EchoCartographerShaders/wonLift`` at every tier (not gated by the tier flags or
    /// Reduce Motion). Feature 406 (R02-G11-06): the lift is scaled by the eased won light `u_wonLight`.
    @Test func aWonLevelLiftsTheWallEdges() {
        let vertex: String = EchoCartographerShaders.chamberVertex
        let fragment: String = EchoCartographerShaders.chamberFragment
        #expect(vertex.contains("v_won = clamp(a_normal.y, 0.0, 1.0) * isEdge;"))
        #expect(fragment.contains("rgb = mix(rgb, EC_FLARE, EC_WON_LIFT * v_won * clamp(u_wonLight, 0.0, 1.0));"))
        #expect(fragment.contains("const float EC_WON_LIFT = 0.5"))
        #expect(EchoCartographerShaders.wonLift > 0 && EchoCartographerShaders.wonLift <= 1)
    }
}
