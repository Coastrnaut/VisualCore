// VoxelOrigamiShaderSourceTests — feature 443 (R02-G15-03) T-R02G1503-003 (FR-R02G1503-001, 002, 004; clarifications
// Q1–Q5). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared uniform
// listed (equal to the uniform name constants the scene sets) and used in its stage, at most 16 vec4 uniform slots per
// program, no texture sampler, no `discard`, no unbounded loop (any `for` bounded by an int constant), vertex outputs
// matching fragment inputs, balanced braces, ASCII-only sources, the `ShaderMeshRenderer` attribute names and
// locations, the material codes distinct, ordered 0 … 13 and each selected by the vertex shader with its palette
// colour, the GLSL palette constants parsing back to `VoxelOrigamiPalette` within 1/255 (and 1e-6), the soft edge,
// frost, bevel, faceted light and stripe references, the won target flare, the glow gain per tier (0 at level-2) and
// the Reduce Flashing cap, and, when `glslangValidator` is installed, a real front-end compile of each source (skipped
// otherwise). The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the
// attributes `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer`
// streams. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiShaderSourceTests {
    typealias Shaders = VoxelOrigamiShaders
    typealias Palette = VoxelOrigamiPalette
    typealias Material = VoxelOrigamiShaders.Material

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "voxel", vertex: Shaders.voxelVertex, fragment: Shaders.voxelFragment,
                 uniforms: Shaders.voxelUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.voxelVertex, Shaders.voxelFragment, Shaders.glowVertex, Shaders.glowFragment]
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
        #expect(Set(constants) == Set(Shaders.voxelUniforms + Shaders.glowUniforms))
        #expect(Shaders.voxelUniforms == ["u_mvp", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.voxelVertex) == ["u_mvp", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.voxelFragment).isEmpty)
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
        #expect(slotsByProgram == ["voxel": 5, "glow": 7])
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
        let voxelOuts: [String: String] = [
            "v_base": "vec3", "v_normal": "vec3", "v_material": "float", "v_local": "float", "v_won": "float",
        ]
        #expect(Self.interface("out", in: Shaders.voxelVertex) == voxelOuts)
        let glowOuts: [String: String] = ["v_colour": "vec3", "v_kind": "float", "v_factor": "float",
                                          "v_radius": "float"]
        #expect(Self.interface("out", in: Shaders.glowVertex) == glowOuts)
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in Shaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.voxelVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.voxelFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        // Both programs read every attribute: the voxel program lights the cubes from the normal, the glow program
        // reads its colour from it.
        let vertices: [String] = [Shaders.voxelVertex, Shaders.glowVertex]
        for vertex in vertices {
            for attribute in Shaders.attributes {
                #expect(Self.wordCount(attribute.name, in: vertex) >= 2, "\(attribute.name) unread")
            }
        }
        let voxel: String = Shaders.voxelVertex
        let voxelLines: [String] = [
            "float m = clamp(floor(a_uv.x + 0.5), 0.0, VO_MAX_MATERIAL);",
            "v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - plain);",
            "v_normal = a_normal;",
        ]
        for line in voxelLines { #expect(voxel.contains(line), "\(line)") }
        let glow: String = Shaders.glowVertex
        #expect(glow.contains("v_colour = clamp(a_normal, 0.0, 1.0);"))
        #expect(glow.contains("float kind = clamp(floor(x * 0.5), 0.0, 1.0);"))
        #expect(glow.contains("v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);"))
        #expect(glow.contains("v_radius = clamp(a_uv.y, 0.0, 1.0);"))
    }

    @Test func shaderPaletteConstantsMatchTheCPUPalette() throws {
        let tolerance: Double = 0.000001
        let byte: Double = 1.0 / 255.0
        let palette: [(name: String, colour: SIMD3<Double>)] = [
            (name: "VO_NIGHT", colour: Palette.night), (name: "VO_IVORY", colour: Palette.ivory),
            (name: "VO_IVORY_SHADE", colour: Palette.ivoryShade), (name: "VO_TARGET", colour: Palette.target),
            (name: "VO_TARGET_GLOW", colour: Palette.targetGlow), (name: "VO_HINGE", colour: Palette.hinge),
            (name: "VO_HINGE_CHOSEN", colour: Palette.hingeChosen), (name: "VO_GLYPH_SOLID", colour: Palette.glyphSolid),
            (name: "VO_GLYPH_HOLLOW", colour: Palette.glyphHollow), (name: "VO_DOTS", colour: Palette.dots),
            (name: "VO_COVERED_LIT", colour: Palette.coveredLit),
            (name: "VO_COVERED_UNLIT", colour: Palette.coveredUnlit),
            (name: "VO_MOVES_LIT", colour: Palette.movesLit), (name: "VO_MOVES_UNLIT", colour: Palette.movesUnlit),
            (name: "VO_BROKEN", colour: Palette.broken), (name: "VO_GLOW", colour: Palette.glow),
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
                #expect(Self.distance(parsed, entry.colour) <= byte, "\(entry.name)")
            }
            #expect(found >= 1, "\(entry.name) is in no source")
        }
        #expect(tableNames.count == palette.count)
        // Every vec3 constant in every source is a palette colour with the table's value, or the light direction.
        for source in Self.sources() {
            for line in Self.lines(source) where line.hasPrefix("const vec3 ") {
                let name: String = Self.tokens(line)[2]
                let parsed: SIMD3<Double> = try #require(Self.vec3Constant(name, in: source), "\(line)")
                if name == "VO_LIGHT_DIR" {
                    #expect(Self.distance(parsed, Shaders.lightDirection) <= tolerance)
                    continue
                }
                #expect(tableNames.contains(name), "\(name) is not in the palette table")
                for constant in Shaders.paletteConstants where constant.name == name {
                    #expect(Self.distance(parsed, constant.colour) <= tolerance, "\(name)")
                }
            }
        }
        // The design's hex values (clarification Q3), six decimals.
        let vertex: String = Shaders.voxelVertex
        #expect(vertex.contains("const vec3 VO_NIGHT = vec3(0.043137, 0.050980, 0.086275);"))
        #expect(vertex.contains("const vec3 VO_IVORY = vec3(0.929412, 0.909804, 0.862745);"))
        #expect(vertex.contains("const vec3 VO_HINGE_CHOSEN = vec3(1.000000, 0.235294, 0.549020);"))
        let fragment: String = Shaders.voxelFragment
        let glowF: String = Shaders.glowFragment
        let floats: [(name: String, value: Double, source: String)] = [
            (name: "VO_FLARE_LIFT", value: Shaders.flareLift, source: vertex),
            (name: "VO_MAX_MATERIAL", value: 13, source: vertex),
            (name: "VO_EDGE_FEATHER", value: Shaders.edgeFeather, source: fragment),
            (name: "VO_FROST_START", value: Shaders.frostStart, source: fragment),
            (name: "VO_FROST_EDGE", value: Shaders.frostEdge, source: fragment),
            (name: "VO_BEVEL_SHEEN", value: Shaders.bevelSheen, source: fragment),
            (name: "VO_AMBIENT", value: Shaders.ambient, source: fragment),
            (name: "VO_DIFFUSE", value: Shaders.diffuse, source: fragment),
            (name: "VO_STRIPE_COUNT", value: Shaders.stripeCount, source: fragment),
            (name: "VO_STRIPE_DUTY", value: Shaders.stripeDuty, source: fragment),
            (name: "VO_GLOW_WEIGHT", value: Shaders.glowWeight, source: glowF),
            (name: "VO_TARGET_REST", value: Shaders.targetRest, source: glowF),
            (name: "VO_MAX_GAIN", value: Shaders.maxGlowGain, source: glowF),
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
            "backdrop", "targetEdge", "cubeFace", "cubeBevel", "glyphSolid", "glyphHollow", "dots", "hinge",
            "hingeChosen", "coveredLit", "coveredUnlit", "movesLit", "movesUnlit", "broken",
        ]
        #expect(names == expectedNames)
        #expect(Set(codes).count == codes.count)
        for (index, code) in codes.enumerated() { #expect(code == Float(index), "\(names[index])") }
        let vertex: String = Shaders.voxelVertex
        for material in Material.allCases where material != .backdrop {
            let selector: String = "isCode(m, \(Int(material.code)).0)"
            #expect(vertex.contains(selector), "\(material) not selected")
        }
        let flare: String = "vec3 base = mix(VO_NIGHT, mix(VO_TARGET, VO_TARGET_GLOW, VO_FLARE_LIFT * won), isCode(m, 1.0));"
        #expect(vertex.contains(flare))
        let selections: [(material: Material, constant: String)] = [
            (material: .cubeFace, constant: "VO_IVORY"), (material: .cubeBevel, constant: "VO_IVORY_SHADE"),
            (material: .glyphSolid, constant: "VO_GLYPH_SOLID"), (material: .glyphHollow, constant: "VO_GLYPH_HOLLOW"),
            (material: .dots, constant: "VO_DOTS"), (material: .hinge, constant: "VO_HINGE"),
            (material: .hingeChosen, constant: "VO_HINGE_CHOSEN"), (material: .coveredLit, constant: "VO_COVERED_LIT"),
            (material: .coveredUnlit, constant: "VO_COVERED_UNLIT"), (material: .movesLit, constant: "VO_MOVES_LIT"),
            (material: .movesUnlit, constant: "VO_MOVES_UNLIT"), (material: .broken, constant: "VO_BROKEN"),
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
        #expect(Material.backdrop.colour == Palette.night)
        #expect(Material.targetEdge.colour == Palette.target)
        var solid: [Material] = []
        var lit: [Material] = []
        for material in Material.allCases {
            if material.isSolid { solid.append(material) }
            if material.isLit { lit.append(material) }
        }
        #expect(solid == [.backdrop, .cubeFace, .cubeBevel])
        #expect(lit == [.cubeFace, .cubeBevel])
        #expect(Material.backdrop.localCoordinate == .none)
        #expect(Material.hingeChosen.localCoordinate == .along)
        #expect(Material.cubeFace.localCoordinate == .fan)
        #expect(Material.dots.localCoordinate == .fan)
        #expect(Material.targetEdge.localCoordinate == .strip)
        #expect(Material.glyphHollow.localCoordinate == .strip)
        // The fragment shader treats exactly the solid materials as opaque and lights exactly the lit ones.
        let fragment: String = Shaders.voxelFragment
        #expect(fragment.contains("float solid = isCode(m, 0.0) + isFace + isBevel;"))
        #expect(fragment.contains("rgb = rgb * mix(1.0, lambert, isFace + isBevel);"))
    }

    @Test func signedDistanceShadingReferences() {
        #expect(Shaders.edgeCoverage(local: 0) == 1)
        #expect(Shaders.edgeCoverage(local: 0.5) == 1)
        #expect(Shaders.edgeCoverage(local: -1) == 0)
        #expect(Shaders.edgeCoverage(local: Double.nan) == 0)
        // The chosen hinge's centre is hot pink; stripes alternate along the bar.
        #expect(Shaders.stripeCoverage(local: 0) == 1)
        #expect(Shaders.stripeCoverage(local: Double.nan) == 1)
        #expect(Shaders.stripeCoverage(local: -1) == 0)
        var pink: Int = 0
        var grey: Int = 0
        for step in 0..<200 {
            let local: Double = -1 + 2 * (Double(step) + 0.5) / 200
            if Shaders.stripeCoverage(local: local) == 1 { pink += 1 } else { grey += 1 }
        }
        #expect(abs(Double(pink) / 200 - Shaders.stripeDuty) < 0.02)
        #expect(grey > 0)
        // Faceted light: brightest facing the light, ambient facing away, within ambient … 1.
        #expect(abs(Shaders.light(normal: Shaders.lightDirection) - 1) < 1e-12)
        #expect(Shaders.light(normal: -Shaders.lightDirection) == Shaders.ambient)
        #expect(Shaders.light(normal: SIMD3<Double>(0, 0, 0)) == Shaders.ambient)
        #expect(Shaders.light(normal: SIMD3<Double>(Double.nan, 0, 1)) == Shaders.ambient)
        let up: Double = Shaders.light(normal: SIMD3<Double>(0, 1, 0))
        let side: Double = Shaders.light(normal: SIMD3<Double>(1, 0, 0))
        #expect(up > side)
        #expect(Shaders.ambient + Shaders.diffuse <= 1)
        // Frosted face: ivory at the centre under full light, darker toward its outline; bevel sheen on its ridge.
        let centre: SIMD3<Double> = Shaders.cubeShade(material: .cubeFace, normal: Shaders.lightDirection, local: 0)
        #expect(Self.distance(centre, Palette.ivory) < 1e-12)
        let rim: SIMD3<Double> = Shaders.cubeShade(material: .cubeFace, normal: Shaders.lightDirection, local: 1)
        #expect(rim.x < centre.x)
        let ridge: SIMD3<Double> = Shaders.cubeShade(material: .cubeBevel, normal: Shaders.lightDirection, local: 0)
        let side2: SIMD3<Double> = Shaders.cubeShade(material: .cubeBevel, normal: Shaders.lightDirection, local: 1)
        #expect(ridge.x > side2.x)
        #expect(Self.distance(side2, Palette.ivoryShade) < 1e-12)
        #expect(Shaders.cubeShade(material: .dots, normal: Shaders.lightDirection, local: 0) == Palette.dots)
        // A dimly lit face stays brighter than the night backdrop (the frame check's cube margin is 0.25).
        let dim: SIMD3<Double> = Shaders.cubeShade(material: .cubeFace, normal: -Shaders.lightDirection, local: 0)
        let weights: SIMD3<Double> = SIMD3<Double>(0.2126, 0.7152, 0.0722)
        #expect((dim * weights).sum() - (Palette.night * weights).sum() >= 0.25)
        let fragment: String = Shaders.voxelFragment
        let lines: [String] = [
            "float edge = 1.0 - smoothstep(1.0 - VO_EDGE_FEATHER, 1.0, d);",
            "vec3 face = mix(VO_IVORY, VO_IVORY_SHADE, VO_FROST_EDGE * smoothstep(VO_FROST_START, 1.0, d));",
            "vec3 bevel = mix(VO_IVORY_SHADE, VO_IVORY, VO_BEVEL_SHEEN * (1.0 - d));",
            "float lambert = VO_AMBIENT + VO_DIFFUSE * max(dot(n, VO_LIGHT_DIR), 0.0) * step(0.0001, nl);",
            "float stripe = 1.0 - step(VO_STRIPE_DUTY * 0.5, abs(phase - 0.5));",
            "rgb = mix(rgb, VO_HINGE, (1.0 - stripe) * isCode(m, 8.0));",
        ]
        for line in lines { #expect(fragment.contains(line), "\(line)") }
    }

    @Test func aWonLevelFlaresTheTargetAndItsGlow() {
        #expect(Shaders.targetColour(won: 0) == Palette.target)
        let flared: SIMD3<Double> = Shaders.targetColour(won: 1)
        let expected: SIMD3<Double> = Palette.target + (Palette.targetGlow - Palette.target) * Shaders.flareLift
        #expect(Self.distance(flared, expected) < 1e-12)
        #expect(Shaders.targetColour(won: Double.nan) == Palette.target)
        let zero: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        let rest: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .target, factor: 1, radius: 0, gain: 1, won: 0)
        let won: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .target, factor: 1, radius: 0, gain: 1, won: 1)
        #expect(won.w > rest.w)
        #expect(abs(rest.w - Shaders.glowWeight * Shaders.targetRest) < 1e-12)
        #expect(abs(won.w - Shaders.glowWeight) < 1e-12)
        #expect(SIMD3<Double>(won.x, won.y, won.z) == Palette.targetGlow)
        let cube: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cube, factor: 1, radius: 0, gain: 1, won: 0)
        #expect(cube.w > 0)
        #expect(SIMD3<Double>(cube.x, cube.y, cube.z) == Palette.glow)
        let outer: SIMD4<Double> = Shaders.glowColour(colour: zero, kind: .cube, factor: 1, radius: 1, gain: 1, won: 0)
        #expect(outer.w == 0)
        for kind in Shaders.GlowKind.allCases {
            let decoded: (kind: Shaders.GlowKind, factor: Double) = Shaders.GlowKind.decode(kind.code(factor: 0.25))
            #expect(decoded.kind == kind)
            #expect(abs(decoded.factor - 0.25) < 1e-12)
        }
        #expect(Shaders.GlowKind.decode(Double.nan).kind == .cube)
        #expect(Shaders.GlowKind.decode(9).kind == .target)
        let line: String = "float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, mix(VO_TARGET_REST, 1.0, won), isTarget);"
        #expect(Shaders.glowFragment.contains(line))
    }

    @Test func glowGainFollowsTheTierAndReduceFlashingCapsIt() {
        var gains: [Double] = []
        for tier in VoxelOrigamiTier.all { gains.append(Shaders.glowGain(for: tier)) }
        #expect(gains == [1.5, 1.0, 0])
        #expect(Shaders.glowLimit(reduceFlashing: false) == Shaders.standardGlowLimit)
        #expect(Shaders.glowLimit(reduceFlashing: true) == Shaders.glowGainCap)
        #expect(Shaders.glowGainCap == 0.5)
        #expect(Shaders.glowLimit(reduceFlashing: true) < Shaders.glowLimit(reduceFlashing: false))
        for gain in gains {
            #expect(gain <= Shaders.glowLimit(reduceFlashing: false))
            #expect(gain <= Shaders.maxGlowGain)
            let capped: Double = Shaders.glowGain(gain: gain, limit: Shaders.glowLimit(reduceFlashing: true))
            #expect(capped <= Shaders.glowGainCap)
            let glow: SIMD4<Double> = Shaders.glowColour(colour: SIMD3<Double>(0, 0, 0), kind: .target, factor: 1,
                                                         radius: 0, gain: capped, won: 1)
            #expect(glow.w <= Shaders.glowWeight * Shaders.glowGainCap + 1e-12)
        }
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        let line: String = "float gain = min(clamp(u_glowGain, 0.0, VO_MAX_GAIN), clamp(u_glowLimit, 0.0, VO_MAX_GAIN));"
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
            .appendingPathComponent("vo-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "voxel.vert", source: Shaders.voxelVertex), (name: "voxel.frag", source: Shaders.voxelFragment),
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

    /// A won level lifts the lit cube faces and bevels toward white by the fallback's lift, at every tier.
    @Test func aWonLevelLiftsTheCubesLikeTheFallback() {
        #expect(VoxelOrigamiShaders.wonLift == VoxelOrigamiSceneGeometry.wonLift)
        #expect(VoxelOrigamiShaders.voxelFragment.contains("VO_WON_LIFT"))
        let normal: SIMD3<Double> = SIMD3(0, 0, 1)
        let materials: [VoxelOrigamiShaders.Material] = [.cubeFace, .cubeBevel]
        for material in materials {
            let plain: SIMD3<Double> = VoxelOrigamiShaders.cubeShade(material: material, normal: normal, local: 0.5)
            let won: SIMD3<Double> = VoxelOrigamiShaders.cubeShade(material: material, normal: normal, local: 0.5,
                                                                   won: 1)
            #expect(won.x > plain.x && won.y > plain.y && won.z > plain.z)
            #expect(won.x <= 1 && won.y <= 1 && won.z <= 1)
        }
    }

}
