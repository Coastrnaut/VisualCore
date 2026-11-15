# Contract: A10-P04 additions

## NeonArcadeCore
- `Sensitivity` — `static let reaches: [Double]`, `static let defaultStep = 2`, `static func steering(offset: Double,
  step: Int) -> Double`.
- `HighScoreEntry`, `HighScoreTable` — `static let boardVersion = 1`, `maxEntries = 10`; `mutating func enter(_:) ->
  Int?` (rank or nil); `validate() -> [String]`; `encoded() -> Data`; `static func decode(_:) -> Result`.
- `ArcadeAnnouncements` — `static func texts(for cues: [EffectCue], run: GameRun, newHighScore: Bool) -> [String]`.

## Experience
- Action `settings.sensitivity [0…4]`; snapshot schema 4; `ArcadeCore.schemaThreeExample()`.
- `HighScoreStore` — `init(storage: ExperienceStorage?)`, `table`, `problem: String?`, `record(run:) -> Int?`.
