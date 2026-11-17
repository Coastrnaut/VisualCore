// GLSLTokenizer — feature 159 (A22-P01) T-A22-108 (FR-A22-105; clarification Q4). The editor model's syntax
// tokens: the source is split into lines on `\n`, `\r\n` and `\r`, and each line into tokens whose texts rebuild the
// line exactly. Kinds are matched in the order of clarification Q4: comment (`//` to the end of the line, `/* … */`
// cut at line ends and continued on the next line, an unclosed one running to the end of the source), preprocessor
// (a line whose first non-blank character is `#`), number, keyword, type, built-in function, built-in variable,
// identifier, operator, punctuation and whitespace. The scan works on the UTF-8 bytes in one forward pass with at
// most three bytes of look-ahead, so it is linear in the source length (no regular expressions). Pure Swift; no UI
// framework, GL call, clock or network.

/// The syntax class of one token of GLSL ES 3.00 source.
public enum TokenKind: String, Sendable, CaseIterable {
    /// A `//` line comment or (a line's part of) a `/* … */` block comment.
    case comment
    /// A preprocessor directive: from the `#` that starts a line up to a comment or the end of the line.
    case preprocessor
    /// An integer or floating literal: decimal, `0x` hexadecimal, fractions, exponents and `u`/`U`/`f`/`F` suffixes.
    case number
    /// A GLSL ES 3.00 control, qualifier or precision word, or a boolean literal (`GLSLTokenizer.keywords`).
    case keyword
    /// A GLSL ES 3.00 basic type name (`GLSLTokenizer.types`).
    case type
    /// A GLSL ES 3.00 built-in function name (`GLSLTokenizer.builtinFunctions`).
    case builtinFunction
    /// A GLSL ES 3.00 built-in variable or constant (`GLSLTokenizer.builtinVariables`).
    case builtinVariable
    /// Any other name: a letter or `_` followed by letters, digits or `_`.
    case identifier
    /// An operator, longest match first (`<<=` before `<<` before `<`).
    case operatorSymbol
    /// Brackets, `;`, `,`, `.` and any other character, including a run of non-ASCII characters outside a comment.
    case punctuation
    /// A run of spaces, tabs, vertical tabs and form feeds.
    case whitespace
}

/// One token of one line: its kind, its text and where that text lies in the line.
public struct Token: Sendable, Equatable {
    /// The syntax class.
    public let kind: TokenKind
    /// The exact characters of the token.
    public let text: String
    /// The token's UTF-8 byte offsets within its line (never across a line end, never inside a multi-byte character).
    public let range: Range<Int>

    /// Creates a token.
    public init(kind: TokenKind, text: String, range: Range<Int>) {
        self.kind = kind
        self.text = text
        self.range = range
    }
}

/// Splits GLSL ES 3.00 source into lines and classifies each line's characters into tokens.
///
/// **Line rule.** `\r\n`, `\n` and `\r` each end a line, and the terminators are not part of any line. Every
/// terminator starts a new line, as a text editor shows it: `"a\nb"` and `"a\r\nb"` are two lines, `"a\nb\n"` is three
/// (the last one empty, where the cursor goes after the final newline), and the empty source is one empty line. So the
/// line count is always the terminator count plus one, line *n* is the compiler's line *n*, and joining the lines
/// with `\n` rebuilds the source with its line ends normalised.
public enum GLSLTokenizer {
    /// GLSL ES 3.00 control, storage, interpolation, precision and other qualifier words, plus `true` and `false`.
    public static let keywords: Set<String> = [
        "attribute", "const", "uniform", "varying", "layout", "centroid", "flat", "smooth", "break", "continue",
        "do", "for", "while", "switch", "case", "default", "if", "else", "in", "out", "inout", "invariant", "discard",
        "return", "lowp", "mediump", "highp", "precision", "struct", "true", "false",
    ]

    /// GLSL ES 3.00 basic types: scalars, vectors, matrices and opaque sampler types.
    public static let types: Set<String> = [
        "void", "bool", "int", "uint", "float",
        "vec2", "vec3", "vec4", "bvec2", "bvec3", "bvec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4",
        "mat2", "mat3", "mat4", "mat2x2", "mat2x3", "mat2x4", "mat3x2", "mat3x3", "mat3x4", "mat4x2", "mat4x3",
        "mat4x4",
        "sampler2D", "sampler3D", "samplerCube", "sampler2DShadow", "samplerCubeShadow", "sampler2DArray",
        "sampler2DArrayShadow", "isampler2D", "isampler3D", "isamplerCube", "isampler2DArray", "usampler2D",
        "usampler3D", "usamplerCube", "usampler2DArray",
    ]

