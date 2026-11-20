// PuzzleCatalogChecker — feature 224 (R02-F24) T-R02F24-004 (FR-R02F24-003; clarification Q3; SC-R02F24-002). Checks a
// finished catalog: re-certifies every level, finds repeated identities, compares each stored difficulty with its
// certificate, applies the progression rule to every neighbour pair of stored difficulties and recomputes the digest.
// Every issue is reported in position order (all issues of one position before those of the next), the digest issue
// last; the same catalog always gives the same report.

/// One problem the checker found in a catalog.
public enum PuzzleCatalogIssue: Sendable, Equatable {
    /// The level at this position does not certify; the payload is its verdict.
    case uncertified(index: Int, verdict: PuzzleVerdict)
    /// The level at this position has the same content (identity without the seed) as the level at position `first`.
    case duplicate(index: Int, first: Int)
    /// The stored difficulty at this position differs from the one its certificate gives.
    case difficultyMismatch(index: Int)
    /// The level at this position is shorter than its predecessor by more than the rule's maximum drop.
    case drop(index: Int)
    /// The level at this position is longer than its predecessor by more than the rule's maximum jump.
    case jump(index: Int)
    /// The stored digest differs from the digest of the catalog's id and entries.
    case digestMismatch
}

/// The result of checking a catalog: every issue found, in position order.
public struct PuzzleCatalogReport: Sendable, Equatable {
    /// The issues found, in position order, a digest mismatch last.
    public let issues: [PuzzleCatalogIssue]

    /// Whether the catalog has no issue.
    public var passes: Bool { issues.isEmpty }

    /// A report of the given issues.
    public init(issues: [PuzzleCatalogIssue]) {
        self.issues = issues
    }
}

/// Checks finished puzzle catalogs.
public enum PuzzleCatalogChecker {
    /// Checks a catalog against its rules and a progression rule.
    ///
    /// For each position in order: the level is certified (`.uncertified` unless valid); an identity seen at an
    /// earlier position is a `.duplicate`; a valid level whose certificate difficulty differs from the stored one is a
    /// `.difficultyMismatch`; from position 1 on, the stored shortest length against its predecessor's is a `.drop` or
    /// a `.jump` when it breaks the rule. A digest that differs from the recomputed one is reported last.
    public static func check<R: PuzzleRules>(_ catalog: PuzzleCatalog<R>, rules: R,
                                             rule: ProgressionRule) -> PuzzleCatalogReport {
        var issues: [PuzzleCatalogIssue] = []
        var firstIndex: [String: Int] = [:]
        var identities: [String] = []
        identities.reserveCapacity(catalog.entries.count)
        for (i, entry) in catalog.entries.enumerated() {
            let certificate = PuzzleValidator.certify(entry.level, rules: rules)
            if certificate.verdict != .valid {
                issues.append(.uncertified(index: i, verdict: certificate.verdict))
            }
            let identity = entry.level.identity
            let key = entry.level.contentKey
            if let first = firstIndex[key] {
                issues.append(.duplicate(index: i, first: first))
            } else {
                firstIndex[key] = i
            }
            if certificate.verdict == .valid, PuzzleDifficulty(certificate: certificate) != entry.difficulty {
                issues.append(.difficultyMismatch(index: i))
            }
            if i >= 1 {
                let previous = catalog.entries[i - 1].difficulty.shortest
                let next = entry.difficulty.shortest
                if next < previous - rule.maxDrop {
                    issues.append(.drop(index: i))
                } else if next > previous + rule.maxJump {
                    issues.append(.jump(index: i))
                }
            }
            identities.append(identity)
        }
        if PuzzleCatalog<R>.digest(id: catalog.id, identities: identities) != catalog.digest {
            issues.append(.digestMismatch)
        }
        return PuzzleCatalogReport(issues: issues)
    }
}
