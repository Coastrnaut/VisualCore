// ExperienceDescriptor — feature 187 T-U01-006 (FR-U01-010, FR-U01-020, FR-U01-021; data-model section 2).
import Foundation

/// What the purchase gate reads: free forever, or part of the premium library.
public enum ExperienceTier: String, Sendable, Equatable, CaseIterable {
    /// Free forever, for everyone.
    case free
    /// Part of the premium library.
    case premium
}

/// The two kinds of experience.
public enum ExperienceKind: String, Sendable, Equatable, CaseIterable {
    /// A creative experience (the original apps A01–A25).
    case creative
    /// A game of a round.
    case game
}

/// The seven launcher categories, in launcher order.
public enum ExperienceCategory: String, Sendable, Equatable, CaseIterable {
    /// Creative and visual tools.
    case create
    /// Music and audio.
    case audio
    /// Games and interactive experiences among the originals.
    case play
    /// Education and science.
    case learn
    /// Ambient and lifestyle.
    case ambient
    /// Developer and creator tools.
    case tools
    /// The puzzle games of the rounds.
    case puzzle
}

/// Content facts of a game whose level catalog is bundled.
public struct ExperienceContent: Sendable, Equatable {
    /// The number of bundled levels (0 to 10,000).
    public let levels: Int
    /// The SHA-256 of the bundled level catalog: 64 lower-case hexadecimal digits.
    public let catalogSHA256: String

    /// Creates content facts. The loader checks the ranges; this initializer does not.
    public init(levels: Int, catalogSHA256: String) {
        self.levels = levels
        self.catalogSHA256 = catalogSHA256
    }
}

/// One validated entry of the runtime catalog.
public struct ExperienceDescriptor: Sendable, Equatable, Identifiable {
    /// The immutable runtime id.
    public let id: ExperienceID
    /// The display name (1 to 80 characters).
    public let title: String
    /// One sentence about the experience (1 to 300 characters).
    public let summary: String
    /// Creative experience or game.
    public let kind: ExperienceKind
    /// Free or premium.
    public let tier: ExperienceTier
    /// The launcher category; a game is always `puzzle`, a creative experience never is.
    public let category: ExperienceCategory
    /// The family the experience belongs to, as display text.
    public let family: String
    /// Search tags; they contain the family in tag form.
    public let tags: [String]
    /// The catalog order (1 to 9,999); unique and ascending in a manifest.
    public let order: Int
    /// Colors the launcher draws the tile from, each `#RRGGBB`; empty until the experience is registered.
    public let palette: [String]
    /// The seed the launcher draws the tile from; derived from the id.
    public let tileSeed: UInt32
    /// Declared capabilities such as `microphone` or `export-image`; empty until the experience is registered.
    public let capabilities: [String]
    /// Declared quality tier names; empty until the experience is registered.
    public let qualityTiers: [String]
    /// Content facts of a registered game; `nil` otherwise.
    public let content: ExperienceContent?
    /// True only when the integration gate of the experience is pass in the migration ledger.
    public let isAvailable: Bool

    /// The catalog code inside the id.
    public var code: ExperienceCode { id.code }

    /// The tag form of a family: lower case, groups of ASCII letters and digits joined by single hyphens
    /// ("Wave mathematics" becomes `wave-mathematics`).
    public static func tag(forFamily family: String) -> String {
        var groups: [String] = []
        var current = ""
        for byte in family.lowercased().utf8 {
            if (97...122).contains(byte) || (48...57).contains(byte) {
                current.unicodeScalars.append(Unicode.Scalar(byte))
            } else if !current.isEmpty {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups.joined(separator: "-")
    }
}
