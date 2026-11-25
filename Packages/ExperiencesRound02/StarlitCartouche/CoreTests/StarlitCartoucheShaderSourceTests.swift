// StarlitCartoucheShaderSourceTests — feature 453 (R02-G16-03) T-R02G1603-003 (FR-R02G1603-001, 002, 004, 006, 007;
// clarifications Q1–Q4). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every
// declared uniform listed (equal to the uniform name constants the scene sets) and used in its stage, at most 16 vec4
// uniform slots per program, no texture sampler, no `discard`, no unbounded loop (any `for` bounded by an int
// constant), vertex outputs matching fragment inputs, balanced braces, ASCII-only sources, the `ShaderMeshRenderer`
// attribute names and locations, the material codes distinct, ordered 0 … 21 and each selected by the vertex shader
// with its palette colour, the GLSL palette constants parsing back to `StarlitCartouchePalette` within 1e-6, the
// layered star shading, the signed-distance references (edge, dashes, hazard stripes, notches, ring dashes, the ship
// dart), the firmament gradient, its sparse specks (under 5 % of sampled pixels) and its turn, the angle rule (0.02
// rad/s, 0 with Reduce Motion, finite for any input), the won flare and seal, the glow gain per tier (0 at level-2) and
// the Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of each source (skipped
// otherwise). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheShaderSourceTests {
    typealias Shaders = StarlitCartoucheShaders
    typealias Palette = StarlitCartouchePalette
    typealias Material = StarlitCartoucheShaders.Material

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "chart", vertex: Shaders.chartVertex, fragment: Shaders.chartFragment,
                 uniforms: Shaders.chartUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.chartVertex, Shaders.chartFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// Relative luminance weights (Rec. 709).
    static let weights: SIMD3<Double> = SIMD3<Double>(0.2126, 0.7152, 0.0722)

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
        let constants: [String] = [Shaders.mvpUniform, Shaders.wonUniform, Shaders.firmamentAngleUniform,
                                   Shaders.glowGainUniform, Shaders.glowLimitUniform]
        #expect(constants == ["u_mvp", "u_won", "u_firmamentAngle", "u_glowGain", "u_glowLimit"])
        #expect(Set(constants) == Set(Shaders.chartUniforms + Shaders.glowUniforms))
        #expect(Shaders.chartUniforms == ["u_mvp", "u_won", "u_firmamentAngle"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.chartVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.chartFragment) == ["u_firmamentAngle"])
        #expect(Self.declared("uniform", in: Shaders.glowVertex) == ["u_mvp"])
        #expect(Self.declared("uniform", in: Shaders.glowFragment) == ["u_glowGain", "u_glowLimit", "u_won"])
        // No time input: the only motion is the firmament angle the presenter passes (0 with Reduce Motion).
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
        #expect(slotsByProgram == ["chart": 6, "glow": 7])
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
        let chartOuts: [String: String] = [
            "v_base": "vec3", "v_aux": "vec3", "v_material": "float", "v_local": "float", "v_won": "float",
        ]
        #expect(Self.interface("out", in: Shaders.chartVertex) == chartOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.chartVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.chartFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        let vertices: [String] = [Shaders.chartVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        let chart: String = Shaders.chartVertex
        let chartLines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, SC_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0);",
            "v_aux = a_normal;",
            "v_won = clamp(u_won, 0.0, 1.0);",
        ]
        for line in chartLines { #expect(chart.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 2.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "SC_NIGHT", colour: Palette.night), (name: "SC_NIGHT_TOP", colour: Palette.nightTop),
            (name: "SC_SPECK", colour: Palette.speck), (name: "SC_PEARL", colour: Palette.pearl),
            (name: "SC_PEARL_SHADE", colour: Palette.pearlShade), (name: "SC_CORRIDOR", colour: Palette.corridor),
            (name: "SC_SYMBOL_DASH", colour: Palette.symbolDash), (name: "SC_TRAIL", colour: Palette.trail),
            (name: "SC_TRAIL_GLOW", colour: Palette.trailGlow), (name: "SC_SHIP", colour: Palette.ship),
            (name: "SC_SHIP_GLOW", colour: Palette.shipGlow), (name: "SC_BEACON", colour: Palette.beacon),
            (name: "SC_CHOSEN", colour: Palette.chosen), (name: "SC_HAZARD_ACTIVE", colour: Palette.hazardActive),
            (name: "SC_HAZARD_IDLE", colour: Palette.hazardIdle), (name: "SC_ACTIONS_LIT", colour: Palette.actionsLit),
            (name: "SC_ACTIONS_UNLIT", colour: Palette.actionsUnlit),
            (name: "SC_BEAT_TRACK", colour: Palette.beatTrack), (name: "SC_WAIT_LIT", colour: Palette.waitLit),
            (name: "SC_WAIT_UNLIT", colour: Palette.waitUnlit), (name: "SC_BROKEN", colour: Palette.broken),
            (name: "SC_GLOW", colour: Palette.glow),
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
                if name == "SC_VIEW_DIR" {
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
        let vertex: String = Shaders.chartVertex
        #expect(vertex.contains("const vec3 SC_NIGHT = vec3(0.039216, 0.070588, 0.250980);"))
        #expect(vertex.contains("const vec3 SC_TRAIL = vec3(0.960784, 0.721569, 0.239216);"))
        #expect(vertex.contains("const vec3 SC_SHIP = vec3(0.184314, 0.419608, 1.000000);"))
        let fragment: String = Shaders.chartFragment
        #expect(fragment.contains("const vec3 SC_NIGHT_TOP = vec3(0.078431, 0.117647, 0.360784);"))
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "SC_MAX_MATERIAL", value: 21, source: vertex),
            (name: "SC_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "SC_TAU", value: Shaders.tau, source: fragment),
            (name: "SC_SKY_SPAN", value: Shaders.skySpan, source: fragment),
            (name: "SC_CELLS_AROUND", value: Shaders.cellsAround, source: fragment),
            (name: "SC_CELLS_PER_RADIAN", value: Shaders.cellsPerRadian, source: fragment),
            (name: "SC_CELLS_UP", value: Shaders.cellsUp, source: fragment),
            (name: "SC_SPECK_DENSITY", value: Shaders.speckDensity, source: fragment),
            (name: "SC_SPECK_RADIUS", value: Shaders.speckRadius, source: fragment),
            (name: "SC_DASH_PERIOD", value: Shaders.dashPeriod, source: fragment),
            (name: "SC_DASH_DUTY", value: Shaders.dashDuty, source: fragment),
            (name: "SC_HAZARD_GAP", value: Shaders.hazardGap, source: fragment),
            (name: "SC_TRAIL_TAIL", value: Shaders.trailTail, source: fragment),
            (name: "SC_FLARE_LIFT", value: Shaders.flareLift, source: fragment),
            (name: "SC_CORE_LIFT", value: Shaders.coreLift, source: fragment),
            (name: "SC_CORONA_LIFT", value: Shaders.coronaLift, source: fragment),
            (name: "SC_NOTCH_DUTY", value: Shaders.notchDuty, source: fragment),
            (name: "SC_RING_DASHES", value: Shaders.ringDashes, source: fragment),
            (name: "SC_ARROW_NOTCH", value: Shaders.arrowNotch, source: fragment),
            (name: "SC_SEAL_LIFT", value: Shaders.sealLift, source: fragment),
            (name: "SC_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "SC_TRAIL_REST", value: Shaders.trailRest, source: glowF),
            (name: "SC_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
        ]
        for entry in floats {
            let value: Double? = Self.scalarConstant("float", entry.name, in: entry.source)
            let parsed: Double = try #require(value, "\(entry.name)")
            #expect(abs(parsed - entry.value) <= tolerance, "\(entry.name)")
        }
        #expect(abs(Shaders.cellsAround - Shaders.cellsPerRadian * Shaders.tau) < 1e-9)
    }

    @Test func materialCodesAreDistinctOrderedAndSelected() {
        var names: [String] = []
        var codes: [Int] = []
        for material in Material.allCases {
            names.append(String(describing: material))
            codes.append(material.rawValue)
        }
        let expectedNames: [String] = [
            "firmament", "corridor", "symbolDash", "hazardActive", "hazardIdle", "trail", "trailGhost", "starCore",
            "starNotches", "ship", "beaconRing", "chosenRing", "cartoucheGrid", "strokeUndrawn", "strokeDrawn",
            "actionsLit", "actionsUnlit", "beatTrack", "beatTrackRest", "waitLit", "waitUnlit", "broken",
        ]
        #expect(names == expectedNames)
        #expect(Set(codes).count == codes.count)
        for (index, code) in codes.enumerated() {
            #expect(code == index, "\(names[index])")
            #expect(Material.allCases[index].code == Float(index))
        }
        let vertex: String = Shaders.chartVertex
        #expect(vertex.contains("vec3 base = SC_NIGHT;"))
        for material in Material.allCases where material != .firmament {
            var constant: String = ""
            for entry in Shaders.paletteConstants where entry.colour == material.colour && constant.isEmpty {
                constant = entry.name
            }
            // Pearl and beacon share a value; the beacon ring selects the beacon constant.
            if material == .beaconRing { constant = "SC_BEACON" }
            if material == .chosenRing { constant = "SC_CHOSEN" }
            if material == .waitLit { constant = "SC_WAIT_LIT" }
            if material == .beatTrack { constant = "SC_BEAT_TRACK" }
            if material == .waitUnlit { constant = "SC_WAIT_UNLIT" }
            if material == .actionsLit { constant = "SC_ACTIONS_LIT" }
            if material == .strokeDrawn || material == .trailGhost { constant = "SC_TRAIL" }
            let line: String = "base = mix(base, \(constant), isCode(m, \(material.rawValue).0));"
            #expect(vertex.contains(line), "\(material): \(line)")
            var colour: SIMD3<Double>? = nil
            for entry in Shaders.paletteConstants where entry.name == constant { colour = entry.colour }
            #expect(colour == material.colour, "\(material) colour")
        }
        #expect(Material.firmament.colour == Palette.night)
        var solid: [Material] = []
        for material in Material.allCases where material.isSolid { solid.append(material) }
        #expect(solid == [.firmament])
        #expect(Material.firmament.localCoordinate == .firmament)
        #expect(Material.symbolDash.localCoordinate == .stripAlong)
        #expect(Material.strokeUndrawn.localCoordinate == .stripAlong)
        #expect(Material.hazardActive.localCoordinate == .stripAlong)
        #expect(Material.trail.localCoordinate == .trail)
        #expect(Material.trailGhost.localCoordinate == .ghost)
        #expect(Material.starCore.localCoordinate == .sphere)
        #expect(Material.starNotches.localCoordinate == .ring)
        #expect(Material.chosenRing.localCoordinate == .ring)
        #expect(Material.ship.localCoordinate == .arrow)
        #expect(Material.corridor.localCoordinate == .strip)
        #expect(Material.actionsLit.localCoordinate == .fan)
        // The fragment shader treats exactly the firmament as opaque and the ship by its dart.
        let fragment: String = Shaders.chartFragment
        #expect(fragment.contains("coverage = mix(coverage, 1.0, sky);"))
        #expect(fragment.contains("float sky = isCode(m, 0.0);"))
        #expect(fragment.contains("coverage = mix(coverage, arrow, isCode(m, 9.0));"))
    }

    @Test func starsAreShadedInLayersFromTheNormal() {
        let night: Double = (Palette.night * Self.weights).sum()
        let core: SIMD3<Double> = Shaders.starShade(mu: 1)
        let mid: SIMD3<Double> = Shaders.starShade(mu: 0.6)
        let limb: SIMD3<Double> = Shaders.starShade(mu: 0.25)
        let rim: SIMD3<Double> = Shaders.starShade(mu: 0)
        let expectedCore: SIMD3<Double> = Palette.pearl + (SIMD3<Double>(1, 1, 1) - Palette.pearl) * Shaders.coreLift
        #expect(Self.distance(core, expectedCore) < 1e-12)
        #expect((core * Self.weights).sum() > (mid * Self.weights).sum())
        #expect((mid * Self.weights).sum() > (limb * Self.weights).sum())
        // The corona lifts the very rim toward the glow colour.
        let shadeRim: SIMD3<Double> = Palette.pearlShade + (Palette.glow - Palette.pearlShade) * Shaders.coronaLift
        #expect(Self.distance(rim, shadeRim) < 1e-12)
        // Every layer is far brighter than the backdrop (the frame check's star margin is 0.25).
        for step in 0...20 {
            let mu: Double = Double(step) / 20
            let lum: Double = (Shaders.starShade(mu: mu) * Self.weights).sum()
            #expect(lum - night >= 0.25, "mu \(mu)")
        }
        #expect(Shaders.starShade(normal: Shaders.viewDirection) == core)
        #expect(Shaders.starShade(normal: SIMD3<Double>(0, 0, 0)) == core)
        #expect(Shaders.starShade(normal: SIMD3<Double>(Double.nan, 0, 1)) == core)
        #expect(Shaders.starShade(normal: -Shaders.viewDirection) == rim)
        #expect(Shaders.starShade(mu: Double.nan) == core)
        #expect(abs((Shaders.viewDirection * Shaders.viewDirection).sum() - 1) < 1e-12)
        let fragment: String = Shaders.chartFragment
        let lines: [String] = [
            "vec3 star = mix(SC_PEARL_SHADE, SC_PEARL, smoothstep(0.0, SC_LIMB_EDGE, mu));",
            "star = mix(star, vec3(1.0), SC_CORE_LIFT * smoothstep(SC_CORE_START, 1.0, mu));",
            "star = mix(star, SC_GLOW, SC_CORONA_LIFT * pow(1.0 - mu, SC_CORONA_POWER));",
            "rgb = mix(rgb, star, isCode(m, 7.0));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func signedDistanceShadingReferences() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        // Dashes and hazard stripes keep their duty along the ribbon.
        var dashes: Int = 0
        var stripes: Int = 0
        let samples: Int = 1200
        for step in 0..<samples {
            let along: Double = 1.2 * (Double(step) + 0.5) / Double(samples)
            dashes += Int(Shaders.dashCoverage(along: along))
            stripes += Int(Shaders.hazardStripe(along: along, across: 0))
        }
        #expect(abs(Double(dashes) / Double(samples) - Shaders.dashDuty) < 0.02)
        #expect(abs(Double(stripes) / Double(samples) - Shaders.hazardDuty) < 0.02)
        #expect(Shaders.dashCoverage(along: Double.nan) == 1)
        #expect(Shaders.hazardStripe(along: 0.01, across: 0) == 1)
        #expect(Shaders.hazardStripe(along: 0.01, across: 1) == 0)
        // A ring of n notches shows exactly n lit runs.
        for count in 1...6 {
            var runs: Int = 0
            var previous: Double = 0
            for step in 0..<720 {
                let value: Double = Shaders.notchCoverage(angle: (Double(step) + 0.5) / 720, count: count)
                if value == 1 && previous == 0 { runs += 1 }
                previous = value
            }
            #expect(runs == count, "\(count) notches")
        }
        var ringLit: Int = 0
        var ringRuns: Int = 0
        var ringPrevious: Double = 0
        for step in 0..<720 {
            let value: Double = Shaders.ringDashCoverage(angle: (Double(step) + 0.5) / 720)
            ringLit += Int(value)
            if value == 1 && ringPrevious == 0 { ringRuns += 1 }
            ringPrevious = value
        }
        #expect(ringRuns == Int(Shaders.ringDashes))
        #expect(abs(Double(ringLit) / 720 - Shaders.ringDashDuty) < 0.02)
        // The dart: its centre, keel and wings inside; the notch, the corners beyond the tip and far points outside.
        let inside: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(0.8, 0), SIMD2(-0.8, 0.8), SIMD2(-0.8, -0.8), SIMD2(0.3, 0.2)]
        for p in inside {
            #expect(Shaders.arrowDistance(u: p.x, v: p.y) > 0, "\(p)")
            #expect(Shaders.arrowCoverage(u: p.x, v: p.y) > 0.5, "\(p)")
        }
        let outside: [SIMD2<Double>] = [SIMD2(-0.9, 0), SIMD2(1.05, 0), SIMD2(0.9, 0.5), SIMD2(-1.1, 1.05),
                                        SIMD2(0, 1)]
        for p in outside {
            #expect(Shaders.arrowDistance(u: p.x, v: p.y) < 0, "\(p)")
        }
        #expect(Shaders.arrowCoverage(u: 0, v: 0) == 1)
        #expect(Shaders.arrowCoverage(u: 0, v: 1.05) == 0)
        #expect(Shaders.arrowDistance(u: Double.nan, v: 0) == -1)
        // The dart fits inside the quad the geometry spans, with room for the feather.
        let e: Double = Shaders.arrowQuadExtent
        for step in 0...40 {
            let s: Double = -e + 2 * e * Double(step) / 40
            let edges: [SIMD2<Double>] = [SIMD2(s, e), SIMD2(s, -e), SIMD2(e, s), SIMD2(-e, s)]
            for p in edges { #expect(Shaders.arrowCoverage(u: p.x, v: p.y) == 0, "\(p)") }
        }
        // The ship's keel stays sapphire: blue above red by far more than the frame check's 0.08.
        let keel: SIMD3<Double> = Palette.ship + (Palette.shipGlow - Palette.ship) * Shaders.keelLift
        #expect(keel.z - keel.x >= 0.08)
        // A trail's midpoint stays gold: red above blue by at least 0.08, won or not.
        for won in [0.0, 1.0] {
            let mid: SIMD3<Double> = Shaders.trailColour(along: 0.5, won: won)
            #expect(mid.x - mid.z >= 0.08, "won \(won)")
        }
        let fragment: String = Shaders.chartFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - SC_EDGE_FEATHER, 1.0, d);",
            "float dash = 1.0 - step(SC_DASH_DUTY, fract(along / SC_DASH_PERIOD));",
            "float notch = 1.0 - step(SC_NOTCH_DUTY * 0.5, abs(fract(t * count) - 0.5));",
            "float ringDash = 1.0 - step(SC_RING_DASH_DUTY, fract(t * SC_RING_DASHES));",
            "float arrow = smoothstep(-SC_ARROW_FEATHER, SC_ARROW_FEATHER, arrowDistance(v_aux.xy));",
            "coverage = coverage * mix(1.0, dash, isCode(m, 2.0) + isCode(m, 13.0));",
            "coverage = coverage * mix(1.0, SC_GHOST_ALPHA * fade * t, isCode(m, 6.0));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func trailGhostsFadeWithFallingAlpha() {
        var previous: Double = 1
        for index in 0..<3 {
            let fade: Double = Shaders.ghostFade(index: index, count: 3)
            #expect(fade > 0 && fade < previous, "ghost \(index)")
            previous = fade
        }
        #expect(Shaders.ghostFade(index: 3, count: 3) == 0)
        #expect(Shaders.ghostFade(index: 0, count: 0) == 0)
        #expect(Shaders.ghostFade(index: 0, count: 1) == 0.5)
        #expect(Shaders.ghostAlpha(along: 1, fade: 1) == Shaders.ghostAlpha)
        #expect(Shaders.ghostAlpha(along: 0, fade: 1) == 0)
        #expect(Shaders.ghostAlpha(along: Double.nan, fade: 1) == 0)
        #expect(Shaders.ghostAlpha(along: 1, fade: 0.25) < Shaders.ghostAlpha(along: 1, fade: 0.5))
        // The trail brightens from its tail to its head.
        let tail: SIMD3<Double> = Shaders.trailColour(along: 0, won: 0)
        let head: SIMD3<Double> = Shaders.trailColour(along: 1, won: 0)
        #expect(Self.distance(head, Palette.trail) < 1e-12)
        #expect(Self.distance(tail, Palette.trail * Shaders.trailTail) < 1e-12)
    }

    @Test func firmamentGradientAndSparseSpecks() {
        let bottom: SIMD3<Double> = Shaders.firmamentColour(height: 0, horizontal: 0.123, angle: 0)
        let top: SIMD3<Double> = Shaders.firmamentColour(height: 1, horizontal: 0.123, angle: 0)
        // Away from a speck the firmament is exactly the gradient.
        if Shaders.speckCoverage(height: 0, horizontal: 0.123, angle: 0) == 0 {
            #expect(Self.distance(bottom, Palette.night) < 1e-12)
        }
        if Shaders.speckCoverage(height: 1, horizontal: 0.123, angle: 0) == 0 {
            #expect(Self.distance(top, Palette.nightTop) < 1e-12)
        }
        // Under 5 % of the firmament's pixels carry a speck, at several turns; some do.
        let angles: [Double] = [0, 0.7, 2.5, 100]
        let columns: Int = 400
        let rows: Int = 240
        for angle in angles {
            var specked: Int = 0
            var gradientDeviation: Double = 0
            for row in 0..<rows {
                let h: Double = (Double(row) + 0.5) / Double(rows)
                for column in 0..<columns {
                    let s: Double = -1 + 2 * (Double(column) + 0.5) / Double(columns)
                    if Shaders.speckCoverage(height: h, horizontal: s, angle: angle) > 0 {
                        specked += 1
                    } else {
                        let c: SIMD3<Double> = Shaders.firmamentColour(height: h, horizontal: s, angle: angle)
                        let g: SIMD3<Double> = Palette.night + (Palette.nightTop - Palette.night) * h
                        gradientDeviation = max(gradientDeviation, Self.distance(c, g))
                    }
                }
            }
            let share: Double = Double(specked) / Double(rows * columns)
            #expect(share < 0.05, "angle \(angle): \(share)")
            #expect(share > 0.001, "angle \(angle): \(share)")
            #expect(gradientDeviation < 1e-12)
        }
        // The specks turn with the angle about the vertical axis: a turn by δ shifts them by δ / span in s.
        let delta: Double = 0.1
        var compared: Int = 0
        var mismatched: Int = 0
        for row in 0..<120 {
            let h: Double = (Double(row) + 0.5) / 120
            for column in 0..<200 {
                let s: Double = -0.8 + 1.6 * (Double(column) + 0.5) / 200
                let a: Double = Shaders.speckCoverage(height: h, horizontal: s, angle: 0.3)
                let b: Double = Shaders.speckCoverage(height: h, horizontal: s - delta / Shaders.skySpan,
                                                      angle: 0.3 + delta)
                if a > 0 || b > 0 { compared += 1 }
                if abs(a - b) > 1e-6 { mismatched += 1 }
            }
        }
        #expect(compared > 0)
        #expect(Double(mismatched) <= Double(compared) * 0.02)
        // A different angle moves the specks (the firmament visibly turns).
        var moved: Int = 0
        for row in 0..<37 {
            let h: Double = (Double(row) + 0.5) / 37
            for column in 0..<400 {
                let s: Double = -1 + 2 * (Double(column) + 0.5) / 400
                let a: Double = Shaders.speckCoverage(height: h, horizontal: s, angle: 0)
                let b: Double = Shaders.speckCoverage(height: h, horizontal: s, angle: 0.05)
                if abs(a - b) > 1e-6 { moved += 1 }
            }
        }
        #expect(moved > 0)
        #expect(Shaders.speckCoverage(height: Double.nan, horizontal: Double.nan, angle: Double.nan) >= 0)
        let fragment: String = Shaders.chartFragment
        let lines: [String] = [
            "float turn = mod(u_firmamentAngle, SC_TAU);",
            "cell.x = mod(cell.x, SC_CELLS_AROUND);",
            "float speck = step(1.0 - SC_SPECK_DENSITY, pick);",
            "vec3 gradient = mix(SC_NIGHT, SC_NIGHT_TOP, h);",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func firmamentAngleRule() {
        #expect(Shaders.firmamentTurnRate == 0.02)
        let times: [Double] = [0, 0.5, 1, 10, 100, 3_600, 86_400]
        for time in times {
            #expect(Shaders.firmamentAngle(time: time, reduceMotion: true) == 0)
            #expect(abs(Shaders.firmamentAngle(time: time, reduceMotion: false) - 0.02 * time) < 1e-12)
        }
        let odd: [Double] = [Double.nan, Double.infinity, -Double.infinity, Double.greatestFiniteMagnitude,
                             -Double.greatestFiniteMagnitude, -5]
        for time in odd {
            #expect(Shaders.firmamentAngle(time: time, reduceMotion: false).isFinite, "\(time)")
            #expect(Shaders.firmamentAngle(time: time, reduceMotion: true) == 0, "\(time)")
        }
        #expect(Shaders.firmamentAngle(time: Double.nan, reduceMotion: false) == 0)
        #expect(Shaders.firmamentAngle(time: Double.infinity, reduceMotion: false) == 0)
    }

    @Test func aWonLevelFlaresTheTrailsAndSealsTheCartouche() {
        #expect(Self.distance(Shaders.trailColour(along: 1, won: 0), Palette.trail) < 1e-12)
        let flared: SIMD3<Double> = Shaders.trailColour(along: 1, won: 1)
        let expected: SIMD3<Double> = Palette.trail + (Palette.trailGlow - Palette.trail) * Shaders.flareLift
        #expect(Self.distance(flared, expected) < 1e-12)
        #expect(Shaders.trailColour(along: 1, won: Double.nan) == Shaders.trailColour(along: 1, won: 0))
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let rest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .trail, factor: 1, radius: 0, gain: 1, won: 0)
        let won: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .trail, factor: 1, radius: 0, gain: 1, won: 1)
        #expect(won.w > rest.w)
        #expect(abs(rest.w - Shaders.glowWeight * Shaders.trailRest) < 1e-12)
        #expect(abs(won.w - Shaders.glowWeight) < 1e-12)
        #expect(SIMD3<Double>(won.x, won.y, won.z) == Palette.trailGlow)
        let star: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .star, factor: 1, radius: 0, gain: 1, won: 0)
        #expect(SIMD3<Double>(star.x, star.y, star.z) == Palette.glow)
        let ship: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .ship, factor: 1, radius: 0, gain: 1, won: 0)
        #expect(SIMD3<Double>(ship.x, ship.y, ship.z) == Palette.shipGlow)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .star, factor: 1, radius: 1, gain: 1, won: 0)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .star)
        #expect(Shaders.GlowKind.decode(9).kind == .trail)
        let glowLine: String =
            "float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, mix(SC_TRAIL_REST, 1.0, won), isTrail);"
        #expect(Shaders.glowFragment.contains(glowLine))
        let fragment: String = Shaders.chartFragment
        let lines: [String] = [
            "rgb = mix(rgb, SC_TRAIL_GLOW, SC_FLARE_LIFT * won * isGolden);",
            "float isGolden = isCode(m, 5.0) + isCode(m, 6.0) + isCode(m, 14.0);",
            "rgb = mix(rgb, SC_TRAIL, SC_SEAL_LIFT * won * isCode(m, 12.0));",
            "coverage = coverage * mix(1.0, mix(SC_GRID_ALPHA, 1.0, SC_SEAL_LIFT * won), isCode(m, 12.0));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in StarlitCartoucheTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowGain(for: StarlitCartoucheTier.of(2)) == 0)
        #expect(Shaders.glowLimit(reduceFlashing: false) == Shaders.standardGlowLimit)
        #expect(Shaders.glowLimit(reduceFlashing: true) == Shaders.glowGainCap)
        #expect(Shaders.glowGainCap == 0.5)
        #expect(Shaders.glowLimit(reduceFlashing: true) < Shaders.glowLimit(reduceFlashing: false))
        for gain in gains {
            #expect(gain <= Shaders.glowLimit(reduceFlashing: false))
            #expect(gain <= Shaders.maxGlowGain)
            let capped: Double = Shaders.glowGain(gain: gain, limit: Shaders.glowLimit(reduceFlashing: true))
            #expect(capped <= Shaders.glowGainCap)
            let glow: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .trail, factor: 1,
                                                         radius: 0, gain: capped, won: 1)
            #expect(glow.w <= Shaders.glowWeight * Shaders.glowGainCap + 1e-12)
        }
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        let line: String =
            "float gain = min(clamp(u_glowGain, 0.0, SC_MAX_GAIN), clamp(u_glowLimit, 0.0, SC_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(line))
    }

    /// The source file itself: no framework import the core must not have, no denylisted name, lines ≤ 120 characters.
    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("StarlitCartoucheShaders.swift")
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
            .appendingPathComponent("sc-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "chart.vert", source: Shaders.chartVertex), (name: "chart.frag", source: Shaders.chartFragment),
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