    /// GLSL ES 3.00 built-in functions (angle, exponential, common, packing, geometric, matrix, vector relational,
    /// texture lookup and fragment derivative functions).
    public static let builtinFunctions: Set<String> = [
        "radians", "degrees", "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh", "asinh", "acosh",
        "atanh", "pow", "exp", "log", "exp2", "log2", "sqrt", "inversesqrt", "abs", "sign", "floor", "trunc", "round",
        "roundEven", "ceil", "fract", "mod", "modf", "min", "max", "clamp", "mix", "step", "smoothstep", "isnan",
        "isinf", "floatBitsToInt", "floatBitsToUint", "intBitsToFloat", "uintBitsToFloat", "packSnorm2x16",
        "unpackSnorm2x16", "packUnorm2x16", "unpackUnorm2x16", "packHalf2x16", "unpackHalf2x16", "length",
        "distance", "dot", "cross", "normalize", "faceforward", "reflect", "refract", "matrixCompMult",
        "outerProduct", "transpose", "determinant", "inverse", "lessThan", "lessThanEqual", "greaterThan",
        "greaterThanEqual", "equal", "notEqual", "any", "all", "not", "textureSize", "texture", "textureProj",
        "textureLod", "textureOffset", "texelFetch", "texelFetchOffset", "textureProjOffset", "textureLodOffset",
        "textureProjLod", "textureProjLodOffset", "textureGrad", "textureGradOffset", "textureProjGrad",
        "textureProjGradOffset", "dFdx", "dFdy", "fwidth",
    ]

    /// GLSL ES 3.00 built-in variables and built-in constants.
    public static let builtinVariables: Set<String> = [
        "gl_FragCoord", "gl_FrontFacing", "gl_FragDepth", "gl_PointCoord", "gl_VertexID", "gl_InstanceID",
        "gl_Position", "gl_PointSize", "gl_DepthRange", "gl_MaxVertexAttribs", "gl_MaxVertexUniformVectors",
        "gl_MaxVertexOutputVectors", "gl_MaxFragmentInputVectors", "gl_MaxVertexTextureImageUnits",
        "gl_MaxCombinedTextureImageUnits", "gl_MaxTextureImageUnits", "gl_MaxFragmentUniformVectors",
        "gl_MaxDrawBuffers", "gl_MinProgramTexelOffset", "gl_MaxProgramTexelOffset",
    ]

    /// Operators, longest first within each starting character, so the first match is the longest.
    static let operators: [[UInt8]] = ([
        "<<=", ">>=", "++", "--", "<<", ">>", "<=", ">=", "==", "!=", "&&", "||", "^^", "+=", "-=", "*=", "/=", "%=",
        "&=", "|=", "^=", "+", "-", "*", "/", "%", "<", ">", "=", "!", "~", "&", "|", "^", "?", ":",
    ] as [String]).map { Array($0.utf8) }

    /// The source's lines without their terminators, by the line rule of `GLSLTokenizer`.
    public static func lines(of source: String) -> [String] {
        let bytes = Array(source.utf8)
        return lineRanges(bytes).map { String(decoding: bytes[$0], as: UTF8.self) }
    }

    /// The tokens of each line of the source (one array per element of `lines(of:)`), continuing a block comment
    /// from one line to the next; an unclosed block comment makes the rest of the source comment tokens.
    public static func tokenize(_ source: String) -> [[Token]] {
        split(source).map(\.tokens)
    }

    /// The tokens of a single line read on its own (outside any block comment); a line terminator in `line`, if
    /// any, is classified as punctuation.
    public static func tokens(of line: String) -> [Token] {
        let bytes = Array(line.utf8)
        var inBlock = false
        return scan(bytes, 0..<bytes.count, inBlockComment: &inBlock)
    }

    /// Each line's text and tokens in one pass over the source; the editor document is built from it.
    static func split(_ source: String) -> [(text: String, tokens: [Token])] {
        let bytes = Array(source.utf8)
        var inBlock = false
        return lineRanges(bytes).map { range in
            (String(decoding: bytes[range], as: UTF8.self), scan(bytes, range, inBlockComment: &inBlock))
        }
    }

