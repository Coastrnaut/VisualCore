// ShaderLibrary.swift — named GLSL ES 3.00 sources with #include expansion and a line map
// (feature 004 T-F305; FR-F301–FR-F303, FR-F317). Contract:
// specs/002-architecture-contracts/contracts/resources-shaders-errors.md §Shaders.
//
import Foundation

// Expanded layout: line 1 `#version 300 es` (from the main source, or generated), then one generated
// `#define` line per define (sorted by name), then the content with every `#include "name"` replaced
// recursively. Every expanded line maps back to (file, line); generated lines map to `<generated>`.

/// Where an expanded line came from.
public struct SourceOrigin: Sendable, Equatable, Hashable, Codable {
    /// Source name the line came from, or `<generated>` for synthesized lines.
    public let file: String
    /// 1-based line in `file`; 0 for generated lines.
    public let line: Int
    /// Creates an origin for 1-based `line` of `file`.
    public init(file: String, line: Int) { self.file = file; self.line = line }
    /// Origin of synthesized lines (`#version`, `#define`): file `<generated>`, line 0.
    public static let generated = SourceOrigin(file: "<generated>", line: 0)
}

/// Rejections before any GPU work (FR-F302, FR-F317).
public enum ShaderSourceError: Error, Equatable, Sendable {
    case tooLarge(Int)
    case tooDeep(Int)
    case cycle([String])
    case unknownInclude(String, file: String, line: Int)
    case unsupportedVersion(file: String, line: Int)
    case unknownSource(String)
}

/// The result of expansion: GLSL text plus a line map.
public struct ExpandedShader: Sendable, Equatable {
    /// Expanded GLSL ES 3.00 text, lines joined with `\n`, at most 64 KiB of UTF-8.
    public let text: String
    /// `origins[i]` is the origin of expanded line `i + 1`.
    public let origins: [SourceOrigin]
    /// Defines in the order they were emitted (sorted by name).
    public let defines: [String]

    /// Origin of a 1-based expanded line; `<generated>` when out of range.
    public func origin(ofExpandedLine line: Int) -> SourceOrigin {
        guard line >= 1, line <= origins.count else { return .generated }
        return origins[line - 1]
    }
}

/// Named GLSL ES 3.00 sources expanded with `#include "name"` (depth ≤ 8, ≤ 64 KiB) and injected `#define`s.
public struct ShaderLibrary: Sendable {
    /// Maximum UTF-8 size of an expanded shader (64 KiB); larger results throw `tooLarge`.
    public static let maxExpandedBytes = 64 * 1024
    /// Maximum `#include` nesting depth (8); deeper nesting throws `tooDeep`.
    public static let maxIncludeDepth = 8
    /// The only accepted version directive, emitted as expanded line 1.
    public static let versionLine = "#version 300 es"

    private var sources: [String: String] = [:]

    /// Creates an empty library.
    public init() {}

    /// Registers `text` under `name`, replacing any source already registered with that name.
    public mutating func add(_ name: String, _ text: String) { sources[name] = text }

    /// Whether a source is registered under `name`.
    public func contains(_ name: String) -> Bool { sources[name] != nil }

    /// Expands a named source.
    public func expand(_ name: String, defines: [String: String] = [:]) throws(ShaderSourceError) -> ExpandedShader {
        guard let text = sources[name] else { throw .unknownSource(name) }
        return try expand(source: text, named: name, defines: defines)
    }

    /// Expands an inline source whose includes resolve against this library.
    public func expand(source text: String, named name: String, defines: [String: String] = [:]) throws(ShaderSourceError) -> ExpandedShader {
        var lines: [String] = []
        var origins: [SourceOrigin] = []
        var body = splitLines(text)
        // Version: an explicit first non-empty line must be exactly GLSL ES 3.00.
        var versionOrigin = SourceOrigin.generated
        if let first = body.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           body[first].trimmingCharacters(in: .whitespaces).hasPrefix("#version") {
            guard isES300(body[first]) else { throw .unsupportedVersion(file: name, line: first + 1) }
            versionOrigin = SourceOrigin(file: name, line: first + 1)
            body[first] = ""   // keep numbering; the version line is emitted first below
            if first == 0 { body.removeFirst() } else { body[first] = "" }
            lines.append(Self.versionLine)
            origins.append(versionOrigin)
            let emittedDefines = defineLines(defines)
            lines += emittedDefines
            origins += Array(repeating: .generated, count: emittedDefines.count)
            try append(lines: body, from: name, startingAt: first == 0 ? 2 : 1, stack: [name], into: &lines, origins: &origins)
        } else {
            lines.append(Self.versionLine)
            origins.append(.generated)
            let emittedDefines = defineLines(defines)
            lines += emittedDefines
            origins += Array(repeating: .generated, count: emittedDefines.count)
            try append(lines: body, from: name, startingAt: 1, stack: [name], into: &lines, origins: &origins)
        }
        let result = lines.joined(separator: "\n")
        let bytes = result.utf8.count
        guard bytes <= Self.maxExpandedBytes else { throw .tooLarge(bytes) }
        return ExpandedShader(text: result, origins: origins, defines: defineLines(defines))
    }

    private func append(lines body: [String], from file: String, startingAt firstLine: Int, stack: [String],
                        into lines: inout [String], origins: inout [SourceOrigin]) throws(ShaderSourceError) {
        for (offset, line) in body.enumerated() {
            let lineNumber = firstLine + offset
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#version") { throw .unsupportedVersion(file: file, line: lineNumber) }
            if let include = includeName(trimmed) {
                if stack.contains(include) { throw .cycle(stack + [include]) }
                guard let text = sources[include] else { throw .unknownInclude(include, file: file, line: lineNumber) }
                let depth = stack.count   // main file has depth 0, its includes depth 1, ...
                guard depth <= Self.maxIncludeDepth else { throw .tooDeep(depth) }
                try append(lines: splitLines(text), from: include, startingAt: 1, stack: stack + [include], into: &lines, origins: &origins)
                // Size guard during expansion so pathological includes stop early.
                if lines.count > Self.maxExpandedBytes { throw .tooLarge(lines.joined(separator: "\n").utf8.count) }
                continue
            }
            lines.append(line)
            origins.append(SourceOrigin(file: file, line: lineNumber))
        }
    }

    private func includeName(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("#include") else { return nil }
        let rest = trimmed.dropFirst("#include".count).trimmingCharacters(in: .whitespaces)
        guard rest.count >= 2, rest.first == "\"", rest.last == "\"" else { return nil }
        return String(rest.dropFirst().dropLast())
    }

    private func isES300(_ line: String) -> Bool {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init) == ["#version", "300", "es"]
    }

    private func defineLines(_ defines: [String: String]) -> [String] {
        defines.keys.sorted().map { "#define \($0) \(defines[$0]!)" }
    }

    private func splitLines(_ text: String) -> [String] {
        var parts = text.components(separatedBy: "\n")
        if parts.last == "" { parts.removeLast() }   // a trailing newline does not add a line
        return parts
    }
}
