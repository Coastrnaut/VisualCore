// DefineSet.swift — validated `#define` sets for shader expansion (feature 206 T-R02F06-002; FR-R02F06-002,
// research R3). Contract: specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// A name matches `[A-Za-z_][A-Za-z0-9_]*` and does not start with `GL_` or `__` (GLSL ES 3.00 §3.4 reserves both);
// a value is a single line of at most 256 characters; a set holds at most 32 defines.

/// Why a define set was refused (FR-R02F06-002).
public enum DefineError: Error, Equatable, Sendable {
    /// The name is not a GLSL identifier (`[A-Za-z_][A-Za-z0-9_]*`).
    case invalidName(String)
    /// The name starts with the reserved prefix `GL_` or `__`.
    case reservedName(String)
    /// The value of the named define contains a line break or is longer than 256 characters.
    case invalidValue(String)
    /// The set holds more than 32 defines; the associated value is the count given.
    case tooMany(Int)
}

/// A validated set of preprocessor defines, emitted as sorted `#define NAME VALUE` lines.
public struct DefineSet: Equatable, Sendable {
    /// Maximum number of defines per shader (32).
    public static let maxDefines = 32
    /// Maximum length of a define value in characters (256).
    public static let maxValueLength = 256

    /// The defines, name to value.
    public let defines: [String: String]

    /// The empty set.
    public static let empty = DefineSet(validated: [:])

    /// Validates `defines`; names are checked in sorted order, so the first offending name is deterministic.
    public init(_ defines: [String: String]) throws(DefineError) {
        guard defines.count <= Self.maxDefines else { throw .tooMany(defines.count) }
        for name in defines.keys.sorted() {
            try Self.validate(name: name, value: defines[name]!)
        }
        self.defines = defines
    }

    /// Wraps defines already checked by `validate(name:value:)` (variant combinations).
    init(validated defines: [String: String]) { self.defines = defines }

    /// Define names in sorted order.
    public var names: [String] { defines.keys.sorted() }

    /// The `#define NAME VALUE` lines in name order, as the expander emits them.
    public var lines: [String] { names.map { "#define \($0) \(defines[$0]!)" } }

    /// Checks one name and its value against the rules of FR-R02F06-002.
    public static func validate(name: String, value: String) throws(DefineError) {
        guard isIdentifier(name) else { throw .invalidName(name) }
        guard !name.hasPrefix("GL_"), !name.hasPrefix("__") else { throw .reservedName(name) }
        guard value.count <= maxValueLength,
              !value.unicodeScalars.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "\u{2028}" || $0 == "\u{2029}" })
        else { throw .invalidValue(name) }
    }

    private static func isIdentifier(_ name: String) -> Bool {
        let scalars = Array(name.unicodeScalars)
        guard let first = scalars.first, first.isASCII, first == "_" || first.properties.isAlphabetic else { return false }
        return scalars.allSatisfy { $0.isASCII && ($0 == "_" || $0.properties.isAlphabetic || ("0"..."9").contains($0)) }
    }
}
