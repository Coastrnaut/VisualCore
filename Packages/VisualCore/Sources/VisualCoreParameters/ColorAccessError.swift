// ColorAccessError — feature 210 (R02-F10) T-R02F10-002 (FR-R02F10-011; clarification Q5; research R11). Why a colour
// or a set of coded states was refused. Every case has a stable `reasonCode` that names the feature (`r2-f10.*`) and the
// case carries the offending index or ids; the consuming experience adds its app id, seed and tick when it reports.

/// A refused colour or coded-state set (see the file header).
public enum ColorAccessError: Error, Equatable, Sendable {
    /// Colour `index` has a component that is not finite.
    case nonFinite(index: Int)
    /// Colour `index` has an sRGB component outside 0…1.
    case outOfRange(index: Int)
    /// The two states with these ids share both shape and pattern.
    case sameClue(String, String)
    /// State `index` has a name that is empty after trimming, or longer than 40 characters.
    case emptyName(index: Int)
    /// Two states share this name.
    case duplicateName(String)
    /// Two states share this id, or the id is not `^[a-z0-9-]{1,40}$`.
    case duplicateID(String)
    /// The set has `count` states; at most `limit` are allowed.
    case tooManyStates(count: Int, limit: Int)

    /// The stable reason code: `r2-f10.non-finite`, `r2-f10.out-of-range`, `r2-f10.same-clue`, `r2-f10.empty-name`,
    /// `r2-f10.duplicate-name`, `r2-f10.duplicate-id` or `r2-f10.too-many-states`.
    public var reasonCode: String {
        switch self {
        case .nonFinite: "r2-f10.non-finite"
        case .outOfRange: "r2-f10.out-of-range"
        case .sameClue: "r2-f10.same-clue"
        case .emptyName: "r2-f10.empty-name"
        case .duplicateName: "r2-f10.duplicate-name"
        case .duplicateID: "r2-f10.duplicate-id"
        case .tooManyStates: "r2-f10.too-many-states"
        }
    }
}
