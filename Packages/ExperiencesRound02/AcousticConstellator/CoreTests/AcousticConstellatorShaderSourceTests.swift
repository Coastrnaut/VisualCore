// AcousticConstellatorShaderSourceTests — feature 423 (R02-G13-03) T-R02G1303-003 (FR-R02G1303-001, 002, 004, 007;
// clarifications Q1–Q5). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and every listed uniform declared and
// used, at most 16 vec4 uniform slots per program (arrays counted by their length), no texture sampler, no `discard`,
// no loops (any `for` would have to be bounded by an int constant), vertex outputs matching fragment inputs, balanced
// braces, ASCII-only sources, the `ShaderMeshRenderer` attribute names and locations and the geometry's vertex
// streams, distinct and documented material codes each selected by the vertex shader, the GLSL palette constants
// parsing back to `AcousticConstellatorPalette` within 1e-6, the star pulse 1 + 0.15 · cos(2π · phase / 12) from
// uniforms (none at level-2 and under Reduce Motion), the wave-shell fade, the won lift, the glow gain per tier (0 at
// level-2) and the Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of each
// source (skipped otherwise; the real compile happens on the simulator).
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams (none of
// these is a dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
// Feature 426 (R02-G13-06) T-R02G1306-005: the constellation vertex stage and the glow fragment stage declare
// `u_wonLight`, which scales the won link's and the won glow's lift (8 and 7 vec4 slots).
import Foundation
import Testing
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorShaderSourceTests {
    typealias Shaders = AcousticConstellatorShaders
    typealias Palette = AcousticConstellatorPalette

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "constellation", vertex: Shaders.constellationVertex, fragment: Shaders.constellationFragment,
                 uniforms: Shaders.constellationUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.constellationVertex, Shaders.constellationFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// Rec. 709 luminance of `c`.
    static func luminance(_ c: SIMD3<Double>) -> Double { 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }

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
        let constants: [String] = [Shaders.mvpUniform, Shaders.phasesLowUniform, Shaders.phasesHighUniform, Shaders.pulseUniform,
                                   Shaders.glowGainUniform, Shaders.glowLimitUniform, Shaders.wonLightUniform]
        #expect(constants == ["u_mvp", "u_phasesLow", "u_phasesHigh", "u_pulse", "u_glowGain", "u_glowLimit",
                              "u_wonLight"])
        #expect(Set(constants) == Set(Shaders.constellationUniforms + Shaders.glowUniforms))
        #expect(Shaders.constellationUniforms == ["u_mvp", "u_phasesLow", "u_phasesHigh", "u_pulse", "u_wonLight"])
        #expect(Shaders.phaseRowUniforms == ["u_phasesLow", "u_phasesHigh"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_wonLight"])
        let vertex: String = Shaders.constellationVertex
        let declarations: [String] = ["uniform mat4 u_mvp;", "uniform vec4 u_phasesLow;", "uniform vec4 u_phasesHigh;", "uniform float u_pulse;", "uniform float u_wonLight;"]
        for declaration in declarations { #expect(vertex.contains(declaration), "\(declaration)") }
        // Feature 426: the glow program declares the won light in its fragment stage only.
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_wonLight"])
        #expect(Shaders.glowFragment.contains("uniform float u_wonLight;"))
        #expect(Self.declared("uniform", in: Shaders.constellationFragment).isEmpty)
        // The glow has no time or pulse input: it never pulses.
        let glow: String = Shaders.glowVertex + Shaders.glowFragment
        #expect(Self.wordCount("u_pulse", in: glow) == 0)
        #expect(Self.wordCount("u_phasesLow", in: glow) == 0)
        #expect(Self.wordCount("u_phasesHigh", in: glow) == 0)
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
        #expect(slotsByProgram == ["constellation": 8, "glow": 7])
        #expect(Shaders.maxStars == AcousticConstellatorLevel.starCounts.upperBound)
        #expect(Shaders.phaseRows * 4 == Shaders.maxStars)
        #expect(Shaders.clockSteps == AcousticConstellatorClock.steps)
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
        }
        // The pulse reads the two phase vectors whole (no array, no dynamic indexing).
        let vertex: String = Shaders.constellationVertex
        #expect(vertex.contains("vec4 row = mix(u_phasesLow, u_phasesHigh, upper);"))
        #expect(Self.wordCount("u_phasesLow", in: vertex) == 2)
        #expect(Self.wordCount("u_phasesHigh", in: vertex) == 2)
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
        let constellationOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_material": "float", "v_local": "float",
        ]
        #expect(Self.interface("out", in: Shaders.constellationVertex) == constellationOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float", "v_age": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.constellationVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.constellationFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.constellationVertex, Shaders.glowVertex]
        for source in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // The geometry's streams: uv = (material code, d or star index); a star's normal the unit-sphere direction;
        // glow colour in the normal slot, uv = (2 kind + factor, age).
        let vertex: String = Shaders.constellationVertex
        let lines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, 14.0);",
            "float index = clamp(floor(a_uv.y + 0.5), 0.0, AC_MAX_STAR);",
            "vec3 offset = AC_STAR_RADII * a_normal * isStar;",
            "v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - isStar);",
        ]
        for line in lines { #expect(vertex.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 2.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_age = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        #expect(Shaders.paletteConstants.count == 16)
        var tableNames: Set<String> = []
        for entry in Shaders.paletteConstants {
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
            (name: "AC_SKY", colour: Palette.sky), (name: "AC_STAR", colour: Palette.star),
            (name: "AC_HAND", colour: Palette.hand), (name: "AC_SILVER", colour: Palette.silver),
            (name: "AC_TEAL", colour: Palette.teal), (name: "AC_GUIDE", colour: Palette.guide),
            (name: "AC_BROKEN", colour: Palette.broken), (name: "AC_COHERENCE_LIT", colour: Palette.coherenceLit),
            (name: "AC_COHERENCE_UNLIT", colour: Palette.coherenceUnlit),
            (name: "AC_THRESHOLD_MARK", colour: Palette.thresholdMark),
            (name: "AC_HOLD_LIT", colour: Palette.holdLit), (name: "AC_HOLD_UNLIT", colour: Palette.holdUnlit),
            (name: "AC_MOVES_LIT", colour: Palette.movesLit), (name: "AC_MOVES_UNLIT", colour: Palette.movesUnlit),
            (name: "AC_SHELL", colour: Palette.shell), (name: "AC_GLOW", colour: Palette.glow),
        ]
        for entry in palette {
            var matched: Bool = false
            for constant in Shaders.paletteConstants where constant.name == entry.name {
                matched = constant.colour == entry.colour
            }
            #expect(matched, "\(entry.name)")
        }
        // Every vec3 constant in every source is a palette colour with the table's value, the light or the radii.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "AC_LIGHT" {
                    #expect(Self.distance(parsed, Shaders.lightDirection) <= tolerance)
                    continue
                }
                if name == "AC_STAR_RADII" {
                    #expect(Self.distance(parsed, Shaders.starRadii) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals.
        let vertex: String = Shaders.constellationVertex
        #expect(vertex.contains("const vec3 AC_SKY = vec3(0.019608, 0.023529, 0.058824);"))
        #expect(vertex.contains("const vec3 AC_TEAL = vec3(0.247059, 0.839216, 0.776471);"))
        #expect(vertex.contains("const vec3 AC_BROKEN = vec3(1.000000, 0.419608, 0.290196);"))
        let light: SIMD3<Double> = Shaders.lightDirection
        #expect(abs((light.x * light.x + light.y * light.y + light.z * light.z) - 1) < 1e-12)
        let fragment: String = Shaders.constellationFragment
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "AC_PI", value: Double.pi, source: vertex),
            (name: "AC_STEPS", value: 12, source: vertex),
            (name: "AC_PULSE", value: 0.15, source: vertex),
            (name: "AC_MAX_STAR", value: 7, source: vertex),
            (name: "AC_WON_LIFT", value: Shaders.wonLift, source: vertex),
            (name: "AC_AMBIENT", value: Shaders.ambient, source: fragment),
            (name: "AC_DIFFUSE", value: Shaders.diffuse, source: fragment),
            (name: "AC_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "AC_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "AC_CORE", value: Shaders.coreLift, source: glowF),
            (name: "AC_WON_LIFT", value: Shaders.wonLift, source: glowF),
            (name: "AC_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(Shaders.ambient + Shaders.diffuse == 1.0)
        #expect(Shaders.starRadii == SIMD3<Double>(0.045, 0.035, 0.045))
    }

    @Test func everyMaterialCodeIsDistinctDocumentedAndSelected() {
        var codes: [Int] = []
        for material in AcousticConstellatorMaterial.allCases { codes.append(material.rawValue) }
        #expect(codes == Array(0...14))
        let vertex: String = Shaders.constellationVertex
        for material in AcousticConstellatorMaterial.allCases where material != .sky {
            #expect(vertex.contains("isCode(m, \(material.rawValue).0)"), "\(material) not selected")
        }
        #expect(AcousticConstellatorMaterial.sky.colour == Palette.sky)
        #expect(AcousticConstellatorMaterial.tealLink.colour == Palette.teal)
        #expect(AcousticConstellatorMaterial.star.isLit)
        var lit: Int = 0
        for material in AcousticConstellatorMaterial.allCases where material.isLit { lit += 1 }
        #expect(lit == 1)
        #expect(AcousticConstellatorMaterial.star.localCoordinate == .starIndex)
        #expect(AcousticConstellatorMaterial.sky.localCoordinate == .none)
        #expect(AcousticConstellatorMaterial.tealLink.localCoordinate == .strip)
        #expect(AcousticConstellatorMaterial.movesLit.localCoordinate == .fan)
        // The won link is teal lifted toward the glow colour: brighter, still green above red.
        let won: SIMD3<Double> = AcousticConstellatorMaterial.wonLink.colour
        #expect(Self.luminance(won) > Self.luminance(Palette.teal))
        #expect(won.y - won.x >= 0.05)
        #expect(Self.distance(won, Palette.teal + (Palette.glow - Palette.teal) * 0.4) < 1e-12)
        // Glow kinds round-trip through the a_uv.x encoding.
        let factors: [Double] = [0, 0.25, 1]
        for kind in AcousticConstellatorGlowKind.allCases {
            for factor in factors {
                let decoded = AcousticConstellatorGlowKind.decode(kind.code(factor: factor))
                #expect(decoded.kind == kind, "\(kind) \(factor)")
                #expect(abs(decoded.factor - factor) < 1e-12, "\(kind) \(factor)")
            }
        }
    }

    @Test func materialCodesAndStreamsAreDocumented() throws {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            .appendingPathComponent("AcousticConstellatorShaders.swift")
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
            "feature 423 (R02-G13-03) T-R02G1303-003", "FR-R02G1303-001, 002, 004, 007",
            "0 sky, 1 guide, 2 silver link, 3 teal link, 4 broken, 5 star, 6 hand, 7 coherence lit,",
            "8 coherence unlit, 9 threshold mark, 10 hold lit, 11 hold unlit, 12 moves lit, 13 moves unlit, 14 won link)",
            "`a_uv.y` the local coordinate d", "on a star `a_uv.y` is the star index", "unit-sphere direction s",
            "`a_uv.x` is 2 · kind + factor", "0 glow shell, 1 won symbol link's glow shell, 2 wave shell",
            "`a_uv.y` the wave shell's age", "1 + ``pulseAmplitude`` · pulse ·",
        ]
        for phrase in phrases { #expect(flat.contains(phrase), "\(phrase)") }
    }

    @Test func softEdgesFollowTheLocalCoordinate() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.8) == 1)
        #expect(Shaders.edgeCoverage(local: 1) == 0)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: .nan) == 0)
        let middle: Double = Shaders.edgeCoverage(local: 0.925)
        #expect(middle > 0 && middle < 1)
        let fragment: String = Shaders.constellationFragment
        #expect(fragment.contains("float alpha = clamp(1.0 - smoothstep(1.0 - AC_EDGE_FEATHER, 1.0, d), 0.0, 1.0);"))
        #expect(fragment.contains("float light = mix(1.0, AC_AMBIENT + AC_DIFFUSE * lambert, isLit);"))
    }

    @Test func theStarPulseComesFromUniformsAndStopsAtLevelTwoAndUnderReduceMotion() {
        #expect(Shaders.pulse(for: AcousticConstellatorTier.of(0), reduceMotion: false) == 1)
        #expect(Shaders.pulse(for: AcousticConstellatorTier.of(1), reduceMotion: false) == 1)
        #expect(Shaders.pulse(for: AcousticConstellatorTier.of(2), reduceMotion: false) == 0)
        for index in 0..<3 {
            #expect(Shaders.pulse(for: AcousticConstellatorTier.of(index), reduceMotion: true) == 0)
        }
        // 1 + 0.15 · cos(2π · phase / 12): 1.15 at 0, 1 at 3, 0.85 at 6; exactly 1 without pulse.
        #expect(abs(Shaders.pulseScale(phase: 0, pulse: 1) - 1.15) < 1e-12)
        #expect(abs(Shaders.pulseScale(phase: 3, pulse: 1) - 1.0) < 1e-12)
        #expect(abs(Shaders.pulseScale(phase: 6, pulse: 1) - 0.85) < 1e-12)
        for phase in 0..<12 {
            let scale: Double = Shaders.pulseScale(phase: Double(phase), pulse: 1)
            let expected: Double = 1 + 0.15 * cos(2 * Double.pi * Double(phase) / 12)
            #expect(abs(scale - expected) < 1e-12)
            #expect(scale >= 0.85 - 1e-12 && scale <= 1.15 + 1e-12)
            #expect(Shaders.pulseScale(phase: Double(phase), pulse: 0) == 1)
        }
        #expect(Shaders.pulseScale(phase: .nan, pulse: .infinity) == 1)
        // The phases uniform: star i in lane i % 4 of row i / 4, reduced, unused lanes 0, extra stars ignored.
        let rows: [SIMD4<Double>] = Shaders.phaseUniform([0, 1, 2, 3, 4, 13, -1])
        #expect(rows == [SIMD4<Double>(0, 1, 2, 3), SIMD4<Double>(4, 1, 11, 0)])
        #expect(Shaders.phaseUniform(Array(0..<12)) == [SIMD4<Double>(0, 1, 2, 3), SIMD4<Double>(4, 5, 6, 7)])
        #expect(Shaders.phaseUniform([]).count == Shaders.phaseRows)
        // A star scales about its centre; without pulse it stays where the geometry wrote it.
        let centre: SIMD3<Double> = SIMD3<Double>(0.1, 0.15, -0.2)
        let direction: SIMD3<Double> = SIMD3<Double>(0, 1, 0)
        let written: SIMD3<Double> = centre + Shaders.starOffset(direction: direction)
        #expect(Shaders.pulsedStarVertex(position: written, direction: direction, phase: 4, pulse: 0) == written)
        let pulsed: SIMD3<Double> = Shaders.pulsedStarVertex(position: written, direction: direction, phase: 0, pulse: 1)
        #expect(Self.distance(pulsed, centre + SIMD3<Double>(0, 0.035 * 1.15, 0)) < 1e-12)
        let vertex: String = Shaders.constellationVertex
        let lines: [String] = [
            "float pulse = clamp(u_pulse, 0.0, 1.0) * isStar;",
            "float scale = 1.0 + AC_PULSE * pulse * cos(2.0 * AC_PI * phase / AC_STEPS);",
            "vec3 position = a_position + offset * (scale - 1.0);",
            "v_normal = mix(a_normal, a_normal / AC_STAR_RADII, isStar);",
        ]
        for line in lines { #expect(vertex.contains(line), "\(line)") }
    }

    @Test func waveShellsFadeAsTheyExpand() {
        #expect(Shaders.waveShellSeconds == 1.0)
        #expect(Shaders.maxWaveShellRadius == 0.12)
        #expect(Shaders.waveShellHalfWidth * 2 == 0.01)
        #expect(Shaders.waveShellRadius(age: 0) == 0)
        #expect(Shaders.waveShellRadius(age: 1) == 0.12)
        #expect(Shaders.waveShellRadius(age: 5) == 0.12)
        #expect(Shaders.waveShellAge(seconds: 0, index: 0, count: 2) == 0)
        #expect(Shaders.waveShellAge(seconds: 0, index: 1, count: 2) == 0.5)
        #expect(abs(Shaders.waveShellAge(seconds: 0.25, index: 0, count: 2) - 0.25) < 1e-12)
        #expect(Shaders.waveShellAge(seconds: .nan, index: 0, count: 0) == 0)
        var previous: Double = 2
        for step in 0...4 {
            let age: Double = Double(step) / 4
            let glow: SIMD4<Double> = Shaders.glowColour(colour: Palette.shell, kind: .waveShell, factor: 1, age: age,
                                                         gain: 1.5)
            #expect(glow.w < previous)
            previous = glow.w
        }
        #expect(previous == 0)
        let fresh: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .waveShell, factor: 1,
                                                      age: 0, gain: 0)
        #expect(SIMD3<Double>(fresh.x, fresh.y, fresh.z) == Palette.shell)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("float fade = mix(1.0, 1.0 - clamp(v_age, 0.0, 1.0), isShell);"))
        #expect(glow.contains("float alpha = clamp(AC_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);"))
        #expect(glow.contains("vec3 fallback = mix(AC_GLOW, AC_SHELL, isShell);"))
    }

    /// Feature 426 (R02-G13-06): the won link's and the won glow's lift are scaled by the eased won light `u_wonLight`.
    @Test func aWonLevelLiftsTheSymbolLinksAndTheirGlow() {
        let vertex: String = Shaders.constellationVertex
        #expect(vertex.contains(
            "base = mix(base, mix(AC_TEAL, AC_GLOW, AC_WON_LIFT * clamp(u_wonLight, 0.0, 1.0)), isCode(m, 14.0));"))
        let glow: String = Shaders.glowFragment
        #expect(glow.contains("float isWon = isCode(kind, 1.0);"))
        #expect(glow.contains("float light = clamp(u_wonLight, 0.0, 1.0);"))
        #expect(glow.contains("float won = isWon * light;"))
        #expect(glow.contains("colour = mix(colour, mix(AC_GLOW, colour, light), isWon);"))
        #expect(glow.contains(
            "vec3 rgb = mix(colour, AC_STAR, clamp((AC_CORE * gain + AC_WON_LIFT * won) * factor, 0.0, 1.0));"))
        let plain: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .glow, factor: 1, age: 0, gain: 1)
        let won: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .wonGlow, factor: 1, age: 0, gain: 1)
        #expect(won.x + won.y + won.z > plain.x + plain.y + plain.z)
        // The won lift never raises the glow's alpha past the gain (Reduce Flashing still caps it), and glow shells
        // never fade by age.
        #expect(won.w == plain.w)
        let aged: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .wonGlow, factor: 1, age: 0.9, gain: 1)
        #expect(aged.w == won.w)
        #expect(Shaders.wonLift > 0 && Shaders.wonLift <= 1)
    }

    /// Feature 426 (R02-G13-06) T-R02G1306-005: at won light 0 a won link is teal and a won glow (even with the
    /// geometry's lifted stream colour) a plain glow; at 1 both are as before; in between the lift grows
    /// monotonically and the alpha never changes.
    @Test func theWonLightScalesTheWonLinkAndTheWonGlow() {
        #expect(Self.distance(Shaders.wonLinkColour(light: 0), Palette.teal) < 1e-12)
        #expect(Self.distance(Shaders.wonLinkColour(light: 1), Shaders.wonLinkColour) < 1e-12)
        #expect(Self.distance(Shaders.wonLinkColour(light: .nan), Shaders.wonLinkColour) < 1e-12)
        #expect(Self.distance(Shaders.wonLinkColour(light: -2), Palette.teal) < 1e-12)
        let stream: SIMD3<Double> = Palette.glow + (SIMD3<Double>(1, 1, 1) - Palette.glow) * 0.35
        let plain: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .glow, factor: 0.5, age: 0, gain: 1)
        let off: SIMD4<Double> = Shaders.glowColour(colour: stream, kind: .wonGlow, factor: 0.5, age: 0, gain: 1,
                                                    wonLight: 0)
        #expect(abs(off.x - plain.x) < 1e-12 && abs(off.y - plain.y) < 1e-12 && abs(off.z - plain.z) < 1e-12)
        let today: SIMD4<Double> = Shaders.glowColour(colour: stream, kind: .wonGlow, factor: 0.5, age: 0, gain: 1)
        #expect(today == Shaders.glowColour(colour: stream, kind: .wonGlow, factor: 0.5, age: 0, gain: 1, wonLight: 1))
        var previous: Double = -1
        var previousLink: Double = -1
        for tenth in 0...10 {
            let light: Double = Double(tenth) / 10
            let glow: SIMD4<Double> = Shaders.glowColour(colour: stream, kind: .wonGlow, factor: 0.5, age: 0, gain: 1,
                                                         wonLight: light)
            #expect(glow.w == plain.w, "the won light never changes the alpha")
            let sum: Double = glow.x + glow.y + glow.z
            #expect(sum >= previous - 1e-12, "the won glow brightens with the light")
            previous = sum
            let link: SIMD3<Double> = Shaders.wonLinkColour(light: light)
            let distance: Double = Self.distance(link, Palette.teal)
            #expect(distance >= previousLink - 1e-12, "the won link moves away from teal with the light")
            previousLink = distance
        }
        // A plain glow ignores the won light.
        let plainOff: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .glow, factor: 0.5, age: 0,
                                                         gain: 1, wonLight: 0)
        #expect(plainOff == plain)
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        let gains: [Double] = [
            Shaders.glowGain(for: AcousticConstellatorTier.of(0)),
            Shaders.glowGain(for: AcousticConstellatorTier.of(1)),
            Shaders.glowGain(for: AcousticConstellatorTier.of(2)),
        ]
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowLimit(reduceFlashing: false) == Shaders.standardGlowLimit)
        #expect(Shaders.glowLimit(reduceFlashing: true) == Shaders.glowGainCap)
        #expect(Shaders.glowGainCap == 0.5)
        #expect(Shaders.standardGlowLimit == 1.5)
        #expect(Shaders.maxGlowGain == 1.5)
        for gain in gains {
            let capped: Double = Shaders.glowGain(gain: gain, limit: Shaders.glowLimit(reduceFlashing: true))
            #expect(capped <= Shaders.glowGainCap)
        }
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        #expect(Shaders.glowGain(gain: .nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: -1, limit: 1) == 0)
        let zero: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .wonGlow, factor: 1, age: 0, gain: 0)
        #expect(zero.w == 0)
        let full: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .glow, factor: 1, age: 0,
                                                     gain: 1.5)
        #expect(abs(full.w - 0.75) < 1e-12)
        let reduced: SIMD4<Double> = Shaders.glowColour(colour: Palette.glow, kind: .glow, factor: 1, age: 0, gain: 0.5)
        #expect(reduced.w < full.w)
        let glow: String = Shaders.glowFragment
        #expect(glow.contains(
            "float gain = min(clamp(u_glowGain, 0.0, AC_MAX_GAIN), clamp(u_glowLimit, 0.0, AC_MAX_GAIN));"))
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
            .appendingPathComponent("ac-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "constellation.vert", source: Shaders.constellationVertex),
            (name: "constellation.frag", source: Shaders.constellationFragment),
            (name: "glow.vert", source: Shaders.glowVertex),
            (name: "glow.frag", source: Shaders.glowFragment),
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
