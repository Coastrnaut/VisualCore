// BinaryGardensShaderSourceTests — feature 503 (R02-G21-03) T-R02G2103-003 (FR-R02G2103-001, 002, 004, 007, 010;
// SC-R02G2103-003; clarifications Q1–Q4, Q6). Host checks of the GLSL ES 3.00 sources: the version line and one
// precision statement, every declared uniform listed (equal to the uniform name constants the scene sets) and used in
// its stage, the time input only in the system vertex stage and multiplied by the motion (Reduce Motion), at most 16
// vec4 uniform slots per program (system 9, glow 7), no texture sampler, no `discard`, no loop (so no unbounded one), no
// reserved word used as a name, vertex outputs matching fragment inputs, balanced braces, ASCII-only sources, the
// attribute names and locations (the `ShaderMeshRenderer` streams), the material code table (contiguous 0 … 37, each
// selected by the vertex shader with its palette colour and handled exactly once by the fragment shader), the value and
// broken mark (offset 64) carried in uv with an encode/decode round trip, the GLSL palette constants generated from
// `BinaryGardensPalette` and parsing back within 1e-6, the still backdrop gradient and the hashed starfield covering
// at most 2 % of its area, the two-sun world shading (ambient floor 0.35, light from each star's side by its response,
// sunrise bands on the terminators), the seasonal banding latitudes (caps at 30° and 60°, belts at 15° and 40°), the
// flowers from a fixed hash, the signed-distance quad shapes inside the quad extent, the coronas and motes moved by time
// and stopped under Reduce Motion, the glow per kind with a won level raising every world, the glow gain per tier (0 at
// level-2) and the Reduce Flashing cap, the source file's own text, and, when `glslangValidator` is installed, a real
// front-end compile of each source (skipped otherwise). Test data uses explicit types and plain loops (CI type-check
// rule).
import Foundation
import Testing
@testable import BinaryGardensCore

@Suite struct BinaryGardensShaderSourceTests {
    typealias Shaders = BinaryGardensShaders
    typealias Palette = BinaryGardensPalette
    typealias Material = BinaryGardensMaterial

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "system", vertex: Shaders.systemVertex, fragment: Shaders.systemFragment,
                 uniforms: Shaders.systemUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.systemVertex, Shaders.systemFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// (type, name) of the declarations in `source` starting with `keyword` and a space.
    static func declarations(_ keyword: String, in source: String) -> [(type: String, name: String)] {
        var result: [(type: String, name: String)] = []
        for line in lines(source) where line.hasPrefix("\(keyword) ") {
            let parts: [String] = tokens(line)
            guard parts.count >= 3 else { continue }
            result.append((type: parts[parts.count - 2], name: parts[parts.count - 1]))
        }
        return result
    }

