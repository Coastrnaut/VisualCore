// SyntaxPalette — feature 161 (A22-P03) T-A22-304 (FR-A22-301, FR-A22-306; clarification Q1; data-model.md
// "SyntaxPalette"). The pure mapping from a `GLSLTokenizer` token kind to the editor's style: a colour role and an
// emphasis. Colour is never the only cue (Principle IX): keywords are bold and comments italic, and emphasis is a
// separate dimension from colour (several kinds share the regular emphasis but differ in colour).
//
// `apply(_:to:)` recolours an `AttributedString` in place from an `EditorDocument` of the same text, walking the
// Unicode scalars (token boundaries never split a scalar; a `\r\n` terminator is two scalars), so the text itself is
// never changed and the editor's selection stays valid (`AttributedString.transform(updating:)`). The SwiftUI colours
// and fonts of a role are chosen here too, from system colours that adapt to light, dark and increased contrast.
import Foundation
import ShaderStudioCore
import SwiftUI
import UIKit

/// The colour role of a token kind in the editor.
enum SyntaxColorRole: String, CaseIterable, Sendable {
    /// Names, whitespace and anything without a special colour.
    case plain
    /// Control, qualifier and precision words.
    case keyword
    /// Basic type names.
    case type
    /// Built-in functions.
    case function
    /// Built-in variables and constants.
    case variable
    /// Numeric literals.
    case number
    /// Comments.
    case comment
    /// Preprocessor directives.
    case preprocessor
    /// Operators and punctuation.
    case symbol
}

/// The emphasis of a token kind, a cue besides colour.
enum SyntaxEmphasis: String, CaseIterable, Sendable {
    /// Regular weight, upright.
    case regular
    /// Bold weight (keywords).
    case bold
    /// Italic (comments).
    case italic
}

/// The editor style of one token kind: a colour role and an emphasis.
struct SyntaxStyle: Equatable, Sendable {
    /// The colour role.
    var role: SyntaxColorRole
    /// The emphasis.
    var emphasis: SyntaxEmphasis
}

/// Maps token kinds to editor styles and recolours editor text (see the file header).
enum SyntaxPalette {
    /// The style of `kind`: keywords bold, comments italic, every other kind regular, each kind in its colour role.
    static func style(for kind: TokenKind) -> SyntaxStyle {
        switch kind {
        case .keyword: return SyntaxStyle(role: .keyword, emphasis: .bold)
        case .comment: return SyntaxStyle(role: .comment, emphasis: .italic)
        case .type: return SyntaxStyle(role: .type, emphasis: .regular)
        case .builtinFunction: return SyntaxStyle(role: .function, emphasis: .regular)
        case .builtinVariable: return SyntaxStyle(role: .variable, emphasis: .regular)
        case .number: return SyntaxStyle(role: .number, emphasis: .regular)
        case .preprocessor: return SyntaxStyle(role: .preprocessor, emphasis: .regular)
        case .operatorSymbol, .punctuation: return SyntaxStyle(role: .symbol, emphasis: .regular)
        case .identifier, .whitespace: return SyntaxStyle(role: .plain, emphasis: .regular)
        }
    }

    /// The colour of `role`: adaptive system colours (light, dark and increased contrast).
    static func color(for role: SyntaxColorRole) -> Color {
        switch role {
        case .plain: return Color(uiColor: .label)
        case .keyword: return Color(uiColor: .systemPink)
        case .type: return Color(uiColor: .systemTeal)
        case .function: return Color(uiColor: .systemIndigo)
        case .variable: return Color(uiColor: .systemPurple)
        case .number: return Color(uiColor: .systemOrange)
        case .comment: return Color(uiColor: .secondaryLabel)
        case .preprocessor: return Color(uiColor: .systemBrown)
        case .symbol: return Color(uiColor: .label)
        }
    }

    /// The editor's monospaced font at `size` points with `emphasis`.
    static func font(size: CGFloat, emphasis: SyntaxEmphasis) -> Font {
        let base = Font.system(size: size, design: .monospaced)
        switch emphasis {
        case .regular: return base
        case .bold: return base.weight(.bold)
        case .italic: return base.italic()
        }
    }

    /// Recolours `text` in place from `document`, which must describe the same characters (`String(text.characters)`
    /// is the document's source). The characters are not changed. A document that does not match (more scalars than
    /// the text holds) stops the walk at the text's end.
    static func apply(_ document: EditorDocument, to text: inout AttributedString, fontSize: CGFloat) {
        let scalars = text.unicodeScalars
        var index = text.startIndex
        for line in document.lines {
            for token in line.tokens {
                let count = token.text.unicodeScalars.count
                guard let end = scalars.index(index, offsetBy: count, limitedBy: text.endIndex) else { return }
                let style = style(for: token.kind)
                text[index..<end].foregroundColor = color(for: style.role)
                text[index..<end].font = font(size: fontSize, emphasis: style.emphasis)
                index = end
            }
            // Skip the line's terminator: `\r\n` is two scalars, `\n` or `\r` one, none after the last line.
            guard index < text.endIndex else { return }
            let first = scalars[index]
            index = scalars.index(after: index)
            if first == "\r", index < text.endIndex, scalars[index] == "\n" { index = scalars.index(after: index) }
        }
    }

    /// `source` as an attributed string coloured by its document.
    static func highlighted(_ source: String, fontSize: CGFloat) -> AttributedString {
        var text = AttributedString(source)
        apply(EditorDocument(source: source), to: &text, fontSize: fontSize)
        return text
    }
}
