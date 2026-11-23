// BackwardsAuroraShaderSourceTests — feature 393 (R02-G10-03) T-R02G1003-003 (FR-R02G1003-002, 004, 007; clarifications
// Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared
// uniform listed (equal to the uniform name constants the scene sets) and every listed uniform declared and used, at
// most 16 vec4 uniform slots per program, no texture sampler, no `discard`, every loop bounded by a constant (the aurora
// fragment's one pulse loop by `BA_MAX_PULSES` = 2, no `while`), vertex outputs matching fragment inputs, balanced
// braces, the `ShaderMeshRenderer` attribute names and locations, distinct material codes, the GLSL palette constants
// parsing back to `BackwardsAuroraPalette` within 1/255, the direction-coded pulses and the shimmer driven by `u_time`
// alone and following the tier, the trailing-layer alphas, the glow gain per tier and the Reduce Flashing limit. The
// real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams; the
// limit 0.5 is Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` (none of these is a dependency of this
// target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "aurora", vertex: BackwardsAuroraShaders.auroraVertex,
                 fragment: BackwardsAuroraShaders.auroraFragment, uniforms: BackwardsAuroraShaders.auroraUniforms),
         Program(name: "glow", vertex: BackwardsAuroraShaders.glowVertex,
                 fragment: BackwardsAuroraShaders.glowFragment, uniforms: BackwardsAuroraShaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [BackwardsAuroraShaders.auroraVertex, BackwardsAuroraShaders.auroraFragment,
         BackwardsAuroraShaders.glowVertex, BackwardsAuroraShaders.glowFragment]
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

    /// The position along |t| in 0 ... 1 (step 1/1000) where the pulse intensity peaks for signed side `sign`.
    static func peak(sign: Double, time: Double, pulses: Double) -> Double {
        var best: Double = -1
        var where_: Double = 0
        for i in 1..<1000 {
            let along: Double = Double(i) / 1000
            let value: Double = BackwardsAuroraShaders.pulseIntensity(t: sign * along, time: time, pulses: pulses)
            if value > best {
                best = value
                where_ = along
            }
        }
        return where_
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(BackwardsAuroraShaders.versionLine == "#version 300 es")
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
            #expect(BackwardsAuroraShaders.uniformNames[program.name] == program.uniforms)
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(BackwardsAuroraShaders.uniformNames.count == 2)
        let constants: [String] = [
            BackwardsAuroraShaders.mvpUniform, BackwardsAuroraShaders.lightDirectionUniform,
            BackwardsAuroraShaders.eyeUniform, BackwardsAuroraShaders.timeUniform,
            BackwardsAuroraShaders.pulsesUniform, BackwardsAuroraShaders.wonUniform,
            BackwardsAuroraShaders.tearLightUniform, BackwardsAuroraShaders.previewLightUniform,
            BackwardsAuroraShaders.glowUniform, BackwardsAuroraShaders.glowLimitUniform,
        ]
        let names: [String] = ["u_mvp", "u_lightDir", "u_eye", "u_time", "u_pulses", "u_won", "u_tearLight",
                               "u_previewLight", "u_glow", "u_glowLimit"]
        #expect(constants == names)
        let listed: Set<String> = Set(BackwardsAuroraShaders.auroraUniforms + BackwardsAuroraShaders.glowUniforms)
        #expect(Set(constants) == listed)
        let aurora: String = BackwardsAuroraShaders.auroraVertex + BackwardsAuroraShaders.auroraFragment
        let auroraDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_lightDir;", "uniform vec3 u_eye;", "uniform float u_time;",
            "uniform float u_pulses;", "uniform float u_won;", "uniform float u_tearLight;",
            "uniform float u_previewLight;",
        ]
        for declaration in auroraDeclarations { #expect(aurora.contains(declaration), "\(declaration)") }
        let glow: String = BackwardsAuroraShaders.glowVertex + BackwardsAuroraShaders.glowFragment
        let glowDeclarations: [String] = ["uniform mat4 u_mvp;", "uniform float u_glow;", "uniform float u_glowLimit;"]
        for declaration in glowDeclarations { #expect(glow.contains(declaration), "\(declaration)") }
        #expect(Self.wordCount("u_time", in: glow) == 0)
    }

    /// Feature 396 (R02-G10-06): the tear cross's and the preview ribbon's alphas are scaled by their eased lights.
    @Test func theTearAndPreviewLightsScaleTheirAlphas() {
        let fragment: String = BackwardsAuroraShaders.auroraFragment
        #expect(fragment.contains("alpha *= 1.0 - isTear * (1.0 - clamp(u_tearLight, 0.0, 1.0));"))
        #expect(fragment.contains("alpha *= 1.0 - isPreview * (1.0 - clamp(u_previewLight, 0.0, 1.0));"))
        #expect(fragment.contains("float isTear = isCode(m, 9.0);"))
        #expect(BackwardsAuroraShaders.auroraUniforms.suffix(2) == ["u_tearLight", "u_previewLight"])
    }

    /// A won level (stage won, or the result after a win) lifts the ribbon; every other stage leaves it.
    @Test func aWonLevelLiftsTheRibbon() {
        #expect(BackwardsAuroraShaders.won(stage: .won, failure: nil) == 1)
        #expect(BackwardsAuroraShaders.won(stage: .result, failure: nil) == 1)
        #expect(BackwardsAuroraShaders.won(stage: .result, failure: .budget) == 0)
        #expect(BackwardsAuroraShaders.won(stage: .failed, failure: .budget) == 0)
        #expect(BackwardsAuroraShaders.won(stage: .playing, failure: nil) == 0)
        #expect(BackwardsAuroraShaders.wonLift == 0.35)
        #expect(BackwardsAuroraShaders.auroraFragment.contains("BA_WON_LIFT"))
    }

    @Test func atMostSixteenVec4UniformsPerProgram() {
        #expect(BackwardsAuroraShaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            var seen: Set<String> = []
            for declaration in Self.declarations("uniform", in: program.vertex + "\n" + program.fragment)
            where !seen.contains(declaration.name) {
                seen.insert(declaration.name)
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= BackwardsAuroraShaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["aurora": 11, "glow": 6])   // feature 396: + u_tearLight, u_previewLight
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
                    #expect(Self.scalarConstant("int", name, in: source) != nil, "\(name) is not a constant")
                }
            }
        }
        #expect(Self.wordCount("for", in: BackwardsAuroraShaders.auroraVertex) == 0)
        #expect(Self.wordCount("for", in: BackwardsAuroraShaders.glowVertex) == 0)
        #expect(Self.wordCount("for", in: BackwardsAuroraShaders.glowFragment) == 0)
        let fragment: String = BackwardsAuroraShaders.auroraFragment
        #expect(Self.wordCount("for", in: fragment) == 1)
        #expect(fragment.contains("for (int i = 0; i < BA_MAX_PULSES; i++) {"))
        #expect(Self.scalarConstant("int", "BA_MAX_PULSES", in: fragment) == 2)
        #expect(BackwardsAuroraShaders.maxPulses == 2)
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
        let auroraOuts: [String: String] = [
            "v_normal": "vec3", "v_base": "vec3", "v_position": "vec3", "v_material": "float", "v_t": "float",
        ]
        #expect(Self.interface("out", in: BackwardsAuroraShaders.auroraVertex) == auroraOuts)
        #expect(Self.interface("out", in: BackwardsAuroraShaders.glowVertex) == ["v_colour": "vec3", "v_glow": "float"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in BackwardsAuroraShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(BackwardsAuroraShaders.auroraVertex) == expected)
        #expect(Self.layouts(BackwardsAuroraShaders.glowVertex) == expected)
        #expect(Self.layouts(BackwardsAuroraShaders.auroraFragment).isEmpty)
        #expect(Self.layouts(BackwardsAuroraShaders.glowFragment).isEmpty)
        for source in [BackwardsAuroraShaders.auroraVertex, BackwardsAuroraShaders.glowVertex] {
            for attribute in BackwardsAuroraShaders.attributes {
                #expect(Self.wordCount(attribute.name, in: source) >= 2, "\(attribute.name) declared but never read")
            }
        }
        // Mesh streams: aurora uv = (material code, signed timeline t); glow colour in the normal slot, uv = (glow, 0).
        let vertex: String = BackwardsAuroraShaders.auroraVertex
        #expect(vertex.contains("float m = clamp(floor(a_uv.x + 0.5), 0.0, 13.0);"))
        #expect(vertex.contains("v_t = clamp(a_uv.y, -1.0, 1.0);"))
        #expect(BackwardsAuroraShaders.glowVertex.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(BackwardsAuroraShaders.glowVertex.contains("v_glow = clamp(a_uv.x, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 1.0 / 255.0
        let auroraV: String = BackwardsAuroraShaders.auroraVertex
        let auroraF: String = BackwardsAuroraShaders.auroraFragment
        let glowF: String = BackwardsAuroraShaders.glowFragment
        let pairs: [(name: String, colour: SIMD3<Double>, source: String)] = [
            (name: "BA_GROUND", colour: BackwardsAuroraPalette.ground, source: auroraV),
            (name: "BA_BAND", colour: BackwardsAuroraPalette.band, source: auroraV),
            (name: "BA_RIBBON", colour: BackwardsAuroraPalette.ribbon, source: auroraV),
            (name: "BA_GHOST", colour: BackwardsAuroraPalette.ghost, source: auroraV),
            (name: "BA_RING", colour: BackwardsAuroraPalette.ring, source: auroraV),
            (name: "BA_MATCHED", colour: BackwardsAuroraPalette.matched, source: auroraV),
            (name: "BA_KINK", colour: BackwardsAuroraPalette.kink, source: auroraV),
            (name: "BA_TEAR", colour: BackwardsAuroraPalette.tear, source: auroraV),
            (name: "BA_SPENT", colour: BackwardsAuroraPalette.spent, source: auroraV),
            (name: "BA_UNSPENT", colour: BackwardsAuroraPalette.unspent, source: auroraV),
            (name: "BA_RIBBON", colour: BackwardsAuroraPalette.ribbon, source: auroraF),
            (name: "BA_HIGHLIGHT", colour: BackwardsAuroraPalette.ribbonHighlight, source: auroraF),
            (name: "BA_HIGHLIGHT", colour: BackwardsAuroraPalette.ribbonHighlight, source: glowF),
        ]
        for pair in pairs {
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(pair.name, in: pair.source), "\(pair.name)")
            #expect(Self.distance(parsed, pair.colour) <= tolerance, "\(pair.name)")
        }
        // Every vec3 constant in every source is a palette colour (no stray colour).
        let palette: [SIMD3<Double>] = [
            BackwardsAuroraPalette.ground, BackwardsAuroraPalette.ribbon, BackwardsAuroraPalette.ribbonHighlight,
            BackwardsAuroraPalette.glow, BackwardsAuroraPalette.ghost, BackwardsAuroraPalette.ring,
            BackwardsAuroraPalette.matched, BackwardsAuroraPalette.kink, BackwardsAuroraPalette.tear,
            BackwardsAuroraPalette.band, BackwardsAuroraPalette.spent, BackwardsAuroraPalette.unspent,
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
        // The design's hex values, six fixed decimals.
        #expect(Self.distance(BackwardsAuroraPalette.ground, SIMD3<Double>(7, 11, 31) / 255) < 1e-12)
        #expect(Self.distance(BackwardsAuroraPalette.ribbon, SIMD3<Double>(31, 200, 214) / 255) < 1e-12)
        #expect(auroraV.contains("const vec3 BA_GROUND = vec3(0.027451, 0.043137, 0.121569);"))
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "BA_AMBIENT", value: BackwardsAuroraShaders.ambient, source: auroraF),
            (name: "BA_DIFFUSE", value: BackwardsAuroraShaders.diffuse, source: auroraF),
            (name: "BA_EMISSION", value: BackwardsAuroraShaders.emission, source: auroraF),
            (name: "BA_FRESNEL_POWER", value: BackwardsAuroraShaders.fresnelPower, source: auroraF),
            (name: "BA_SHEEN_WEIGHT", value: BackwardsAuroraShaders.sheenWeight, source: auroraF),
            (name: "BA_SHIMMER_WEIGHT", value: BackwardsAuroraShaders.shimmerWeight, source: auroraF),
            (name: "BA_SHIMMER_FREQUENCY", value: BackwardsAuroraShaders.shimmerFrequency, source: auroraF),
            (name: "BA_SHIMMER_SPEED", value: BackwardsAuroraShaders.shimmerSpeed, source: auroraF),
            (name: "BA_PULSE_SPEED", value: BackwardsAuroraShaders.pulseSpeed, source: auroraF),
            (name: "BA_PULSE_WIDTH", value: BackwardsAuroraShaders.pulseWidth, source: auroraF),
            (name: "BA_FIRST_LAYER_ALPHA", value: BackwardsAuroraShaders.firstLayerAlpha, source: auroraF),
            (name: "BA_SECOND_LAYER_ALPHA", value: BackwardsAuroraShaders.secondLayerAlpha, source: auroraF),
            (name: "BA_GLOW_WEIGHT", value: BackwardsAuroraShaders.glowWeight, source: glowF),
            (name: "BA_CORE", value: BackwardsAuroraShaders.coreLift, source: glowF),
            (name: "BA_MAX_GAIN", value: BackwardsAuroraShaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let parsed: Double = try #require(Self.scalarConstant("float", entry.name, in: entry.source),
                                              "\(entry.name)")
            #expect(abs(parsed - entry.value) < 1e-6, "\(entry.name)")
        }
        #expect(BackwardsAuroraShaders.ambient + BackwardsAuroraShaders.diffuse == 1.0)
        // Shimmer and sheen together never push the ribbon past the highlight.
        #expect(BackwardsAuroraShaders.shimmerWeight + BackwardsAuroraShaders.sheenWeight <= 1.0)
    }

    @Test func materialCodesAreDistinctAndSelectThePalette() {
        typealias Material = BackwardsAuroraShaders.AuroraMaterial
        var codes: [Double] = []
        for material in Material.allCases {
            codes.append(material.code)
            #expect(Double(material.rawValue) == material.code)
            if material != .ground { #expect(material.colour != BackwardsAuroraPalette.ground) }
        }
        #expect(codes == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
        let named: [Double] = [
            BackwardsAuroraShaders.groundMaterial, BackwardsAuroraShaders.bandMaterial,
            BackwardsAuroraShaders.trailingLayerMaterial, BackwardsAuroraShaders.ghostMaterial,
            BackwardsAuroraShaders.tickMaterial, BackwardsAuroraShaders.ribbonMaterial,
            BackwardsAuroraShaders.ringMaterial, BackwardsAuroraShaders.discMaterial,
            BackwardsAuroraShaders.kinkMaterial, BackwardsAuroraShaders.tearMaterial,
            BackwardsAuroraShaders.spentMaterial, BackwardsAuroraShaders.unspentMaterial,
            BackwardsAuroraShaders.secondTrailingLayerMaterial, BackwardsAuroraShaders.previewMaterial,
        ]
        #expect(named == codes)
        #expect(Set(named).count == named.count)
        #expect(Material.band.colour == BackwardsAuroraPalette.band)
        #expect(Material.trailingLayer.colour == BackwardsAuroraPalette.ribbon)
        #expect(Material.secondTrailingLayer.colour == BackwardsAuroraPalette.ribbon)
        #expect(Material.ghost.colour == BackwardsAuroraPalette.ghost)
        #expect(Material.tick.colour == BackwardsAuroraPalette.ring)
        #expect(Material.ribbon.colour == BackwardsAuroraPalette.ribbon)
        #expect(Material.ring.colour == BackwardsAuroraPalette.ring)
        #expect(Material.disc.colour == BackwardsAuroraPalette.matched)
        #expect(Material.kink.colour == BackwardsAuroraPalette.kink)
        #expect(Material.tear.colour == BackwardsAuroraPalette.tear)
        #expect(Material.spent.colour == BackwardsAuroraPalette.spent)
        #expect(Material.unspent.colour == BackwardsAuroraPalette.unspent)
        #expect(Material.preview.colour == BackwardsAuroraPalette.ribbonHighlight)
        // The vertex shader's selection chain covers every code with its palette constant, in code order.
        let vertex: String = BackwardsAuroraShaders.auroraVertex
        let selections: [String] = [
            "vec3 base = mix(BA_GROUND, BA_BAND, isCode(m, 1.0));", "base = mix(base, BA_RIBBON, isCode(m, 2.0));",
            "base = mix(base, BA_GHOST, isCode(m, 3.0));", "base = mix(base, BA_RING, isCode(m, 4.0));",
            "base = mix(base, BA_RIBBON, isCode(m, 5.0));", "base = mix(base, BA_RING, isCode(m, 6.0));",
            "base = mix(base, BA_MATCHED, isCode(m, 7.0));", "base = mix(base, BA_KINK, isCode(m, 8.0));",
            "base = mix(base, BA_TEAR, isCode(m, 9.0));", "base = mix(base, BA_SPENT, isCode(m, 10.0));",
            "base = mix(base, BA_UNSPENT, isCode(m, 11.0));", "base = mix(base, BA_RIBBON, isCode(m, 12.0));",
            "base = mix(base, BA_HIGHLIGHT, isCode(m, 13.0));",
        ]
        for selection in selections { #expect(vertex.contains(selection), "\(selection)") }
        // Lit set and alphas agree with the fragment source.
        var lit: [Int] = []
        for material in Material.allCases where material.isLit { lit.append(material.rawValue) }
        #expect(lit == [0, 1, 11])
        let fragment: String = BackwardsAuroraShaders.auroraFragment
        #expect(fragment.contains("float isLit = isCode(m, 0.0) + isCode(m, 1.0) + isCode(m, 11.0);"))
        #expect(fragment.contains("float isRibbon = isCode(m, 5.0);"))
        #expect(fragment.contains("float isFirstLayer = isCode(m, 2.0);"))
        #expect(fragment.contains("float isSecondLayer = isCode(m, 12.0);"))
        #expect(fragment.contains("float isPreview = isCode(m, 13.0);"))
        for material in Material.allCases {
            var expected: Double = material == .trailingLayer ? 0.45 : (material == .secondTrailingLayer ? 0.25 : 1)
            if material == .preview { expected = BackwardsAuroraShaders.previewAlpha }
            #expect(material.alpha == expected, "\(material)")
        }
    }

    @Test func pulsesAreDirectionCodedBoundedAndFollowTheTier() {
        // At time 0 bead 0 sits at the left end; after 1 s it moved right where t >= 0 and left where t < 0.
        let speed: Double = BackwardsAuroraShaders.pulseSpeed
        let right: Double = Self.peak(sign: 1, time: 1, pulses: 1)
        let left: Double = Self.peak(sign: -1, time: 1, pulses: 1)
        #expect(abs(right - speed) < 0.002)
        #expect(abs(left - (1 - speed)) < 0.002)
        // Two pulses are half a unit apart.
        let first: Double = BackwardsAuroraShaders.pulseIntensity(t: 0.3, time: 0, pulses: 2)
        let second: Double = BackwardsAuroraShaders.pulseIntensity(t: 0.5, time: 0, pulses: 2)
        #expect(first == 0)
        #expect(abs(second - 1) < 1e-12)
        #expect(BackwardsAuroraShaders.pulseIntensity(t: 0.5, time: 0, pulses: 1) == 0)
        // No pulses at level-2, at most maxPulses, every value in 0 ... 1.
        var samples: Int = 0
        for i in 0...200 {
            let t: Double = -1 + Double(i) / 100
            #expect(BackwardsAuroraShaders.pulseIntensity(t: t, time: 3.7, pulses: 0) == 0)
            let capped: Double = BackwardsAuroraShaders.pulseIntensity(t: t, time: 3.7, pulses: 9)
            #expect(capped == BackwardsAuroraShaders.pulseIntensity(t: t, time: 3.7, pulses: 2))
            #expect(capped >= 0 && capped <= 1)
            let shimmer: Double = BackwardsAuroraShaders.shimmer(t: t, time: 3.7)
            #expect(shimmer >= 0 && shimmer <= 1)
            samples += 1
        }
        #expect(samples == 201)
        #expect(BackwardsAuroraShaders.pulseIntensity(t: .nan, time: .infinity, pulses: .nan) == 0)
        // Reduce Motion: time 0 is still.
        #expect(BackwardsAuroraShaders.shimmer(t: 0.4, time: 0) == BackwardsAuroraShaders.shimmer(t: 0.4, time: 0))
        #expect(BackwardsAuroraShaders.shimmer(t: 0.4, time: 0) != BackwardsAuroraShaders.shimmer(t: 0.4, time: 1))
        // The shader's direction and head formulas.
        let fragment: String = BackwardsAuroraShaders.auroraFragment
        #expect(fragment.contains("float direction = 2.0 * step(0.0, v_t) - 1.0;"))
        #expect(fragment.contains("float head = fract(direction * BA_PULSE_SPEED * u_time + float(i) / max(pulses, 1.0));"))
        #expect(fragment.contains("float pulses = clamp(u_pulses, 0.0, float(BA_MAX_PULSES));"))
        // Per tier: 2 / 1 / 0.
        var values: [Double] = []
        for tier in BackwardsAuroraTier.all { values.append(BackwardsAuroraShaders.pulses(for: tier)) }
        #expect(values == [2, 1, 0])
    }

    @Test func glowGainPerTierAndReduceFlashingLimit() {
        #expect(BackwardsAuroraShaders.glowLimit(reduceFlashing: false) == 1.5)
        #expect(BackwardsAuroraShaders.glowLimit(reduceFlashing: true) == 0.5)
        var gains: [Double] = []
        for tier in BackwardsAuroraTier.all {
            let gain: Double = BackwardsAuroraShaders.glowGain(for: tier)
            gains.append(gain)
            if tier.glowShells == 0 { #expect(gain == 0) }
            #expect(gain <= BackwardsAuroraShaders.maxGlowGain)
        }
        #expect(gains == [1.5, 1.0, 0])
        #expect(BackwardsAuroraShaders.glowGain(for: BackwardsAuroraTier.of(7)) == 0)
        // Applied gain: the smaller of gain and limit, each clamped.
        #expect(BackwardsAuroraShaders.glowGain(gain: 1.5, limit: 0.5) == 0.5)
        #expect(BackwardsAuroraShaders.glowGain(gain: 1.0, limit: 1.5) == 1.0)
        #expect(BackwardsAuroraShaders.glowGain(gain: 9, limit: 9) == 1.5)
        #expect(BackwardsAuroraShaders.glowGain(gain: .nan, limit: 1) == 0)
        #expect(BackwardsAuroraShaders.glowGain(gain: -1, limit: 1) == 0)
        let fragment: String = BackwardsAuroraShaders.glowFragment
        #expect(fragment.contains(
            "float gain = min(clamp(u_glow, 0.0, BA_MAX_GAIN), clamp(u_glowLimit, 0.0, BA_MAX_GAIN));"))
        let full: SIMD4<Double> = BackwardsAuroraShaders.glowColour(colour: BackwardsAuroraPalette.glow, glow: 1,
                                                                    gain: 1.5)
        #expect(abs(full.w - 0.75) < 1e-12)
        let capped: SIMD4<Double> = BackwardsAuroraShaders.glowColour(colour: BackwardsAuroraPalette.glow, glow: 1,
                                                                      gain: 0.5)
        #expect(capped.w < full.w)
        let none: SIMD4<Double> = BackwardsAuroraShaders.glowColour(colour: BackwardsAuroraPalette.glow, glow: 0,
                                                                    gain: 1.5)
        #expect(Self.distance(SIMD3<Double>(none.x, none.y, none.z), BackwardsAuroraPalette.glow) < 1e-12)
        #expect(none.w == 0)
        #expect(BackwardsAuroraShaders.fresnel(normalDotView: 1) == 0)
        #expect(BackwardsAuroraShaders.fresnel(normalDotView: 0) == 1)
    }
}