    /// Names of the declarations in `source` starting with `keyword` and a space.
    static func declared(_ keyword: String, in source: String) -> [String] {
        var names: [String] = []
        for declaration in declarations(keyword, in: source) { names.append(declaration.name) }
        return names
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

    /// The value of `const float <name> = <value>;` in `source`, nil when absent or not a number.
    static func floatConstant(_ name: String, in source: String) -> Double? {
        let prefix: String = "const float \(name) = "
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

    /// The vec4 slots one uniform of GLSL `type` occupies (mat4: 4, anything scalar or vector: 1).
    static func vec4Slots(_ type: String) -> Int { type == "mat4" ? 4 : 1 }

    /// The largest component difference of `a` and `b`.
    static func gap(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z)))
    }

    /// Relative luminance (Rec. 709 weights).
    static func luminance(_ c: SIMD3<Double>) -> Double {
        (c * SIMD3<Double>(0.2126, 0.7152, 0.0722)).sum()
    }

    /// The unit normal at latitude `degrees` (azimuth 0.3 rad).
    static func normal(latitude degrees: Double) -> SIMD3<Double> {
        let phi: Double = degrees * Double.pi / 180
        return SIMD3<Double>(cos(phi) * cos(0.3), cos(phi) * sin(0.3), sin(phi))
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
            #expect(Set(vertexDeclared).isDisjoint(with: Set(fragmentDeclared)), "\(program.name) declares twice")
            #expect(vertexDeclared + fragmentDeclared == program.uniforms, "\(program.name) declares another set")
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
                                   Shaders.starOneUniform, Shaders.starTwoUniform, Shaders.glowGainUniform,
                                   Shaders.glowLimitUniform]
        #expect(constants == ["u_mvp", "u_time", "u_motion", "u_won", "u_star1", "u_star2", "u_glowGain",
                              "u_glowLimit"])
        #expect(Shaders.systemUniforms == ["u_mvp", "u_time", "u_motion", "u_won", "u_star1", "u_star2"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.systemVertex) == ["u_mvp", "u_time", "u_motion", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.systemFragment) == ["u_star1", "u_star2"])
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won"])
        // Time moves only the system vertex stage, always times the motion (Reduce Motion stops it).
        #expect(Self.wordCount("u_time", in: Shaders.systemVertex) == 2)
        #expect(Shaders.systemVertex.contains("float clock = max(u_time, 0.0) * clamp(u_motion, 0.0, 1.0);"))
        let timeless: [String] = [Shaders.systemFragment, Shaders.glowVertex, Shaders.glowFragment]
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
            for declaration in Self.declarations("uniform", in: "\(program.vertex)\n\(program.fragment)") {
                slots += Self.vec4Slots(declaration.type)
            }
            #expect(slots <= Shaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["system": 9, "glow": 7])
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
            // GLSL ES 3.00 reserved words never used as names.
            let reserved: [String] = [
                "flat", "smooth", "centroid", "sample", "input", "output", "filter", "fixed", "half", "patch",
                "active", "common", "partition", "long", "short", "double", "unsigned", "superp", "inline", "static",
                "public", "external", "interface", "class", "union", "enum", "typedef", "template", "this", "goto",
                "resource", "cast", "namespace", "using", "sizeof", "noperspective", "volatile", "precise",
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
            #expect(braces == 0 && parens == 0 && !negative)
            #expect(source.contains("void main() {"))
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
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
        let systemOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_pos": "vec3", "v_material": "float", "v_local": "float",
            "v_value": "float", "v_bloom": "float",
        ]
        #expect(Self.interface("out", in: Shaders.systemVertex) == systemOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.systemVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.systemFragment).isEmpty && Self.layouts(Shaders.glowFragment).isEmpty)
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        #expect(Shaders.paletteConstants.count == 27)
        #expect(Shaders.constantName("spaceTop") == "BG_SPACE_TOP" && Shaders.constantName("world") == "BG_WORLD")
        var names: Set<String> = []
        for (index, entry) in Shaders.paletteConstants.enumerated() {
            names.insert(entry.name)
            #expect(entry.colour == Palette.all[index].colour)
            // Every colour is declared in the system vertex shader and parses back within 1e-6.
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(entry.name, in: Shaders.systemVertex))
            #expect(Self.gap(parsed, entry.colour) < 1e-6, "\(entry.name)")
        }
        #expect(names.count == 27)
        // The fragment and glow shaders declare the colours they use, with the same values.
        for name in Shaders.fragmentColours {
            let constant: String = Shaders.constantName(name)
            let parsed: SIMD3<Double> = try #require(Self.vec3Constant(constant, in: Shaders.systemFragment))
            var colour: SIMD3<Double> = SIMD3<Double>(-1, -1, -1)
            for entry in Palette.all where entry.name == name { colour = entry.colour }
            #expect(Self.gap(parsed, colour) < 1e-6, "\(name)")
        }
        let world: SIMD3<Double> = try #require(Self.vec3Constant("BG_WORLD", in: Shaders.glowFragment))
        let glow: SIMD3<Double> = try #require(Self.vec3Constant("BG_GLOW", in: Shaders.glowFragment))
        #expect(Self.gap(world, Palette.world) < 1e-6 && Self.gap(glow, Palette.glow) < 1e-6)
        // The numeric constants the sources are built from.
        let pairs: [(name: String, value: Double, source: String)] = [
            ("BG_MAX_MATERIAL", 37, Shaders.systemVertex), ("BG_BROKEN_OFFSET", 64, Shaders.systemVertex),
            ("BG_VALUE_SCALE", 0.4, Shaders.systemVertex), ("BG_AMBIENT", 0.35, Shaders.systemFragment),
            ("BG_LETHAL_CAP", 30, Shaders.systemFragment), ("BG_DIM_CAP", 60, Shaders.systemFragment),
            ("BG_BRIGHT_BELT", 15, Shaders.systemFragment), ("BG_LETHAL_BELT", 40, Shaders.systemFragment),
            ("BG_SHARE_SCALE", 64_000, Shaders.systemFragment), ("BG_CORE_SHARE", 0.5, Shaders.systemFragment),
            ("BG_STAR_PRESENCE", Shaders.starPresence, Shaders.systemFragment),
            ("BG_MAX_GAIN", Shaders.maxGlowGain, Shaders.glowFragment),
        ]
        for pair in pairs {
            let parsed: Double = try #require(Self.floatConstant(pair.name, in: pair.source), "\(pair.name)")
            #expect(abs(parsed - pair.value) < 1e-6, "\(pair.name)")
        }
    }

    @Test func materialCodeTableIsConsistent() {
        let all: [Material] = Material.allCases
        #expect(all.count == 38)
        for (index, material) in all.enumerated() {
            #expect(material.rawValue == index, "contiguous codes from 0")
            #expect(material.code == Float(index))
        }
        #expect(Shaders.maxMaterial == 37 && Shaders.brokenOffset == 64 && Shaders.brokenOffset > 37 + 0.4)
        #expect(Shaders.materials.count == 38)
        let valued: Set<Material> = [.worldLethalLow, .worldDim, .worldComfortable, .worldBright, .worldLethalHigh,
                                     .trail, .cellLethalLow, .cellDim, .cellComfortable, .cellBright,
                                     .cellLethalHigh, .corona, .mote]
        for material in all {
            #expect(material.isValued == valued.contains(material), "\(material)")
            // The vertex shader selects the material's palette constant by its code.
            if material != .backdrop {
                let line: String = "base = mix(base, \(material.paletteConstant), isCode(m, "
                    + String(format: "%.6f", Double(material.rawValue)) + "));"
                #expect(Shaders.systemVertex.contains(line), "\(material)")
            }
            var known: Bool = false
            for entry in Shaders.paletteConstants where entry.name == material.paletteConstant { known = true }
            #expect(known, "\(material) names a declared colour")
            // The fragment shader handles every code exactly once.
            let code: String = "isCode(m, " + String(format: "%.1f", Double(material.rawValue)) + ")"
            var count: Int = 0
            var start: String.Index = Shaders.systemFragment.startIndex
            while let range = Shaders.systemFragment.range(of: code, range: start..<Shaders.systemFragment.endIndex) {
                count += 1
                start = range.upperBound
            }
            if material.isWorld {
                #expect(count == 0, "worlds are handled by the band range 9 … 13")
            } else {
                #expect(count == 1, "\(material) is handled \(count) times")
            }
        }
        #expect(Shaders.systemFragment.contains("float isWorld = step(8.5, m) * step(m, 13.5);"))
        let bands: [BinaryGardensBand] = BinaryGardensBand.allCases
        for band in bands {
            #expect(Material.world(band).band == band && Material.world(band).isWorld)
            #expect(Material.cell(band).isValued && !Material.cell(band).isWorld)
        }
        #expect(Material.world(.lethalLow).rawValue == 9 && Material.world(.lethalHigh).rawValue == 13)
    }

    @Test func theValueAndTheBrokenMarkTravelInUV() {
        let values: [Double] = [0, 0.25, 0.5, 1]
        for material in Material.allCases {
            for broken in [false, true] {
                for value in values {
                    let x: Double = Shaders.encode(material, value: value, broken: broken)
                    let decoded: (material: Material, value: Double, broken: Bool) = Shaders.decode(x)
                    #expect(decoded.material == material && decoded.broken == broken, "\(material)")
                    let expected: Double = material.isValued ? value : 0
                    #expect(abs(decoded.value - expected) < 1e-9, "\(material) \(value)")
                    // As a 32-bit float, the code survives too.
                    let rounded: (material: Material, value: Double, broken: Bool) = Shaders.decode(Double(Float(x)))
                    #expect(rounded.material == material && rounded.broken == broken)
                }
            }
        }
        #expect(Shaders.encode(.worldDim, value: 7, broken: false) == 10.4)
        #expect(Shaders.encode(.orbit, value: 0.9, broken: true) == 71)
        #expect(Shaders.decode(.nan).material == .backdrop && Shaders.decode(-5).material == .backdrop)
        #expect(Shaders.decode(500).material == .brokenRing && Shaders.decode(500).broken)
        #expect(Shaders.shareValue(64_000) == 1 && Shaders.shareValue(32_000) == 0.5 && Shaders.shareValue(-1) == 0)
        #expect(Shaders.heightShare(flux: 50, lethalHigh: 100) == 0.5)
        #expect(Shaders.heightShare(flux: 128_000, lethalHigh: 100) == 1)
        #expect(Shaders.heightShare(flux: 0, lethalHigh: 0) == 0)
        // The base colours: a shared ring's odd dashes and star 2's corona rays in star 2's colour, broken parts in
        // the broken colour.
        #expect(Shaders.baseColour(of: .ringShared, value: 0, broken: false, won: 0, shape: 0) == Palette.starOne)
        #expect(Shaders.baseColour(of: .ringShared, value: 0, broken: false, won: 0, shape: 1) == Palette.starTwo)
        #expect(Shaders.baseColour(of: .corona, value: 0, broken: false, won: 0, shape: 1) == Palette.starTwo)
        #expect(Shaders.baseColour(of: .cellDim, value: 0, broken: true, won: 0) == Palette.broken)
        #expect(Material.starOne.baseColour == Palette.starOne && Material.starTwo.baseColour == Palette.starTwo)
        #expect(Material.mote.baseColour == Palette.pollen && Material.brokenRing.baseColour == Palette.broken)
    }

    @Test func theBackdropIsAStillGradientWithASparseStarfield() {
        #expect(Shaders.backdropColour(height: 0) == Palette.space)
        #expect(Self.gap(Shaders.backdropColour(height: 1), Palette.spaceTop) < 1e-12)
        #expect(Shaders.backdropColour(height: -1) == Palette.space)
        #expect(Shaders.backdropColour(height: .nan) == Palette.space)
        // Mean starfield coverage over a dense grid of the backdrop plane: at most 2 %.
        var total: Double = 0
        var samples: Int = 0
        var lit: Int = 0
        for i in 0..<400 {
            for j in 0..<400 {
                let u: Double = -4 + Double(i) * 0.02 + 0.0037
                let v: Double = -3 + Double(j) * 0.02 + 0.0051
                let c: Double = Shaders.starfieldCoverage(u: u, v: v)
                #expect(c >= 0 && c <= 1)
                total += c
                samples += 1
                if c > 0.5 { lit += 1 }
            }
        }
        let mean: Double = total / Double(samples)
        #expect(mean <= 0.02 && mean > 0.001, "starfield coverage \(mean)")
        #expect(lit > 0)
        // The fixed hash: the same input, the same output; never a random source.
        #expect(Shaders.hash(x: 3, y: 7) == Shaders.hash(x: 3, y: 7))
        #expect(Shaders.starfieldCoverage(u: .nan, v: 0) == 0)
        let lifted: SIMD3<Double> = Shaders.backdropColour(height: 0.5, u: 0, v: 0)
        #expect(lifted.x >= Shaders.backdropColour(height: 0.5).x - 1e-12)
    }

    @Test func worldsAreLitByBothStarsOverTheAmbientFloor() {
        let up: SIMD3<Double> = SIMD3<Double>(0, 0, 1)
        let side: SIMD3<Double> = SIMD3<Double>(1, 0, 0)
        // A comfortable world's night side (no light) keeps 0.35 of its surface colour, and its luminance stays
        // above 0.15 over the darkest backdrop (the frame check's margin).
        let n: SIMD3<Double> = Self.normal(latitude: 55)
        let night: SIMD3<Double> = Shaders.worldShade(normal: n, band: .comfortable, shareOne: 0, shareTwo: 0,
                                                      toStarOne: side, toStarTwo: side)
        let surface: SIMD3<Double> = Shaders.worldSurface(normal: n, band: .comfortable)
        #expect(Self.gap(night, surface * 0.35) < 1e-12)
        for band in BinaryGardensBand.allCases {
            let dark: SIMD3<Double> = Shaders.worldShade(normal: n, band: band, shareOne: 0, shareTwo: 0,
                                                         toStarOne: side, toStarTwo: side)
            #expect(Self.luminance(dark) - Self.luminance(Palette.spaceTop) >= 0.15, "\(band)")
        }
        // The side facing star 1 is lit in its colour; the response grows with the share and saturates.
        let share: Double = Shaders.shareValue(200)
        let lit: SIMD3<Double> = Shaders.worldShade(normal: up, band: .comfortable, shareOne: share, shareTwo: 0,
                                                    toStarOne: up, toStarTwo: -up)
        let dim: SIMD3<Double> = Shaders.worldShade(normal: up, band: .comfortable, shareOne: 0, shareTwo: 0,
                                                    toStarOne: up, toStarTwo: -up)
        #expect(lit.x > dim.x + 0.05 && Self.luminance(lit) > Self.luminance(dim))
        #expect(Shaders.lightResponse(share: 0) == 0 && Shaders.lightResponse(share: 1) == 1)
        #expect(Shaders.lightResponse(share: Shaders.shareValue(1024)) == 1)
        let responses: [Double] = [20, 50, 100, 400, 1000].map { Shaders.lightResponse(share: Shaders.shareValue($0)) }
        for k in 1..<responses.count { #expect(responses[k] > responses[k - 1]) }
        #expect(responses[0] > 0.3, "a catalog share of 20 milliflux is visible")
        // Two suns paint two sunrise bands: the terminator of each star (n · l = 0) is brighter than the night side.
        let star2: SIMD3<Double> = SIMD3<Double>(0, 1, 0)
        let terminator: SIMD3<Double> = Shaders.worldShade(normal: up, band: .comfortable, shareOne: share,
                                                           shareTwo: share, toStarOne: side, toStarTwo: star2)
        #expect(Self.luminance(terminator) > Self.luminance(dim) + 0.1)
        let warm: SIMD3<Double> = Shaders.worldShade(normal: up, band: .comfortable, shareOne: share, shareTwo: 0,
                                                     toStarOne: side, toStarTwo: star2)
        let cool: SIMD3<Double> = Shaders.worldShade(normal: up, band: .comfortable, shareOne: 0, shareTwo: share,
                                                     toStarOne: side, toStarTwo: star2)
        #expect(warm.x - dim.x > cool.x - dim.x, "star 1's band is warm")
        #expect(cool.z - dim.z > warm.z - dim.z, "star 2's band is cool")
        // Every shade stays in 0 … 1, also for zero and non-finite inputs.
        let odd: SIMD3<Double> = Shaders.worldShade(normal: SIMD3<Double>(0, 0, 0), band: .bright, shareOne: .nan,
                                                    shareTwo: 5, toStarOne: SIMD3<Double>(.nan, 0, 0),
                                                    toStarTwo: up)
        for c in [odd.x, odd.y, odd.z, lit.x, lit.y, lit.z] { #expect(c >= 0 && c <= 1) }
    }

    @Test func seasonalBandingFollowsTheBandByLatitude() {
        // Caps: lethal low from 30°, dim from 60°; belts: bright to 15°, lethal high to 40°; feathered by 4°.
        #expect(Shaders.bandCoverage(latitude: 40, band: .lethalLow) == 1)
        #expect(Shaders.bandCoverage(latitude: 20, band: .lethalLow) == 0)
        #expect(Shaders.bandCoverage(latitude: -40, band: .lethalLow) == 1)
        #expect(abs(Shaders.bandCoverage(latitude: 30, band: .lethalLow) - 0.5) < 1e-12)
        #expect(Shaders.bandCoverage(latitude: 70, band: .dim) == 1)
        #expect(Shaders.bandCoverage(latitude: 50, band: .dim) == 0)
        #expect(Shaders.bandCoverage(latitude: 5, band: .bright) == 1)
        #expect(Shaders.bandCoverage(latitude: 25, band: .bright) == 0)
        #expect(Shaders.bandCoverage(latitude: 30, band: .lethalHigh) == 1)
        #expect(Shaders.bandCoverage(latitude: 50, band: .lethalHigh) == 0)
        for latitude in [-90.0, -30, 0, 30, 90] {
            #expect(Shaders.bandCoverage(latitude: latitude, band: .comfortable) == 0)
        }
        // The surfaces: frost caps, a scorched belt, flowers only where comfortable (or on a won level).
        let pole: SIMD3<Double> = Self.normal(latitude: 80)
        let equator: SIMD3<Double> = Self.normal(latitude: 0)
        #expect(Self.gap(Shaders.worldSurface(normal: pole, band: .lethalLow), Palette.frost) < 1e-12)
        #expect(Self.gap(Shaders.worldSurface(normal: equator, band: .lethalLow), Palette.world) < 1e-12)
        #expect(Self.gap(Shaders.worldSurface(normal: equator, band: .lethalHigh), Palette.scorch) < 1e-12)
        #expect(Self.gap(Shaders.worldSurface(normal: pole, band: .lethalHigh), Palette.world) < 1e-12)
        #expect(abs(Shaders.latitude(Self.normal(latitude: 33)) - 33) < 1e-9)
        var flowered: Int = 0
        var samples: Int = 0
        for i in 0..<60 {
            for j in 0..<30 {
                let theta: Double = Double(i) * 0.1047
                let phi: Double = -1.4 + Double(j) * 0.0966
                let n: SIMD3<Double> = SIMD3<Double>(cos(phi) * cos(theta), cos(phi) * sin(theta), sin(phi))
                let flower: Double = Shaders.flowerCoverage(normal: n)
                #expect(flower >= 0 && flower <= 1)
                samples += 1
                if flower > 0.5 { flowered += 1 }
                let comfortable: SIMD3<Double> = Shaders.worldSurface(normal: n, band: .comfortable)
                let bright: SIMD3<Double> = Shaders.worldSurface(normal: n, band: .dim, won: 1)
                #expect(Self.gap(comfortable, bright) < 1e-12, "a won level blooms every world")
            }
        }
        #expect(flowered > samples / 20 && flowered < samples / 2, "flowers \(flowered) of \(samples)")
        #expect(Shaders.flowerCoverage(normal: SIMD3<Double>(0, 0, 0)) == 0)
    }

    @Test func signedDistanceQuadShapesStayInsideTheQuad() {
        let e: Double = Shaders.quadExtent
        let quads: [Material] = [.tiltPipLit, .tiltPipUnlit, .ringIdle, .ringStarOne, .ringStarTwo, .ringShared,
                                 .orbit, .trail, .worldPip, .starOne, .starTwo, .corona, .luminosityPipLit,
                                 .luminosityPipUnlit, .gaugePlate, .cellLethalLow, .cellDim, .cellComfortable,
                                 .cellBright, .cellLethalHigh, .guide, .windowBracket, .windowBracketShort,
                                 .requiredTick, .tickMarker, .bloomTrack, .bloomBracket, .bloomMarker, .actionsLit,
                                 .actionsUnlit, .mote, .brokenRing]
        for material in quads {
            // Nothing at the quad's corners and edges (the extent leaves room for the feather).
            var corners: [(Double, Double)] = [(e, e), (-e, e), (e, -e), (-e, -e), (0, -e)]
            // The gauge plate's coverage ignores u (its quad ends at u = ±1).
            if material != .gaugePlate { corners.append((e, 0)) }
            for corner in corners {
                #expect(Shaders.quadCoverage(material, u: corner.0, v: corner.1) == 0, "\(material)")
            }
        }
        // Discs fill the centre, rings and hollows leave it empty, squares fill to their edges.
        #expect(Shaders.quadCoverage(.tiltPipLit, u: 0, v: 0) == 1 && Shaders.quadCoverage(.brokenRing, u: 0, v: 0) == 0)
        #expect(Shaders.quadCoverage(.brokenRing, u: 0.82, v: 0) == 1)
        #expect(Shaders.quadCoverage(.cellComfortable, u: 0.9, v: -0.9) == 1)
        #expect(Shaders.quadCoverage(.gaugePlate, u: 1, v: 0.9) == 1)
        #expect(Shaders.quadCoverage(.gaugePlate, u: 0, v: 1.2) == 0)
        #expect(Shaders.quadCoverage(.cellDim, u: 0.3, v: 0.2) == 0 && Shaders.quadCoverage(.cellDim, u: 0.9, v: 0) == 1)
        #expect(Shaders.quadCoverage(.cellLethalLow, u: 0.3, v: 0.3) == 1, "a crossed cell's diagonal")
        #expect(Shaders.quadCoverage(.cellLethalLow, u: 0.5, v: -0.1) == 0)
        // Brackets: the bar at the bottom and the end ticks; the dashed one has gaps along its bar.
        #expect(Shaders.quadCoverage(.windowBracket, u: 0, v: -0.8) == 1)
        #expect(Shaders.quadCoverage(.windowBracket, u: 0, v: 0.5) == 0)
        #expect(Shaders.quadCoverage(.windowBracket, u: 0.92, v: 0.5) == 1)
        var gaps: Int = 0
        for k in 0..<64 {
            let u: Double = -0.8 + Double(k) * 0.025
            if Shaders.quadCoverage(.windowBracketShort, u: u, v: -0.8) < 0.5 { gaps += 1 }
        }
        #expect(gaps > 10 && gaps < 54)
        // A trail dot fades with its freshness; a corona ray's reach pulses with its value.
        #expect(Shaders.quadCoverage(.trail, u: 0, v: 0, value: 0.25) == 0.25)
        #expect(Shaders.quadCoverage(.corona, u: 0, v: 0.6, value: 1) == 1)
        #expect(Shaders.quadCoverage(.corona, u: 0, v: 0.6, value: 0) == 0)
        #expect(Shaders.quadCoverage(.corona, u: 0, v: -0.9, value: 0) == 1)
        #expect(Shaders.quadCoverage(.worldDim, u: 0, v: 0) == 0 && Shaders.quadCoverage(.backdrop, u: 0, v: 0) == 0)
        // A star disc's white-hot core is the inner half of its radius.
        #expect(Self.gap(Shaders.starDiscColour(0, radius: 0.2), Palette.core) < 1e-12)
        #expect(Self.gap(Shaders.starDiscColour(0, radius: 0.9), Palette.starOne) < 1e-12)
        #expect(Self.gap(Shaders.starDiscColour(1, radius: 0.9), Palette.starTwo) < 1e-12)
    }

    @Test func coronasAndMotesMoveByTimeAndStopUnderReduceMotion() {
        #expect(Shaders.motion(reduceMotion: true) == 0 && Shaders.motion(reduceMotion: false) == 1)
        #expect(Shaders.shaderTime(-1) == 0 && Shaders.shaderTime(.nan) == 0)
        #expect(Shaders.shaderTime(601) == 1 && Shaders.shaderTime(12.5) == 12.5)
        // Whole cycles of both motions fit the wrap, so nothing jumps.
        #expect((Shaders.timeWrap * Shaders.coronaRate).truncatingRemainder(dividingBy: 1) == 0)
        #expect((Shaders.timeWrap * Shaders.moteRate).truncatingRemainder(dividingBy: 1) < 1e-9)
        let phases: [Double] = [0, 0.25, 0.6]
        let times: [Double] = [0, 1, 3.7, 100]
        for phase in phases {
            let still: Double = Shaders.coronaPulse(phase: phase, time: 0, motion: 1)
            let stillOffset: SIMD2<Double> = Shaders.moteOffset(phase: phase, radius: 0.11, time: 0, motion: 1)
            for time in times {
                #expect(Shaders.coronaPulse(phase: phase, time: time, motion: 0) == still, "Reduce Motion")
                let offset: SIMD2<Double> = Shaders.moteOffset(phase: phase, radius: 0.11, time: time, motion: 0)
                #expect(offset == stillOffset, "Reduce Motion")
                let pulse: Double = Shaders.coronaPulse(phase: phase, time: time, motion: 1)
                #expect(pulse >= 0 && pulse <= 1)
            }
            #expect(Shaders.coronaPulse(phase: phase, time: 1, motion: 1) != still)
        }
        #expect(Shaders.moteOffset(phase: 0, radius: 0.11, time: 0, motion: 1) == SIMD2<Double>(0, 0))
        let quarter: SIMD2<Double> = Shaders.moteOffset(phase: 0.25, radius: 0.11, time: 0, motion: 1)
        #expect(abs(quarter.x + 0.11) < 1e-12 && abs(quarter.y - 0.11) < 1e-12)
        #expect(Shaders.systemVertex.contains("p.xy = p.xy + isMote * a_normal.z * vec2(cos(angle) - 1.0, sin(angle));"))
    }

    @Test func glowShadesTheStarsAndTheWorlds() {
        #expect(Shaders.GlowKind.star.code(factor: 1) == 1 && Shaders.GlowKind.world.code(factor: 0) == 2)
        let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(2.5)
        #expect(decoded.kind == .world && decoded.factor == 0.5)
        #expect(Shaders.GlowKind.decode(.nan).kind == .star)
        #expect(Shaders.glowFactor(blooming: true) == 1 && Shaders.glowFactor(blooming: false) == 0)
        // A world shell that is not blooming is invisible, unless the level is won.
        let hidden: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .world, factor: 0,
                                                       radius: 0, gain: 1, won: 0)
        let raised: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .world, factor: 0,
                                                       radius: 0, gain: 1, won: 1)
        #expect(hidden.w == 0 && raised.w == 0.5)
        let star: SIMD4<Double> = Shaders.glowColour(colour: Palette.starOne, kind: .star, factor: 1, radius: 1,
                                                     gain: 1, won: 1)
        #expect(star.w == 0, "the outer edge fades out")
        #expect(Shaders.glowFragment.contains("float factor = mix(clamp(v_factor, 0.0, 1.0), 1.0, won * isWorld);"))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        let gains: [Double] = BinaryGardensTier.all.map { Shaders.glowGain(for: $0) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowLimit(reduceFlashing: true) == 0.5 && Shaders.glowLimit(reduceFlashing: false) == 1.5)
        #expect(Shaders.glowGain(gain: 1.5, limit: Shaders.glowLimit(reduceFlashing: true)) == 0.5)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == 1.5 && Shaders.glowGain(gain: .nan, limit: 1) == 0)
        let line: String =
            "float gain = min(clamp(u_glowGain, 0.0, BG_MAX_GAIN), clamp(u_glowLimit, 0.0, BG_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("BinaryGardensShaders.swift")
        let text: String = try String(contentsOf: core, encoding: .utf8)
        let metal: String = "import " + "Metal" + "Kit"
        #expect(!text.contains(metal))
        let denied: [String] = ["Project" + "M", "Preset" + "Library", "Milk" + "Drop"]
        for word in denied { #expect(!text.contains(word), "\(word)") }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            #expect(line.count <= 120, "\(line)")
        }
        #expect(text.contains("T-R02G2103-003"))
    }

    /// A real front-end compile with `glslangValidator` when it is installed (macOS only; skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { tool = path }
        guard let validator = tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bg-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "system.vert", source: Shaders.systemVertex), (name: "system.frag", source: Shaders.systemFragment),
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