    /// The byte ranges of the lines (terminators excluded); always at least one range.
    static func lineRanges(_ bytes: [UInt8]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0, i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x0A || b == 0x0D {
                ranges.append(start..<i)
                i += (b == 0x0D && i + 1 < bytes.count && bytes[i + 1] == 0x0A) ? 2 : 1
                start = i
            } else {
                i += 1
            }
        }
        ranges.append(start..<bytes.count)
        return ranges
    }

    /// Tokenizes `bytes[range]` (one line), with offsets relative to `range.lowerBound`. `inBlockComment` says
    /// whether the line starts inside a block comment and, on return, whether the next one does.
    static func scan(_ bytes: [UInt8], _ range: Range<Int>, inBlockComment: inout Bool) -> [Token] {
        var tokens: [Token] = []
        let base = range.lowerBound, end = range.upperBound
        var i = base
        var lineStart = !inBlockComment    // true while only whitespace has been seen on a line not opened in a comment
        func at(_ k: Int) -> UInt8 { k < end ? bytes[k] : 0 }
        func emit(_ kind: TokenKind, _ from: Int, _ to: Int) {
            tokens.append(Token(kind: kind, text: String(decoding: bytes[from..<to], as: UTF8.self),
                                range: (from - base)..<(to - base)))
        }
        while i < end {
            let start = i
            if inBlockComment {
                while i < end && !(bytes[i] == 0x2A && at(i + 1) == 0x2F) { i += 1 }    // `*/`
                if i < end { i += 2; inBlockComment = false }
                emit(.comment, start, i)
                continue
            }
            let b = bytes[i]
            if b == 0x2F && at(i + 1) == 0x2F {                                        // `//`
                emit(.comment, start, end)
                i = end
            } else if b == 0x2F && at(i + 1) == 0x2A {                                 // `/*`
                i += 2
                inBlockComment = true
                while i < end && !(bytes[i] == 0x2A && at(i + 1) == 0x2F) { i += 1 }
                if i < end { i += 2; inBlockComment = false }
                emit(.comment, start, i)
            } else if b == 0x23 && lineStart {                                         // `#` first on the line
                while i < end && !(bytes[i] == 0x2F && (at(i + 1) == 0x2F || at(i + 1) == 0x2A)) { i += 1 }
                emit(.preprocessor, start, i)
            } else if isBlank(b) {
                while i < end && isBlank(bytes[i]) { i += 1 }
                emit(.whitespace, start, i)
                continue    // whitespace keeps `lineStart`
            } else if isDigit(b) || (b == 0x2E && isDigit(at(i + 1))) {
                i = scanNumber(bytes, i, end)
                emit(.number, start, i)
            } else if isIdentifierHead(b) {
                while i < end && isIdentifierBody(bytes[i]) { i += 1 }
                let word = String(decoding: bytes[start..<i], as: UTF8.self)
                emit(classify(word), start, i)
            } else if let op = operators.first(where: { matches($0, bytes, i, end) }) {
                i += op.count
                emit(.operatorSymbol, start, i)
            } else if b >= 0x80 {
                while i < end && bytes[i] >= 0x80 { i += 1 }    // whole UTF-8 characters, never split
                emit(.punctuation, start, i)
            } else {
                i += 1
                emit(.punctuation, start, i)
            }
            lineStart = false
        }
        return tokens
    }

    /// The end of the number starting at `i`: `0x` hex digits, or digits with an optional fraction and exponent,
    /// then an optional `u`/`U` (integers) or `f`/`F` (floats) suffix.
    static func scanNumber(_ bytes: [UInt8], _ start: Int, _ end: Int) -> Int {
        var i = start
        func at(_ k: Int) -> UInt8 { k < end ? bytes[k] : 0 }
        if bytes[i] == 0x30 && (at(i + 1) == 0x78 || at(i + 1) == 0x58) && isHexDigit(at(i + 2)) {
            i += 2
            while i < end && isHexDigit(bytes[i]) { i += 1 }
            if at(i) == 0x75 || at(i) == 0x55 { i += 1 }
            return i
        }
        var isFloat = false
        while i < end && isDigit(bytes[i]) { i += 1 }
        if at(i) == 0x2E {
            isFloat = true
            i += 1
            while i < end && isDigit(bytes[i]) { i += 1 }
        }
        if at(i) == 0x65 || at(i) == 0x45 {                                            // `e` / `E`
            let sign = at(i + 1) == 0x2B || at(i + 1) == 0x2D
            if isDigit(at(i + (sign ? 2 : 1))) {
                isFloat = true
                i += sign ? 2 : 1
                while i < end && isDigit(bytes[i]) { i += 1 }
            }
        }
        if isFloat {
            if at(i) == 0x66 || at(i) == 0x46 { i += 1 }
        } else if at(i) == 0x75 || at(i) == 0x55 {
            i += 1
        }
        return i
    }

    /// The kind of a name: keyword, type, built-in function, built-in variable or plain identifier.
    static func classify(_ word: String) -> TokenKind {
        if keywords.contains(word) { return .keyword }
        if types.contains(word) { return .type }
        if builtinFunctions.contains(word) { return .builtinFunction }
        if builtinVariables.contains(word) { return .builtinVariable }
        return .identifier
    }

    @inline(__always) static func matches(_ op: [UInt8], _ bytes: [UInt8], _ i: Int, _ end: Int) -> Bool {
        guard i + op.count <= end else { return false }
        for k in 0..<op.count where bytes[i + k] != op[k] { return false }
        return true
    }

    @inline(__always) static func isBlank(_ b: UInt8) -> Bool { b == 0x20 || b == 0x09 || b == 0x0B || b == 0x0C }
    @inline(__always) static func isDigit(_ b: UInt8) -> Bool { b >= 0x30 && b <= 0x39 }
    @inline(__always) static func isHexDigit(_ b: UInt8) -> Bool {
        isDigit(b) || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66)
    }
    @inline(__always) static func isIdentifierHead(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b == 0x5F
    }
    @inline(__always) static func isIdentifierBody(_ b: UInt8) -> Bool { isIdentifierHead(b) || isDigit(b) }
}
