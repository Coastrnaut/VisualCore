# Contract: Light Maze solver and content QA (feature 100)

```swift
public enum SolverRefusal: Equatable, Sendable { case invalidBoard(BoardRefusal); case tooManyTiles(Int) }
public enum SolverResult: Equatable, Sendable {
    case solved(orientations: [Orientation], turns: Int, examined: Int)
    case unsolvable(examined: Int)
    case refused(SolverRefusal)
}
public enum Solver {
    public static let maxTurnable = 16
    public static func solve(_ board: Board) -> SolverResult        // from the board's own orientations
}
public enum QACheck: String, CaseIterable, Sendable { case unsolvable, wrongSolution = "wrong-solution",
    longerSolution = "longer-solution", solvedStart = "solved-start", noLicense = "no-license" }
public struct LevelQA: Equatable, Sendable { public let id: String; public let fewestTurns: Int?;
    public let recordedTurns: Int; public let failures: [QACheck]; public var passes: Bool }
public enum ContentQA {
    public static func check(_ level: Level) -> LevelQA
    public static func results(_ catalog: LevelCatalog) -> [LevelQA]
    public static func markdown(_ catalog: LevelCatalog) -> String  // docs/apps/light-maze/content-qa.md
}
```

Turns of a set = number of turnable tiles whose orientation differs from the start. `recordedTurns` = turns of the
level's recorded solution.
